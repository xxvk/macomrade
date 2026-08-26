---
component_id: "elgato-stream-deck"
name: "Elgato Stream Deck"
category: "Hardware utilities"
tier: "optional"
lifecycle_status: "active"
source: "homebrew"
delivery_method: "homebrew-cask"
brew_cask: "elgato-stream-deck"
official_url: "https://www.elgato.com/us/en/s/downloads?product=Stream+Deck"
check_command: "test -d '/Applications/Elgato Stream Deck.app'"
reboot_required: false
install_after: []
account_required: false
permissions_required: ["Only permissions requested by the app and approved by the user"]
secrets_policy: "Never store passwords, API keys, recovery codes, or license secrets here."
download_estimate_bytes: 300000000
download_estimate_method: "catalog_size_gb_planning_estimate"
---
# Elgato Stream Deck

Optional utility for configuring Elgato Stream Deck hardware. The device is
currently detected as `Stream Deck MK.2` over USB.

## Installation

```sh
brew install --cask elgato-stream-deck
```

Homebrew's cask is the preferred source. The official vendor download remains
the fallback if the cask is unavailable.

## Verification

Confirm the application bundle, launch it once, and verify that the connected
Stream Deck appears in the app. Then rerun the macOS application scan.

```sh
test -d "/Applications/Elgato Stream Deck.app"
ioreg -p IOUSB -l | grep -q "Stream Deck MK.2"
```

## Configuration

Create an initial profile, then add only the desired hotkeys, multi-actions,
or marketplace plugins. Review and approve any macOS permissions requested by
the application; do not store permission state or account credentials here.

## Rollback

```sh
brew uninstall --cask elgato-stream-deck
```
