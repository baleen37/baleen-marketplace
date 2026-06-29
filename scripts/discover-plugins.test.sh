#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/discover-plugins.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/sources.json" <<'EOF'
{ "private-journal-mcp": { "repo": "baleen37/private-journal-mcp", "paths": ["./"] },
  "bstack": { "repo": "baleen37/bstack", "paths": ["plugins/*"] } }
EOF

# 케이스 A: 루트형 (./에 plugin.json)
mkdir -p "$TMP/rootform/.claude-plugin"
echo '{"name":"foo","version":"1.2.3"}' > "$TMP/rootform/.claude-plugin/plugin.json"
out=$(SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" private-journal-mcp "$TMP/rootform")
echo "$out" | jq -e 'select(.name=="foo" and .version=="1.2.3" and .path==".")' >/dev/null \
  || { echo "FAIL: rootform discovery"; echo "$out"; exit 1; }

# 케이스 B: 멀티형 (plugins/*에 여러 plugin.json)
mkdir -p "$TMP/multi/plugins/a/.claude-plugin" "$TMP/multi/plugins/b/.claude-plugin"
echo '{"name":"a","version":"9.0.0"}' > "$TMP/multi/plugins/a/.claude-plugin/plugin.json"
echo '{"name":"b","version":"9.0.0"}' > "$TMP/multi/plugins/b/.claude-plugin/plugin.json"
cnt=$(SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" bstack "$TMP/multi" | jq -s 'length')
[[ "$cnt" == "2" ]] || { echo "FAIL: multi discovery count=$cnt"; exit 1; }

echo "PASS: discover-plugins"
