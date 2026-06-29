#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/sources.json"

jq empty "$F" || { echo "FAIL: invalid JSON"; exit 1; }

# 각 항목은 repo(owner/name)와 비어있지 않은 paths 배열을 가져야 한다
bad=$(jq -r 'to_entries[] | select((.value.repo // "" | test("^[^/]+/[^/]+$")) and (.value.paths | type=="array" and length>0) | not) | .key' "$F")
if [[ -n "$bad" ]]; then echo "FAIL: invalid entries: $bad"; exit 1; fi

echo "PASS: sources.json valid"
