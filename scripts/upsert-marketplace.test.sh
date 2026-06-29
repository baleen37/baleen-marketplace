#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/upsert-marketplace.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/sources.json" <<'EOF'
{ "bstack": { "repo": "baleen37/bstack", "paths": ["plugins/*"] } }
EOF
echo '{"name":"bstack","plugins":[]}' > "$TMP/mp.json"

# 신규 플러그인 2개 발견 → 추가
printf '%s\n%s\n' '{"name":"me","version":"17.28.1","path":"plugins/me"}' \
                  '{"name":"jira","version":"17.28.1","path":"plugins/jira"}' \
  | SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" bstack "$TMP/mp.json"

cnt=$(jq '.plugins | length' "$TMP/mp.json")
[[ "$cnt" == "2" ]] || { echo "FAIL: expected 2 plugins got $cnt"; exit 1; }
url=$(jq -r '.plugins[] | select(.name=="me") | .source.url' "$TMP/mp.json")
[[ "$url" == "https://github.com/baleen37/bstack.git" ]] || { echo "FAIL: url=$url"; exit 1; }

# 기존 갱신: me 버전 변경
echo '{"name":"me","version":"17.29.0","path":"plugins/me"}' \
  | SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" bstack "$TMP/mp.json"
ver=$(jq -r '.plugins[] | select(.name=="me") | .version' "$TMP/mp.json")
[[ "$ver" == "17.29.0" ]] || { echo "FAIL: version not updated: $ver"; exit 1; }

echo "PASS: upsert-marketplace"
