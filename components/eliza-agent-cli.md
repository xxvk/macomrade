---
component_id: "eliza-agent-cli"
name: "Eliza Agent CLI (elizaos)"
category: "AI developer agent"
tier: "core"
lifecycle_status: "active"
source: "official_web"
delivery_method: "bun-global-package"
brew_cask: null
brew_formula: null
official_url: "https://github.com/elizaOS/eliza"
check_command: "elizaos --version"
install_after: []
account_required: true
permissions_required: []
secrets_policy: "Never store provider API keys, OAuth tokens, subscription sessions, prompts, repository content, or agent credentials here."
download_estimate_bytes: 100000000
download_estimate_method: "catalog_size_gb_planning_estimate"
---

# Eliza Agent CLI (elizaos)

> [!summary] Purpose
> Core terminal OSINT and autonomous agent framework (elizaOS). Supports Grok (xAI) and other LLM providers. Runs locally as a background runtime, REST server, or interactive Terminal UI.

## Parameters

| Parameter | Value |
|---|---|
| Delivery | `bun install -g @elizaos/cli` (primary) / `pnpm add -g @elizaos/cli` (secondary) |
| Executable | `elizaos` (at `~/.bun/bin/elizaos` or global PATH) |
| Account | Requires Model Provider API keys (e.g. `XAI_API_KEY`, `OPENAI_API_KEY`) |

## Installation

### Primary: Global CLI via Bun (Recommended)

```sh
bun install -g @elizaos/cli
```

Ensure `~/.bun/bin` or `~/.local/bin` is in your `$PATH`.

### Secondary Fallback: Global CLI via pnpm / npm

```sh
pnpm add -g @elizaos/cli
# or npm install -g @elizaos/cli
```

### Alternative: Local Monorepo Build (Source Contributors only)

For contributors modifying the core engine or building custom plugins from source:

```sh
git clone https://github.com/elizaOS/eliza.git
cd eliza
bun install
bun run build
```

## Verification

```sh
elizaos --version
elizaos --help
```

To create a new agent project interactively:
```sh
elizaos create my-agent
cd my-agent
elizaos start
```

## Configuration

Configure your environment variables and API keys inside the project directory:
```sh
cp .env.example .env
# Set OPENAI_API_KEY=..., XAI_API_KEY=...
```

## Rollback

To remove global CLI:
```sh
bun remove -g @elizaos/cli
# or pnpm remove -g @elizaos/cli
```

## Evidence and notes

- Official Documentation: `https://elizaos.ai/`
- Official Repository: `https://github.com/elizaOS/eliza`
- Machine-specific version, authentication and verification evidence belongs only in machine-local state.

