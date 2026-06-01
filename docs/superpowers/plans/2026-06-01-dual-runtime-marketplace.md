# Dual Runtime Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `baleen-marketplace` the central marketplace for Claude Code and Codex, and roll out the release-dispatch integration to `~/dev/wooto/memmem` and `~/dev/wooto/bstack`.

**Architecture:** `baleen-marketplace` owns runtime-specific marketplace files and update automation. `memmem` and `bstack` keep their plugin code and per-runtime manifests, then call a reusable marketplace dispatch action after release. Repository-specific implementation should be delegated to subagents with disjoint write scopes.

**Tech Stack:** Bash, jq, GitHub Actions, Claude plugin marketplace JSON, Codex marketplace JSON, Bun, Bats.

---

## File Map

`/Users/jito.hello/dev/wooto/baleen-marketplace/.worktrees/00001-bright-otter-hopper`

- Modify: `.claude-plugin/marketplace.json` to include public and private Baleen plugin entries for Claude Code.
- Create: `.agents/plugins/marketplace.json` for Codex marketplace entries.
- Modify: `.github/workflows/reusable-update-versions.yml` so workflow calls update script for both marketplace files and accepts repository dispatch.
- Create: `.github/actions/dispatch-marketplace-update/action.yml` as the reusable plugin-repo action.
- Modify: `scripts/update-versions.sh` to update one or more marketplace files.
- Modify: `scripts/update-versions.test.sh` to cover multi-file update, dry-run, private-token behavior, and unchanged commits.
- Create: `scripts/dispatch-marketplace-update.test.sh` to statically validate the reusable action.
- Modify: `README.md` to document Claude, Codex, private plugins, dispatch action usage, and version flow.

`/Users/jito.hello/dev/wooto/memmem`

- Modify: `.github/workflows/on-release.yml` or the release workflow that currently dispatches marketplace updates.
- Modify: `.github/workflows/update-versions.yml` to keep standalone metadata aligned.
- Modify: `scripts/verify-update-versions-workflow.test.sh`.
- Modify: `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` only to fix version drift or dispatch compatibility.
- Modify: `README.md` to include `.codex-plugin/`.

`/Users/jito.hello/dev/wooto/bstack`

- Modify: `.github/workflows/sync-marketplace.yml`.
- Modify: `scripts/check-codex-artifacts.sh`.
- Modify: `tests/codex_plugin_json.bats`.
- Modify release workflow only if there is a separate release workflow not covered by `sync-marketplace.yml`.
- Do not directly edit generated Codex artifacts except through `bun run sync:codex`.

---

### Task 1: Lock Marketplace Test Coverage First

**Files:**
- Modify: `scripts/update-versions.test.sh`
- Create: `scripts/dispatch-marketplace-update.test.sh`

- [ ] **Step 1: Add a multi-marketplace fixture test**

In `scripts/update-versions.test.sh`, add a test that creates both `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`, mocks GitHub release `v1.2.3`, runs the update script with both paths, and asserts both files update.

Use this test body:

```bash
test_updates_multiple_marketplace_files() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  setup_repo "$repo" "$remote"
  mkdir -p "$repo/.agents/plugins"
  cp "$repo/.claude-plugin/custom-marketplace.json" "$repo/.agents/plugins/marketplace.json"
  setup_mock_curl "$bin_dir"

  (
    cd "$repo"
    PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json,.agents/plugins/marketplace.json" bash "$SCRIPT_PATH"
  )

  local claude_version
  claude_version=$(jq -r '.plugins[0].version' "$repo/.claude-plugin/custom-marketplace.json")
  local codex_version
  codex_version=$(jq -r '.plugins[0].version' "$repo/.agents/plugins/marketplace.json")

  if [[ "$claude_version" != "1.2.3" || "$codex_version" != "1.2.3" ]]; then
    echo "ASSERTION FAILED: expected both marketplace files to update to 1.2.3"
    echo "  claude=$claude_version codex=$codex_version"
    exit 1
  fi
}
```

- [ ] **Step 2: Add the new test to `main`**

Append the new test before the final echo:

```bash
main() {
  test_dry_run_with_marketplace_override
  test_commit_prefix_and_override_path
  test_curl_failure_skips_plugin
  test_curl_failure_skips_only_failed_plugin
  test_commit_message_no_leading_space
  test_no_url_plugins_exits_cleanly
  test_updates_multiple_marketplace_files
  echo "All tests passed"
}
```

- [ ] **Step 3: Create a static action validation test**

Create `scripts/dispatch-marketplace-update.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ACTION_FILE="${1:-.github/actions/dispatch-marketplace-update/action.yml}"

if [[ ! -f "$ACTION_FILE" ]]; then
  echo "ASSERTION FAILED: action file not found: $ACTION_FILE"
  exit 1
fi

required_patterns=(
  "github-token"
  "marketplace-repository"
  "event-type"
  "plugin"
  "version"
  "/repos/\\$\\{MARKETPLACE_REPOSITORY\\}/dispatches"
  "client_payload"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -q "$pattern" "$ACTION_FILE"; then
    echo "ASSERTION FAILED: missing pattern in action: $pattern"
    exit 1
  fi
done

echo "dispatch marketplace update action test passed"
```

- [ ] **Step 4: Run tests and confirm failure**

Run:

```bash
bash scripts/update-versions.test.sh
bash scripts/dispatch-marketplace-update.test.sh
```

Expected: `update-versions.test.sh` fails because multi-file update is not implemented. `dispatch-marketplace-update.test.sh` fails because the action does not exist.

- [ ] **Step 5: Commit failing tests**

```bash
git add scripts/update-versions.test.sh scripts/dispatch-marketplace-update.test.sh
git commit -m "test: cover dual marketplace automation"
```

---

### Task 2: Add Codex Marketplace Manifest

**Files:**
- Create: `.agents/plugins/marketplace.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create Codex marketplace file**

Create `.agents/plugins/marketplace.json`:

```json
{
  "name": "baleen-marketplace",
  "interface": {
    "displayName": "Baleen Marketplace"
  },
  "plugins": [
    {
      "name": "memmem",
      "source": {
        "source": "git",
        "url": "https://github.com/baleen37/memmem.git"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity",
      "version": "1.1.2"
    },
    {
      "name": "me",
      "source": {
        "source": "git",
        "url": "https://github.com/baleen37/bstack.git",
        "path": "./plugins/me"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Engineering",
      "version": "17.18.0"
    },
    {
      "name": "jira",
      "source": {
        "source": "git",
        "url": "https://github.com/baleen37/bstack.git",
        "path": "./plugins/jira"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Engineering",
      "version": "17.18.0"
    },
    {
      "name": "autoresearch",
      "source": {
        "source": "git",
        "url": "https://github.com/baleen37/bstack.git",
        "path": "./plugins/autoresearch"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Engineering",
      "version": "17.18.0"
    },
    {
      "name": "me-private",
      "source": {
        "source": "git",
        "url": "https://github.com/baleen37/bstack-private.git",
        "path": "./plugins/me"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Engineering",
      "version": "1.0.2"
    }
  ]
}
```

- [ ] **Step 2: Update Claude marketplace entries**

Modify `.claude-plugin/marketplace.json` so it lists the same installable names as the Codex catalog. Use the existing marketplace entry shape and include plugin paths in the `source` object:

```json
{
  "name": "me",
  "description": "AI coding assistant toolkit - git workflow protection, session handoff, context management, and development automation",
  "source": {
    "source": "url",
    "url": "https://github.com/baleen37/bstack.git",
    "path": "./plugins/me"
  },
  "category": "development",
  "tags": [
    "git",
    "workflow",
    "automation",
    "tdd",
    "debugging",
    "handoff",
    "memory",
    "context"
  ],
  "version": "17.18.0"
}
```

Use the same pattern for `jira`, `autoresearch`, and `me-private`. Keep `memmem` as the existing public URL entry without `path`.

- [ ] **Step 3: Validate JSON**

Run:

```bash
jq empty .claude-plugin/marketplace.json
jq empty .agents/plugins/marketplace.json
```

Expected: both commands exit 0.

- [ ] **Step 4: Commit manifest changes**

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json
git commit -m "feat: add codex marketplace catalog"
```

---

### Task 3: Implement Multi-File Version Updates

**Files:**
- Modify: `scripts/update-versions.sh`
- Modify: `.github/workflows/reusable-update-versions.yml`

- [ ] **Step 1: Parse comma-separated marketplace paths**

In `scripts/update-versions.sh`, replace single-file assumptions with an array:

```bash
IFS=',' read -r -a MARKETPLACE_FILES <<< "$MARKETPLACE_JSON"

for file in "${MARKETPLACE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: marketplace file not found: $file"
    exit 1
  fi
done
```

- [ ] **Step 2: Extract plugin release repo from each supported source shape**

Add helper logic:

```bash
extract_repo() {
  local plugin="$1"
  local url
  url=$(echo "$plugin" | jq -r '.source.url // .source.git // empty')

  if [[ -z "$url" || "$url" == "null" ]]; then
    return 1
  fi

  echo "$url" | sed 's|https://github.com/||;s|git@github.com:||;s|\.git$||'
}
```

- [ ] **Step 3: Update every marketplace file using latest releases**

The implementation should loop over every file, every plugin, compute latest version by repository, and write each changed file. Cache latest versions per repository in an associative array so `bstack` plugins share one API lookup.

Use this structure:

```bash
declare -A LATEST_BY_REPO
declare -A CHANGE_BY_PLUGIN
CHANGED=false

for marketplace_file in "${MARKETPLACE_FILES[@]}"; do
  updated=$(cat "$marketplace_file")
  plugins=$(jq -c '.plugins[] | select(.source != null)' "$marketplace_file")

  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue
    name=$(echo "$plugin" | jq -r '.name')
    current_version=$(echo "$plugin" | jq -r '.version // empty')
    repo=$(extract_repo "$plugin") || continue

    if [[ -z "${LATEST_BY_REPO[$repo]:-}" ]]; then
      latest=$(fetch_latest_release "$repo") || {
        echo "WARNING: Could not fetch latest release for $name ($repo), skipping."
        continue
      }
      LATEST_BY_REPO[$repo]="$latest"
    fi

    latest="${LATEST_BY_REPO[$repo]}"
    echo "$name: current=$current_version latest=$latest"

    if [[ "$latest" != "$current_version" ]]; then
      updated=$(echo "$updated" | jq --arg name "$name" --arg ver "$latest" --indent 2 \
        '(.plugins[] | select(.name == $name) | .version) |= $ver')
      CHANGED=true
      CHANGE_BY_PLUGIN["$name"]="$current_version->$latest"
    fi
  done <<< "$plugins"

  UPDATED_BY_FILE["$marketplace_file"]="$updated"
done
```

- [ ] **Step 4: Keep authenticated release lookup compatible with public repos**

Add `fetch_latest_release`:

```bash
fetch_latest_release() {
  local repo="$1"
  local auth_args=()

  if [[ -n "${GH_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${GH_TOKEN}")
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  curl -sf "${auth_args[@]}" "https://api.github.com/repos/$repo/releases/latest" \
    | jq -r '.tag_name | ltrimstr("v")'
}
```

- [ ] **Step 5: Write all changed files and commit once**

When `DRY_RUN=false`, write each updated marketplace file, `git add` all files, commit once, and push once.

- [ ] **Step 6: Update workflow defaults**

In `.github/workflows/reusable-update-versions.yml`, set the default `marketplace-json` to:

```yaml
default: .claude-plugin/marketplace.json,.agents/plugins/marketplace.json
```

Make the action invocation pass the same default.

- [ ] **Step 7: Run tests**

Run:

```bash
bash scripts/update-versions.test.sh
```

Expected: all tests pass.

- [ ] **Step 8: Commit implementation**

```bash
git add scripts/update-versions.sh .github/workflows/reusable-update-versions.yml
git commit -m "feat: update all runtime marketplaces"
```

---

### Task 4: Add Reusable Dispatch Action

**Files:**
- Create: `.github/actions/dispatch-marketplace-update/action.yml`
- Modify: `scripts/dispatch-marketplace-update.test.sh`

- [ ] **Step 1: Create action metadata**

Create `.github/actions/dispatch-marketplace-update/action.yml`:

```yaml
name: Dispatch marketplace update
description: Trigger Baleen marketplace version synchronization from a plugin repository

inputs:
  github-token:
    description: Token with permission to dispatch the marketplace workflow
    required: true
  marketplace-repository:
    description: Repository that owns the marketplace workflow
    required: false
    default: baleen37/baleen-marketplace
  event-type:
    description: Repository dispatch event type
    required: false
    default: update_versions
  plugin:
    description: Plugin name for traceability
    required: false
    default: ""
  version:
    description: Plugin version for traceability
    required: false
    default: ""

runs:
  using: composite
  steps:
    - name: Dispatch marketplace update
      shell: bash
      env:
        GH_TOKEN: ${{ inputs.github-token }}
        MARKETPLACE_REPOSITORY: ${{ inputs.marketplace-repository }}
        EVENT_TYPE: ${{ inputs.event-type }}
        PLUGIN: ${{ inputs.plugin }}
        VERSION: ${{ inputs.version }}
      run: |
        set -euo pipefail

        payload=$(jq -n \
          --arg event_type "$EVENT_TYPE" \
          --arg plugin "$PLUGIN" \
          --arg version "$VERSION" \
          '{event_type: $event_type, client_payload: {plugin: $plugin, version: $version}}')

        curl -sSf -X POST \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer ${GH_TOKEN}" \
          "https://api.github.com/repos/${MARKETPLACE_REPOSITORY}/dispatches" \
          -d "$payload"
```

- [ ] **Step 2: Run static validation**

Run:

```bash
bash scripts/dispatch-marketplace-update.test.sh
```

Expected: `dispatch marketplace update action test passed`.

- [ ] **Step 3: Commit**

```bash
git add .github/actions/dispatch-marketplace-update/action.yml scripts/dispatch-marketplace-update.test.sh
git commit -m "feat: add marketplace dispatch action"
```

---

### Task 5: Update Marketplace README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add runtime sections**

Replace the installation section with separate Claude and Codex sections:

```markdown
## Claude Code Installation

Add this marketplace in Claude Code:

```text
/plugin marketplace add baleen37/baleen-marketplace
```

Install plugins:

```text
/plugin install memmem@baleen-marketplace
/plugin install me@baleen-marketplace
/plugin install jira@baleen-marketplace
/plugin install autoresearch@baleen-marketplace
```

## Codex Installation

Add the marketplace source supported by your Codex installation, then install plugins from `baleen-marketplace`.

The Codex marketplace manifest lives at:

```text
.agents/plugins/marketplace.json
```
```

- [ ] **Step 2: Add dispatch action usage**

Add:

```markdown
## Triggering Marketplace Updates From Plugin Repositories

Plugin repositories should call the reusable action after publishing a release:

```yaml
- name: Trigger Baleen marketplace update
  uses: baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main
  with:
    github-token: ${{ secrets.BALEEN_MARKETPLACE_DISPATCH_TOKEN }}
    plugin: memmem
    version: ${{ github.ref_name }}
```

The marketplace workflow treats the payload as trace metadata. It fetches the latest GitHub releases and updates the marketplace manifests from release data.
```

- [ ] **Step 3: Add private plugin note**

Add:

```markdown
## Private Plugins

Private plugins may appear in the catalog, but installation requires access to the underlying private GitHub repository. Use a GitHub App installation token for private release lookup and cross-repository dispatch.
```

- [ ] **Step 4: Run README/action consistency check**

Run:

```bash
bash scripts/dispatch-marketplace-update.test.sh
rg -n "dispatch-marketplace-update|BALEEN_MARKETPLACE_DISPATCH_TOKEN|Codex" README.md
```

Expected: the README references the action and token name.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document dual runtime marketplace"
```

---

### Task 6: Subagent Task for `memmem`

**Files:**
- Worktree: `/Users/jito.hello/dev/wooto/memmem`
- Modify: `.github/workflows/on-release.yml`
- Modify: `.github/workflows/update-versions.yml`
- Modify: `scripts/verify-update-versions-workflow.test.sh`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.codex-plugin/plugin.json`
- Modify: `README.md`

- [ ] **Step 1: Dispatch a worker subagent**

Prompt:

```text
한국어로 답하세요. /Users/jito.hello/dev/wooto/memmem 에서 작업하세요. 당신은 이 repo만 담당합니다. 다른 에이전트나 사용자가 다른 repo를 수정할 수 있으므로 unrelated change를 되돌리지 마세요.

목표: baleen-marketplace dual-runtime rollout에 맞춰 memmem release/update workflow를 정리하세요.

요구사항:
1. .github/workflows/on-release.yml이 baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main 을 사용해 update_versions dispatch를 보내게 하세요.
2. scripts/verify-update-versions-workflow.test.sh가 .claude-plugin/marketplace.json, .claude-plugin/plugin.json, .codex-plugin/plugin.json 존재와 version consistency를 검사하게 하세요.
3. package.json, .claude-plugin/plugin.json, .codex-plugin/plugin.json, .claude-plugin/marketplace.json version drift를 release/package 기준으로 정리하세요.
4. .codex-plugin/plugin.json의 interface object와 mcpServers 필드는 보존하세요.
5. unrelated untracked docs/plans 파일은 건드리지 마세요.

검증:
- jq -r '.version' package.json .claude-plugin/plugin.json .codex-plugin/plugin.json
- jq -r '.plugins[0].version' .claude-plugin/marketplace.json
- jq empty .claude-plugin/plugin.json
- jq empty .codex-plugin/plugin.json
- jq empty .claude-plugin/marketplace.json
- bash scripts/verify-update-versions-workflow.test.sh
- bun run typecheck
- bun test --jobs=1
- bun run build
- bun dist/cli.mjs --help

완료 시 변경 파일, 실행한 검증 명령과 결과, 남은 리스크를 요약하세요.
```

- [ ] **Step 2: Review subagent result**

Check:

```bash
cd /Users/jito.hello/dev/wooto/memmem
git status --short
git diff --stat
git diff -- .github/workflows scripts .claude-plugin .codex-plugin README.md
```

- [ ] **Step 3: Commit memmem changes**

Only after review:

```bash
cd /Users/jito.hello/dev/wooto/memmem
git add .github/workflows scripts .claude-plugin .codex-plugin README.md
git commit -m "chore: sync marketplace release workflow"
```

---

### Task 7: Subagent Task for `bstack`

**Files:**
- Worktree: `/Users/jito.hello/dev/wooto/bstack`
- Modify: `.github/workflows/sync-marketplace.yml`
- Modify: `scripts/check-codex-artifacts.sh`
- Modify: `tests/codex_plugin_json.bats`
- Modify release workflow if separate from sync workflow
- Generated by command: `.agents/plugins/marketplace.json`, `plugins/*/.codex-plugin/plugin.json`

- [ ] **Step 1: Dispatch a worker subagent**

Prompt:

```text
한국어로 답하세요. /Users/jito.hello/dev/wooto/bstack 에서 작업하세요. 당신은 이 repo만 담당합니다. 다른 에이전트나 사용자가 다른 repo를 수정할 수 있으므로 unrelated change를 되돌리지 마세요.

목표: baleen-marketplace dual-runtime rollout에 맞춰 bstack의 Codex artifact 검증과 marketplace dispatch workflow를 정리하세요.

요구사항:
1. .github/workflows/sync-marketplace.yml의 change detection/git add가 jira/me/ralph만 보지 않고 전체 eligible Codex artifacts를 포함하게 하세요.
2. scripts/check-codex-artifacts.sh의 hardcoded jira/me/ralph assumptions를 제거하고 .agents/plugins/marketplace.json 및 plugins/*/.codex-plugin/plugin.json 전체 drift를 확인하게 하세요.
3. tests/codex_plugin_json.bats가 datadog/autoresearch를 포함한 eligible plugin 전체를 검증하게 하세요.
4. release 또는 sync workflow가 baleen37/baleen-marketplace/.github/actions/dispatch-marketplace-update@main 을 사용해 update_versions dispatch를 보내게 하세요.
5. Codex artifacts는 직접 손편집하지 말고 bun run sync:codex로 생성하세요.

검증:
- jq empty .claude-plugin/marketplace.json
- find plugins -path '*/.claude-plugin/plugin.json' -print -exec jq empty {} \\;
- find plugins -path '*/.codex-plugin/plugin.json' -print -exec jq empty {} \\;
- bun run sync:codex
- bun run check:codex
- git diff --exit-code -- .agents/plugins/marketplace.json 'plugins/*/.codex-plugin/plugin.json'
- bats tests/marketplace_json.bats tests/plugin_json.bats
- bats tests/codex_marketplace_json.bats tests/codex_plugin_json.bats
- bats tests/github_workflows.bats
- bun test
- bash tests/run-all-tests.sh

완료 시 변경 파일, 실행한 검증 명령과 결과, 남은 리스크를 요약하세요.
```

- [ ] **Step 2: Review subagent result**

Check:

```bash
cd /Users/jito.hello/dev/wooto/bstack
git status --short
git diff --stat
git diff -- .github/workflows scripts tests .agents plugins
```

- [ ] **Step 3: Commit bstack changes**

Only after review:

```bash
cd /Users/jito.hello/dev/wooto/bstack
git add .github/workflows scripts tests .agents plugins
git commit -m "chore: sync codex marketplace automation"
```

---

### Task 8: Final Integration Verification

**Files:**
- Verify all touched repositories.

- [ ] **Step 1: Verify marketplace**

Run:

```bash
cd /Users/jito.hello/dev/wooto/baleen-marketplace/.worktrees/00001-bright-otter-hopper
jq empty .claude-plugin/marketplace.json
jq empty .agents/plugins/marketplace.json
bash scripts/update-versions.test.sh
bash scripts/dispatch-marketplace-update.test.sh
MARKETPLACE_JSON=".claude-plugin/marketplace.json,.agents/plugins/marketplace.json" DRY_RUN=true bash scripts/update-versions.sh
git status --short
```

Expected: tests pass, dry-run writes no files, only intended changes remain committed.

- [ ] **Step 2: Verify memmem**

Run the Task 6 verification commands again from `/Users/jito.hello/dev/wooto/memmem`.

- [ ] **Step 3: Verify bstack**

Run the Task 7 verification commands again from `/Users/jito.hello/dev/wooto/bstack`.

- [ ] **Step 4: Final report**

Final response must include:

```text
Marketplace: commands run and pass/fail result
memmem: commands run and pass/fail result
bstack: commands run and pass/fail result
Commits: one line per repository
Known risks: private repo install requires access token; Codex marketplace source schema may need runtime validation if the local Codex installer rejects git+path entries
```
