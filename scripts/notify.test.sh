#!/usr/bin/env bash
set -euo pipefail

ACTION_FILE="${1:-.github/actions/notify/action.yml}"

if [[ ! -f "$ACTION_FILE" ]]; then
  echo "ASSERTION FAILED: action file not found: $ACTION_FILE"
  exit 1
fi

# Verify required patterns exist in action file
required_patterns=(
  "source"
  "version"
  "token"
  "repository"
  "update_versions"
  "client_payload"
  '/repos/${REPOSITORY}/dispatches'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -Fq "$pattern" "$ACTION_FILE"; then
    echo "ASSERTION FAILED: missing pattern in action: $pattern"
    exit 1
  fi
done

# Test payload jq assembly: verify all required keys are present
payload=$(jq -n \
  --arg source "bstack" \
  --arg version "1.2.3" \
  --arg repo "owner/repo" \
  --arg ref "refs/heads/main" \
  --arg sha "abc123def456" \
  '{event_type:"update_versions", client_payload:{source:$source, version:$version, repo:$repo, ref:$ref, sha:$sha}}')

for key in source version repo ref sha; do
  val=$(echo "$payload" | jq -r --arg k "$key" '.client_payload[$k]')
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "ASSERTION FAILED: client_payload missing key: $key"
    exit 1
  fi
done

# Test v-prefix stripping: "v1.2.3" should become "1.2.3" in payload
raw_version="v1.2.3"
version="${raw_version#v}"
payload_v=$(jq -n \
  --arg source "bstack" \
  --arg version "$version" \
  --arg repo "owner/repo" \
  --arg ref "refs/heads/main" \
  --arg sha "abc123def456" \
  '{event_type:"update_versions", client_payload:{source:$source, version:$version, repo:$repo, ref:$ref, sha:$sha}}')

actual_version=$(echo "$payload_v" | jq -r '.client_payload.version')
if [[ "$actual_version" == v* ]]; then
  echo "ASSERTION FAILED: version still has 'v' prefix: $actual_version"
  exit 1
fi
if [[ "$actual_version" != "1.2.3" ]]; then
  echo "ASSERTION FAILED: expected version=1.2.3, got: $actual_version"
  exit 1
fi

echo "notify action test passed"
