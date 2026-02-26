#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/update-versions.sh"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ASSERTION FAILED: expected output to contain: $needle"
    echo "  actual: $haystack"
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ASSERTION FAILED: expected output NOT to contain: $needle"
    echo "  actual: $haystack"
    exit 1
  fi
}

setup_mock_curl() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"tag_name":"v1.2.3"}
JSON
EOF
  chmod +x "$bin_dir/curl"
}

setup_repo() {
  local repo_dir="$1"
  local remote_dir="$2"

  mkdir -p "$repo_dir/.claude-plugin"
  cat > "$repo_dir/.claude-plugin/custom-marketplace.json" <<'EOF'
{
  "plugins": [
    {
      "name": "memmem",
      "version": "1.0.0",
      "source": {
        "url": "https://github.com/baleen37/memmem.git"
      }
    }
  ]
}
EOF

  git init "$repo_dir" >/dev/null
  git -C "$repo_dir" config user.name "test"
  git -C "$repo_dir" config user.email "test@example.com"
  git -C "$repo_dir" add .
  git -C "$repo_dir" commit -m "init" >/dev/null

  git init --bare "$remote_dir" >/dev/null
  git -C "$repo_dir" remote add origin "$remote_dir"
  git -C "$repo_dir" branch -M main
  git -C "$repo_dir" push -u origin main >/dev/null 2>&1
}

test_dry_run_with_marketplace_override() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  setup_repo "$repo" "$remote"
  setup_mock_curl "$bin_dir"

  local before
  before=$(cat "$repo/.claude-plugin/custom-marketplace.json")

  local output
  output=$(cd "$repo" && PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" DRY_RUN="true" bash "$SCRIPT_PATH")

  local after
  after=$(cat "$repo/.claude-plugin/custom-marketplace.json")

  if [[ "$before" != "$after" ]]; then
    echo "ASSERTION FAILED: dry-run must not modify marketplace file"
    exit 1
  fi

  assert_contains "$output" "DRY_RUN: would update"
}

test_commit_prefix_and_override_path() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  setup_repo "$repo" "$remote"
  setup_mock_curl "$bin_dir"

  (cd "$repo" && PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" COMMIT_MESSAGE_PREFIX="ci: automated update" bash "$SCRIPT_PATH")

  local version
  version=$(jq -r '.plugins[0].version' "$repo/.claude-plugin/custom-marketplace.json")
  if [[ "$version" != "1.2.3" ]]; then
    echo "ASSERTION FAILED: expected version to be updated to 1.2.3, got $version"
    exit 1
  fi

  local msg
  msg=$(git -C "$repo" log -1 --pretty=%s)
  assert_contains "$msg" "ci: automated update"
}

setup_mock_curl_fail() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/curl" <<'CURLEOF'
#!/usr/bin/env bash
exit 22
CURLEOF
  chmod +x "$bin_dir/curl"
}

setup_mock_curl_mixed() {
  local bin_dir="$1"
  local fail_repo="$2"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/curl" <<CURLEOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$*" == *"$fail_repo"* ]]; then
  exit 22
fi
cat <<'JSON'
{"tag_name":"v1.2.3"}
JSON
CURLEOF
  chmod +x "$bin_dir/curl"
}

test_curl_failure_skips_plugin() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  setup_repo "$repo" "$remote"
  setup_mock_curl_fail "$bin_dir"

  local output
  output=$(cd "$repo" && PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" bash "$SCRIPT_PATH" 2>&1) || true

  assert_contains "$output" "WARNING"
  assert_contains "$output" "No version changes detected."
}

test_curl_failure_skips_only_failed_plugin() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  mkdir -p "$repo/.claude-plugin"
  cat > "$repo/.claude-plugin/custom-marketplace.json" <<'EOF'
{
  "plugins": [
    {
      "name": "plugin-a",
      "version": "1.0.0",
      "source": {
        "url": "https://github.com/owner/fail-repo.git"
      }
    },
    {
      "name": "plugin-b",
      "version": "1.0.0",
      "source": {
        "url": "https://github.com/owner/good-repo.git"
      }
    }
  ]
}
EOF

  git init "$repo" >/dev/null
  git -C "$repo" config user.name "test"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" add .
  git -C "$repo" commit -m "init" >/dev/null

  git init --bare "$remote" >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" branch -M main
  git -C "$repo" push -u origin main >/dev/null 2>&1

  setup_mock_curl_mixed "$bin_dir" "owner/fail-repo"

  local output
  output=$(cd "$repo" && PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" bash "$SCRIPT_PATH" 2>&1)

  assert_contains "$output" "WARNING"
  assert_contains "$output" "plugin-a"

  local version_b
  version_b=$(jq -r '.plugins[1].version' "$repo/.claude-plugin/custom-marketplace.json")
  if [[ "$version_b" != "1.2.3" ]]; then
    echo "ASSERTION FAILED: plugin-b should be updated to 1.2.3, got $version_b"
    exit 1
  fi
}

test_commit_message_no_leading_space() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"
  local bin_dir="$tmp/bin"

  setup_repo "$repo" "$remote"
  setup_mock_curl "$bin_dir"

  (cd "$repo" && PATH="$bin_dir:$PATH" MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" bash "$SCRIPT_PATH")

  local msg
  msg=$(git -C "$repo" log -1 --pretty=%s)
  assert_not_contains "$msg" "( "
  assert_contains "$msg" "(memmem"
}

test_no_url_plugins_exits_cleanly() {
  local tmp
  tmp=$(mktemp -d)
  local repo="$tmp/repo"
  local remote="$tmp/remote.git"

  mkdir -p "$repo/.claude-plugin"
  cat > "$repo/.claude-plugin/custom-marketplace.json" <<'EOF'
{
  "plugins": [
    {
      "name": "local-only",
      "version": "1.0.0",
      "source": {}
    }
  ]
}
EOF

  git init "$repo" >/dev/null
  git -C "$repo" config user.name "test"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" add .
  git -C "$repo" commit -m "init" >/dev/null

  git init --bare "$remote" >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" branch -M main
  git -C "$repo" push -u origin main >/dev/null 2>&1

  local output
  output=$(cd "$repo" && MARKETPLACE_JSON=".claude-plugin/custom-marketplace.json" bash "$SCRIPT_PATH" 2>&1)

  assert_contains "$output" "No version changes detected."
}

main() {
  test_dry_run_with_marketplace_override
  test_commit_prefix_and_override_path
  test_curl_failure_skips_plugin
  test_curl_failure_skips_only_failed_plugin
  test_commit_message_no_leading_space
  test_no_url_plugins_exits_cleanly
  echo "All tests passed"
}

main
