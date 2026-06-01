# Dual Runtime Marketplace Design

## Goal

Manage Baleen plugins from one marketplace repository while supporting both Claude Code and Codex.

The marketplace must expose the same logical plugin catalog to both runtimes, keep plugin versions synchronized with GitHub releases, and provide a reusable GitHub Action that plugin repositories can call after release. Private plugins may be listed in the catalog while still requiring repository access at install time.

## Context

The current `baleen-marketplace` repository already supports Claude Code through `.claude-plugin/marketplace.json`.

Current known plugin sources:

- `baleen37/memmem`: public single-plugin repository.
- `baleen37/bstack`: public multi-plugin repository containing plugins such as `me`, `jira`, and `autoresearch`.
- `baleen37/bstack-private`: private multi-plugin repository containing private plugins.

`bstack` and `bstack-private` are marketplace-style repositories, not single plugin repositories. The central marketplace should list their installable plugin entries, not only the repository names.

## Assumptions

- Plugin repositories publish GitHub releases when a plugin version changes.
- Public repository versions can be read through the unauthenticated GitHub releases API.
- Private repository versions require a GitHub token or GitHub App installation token.
- Claude Code and Codex may use different marketplace manifest shapes, so one file per runtime is clearer than forcing one shared schema.
- The marketplace should remain the source of installable catalog metadata, while each plugin repository remains the source of plugin code and per-runtime plugin manifests.

## Non-Goals

- Do not merge `memmem`, `bstack`, or `bstack-private` into this repository.
- Do not move plugin source code into `baleen-marketplace`.
- Do not rewrite release automation in the plugin repositories.
- Do not solve access control beyond documenting and supporting authenticated private release lookup.

## Marketplace Layout

The repository should contain two runtime-specific marketplace files:

- `.claude-plugin/marketplace.json`
- `.agents/plugins/marketplace.json`

The Claude file keeps the existing Anthropic marketplace schema.

The Codex file follows the installed Codex marketplace shape used by bundled marketplaces:

```json
{
  "name": "baleen-marketplace",
  "interface": {
    "displayName": "Baleen Marketplace"
  },
  "plugins": []
}
```

Each plugin entry should point to the plugin source location expected by that runtime. For repository-backed plugins, entries should include enough source metadata for the runtime to fetch the plugin and for automation to discover the GitHub repository that owns releases.

## Catalog Policy

The central marketplace should expose these plugin groups:

- `memmem` from `baleen37/memmem`.
- Public `bstack` plugins from `baleen37/bstack`.
- Private `bstack-private` plugins from `baleen37/bstack-private` when the user has repository access.

Private plugins can appear in the catalog, but installation is expected to fail for users without repository access. README documentation must call this out explicitly.

Name collisions must be avoided. If public and private repositories both contain a `me` plugin, the central marketplace must not expose both as plain `me` in the same runtime catalog unless the runtime supports disambiguation. Prefer distinct names for conflicting entries, for example:

- `me`
- `me-private`

## Version Synchronization

Marketplace versions must change when plugin release versions change.

The desired operating model:

1. A plugin repository publishes a GitHub release.
2. The plugin repository triggers the marketplace update workflow.
3. The marketplace workflow reads latest releases for all configured plugin source repositories.
4. The workflow updates both Claude and Codex marketplace files.
5. The workflow commits the version changes, or exits cleanly when no versions changed.

The existing `scripts/update-versions.sh` should be extended instead of replaced.

Required behavior:

- Accept one or more marketplace JSON paths.
- Update plugin entries in every configured marketplace file.
- Read public releases without a token.
- Read private releases with `GH_TOKEN` or `GITHUB_TOKEN` when available.
- Skip a plugin with a warning if its release cannot be read.
- Preserve current dry-run behavior.
- Keep commit messages concise and include changed plugin versions.

## Plugin Repository Action

Add a reusable action in this repository for plugin repositories to call after release.

Proposed path:

- `.github/actions/dispatch-marketplace-update/action.yml`

Purpose:

- Hide the `repository_dispatch` details from plugin repositories.
- Standardize payload shape.
- Make public and private plugin repositories use the same integration pattern.

Inputs:

- `github-token`: required token with permission to dispatch workflows in `baleen37/baleen-marketplace`.
- `marketplace-repository`: optional, default `baleen37/baleen-marketplace`.
- `event-type`: optional, default `update_versions`.
- `plugin`: optional plugin name for traceability.
- `version`: optional version for traceability.

The action should call the GitHub repository dispatch API with a small payload:

```json
{
  "event_type": "update_versions",
  "client_payload": {
    "plugin": "memmem",
    "version": "1.1.3"
  }
}
```

The marketplace workflow remains authoritative. It should not blindly trust the payload version; it should fetch current releases and update manifests from release data.

## Plugin Repository Usage

Plugin repositories should add a workflow step after a release is published:

```yaml
- name: Trigger Baleen marketplace update
  uses: baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main
  with:
    github-token: ${{ secrets.BALEEN_MARKETPLACE_DISPATCH_TOKEN }}
    plugin: memmem
    version: ${{ github.ref_name }}
```

For private repositories, `BALEEN_MARKETPLACE_DISPATCH_TOKEN` should be a GitHub App installation token or another token approved for cross-repository dispatch. Prefer GitHub App tokens over personal access tokens.

## README Updates

The README should document:

- Claude Code marketplace installation.
- Codex marketplace installation, using the local or git marketplace source supported by Codex.
- The difference between public and private plugins.
- How plugin repositories call the dispatch action.
- How version updates flow from plugin release to marketplace manifest.

## Validation

The implementation is complete when these checks pass:

- `jq empty .claude-plugin/marketplace.json`
- `jq empty .agents/plugins/marketplace.json`
- `bash scripts/update-versions.test.sh`
- A dry-run update can process both marketplace files without writing changes.
- The dispatch action shell path is covered by a lightweight test or static validation.
- README examples use the same action inputs as the action metadata.

## Open Decisions

Before implementation, choose the public catalog names for private plugins that collide with public plugin names. The likely first decision is whether `bstack-private/plugins/me` should be exposed as `me-private`.
