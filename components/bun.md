---
component_id: "bun"
name: "bun"
category: "Developer CLI"
tier: "core"
lifecycle_status: "active"
source: "homebrew"
delivery_method: "homebrew-formula"
brew_cask: null
brew_formula: "bun"
official_url: "https://bun.com/"
check_command: "bun --version"
install_after: []
account_required: false
permissions_required: []
secrets_policy: "Never store passwords, API keys, recovery codes, or license secrets here."
download_estimate_bytes: 60000000
download_estimate_method: "catalog_size_gb_planning_estimate"
---
# bun

Fast all-in-one JavaScript runtime, package manager, bundler, and test runner. Core component supporting modern agent CLI tools (such as `@elizaos/cli`) and TS execution.

## Installation

```sh
brew install bun
```

## Verification

```sh
bun --version
```

Verify global binary path and basic script execution:
```sh
bun -e "console.log('Bun is ready')"
```

## Rollback

```sh
brew uninstall bun
```

## Evidence and notes

- Official Documentation: `https://bun.com/docs`
- Machine-specific version, authentication and verification evidence belongs only in machine-local state.
