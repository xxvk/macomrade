---
component_id: "workbuddy"
name: "WorkBuddy"
category: "AI development"
tier: "core"
lifecycle_status: "active"
source: "official_web"
delivery_method: "vendor-download"
brew_cask: null
brew_formula: null
official_url: "https://www.workbuddy.ai/"
bundle_identifiers: ["com.workbuddy.workbuddy-ai"]
application_path: "/Applications/WorkBuddy AI.app"
check_command: "test -d '/Applications/WorkBuddy AI.app'"
install_after: []
account_required: true
permissions_required: []
secrets_policy: "Never store provider API keys, OAuth tokens, prompts, repository content, or agent credentials here."
download_estimate_bytes: 1000000000
download_estimate_method: "dmg_zlib_plus_unpacked_app_bundle"
---

# WorkBuddy

> [!summary] Purpose
> Tencent Cloud's international desktop AI agent workstation for
> office-deliverable tasks (reports, sheets, decks) via multi-agent
> planning; built by the same team as CodeBuddy and shares its account/
> permission layer. Not a coding IDE — see [opencode.md](opencode.md),
> [trae-work.md](trae-work.md), and a future CodeBuddy guide for
> repository-level coding tools.

## Source

- **No Homebrew cask exists for WorkBuddy** (checked `homebrew/cask` core
  and open/merged PRs on `Homebrew/homebrew-cask`; confirmed absent). The
  only reviewed source class today is `official_web` per
  `references/source-policy.json` (risk: high; requires HTTPS vendor
  domain, SHA-256, codesign, spctl, and bundle identifier/version
  verification before trust).
- International entry point: `https://www.workbuddy.ai/` — the site's own
  auto-update endpoint (`GET /v2/update?platform=workbuddy-darwin-arm64`)
  returns the resolved artifact URL, version, and a SHA-256 for the
  auto-update payload; the "Download Now" button on the homepage serves a
  versioned DMG (e.g. `WorkBuddy-darwin-arm64-<version>-<buildhash>.dmg`)
  from a Tencent COS CDN under the same build hash. Do not substitute the
  domestic `codebuddy.cn/work` download page for the overseas account.
- Installed app is named **`WorkBuddy AI.app`** (not `WorkBuddy.app`),
  bundle ID `com.workbuddy.workbuddy-ai`. Verified signed with
  `Developer ID Application: Tencent Technology (Shanghai) Company Limited
  (FN2V63AD2J)` and notarized (`spctl` reports `accepted` /
  `source=Notarized Developer ID`).
- The DMG ships a `Fix-Damage.txt` with a documented workaround
  (`xattr -rd com.apple.quarantine`) for a known false-positive "app is
  damaged" Gatekeeper error when Apple's notarization-ticket check cannot
  reach Apple's servers. Always run `codesign -dv` and `spctl -a -vv`
  first; only consider the quarantine-strip workaround if the app is
  confirmed genuinely notarized and Gatekeeper is failing purely on
  network reachability, never as a substitute for signature verification.

## Parameters

| Parameter | Value |
|---|---|
| Delivery | Vendor DMG download (no cask) |
| Official source | `https://www.workbuddy.ai/` |
| Required tier | Core |
| App path | `/Applications/WorkBuddy AI.app` |
| Bundle ID | `com.workbuddy.workbuddy-ai` |
| Account | provider/Tencent Cloud account authentication is interactive |
| Permissions | review at first launch; none required at install |
| macOS | >= 10.15 |
| Installed footprint | ~1.0 GB unpacked `.app` (vendor site advertises ~500 MB for the compressed DMG download only) |

## Installation

1. Confirm the exact architecture build (ARM64/Intel) and capture the
   resolved download URL, version, and SHA-256 before fetching — the
   site's own `/v2/update?platform=workbuddy-darwin-<arch>` endpoint
   returns all three, per the `official_web` verification checklist.
2. Download the DMG only from `https://www.workbuddy.ai/` (its "Download
   Now" button) or the Tencent COS CDN URL that endpoint resolves to —
   never from a third-party mirror.
3. Inspect the disk image before mounting, then mount, and verify code
   signature and Gatekeeper acceptance on the mounted app before copying:

```sh
hdiutil imageinfo <downloaded>.dmg
hdiutil attach <downloaded>.dmg -nobrowse
codesign -dv --verbose=4 "/Volumes/WorkBuddy AI <version>/WorkBuddy AI.app"
spctl -a -vv "/Volumes/WorkBuddy AI <version>/WorkBuddy AI.app"
```

4. Only after `spctl` reports `accepted` / `source=Notarized Developer ID`
   with `origin=Developer ID Application: Tencent Technology (Shanghai)
   Company Limited (FN2V63AD2J)`, copy `WorkBuddy AI.app` to
   `/Applications` and eject the DMG.

Do not automate the Tencent Cloud account sign-in; the user completes that
step interactively.

## Verification

```sh
test -d '/Applications/WorkBuddy AI.app'
spctl -a -vv '/Applications/WorkBuddy AI.app'
du -sh '/Applications/WorkBuddy AI.app'
```

Open the app once and confirm the first window appears without a crash or
Gatekeeper warning. Record the measured `du -sh` footprint and installed
version only in machine-local state.

## Updates and rollback

No cask exists, so updates go through the app's own updater or a fresh
vendor download repeating the same verification steps. Remove by deleting
`/Applications/WorkBuddy AI.app`; do not remove account/session state
without a separate, explicit confirmation.

## Evidence and notes

- Overseas guide: `https://www.tencentcloud.com/techpedia/144100?lang=en`
- Docs: `https://www.workbuddy.ai/docs/workbuddy/Overview`
- Machine-specific version, path, size, authentication, and verification
  evidence belongs only in machine-local state.
