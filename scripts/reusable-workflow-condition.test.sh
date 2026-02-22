#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_FILE="${1:-.github/workflows/reusable-update-versions.yml}"
EXPECTED_CONDITION='${{ github.event_name == '\''workflow_call'\'' || github.repository == '\''baleen37/baleen-marketplace'\'' }}'

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "ASSERTION FAILED: workflow file not found: $WORKFLOW_FILE"
  exit 1
fi

ACTUAL_CONDITION=$(python3 - "$WORKFLOW_FILE" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("if:"):
            print(stripped[len("if:"):].strip())
            break
PY
)

if [[ -z "$ACTUAL_CONDITION" ]]; then
  echo "ASSERTION FAILED: could not find job if condition"
  exit 1
fi

if [[ "$ACTUAL_CONDITION" != "$EXPECTED_CONDITION" ]]; then
  echo "ASSERTION FAILED: unexpected job if condition"
  echo "  expected: $EXPECTED_CONDITION"
  echo "  actual:   $ACTUAL_CONDITION"
  exit 1
fi

should_run() {
  local event_name="$1"
  local repository="$2"
  if [[ "$event_name" == "workflow_call" || "$repository" == "baleen37/baleen-marketplace" ]]; then
    return 0
  fi
  return 1
}

assert_runs() {
  local event_name="$1"
  local repository="$2"
  if ! should_run "$event_name" "$repository"; then
    echo "ASSERTION FAILED: expected run but got skip for event=$event_name repo=$repository"
    exit 1
  fi
}

assert_skips() {
  local event_name="$1"
  local repository="$2"
  if should_run "$event_name" "$repository"; then
    echo "ASSERTION FAILED: expected skip but got run for event=$event_name repo=$repository"
    exit 1
  fi
}

assert_runs "workflow_dispatch" "baleen37/baleen-marketplace"
assert_runs "repository_dispatch" "baleen37/baleen-marketplace"
assert_runs "workflow_call" "other-org/other-repo"
assert_skips "workflow_dispatch" "other-org/other-repo"

echo "reusable workflow condition test passed"