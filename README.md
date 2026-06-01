# baleen-marketplace

Claude Code and Codex plugin marketplace by [Baleen](https://github.com/baleen37).

## Claude Code Installation

Add this marketplace in Claude Code, then install plugins from `baleen-marketplace`:

```
/plugin marketplace add baleen37/baleen-marketplace
/plugin install memmem@baleen-marketplace
/plugin install me@baleen-marketplace
/plugin install jira@baleen-marketplace
/plugin install autoresearch@baleen-marketplace
```

## Codex Installation

Codex marketplace entries are published in `.agents/plugins/marketplace.json`.

Use the Codex plugin installer to add plugins from the `baleen-marketplace` marketplace manifest. The exact Codex CLI install command is intentionally not documented here because it can vary by runtime version; the stable integration point is the manifest path above.

## Plugins

| Plugin | Description | Repo |
|--------|-------------|------|
| memmem | Persistent semantic memory for Claude Code — search and retrieve past sessions using embeddings | [baleen37/memmem](https://github.com/baleen37/memmem) |
| me | AI coding assistant toolkit — git workflow protection, session handoff, context management, and development automation | [baleen37/bstack](https://github.com/baleen37/bstack) |
| jira | Atlassian Jira integration skills for triage, status reports, knowledge search, and backlog management | [baleen37/bstack](https://github.com/baleen37/bstack) |
| autoresearch | Autonomous experiment loop for iteratively optimizing any metric with git-tracked experiments | [baleen37/bstack](https://github.com/baleen37/bstack) |
| me-private | Private AI coding assistant toolkit extensions | [baleen37/bstack-private](https://github.com/baleen37/bstack-private) |

## Private Plugins

Private plugin installation requires access to the underlying private GitHub repository. Marketplace visibility alone is not enough; the runtime still needs permission to fetch the plugin source.

For private release lookup and cross-repo dispatch, prefer a GitHub App installation token. Install the app on both the plugin repository and `baleen37/baleen-marketplace`, grant the minimum repository permissions needed for release reads and repository dispatch, then expose the installation token to the workflow as a secret.

## Version Flow

Version updates flow from plugin repositories into both runtime marketplace files:

1. A plugin repository publishes a GitHub release.
2. The plugin repository triggers the Baleen marketplace dispatch action.
3. The marketplace workflow receives the dispatch payload as trace metadata.
4. The marketplace workflow fetches GitHub releases as the authoritative source for versions.
5. The workflow updates `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.

The dispatch payload identifies which plugin and version initiated the update, but it is not the source of truth for marketplace versions.

## Dispatch action usage

Use this from a plugin repository after publishing a release:

```yaml
- name: Trigger Baleen marketplace update
  uses: baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main
  with:
    github-token: ${{ secrets.BALEEN_MARKETPLACE_DISPATCH_TOKEN }}
    plugin: memmem
    version: ${{ github.ref_name }}
```

## Reusable version update automation

This repository provides reusable automation for plugin version updates. The automation reads latest GitHub releases and can update both Claude Code and Codex marketplace manifests.

### 1) Composite action

Use the action directly in any workflow after checkout. Pass both manifest paths when updating the dual-runtime marketplace:

```yaml
- uses: actions/checkout@v4
- name: Update versions
  uses: baleen37/baleen-marketplace/.github/actions/update-versions@main
  with:
    marketplace-json: .claude-plugin/marketplace.json,.agents/plugins/marketplace.json
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
      marketplace-json: .claude-plugin/marketplace.json,.agents/plugins/marketplace.json
      dry-run: false
      commit-message-prefix: chore: update plugin versions
```

### 3) Plugin repository example

Plugin repositories can trigger the marketplace workflow through repository dispatch. The payload is trace metadata; the marketplace workflow still fetches GitHub releases as the authoritative source.

```yaml
- name: Trigger Baleen marketplace update
  uses: baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main
  with:
    github-token: ${{ secrets.BALEEN_MARKETPLACE_DISPATCH_TOKEN }}
    plugin: memmem
    version: ${{ github.ref_name }}
```

### 4) Cross-repo repository_dispatch auth (GitHub App token)

Use a GitHub App installation token for cross-repo dispatch calls, especially for private plugins. A fine-scoped GitHub App token is preferred over a PAT.

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
