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
