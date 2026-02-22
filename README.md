# baleen-marketplace

Claude Code plugin marketplace by [Baleen](https://github.com/baleen37).

## Installation

Add this marketplace in Claude Code:

```
/plugin marketplace add baleen37/baleen-marketplace
```

Then install plugins:

```
/plugin install everything-agent@baleen-marketplace
/plugin install memmem@baleen-marketplace
```

## Plugins

| Plugin | Description | Repo |
|--------|-------------|------|
| everything-agent | AI coding assistant toolkit — LSP servers, git workflow protection, session handoff, context management, and development automation | [baleen37/everything-agent](https://github.com/baleen37/everything-agent) |
| memmem | Persistent semantic memory for Claude Code — search and retrieve past sessions using embeddings | [baleen37/memmem](https://github.com/baleen37/memmem) |

## Reusable version update automation

This repository provides reusable automation for plugin version updates.

### 1) Composite action

Use the action directly in any workflow after checkout:

```yaml
- uses: actions/checkout@v4
- name: Update versions
  uses: baleen37/baleen-marketplace/.github/actions/update-versions@main
  with:
    marketplace-json: .claude-plugin/marketplace.json
    dry-run: "false"
    commit-message-prefix: "chore: update plugin versions"
```

### 2) Reusable workflow

Use the reusable workflow as an entrypoint with schedule, manual, and dispatch support:

```yaml
name: Update Versions

on:
  schedule:
    - cron: '0 * * * *'
  workflow_dispatch:
  repository_dispatch:
    types: [update_versions]

jobs:
  update:
    uses: baleen37/baleen-marketplace/.github/workflows/reusable-update-versions.yml@main
    with:
      marketplace-json: .claude-plugin/marketplace.json
      dry-run: false
      commit-message-prefix: chore: update plugin versions
```

### 3) memmem example

`memmem` can use the same reusable workflow:

```yaml
name: Update Versions

on:
  schedule:
    - cron: '0 * * * *'
  workflow_dispatch:
  repository_dispatch:
    types: [update_versions]

jobs:
  update:
    uses: baleen37/baleen-marketplace/.github/workflows/reusable-update-versions.yml@main
```

### 4) Cross-repo repository_dispatch auth (GitHub App token)

Use GitHub App token for cross-repo dispatch calls. Do not use PAT.

```yaml
- name: Trigger baleen-marketplace update
  env:
    GH_TOKEN: ${{ secrets.GH_APP_TOKEN }}
  run: |
    curl -sSf -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      https://api.github.com/repos/baleen37/baleen-marketplace/dispatches \
      -d '{"event_type":"update_versions"}'
```

Required GitHub App setup:
- Install the app on both source and target repositories.
- Grant repository access needed for dispatch and workflow execution.
- Generate an installation token at runtime and expose it as a workflow secret/env (e.g. `GH_APP_TOKEN`) before calling the dispatch API.
