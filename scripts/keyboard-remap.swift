import Foundation
import IOKit.hid
import AppKit
import ApplicationServices

private let logURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Logs/macomrade/keyboard-remap.log")
private let configURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/macomrade/keyboard-remap.json")
private var pressedUsages = Set<UInt32>()
private var lastTriggerByUsage = [UInt32: Date]()

private func log(_ message: String) {
    let directory = logURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

// MARK: - Dynamic configuration
//
// Not specific to any keyboard brand or model: which HID receiver to match
// (device.vendor_id/product_id) is itself part of this config file, so
// pointing this app at a different keyboard is a config edit, not a
// recompile. F1/F2/F3 each have a plain action and a Control-or-Command-
// modified action; F5 (media-app fallback chain) and F12 (screenshot) keep
// their bespoke logic below and stay out of this file since they're unlikely
// to change and don't fit a plain "usage -> app path" table.

private struct DeviceConfig: Codable {
    var vendorId: String
    var productId: String

    enum CodingKeys: String, CodingKey {
        case vendorId = "vendor_id"
        case productId = "product_id"
    }
}

private struct KeyboardActionConfig: Codable {
    var device: DeviceConfig
    var singles: [String: String]
    var modified: [String: String]
}

private let defaultConfigJSON = """
{
  "device": {
    "vendor_id": "0x046d",
    "product_id": "0xc534"
  },
  "singles": {
    "F1": "/Applications/ChatGPT.app",
    "F2": "/Applications/Antigravity.app",
    "F3": "/Applications/Deepseek Harness Desktop.app"
  },
  "modified": {
    "F1": "/Applications/Claude.app",
    "F2": "/Applications/OpenCode.app",
    "F3": "/Applications/Perplexity.app"
  }
}
"""

private func loadConfig() -> KeyboardActionConfig {
    let decoder = JSONDecoder()
    let fallback = { () -> KeyboardActionConfig in
        // The embedded default is trusted input; force-unwrap is safe here.
        try! decoder.decode(KeyboardActionConfig.self, from: defaultConfigJSON.data(using: .utf8)!)
    }

    if !FileManager.default.fileExists(atPath: configURL.path) {
        let directory = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try defaultConfigJSON.data(using: .utf8)?.write(to: configURL, options: .atomic)
            log("No keyboard config found; wrote default to \(configURL.path)")
        } catch {
            log("Unable to write default keyboard config to \(configURL.path): \(error)")
        }
        return fallback()
    }

    guard let data = try? Data(contentsOf: configURL),
          let config = try? decoder.decode(KeyboardActionConfig.self, from: data) else {
        log("Unable to read/parse \(configURL.path); falling back to built-in default")
        return fallback()
    }
    return config
}

private func parseHex(_ value: String) -> Int? {
    var trimmed = value.trimmingCharacters(in: .whitespaces)
    if trimmed.lowercased().hasPrefix("0x") {
        trimmed.removeFirst(2)
    }
    return Int(trimmed, radix: 16)
}

private var config = loadConfig()

// USB HID Keyboard/Keypad page (0x07) usage codes this listener cares about.
// These are standard HID usages defined by the USB HID spec, not specific to
// any keyboard model.
private let usageF1: UInt32 = 0x3a
private let usageF2: UInt32 = 0x3b
private let usageF3: UInt32 = 0x3c
private let usageF5: UInt32 = 0x3e
private let usageF12: UInt32 = 0x45
private let usageLeftControl: UInt32 = 0xe0
private let usageRightControl: UInt32 = 0xe4
private let usageLeftCommand: UInt32 = 0xe3
private let usageRightCommand: UInt32 = 0xe7
private let modifierUsages: Set<UInt32> = [usageLeftControl, usageRightControl, usageLeftCommand, usageRightCommand]
private let watchedUsages: Set<UInt32> = Set([usageF1, usageF2, usageF3, usageF5, usageF12])
    .union(modifierUsages)

// MARK: - Actions

private func openApp(_ path: String, context: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", path]
    do {
        try process.run()
        log("\(context): opened \(path)")
    } catch {
        log("\(context): failed to open \(path): \(error)")
    }
}

private func runF5Action() {
    let standardYouTube = "/Applications/YouTube.app"
    let playCoverYouTube = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Applications/PlayCover/YouTube.app").path
    if FileManager.default.fileExists(atPath: standardYouTube) {
        openApp(standardYouTube, context: "F5")
    } else if FileManager.default.fileExists(atPath: playCoverYouTube + "/YouTube") {
        if activateRunningApplication(bundleIdentifier: "com.google.ios.youtube") {
            log("F5 received; activated existing PlayCover YouTube")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: playCoverYouTube + "/YouTube")
        do {
            try process.run()
            log("F5: launched PlayCover YouTube")
        } catch {
            log("F5: failed to launch PlayCover YouTube: \(error)")
        }
    } else {
        openApp("/System/Applications/Music.app", context: "F5 (fallback)")
    }
}

private func runF12Action() {
    openApp("/System/Applications/Utilities/Screenshot.app", context: "F12")
}

private func activateRunningApplication(bundleIdentifier: String) -> Bool {
    guard let application = NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .first else {
        return false
    }

    // Activation alone does not reliably restore a window minimized with the
    // yellow button. Unhide the app first, then clear AXMinimized on its
    // windows before activating it, matching the behavior of native apps.
    application.unhide()
    var restoredWindow = false
    let axApplication = AXUIElementCreateApplication(application.processIdentifier)
    var windowsValue: CFTypeRef?
    let copyResult = AXUIElementCopyAttributeValue(
        axApplication,
        kAXWindowsAttribute as CFString,
        &windowsValue
    )
    if copyResult == .success, let windows = windowsValue as? [AXUIElement] {
        for window in windows {
            if AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            ) == .success {
                restoredWindow = true
            }
        }
    } else if copyResult != .success {
        log("Unable to inspect PlayCover YouTube windows for restoration: AXError \(copyResult.rawValue)")
    }

    let activated = application.activate(options: [.activateAllWindows])
    log("Restored existing PlayCover YouTube window: restored=\(restoredWindow) activated=\(activated)")
    return activated || restoredWindow
}

// MARK: - F-key + modifier handling
//
// F1/F2/F3 each fire immediately: no chord window, no "which key came first"
// ambiguity, and no two-F-key combos. Control and Command are tracked as
// ordinary keys via pressedUsages (both generate independent HID usage
// down/up events on this page, just like F1-F3), and whichever table
// (singles or modified) applies is picked at the moment the F-key goes down.

private func handleFKey(_ name: String) {
    let modifierHeld = !pressedUsages.isDisjoint(with: modifierUsages)
    let table = modifierHeld ? config.modified : config.singles
    guard let app = table[name] else { return }
    openApp(app, context: modifierHeld ? "\(name)+modifier" : "\(name) solo")
}

private func handleKeyDown(_ usage: UInt32) {
    switch usage {
    case usageF1:
        handleFKey("F1")
    case usageF2:
        handleFKey("F2")
    case usageF3:
        handleFKey("F3")
    case usageF5:
        runF5Action()
    case usageF12:
        runF12Action()
    case usageLeftControl, usageRightControl, usageLeftCommand, usageRightCommand:
        break // modifier state only; presence is read via pressedUsages
    default:
        break
    }
}

// MARK: - HID plumbing

private func inputValueCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ value: IOHIDValue
) {
    let element = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)

    guard usagePage == 0x07, watchedUsages.contains(usage) else { return }

    let isDown = IOHIDValueGetIntegerValue(value) != 0
    if isDown {
        let now = Date()
        let lastTrigger = lastTriggerByUsage[usage] ?? .distantPast
        guard !pressedUsages.contains(usage), now.timeIntervalSince(lastTrigger) > 0.5 else { return }
        pressedUsages.insert(usage)
        lastTriggerByUsage[usage] = now
        handleKeyDown(usage)
    } else {
        pressedUsages.remove(usage)
    }
}

// MARK: - Menu bar UI

private final class StatusMenuController: NSObject {
    private var statusItem: NSStatusItem?

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard Remap")

        let menu = NSMenu()
        menu.addItem(menuItem("Reload Config", #selector(reloadConfig)))
        menu.addItem(menuItem("Open Config in Editor", #selector(openConfig)))
        menu.addItem(menuItem("View Log", #selector(openLog)))
        menu.addItem(.separator())
        menu.addItem(menuItem("About Keyboard Remap", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit", #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    private func menuItem(_ title: String, _ action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func reloadConfig() {
        config = loadConfig()
        log("Config reloaded from menu bar: device=\(config.device) singles=\(config.singles) modified=\(config.modified)")
    }

    // Prefer plain text editors over whatever the system has associated with
    // .json/.log (which can be Xcode) — TextEdit first, VS Code as a
    // fallback, then whatever NSWorkspace resolves as a last resort.
    private func openInTextEditor(_ url: URL) {
        let candidates = [
            "/System/Applications/TextEdit.app",
            "/Applications/Visual Studio Code.app"
        ]
        for appPath in candidates where FileManager.default.fileExists(atPath: appPath) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: URL(fileURLWithPath: appPath),
                configuration: configuration
            )
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openConfig() {
        openInTextEditor(configURL)
    }

    @objc private func openLog() {
        openInTextEditor(logURL)
    }

    @objc private func showAbout() {
        let bundleInfo = Bundle.main.infoDictionary
        let version = bundleInfo?["CFBundleShortVersionString"] as? String ?? "unknown"

        let alert = NSAlert()
        alert.messageText = "Keyboard Remap"
        alert.informativeText = "Version \(version)\nDeveloper: xxvk"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        let repoURLString = "https://github.com/xxvk/macomrade"
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 18))
        let attributed = NSMutableAttributedString(string: repoURLString)
        let fullRange = NSRange(location: 0, length: (repoURLString as NSString).length)
        attributed.addAttribute(.link, value: repoURLString, range: fullRange)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), range: fullRange)
        textView.textStorage?.setAttributedString(attributed)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        alert.accessoryView = textView

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

private let statusMenuController = StatusMenuController()
statusMenuController.setup()

guard let vendorId = parseHex(config.device.vendorId), let productId = parseHex(config.device.productId) else {
    log("Invalid device.vendor_id/product_id in \(configURL.path); expected hex strings like \"0x046d\"")
    exit(1)
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: vendorId,
    kIOHIDProductIDKey as String: productId
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
IOHIDManagerRegisterInputValueCallback(manager, inputValueCallback, nil)
// .commonModes (not just .defaultMode) so HID events keep flowing while the
// status item's menu is open and the run loop is in tracking mode.
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
    log("Unable to open HID receiver \(config.device.vendorId):\(config.device.productId); grant Input Monitoring permission if needed")
    exit(1)
}

log("Listening for receiver \(config.device.vendorId):\(config.device.productId) F1, F2, F3, F5, F12, plus Control/Command modifiers; config at \(configURL.path)")
app.run()
