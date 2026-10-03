#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/sources.json"

jq empty "$F" || { echo "FAIL: invalid JSON"; exit 1; }

jq -e 'has("skills") and (has("bstack") | not) and .skills.repo == "baleen37/skills"' "$F" >/dev/null \
  || { echo "FAIL: skills source must point to baleen37/skills"; exit 1; }

for catalog in "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.agents/plugins/marketplace.json"; do
  jq -e '[.plugins[] | select(.source.url == "https://github.com/baleen37/skills.git")] | length == 5' "$catalog" >/dev/null \
    || { echo "FAIL: skills plugin entries missing from $catalog"; exit 1; }
  if grep -q 'github.com/baleen37/bstack.git' "$catalog"; then
    echo "FAIL: old bstack source URL remains in $catalog"
    exit 1
  fi
done

# 각 항목은 repo(owner/name)와 비어있지 않은 paths 배열을 가져야 한다
bad=$(jq -r 'to_entries[] | select((.value.repo // "" | test("^[^/]+/[^/]+$")) and (.value.paths | type=="array" and length>0) | not) | .key' "$F")
if [[ -n "$bad" ]]; then echo "FAIL: invalid entries: $bad"; exit 1; fi

echo "PASS: sources.json valid"
