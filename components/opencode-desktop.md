---
component_id: "opencode-desktop"
name: "OpenCode Desktop"
category: "Developer CLI"
tier: "core"
lifecycle_status: "active"
source: "homebrew"
delivery_method: "homebrew-cask"
brew_cask: "opencode-desktop"
brew_formula: null
official_url: "https://opencode.ai/"
bundle_identifiers: ["ai.opencode.desktop"]
application_path: "/Applications/OpenCode.app"
check_command: "test -d '/Applications/OpenCode.app'"
install_after: ["opencode"]
account_required: true
permissions_required: []
secrets_policy: "Never store provider API keys, OAuth tokens, prompts, repository content, or agent credentials here."
download_estimate_bytes: 150000000
download_estimate_method: "cask_dmg_metadata"
---

# OpenCode Desktop

> [!summary] Purpose
> Official GUI client for OpenCode (beta), built on the same open-source,
> provider-neutral agent as the [OpenCode](opencode.md) CLI/TUI. Adds
> multiple concurrent sessions, session sharing via links, a built-in editor
> with diff view, and drag-and-drop file support. The TUI remains the
> recommended interface for most work; this cask is the optional GUI
> companion, not a replacement.

## Source

- Cask: `opencode-desktop` (official Homebrew Core cask, `official_homebrew`
  source class — see `references/source-policy.json`)
- Upstream: `https://github.com/anomalyco/opencode` (same repository as the
  CLI tap `anomalyco/tap/opencode`)
- Cask URL: `https://github.com/anomalyco/opencode/releases/download/v<version>/opencode-desktop-mac-<arch>.dmg`

## Parameters

| Parameter | Value |
|---|---|
| Delivery | Homebrew Core cask |
| Package identifier | `opencode-desktop` |
| Official source | `https://opencode.ai/` |
| Required tier | Core |
| Install order | after `opencode` CLI (`anomalyco/tap/opencode`) |
| App path | `/Applications/OpenCode.app` |
| Bundle ID | `ai.opencode.desktop` |
| Account | provider authentication is interactive |
| Permissions | none at installation |
| macOS | >= Monterey |

## Installation

```sh
brew install --cask opencode-desktop
```

Do not let this cask install imply a provider login, API key entry,
repository access grant, or unattended agent execution.

## Configuration

Provider authentication and agent profiles are shared with the CLI/TUI
install; see [opencode.md](opencode.md) for the Primary/Subagent routing
architecture and provider-key guidance. The desktop app reads the same
`opencode` configuration — do not duplicate or fork provider credentials
between the CLI and the desktop client.

## Verification

```sh
test -d '/Applications/OpenCode.app'
brew list --cask --versions opencode-desktop
brew outdated --cask opencode-desktop
```

Open the app once and confirm the first window appears without a crash or
security warning. A version result proves package health, not provider
access.

## Updates and rollback

```sh
brew upgrade --cask opencode-desktop
brew uninstall --cask opencode-desktop
```

Uninstalling removes only the app bundle; a full `zap` additionally clears
`~/Library/Application Support/ai.opencode.desktop` and related caches —
run `zap` only after explicit approval, since it discards local session
state.

## Evidence and notes

- Documentation: `https://opencode.ai/docs/`
- Repository: `https://github.com/anomalyco/opencode`
- Cask source: `https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/o/opencode-desktop.rb`
- Machine-specific version, path, size, authentication, and verification
  evidence belongs only in machine-local state.
