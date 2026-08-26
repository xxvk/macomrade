# Keyboard and Logitech hardware

Load this reference only when the current task uses this domain. Its rules were moved verbatim from the original skill entry point during RC-05.

## Contents

- Keyboard settings workflow
- Logitech K240 profile
- Logitech MX Keys Mac profile
- F1–F3, F5, and F12 native listener implementation
- Known keyboard limitations
- Logitech K240/M212 battery telemetry

## Keyboard settings workflow

Keyboard configuration has a dedicated entry point and must not be scattered
through app component guides:

- Main policy: `Private/keyboard.yaml`
- Device profile: `Private/keyboards/logitech-k240-japanese-dictation.yaml`
- Menu bar remap app (receiver-agnostic, not brand/model-specific):
  `scripts/keyboard-remap.swift`, built via `scripts/build-keyboard-remap-app.sh`
- Machine-specific observations: machine-local state and
  `~/Library/Logs/macomrade/`

### Logitech K240 profile

The K240 Japanese keyboard uses a Logitech USB receiver. Confirm all of the
following before applying its profile:

```sh
hidutil list
defaults read -g AppleSelectedInputSources
```

The expected receiver is Logitech `VID 0x046d`, `PID 0xc534`; the physical
keyboard model must also be confirmed as K240, and the active input layout must
be Japanese. The receiver identifier alone is not enough to distinguish every
keyboard paired to that receiver.

### Logitech MX Keys Mac profile

When a Logitech MX Keys Mac is detected, prefer Logitech Options+ hardware
remapping for F1/F2 and other function keys. It works at the device layer and
avoids a custom HID listener, Fn-layer ambiguity, and Input Monitoring grants.
Use a native Swift listener only for hardware without a reliable vendor
configuration tool, such as the documented K240 fallback profile.

The current target mapping is:

```text
F1        Open ChatGPT.app
Ctrl/⌘F1  Open Claude.app
F2        Open Antigravity.app
Ctrl/⌘F2  Open OpenCode.app
F3        Open Deepseek Harness Desktop.app
Ctrl/⌘F3  Open Perplexity.app
F4        Mission Control
F5        Open YouTube.app if present (including PlayCover), otherwise Apple Music
F6        Previous Track
F7        Play/Pause
F8        Next Track
F9        Mute
F10       Volume Down
F11       Volume Up
F12       Open macOS Screenshot.app toolbar
```

There is no "hold two F-keys at once" binding — each F-key only combines with
a standard Control/Command modifier, never with another F-key.

Use native `hidutil` consumer usages for F6–F11. These mappings are local HID
state, not iCloud settings, and can disappear after restart, logout, or a
receiver reconnect. Reapply and verify them rather than assuming persistence:

```sh
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":30064771135,"HIDKeyboardModifierMappingDst":3221225654},
  {"HIDKeyboardModifierMappingSrc":30064771136,"HIDKeyboardModifierMappingDst":3221225677},
  {"HIDKeyboardModifierMappingSrc":30064771137,"HIDKeyboardModifierMappingDst":3221225653},
  {"HIDKeyboardModifierMappingSrc":30064771138,"HIDKeyboardModifierMappingDst":3221225698},
  {"HIDKeyboardModifierMappingSrc":30064771139,"HIDKeyboardModifierMappingDst":3221225706},
  {"HIDKeyboardModifierMappingSrc":30064771140,"HIDKeyboardModifierMappingDst":3221225705}
]}'
hidutil property --get UserKeyMapping
```

### F1–F3, F5, and F12: the Keyboard Remap menu bar app

Do not rely on editing `com.apple.symbolichotkeys` IDs for this profile. Those
preferences may read back as successfully changed while an external K240 key
still does nothing. macOS's standard `Command-Shift-4` is area capture;
`Command-Shift-5` opens the Screenshot toolbar. The intended K240 behavior is
F12 opening the latter.

The supported implementation is a small menu bar app (not tied to any
particular keyboard brand or model — see below), built and installed with:

```sh
scripts/build-keyboard-remap-app.sh
open "$HOME/Applications/Keyboard Remap.app"
```

The app handles F1, F2, F3, F5, F12, and the four Control/Command modifier
usages (left/right each). F4 is handled by macOS's
native Mission Control shortcut configuration and is intentionally excluded:

1. Matches whichever HID receiver is named by `device.vendor_id`/
   `device.product_id` in its config file (see below) — not a hardcoded
   vendor/product ID, so the same app can be pointed at a different keyboard
   receiver by editing the config, no recompile needed.
2. Filters the USB HID keyboard page `0x07`: F1 `0x3a`, F2 `0x3b`, F3
   `0x3c`, F5 `0x3e`, F12 `0x45`, and Control/Command `0xe0`/`0xe4`/`0xe3`/`0xe7`.
3. Debounces duplicate reports from the receiver.
4. F1 alone opens ChatGPT.app; Control or Command + F1 opens Claude.app
   instead. F2 alone opens Antigravity.app; Control/Command+F2 opens
   OpenCode.app. F3 alone opens Deepseek Harness Desktop.app;
   Control/Command+F3 opens Perplexity.app. Every key fires immediately — no
   chord window, no "two F-keys held together" binding. F5 opens YouTube.app
   when present (including `~/Applications/PlayCover/YouTube.app`), otherwise
   Apple Music; F12 opens Screenshot.app.
5. Writes operational diagnostics to
   `~/Library/Logs/macomrade/keyboard-remap.log`.
6. Reads the device match and every single-key/modified → app table from
   `~/Library/Application Support/macomrade/keyboard-remap.json` at launch,
   writing its built-in default there first if the file is missing (scoped to
   the Logitech K240 receiver `0x046d:0xc534` by default). Editing that JSON
   changes the mapping — or the target receiver — without recompiling; the
   app's menu bar **Reload Config** item re-reads it into the running process
   immediately, or restart the launch agent to the same effect.

A physical Fn+F1 chord (instead of Control/Command+F1) was ruled out by an
IOHIDManager probe against the K240 receiver on 2026-08-26: its Fn key
produced no independent HID report at all, distinct from "F1 alone" — Fn
state is resolved by keyboard/receiver firmware before any event reaches host
software. See `fn_key_probe_2026_08_26` in
`Private/keyboards/logitech-k240-japanese-dictation.yaml` for the full result.

The first validation must run the app in the foreground (double-click, or
`open`). Press F1 alone, then Control+F1, then F2 alone, then Control+F2, then
F3 alone, then Control+F3, then F5, then F12, and confirm ChatGPT, Claude,
Antigravity, OpenCode, Deepseek Harness Desktop, Perplexity, YouTube or Apple
Music, and the Screenshot toolbar respectively. Separately verify left
Command twice for Dictation. If the app cannot open the receiver, grant
**Privacy & Security → Input Monitoring** to it (see below); it does not need
Accessibility for the direct application launches. Screenshot capture
permissions remain controlled by the native Screenshot app and macOS Screen
Recording settings.

The app source is the reusable implementation; an always-on LaunchAgent is a
separate installation step. When persistence is requested, install the
template `templates/keyboard-remap.launchagent.plist` as
`~/Library/LaunchAgents/com.xvk.macomrade.keyboard-remap.plist`. Each
installed LaunchAgent still only ever talks to the one receiver named in its
config file — pointing it at a different keyboard is a config edit, not a new
LaunchAgent. Verify the loaded agent and record its current status in
machine-local state.

The installed user-level paths are:

```text
App:          ~/Applications/Keyboard Remap.app
LaunchAgent:  ~/Library/LaunchAgents/com.xvk.macomrade.keyboard-remap.plist
Config:       ~/Library/Application Support/macomrade/keyboard-remap.json
Logs:         ~/Library/Logs/macomrade/keyboard-remap.log
```

Input Monitoring is macOS TCC-protected: CLI can open the settings page, but
cannot silently grant the permission. `tccutil` resets permissions; it does
not grant Input Monitoring to a new executable. Rebuilding the app with
`scripts/build-keyboard-remap-app.sh` re-signs it, which macOS treats as a new
executable — every rebuild must automatically run the following two commands
before asking the user to grant the permission:

```sh
open -R "$HOME/Applications/Keyboard Remap.app"
open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent'
```

If the log says `Unable to open HID receiver`, stop the `KeepAlive` agent,
authorize the app in Input Monitoring, and reload it:

```sh
launchctl bootout gui/$(id -u)/com.xvk.macomrade.keyboard-remap 2>/dev/null
open -R "$HOME/Applications/Keyboard Remap.app"
open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent'
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/com.xvk.macomrade.keyboard-remap.plist"
```

F4 remains a native macOS Mission Control shortcut (symbolic hotkey ID 32) and
must not be duplicated in Swift. F5 chooses YouTube in this order:

1. `/Applications/YouTube.app`
2. `~/Applications/PlayCover/YouTube.app/YouTube` (direct executable)
3. `/System/Applications/Music.app`

PlayCover's YouTube bundle is not a conventional macOS `.app` bundle: its
`Info.plist` is at the bundle root rather than under `Contents/`. Therefore
`open -a ~/Applications/PlayCover/YouTube.app` can fail with Launch Services
error `-10670`; launch the inner `YouTube` executable instead.
Before starting it, query the running application by bundle identifier
`com.google.ios.youtube`; if it is already running, activate its existing
windows rather than creating another process. The listener must also clear
the macOS Accessibility `AXMinimized` attribute before activation, because
`activate(.activateAllWindows)` alone does not reliably restore a window
minimized with the yellow button. If the app activates but remains minimized,
grant the installed listener Accessibility permission and retry. This preserves
the normal single-instance behavior expected from ChatGPT and Claude.

### Known keyboard limitations

The native listener is scoped to the Logitech receiver identifiers, but the
listener must still be foreground-tested after macOS updates or receiver
changes. Do not install Karabiner-Elements as an implicit dependency.

### Logitech K240/M212 battery telemetry

The current hardware pairing is a Logitech K240 keyboard and M212 mouse using
the shared receiver `VID 0x046d`, `PID 0xc534`. The receiver identifier alone
does not prove the physical device models. macOS `hidutil`, `ioreg`, and
`pmset` do not expose their battery values as native macOS battery devices.

Logi Options+ and OpenLogi may install successfully while still failing to
detect these legacy devices. Do not interpret that as an installation failure.
Use the optional Solaar workflow in `components/solaar.md` as the next
macOS-native experiment; Solaar has explicit Nano receiver support but only
limited macOS support.

Solaar battery values are device-reported and may be approximate. The details
pane must be selected for each device before assigning a value to keyboard or
mouse. A label such as `next reported 5%` is a future reporting threshold, not
the current battery level. Never infer the second device's identity from its
row alone; confirm the right-hand details pane.

Solaar has no official Homebrew cask. The supported macOS setup installs its
dependencies with Homebrew, installs Solaar through `pipx`, and creates a local
`/Applications/Solaar.app` wrapper from the official GitHub script:

```sh
brew install hidapi gtk+3 pygobject3 pipx
pipx install --system-site-packages solaar
curl -fL \
  https://raw.githubusercontent.com/pwr-Solaar/Solaar/4bda869542ea0b2e54f24decd4cca65113679e25/tools/create-macos-app.sh \
  -o /tmp/solaar-create-macos-app.sh
echo "00fdb57a6676cfc0b31addcf34dc76a0233c720635ced9a7a7f528e93595b563  /tmp/solaar-create-macos-app.sh" \
  | shasum -a 256 -c -
bash /tmp/solaar-create-macos-app.sh
```

Quit Logi Options+ and OpenLogi before Solaar accesses the receiver. Keep
current battery readings, detected names, versions, and permission results in
machine-local state, not synced catalog or policy Markdown. Do not send unknown
write commands to the receiver; battery investigation must remain read-only.

Keyboard policy is machine-local. Do not claim that `defaults`, `hidutil`, or
the Swift listener synchronizes through iCloud. Keep reusable policy in
`settings/`; keep current device detection, permissions, versions, and test
results out of synced policy files.


