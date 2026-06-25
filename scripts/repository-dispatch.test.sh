#!/usr/bin/env bash
set -euo pipefail

ACTION_FILE="${1:-.github/actions/repository-dispatch/action.yml}"

if [[ ! -f "$ACTION_FILE" ]]; then
  echo "ASSERTION FAILED: action file not found: $ACTION_FILE"
  exit 1
fi

required_patterns=(
  "token"
  "repository"
  "event-type"
  "client-payload"
  '/repos/${REPOSITORY}/dispatches'
  "client_payload"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -Fq "$pattern" "$ACTION_FILE"; then
    echo "ASSERTION FAILED: missing pattern in action: $pattern"
    exit 1
  fi
done

echo "repository dispatch action test passed"
