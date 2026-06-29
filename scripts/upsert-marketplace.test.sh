#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/upsert-marketplace.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/sources.json" <<'EOF'
{ "bstack": { "repo": "baleen37/bstack", "paths": ["plugins/*"] }, "memmem": { "repo": "baleen37/memmem", "paths": ["./"] } }
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

echo "PASS: upsert-marketplace (claude)"

# ── Codex FORMAT=codex ──────────────────────────────────────────────────────
# 신규 엔트리: memmem (path=".") → source.source=="git", source.path 없음
cat > "$TMP/codex-mp.json" <<'EOF'
{"name":"baleen-marketplace","plugins":[]}
EOF

echo '{"name":"memmem","version":"1.11.4","path":"."}' \
  | SOURCES_JSON="$TMP/sources.json" FORMAT=codex bash "$SCRIPT" memmem "$TMP/codex-mp.json"

src_source=$(jq -r '.plugins[0].source.source' "$TMP/codex-mp.json")
[[ "$src_source" == "git" ]] || { echo "FAIL: codex source.source=$src_source"; exit 1; }
src_url=$(jq -r '.plugins[0].source.url' "$TMP/codex-mp.json")
[[ "$src_url" == "https://github.com/baleen37/memmem.git" ]] || { echo "FAIL: codex url=$src_url"; exit 1; }
has_path=$(jq '.plugins[0].source | has("path")' "$TMP/codex-mp.json")
[[ "$has_path" == "false" ]] || { echo "FAIL: codex root entry should have no path, got has_path=$has_path"; exit 1; }
default_policy=$(jq -r '.plugins[0].policy.installation' "$TMP/codex-mp.json")
[[ "$default_policy" == "AVAILABLE" ]] || { echo "FAIL: codex default policy=$default_policy"; exit 1; }

# 기존 갱신: policy/category 보존 확인
cat > "$TMP/codex-mp2.json" <<'EOF'
{"name":"baleen-marketplace","plugins":[
  {"name":"memmem","source":{"source":"git","url":"https://github.com/baleen37/memmem.git"},"version":"1.11.3","category":"Productivity","policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"}}
]}
EOF

echo '{"name":"memmem","version":"1.11.4","path":"."}' \
  | SOURCES_JSON="$TMP/sources.json" FORMAT=codex bash "$SCRIPT" memmem "$TMP/codex-mp2.json"

ver=$(jq -r '.plugins[0].version' "$TMP/codex-mp2.json")
[[ "$ver" == "1.11.4" ]] || { echo "FAIL: codex version not updated: $ver"; exit 1; }
cat_val=$(jq -r '.plugins[0].category' "$TMP/codex-mp2.json")
[[ "$cat_val" == "Productivity" ]] || { echo "FAIL: codex category not preserved: $cat_val"; exit 1; }
policy_auth=$(jq -r '.plugins[0].policy.authentication' "$TMP/codex-mp2.json")
[[ "$policy_auth" == "ON_INSTALL" ]] || { echo "FAIL: codex policy.authentication not preserved: $policy_auth"; exit 1; }

# sub-path 엔트리: me (path="plugins/me") → source.path 있어야 함
echo '{"name":"me","version":"17.28.1","path":"plugins/me"}' \
  | SOURCES_JSON="$TMP/sources.json" FORMAT=codex bash "$SCRIPT" bstack "$TMP/codex-mp.json"

path_val=$(jq -r '.plugins[] | select(.name=="me") | .source.path' "$TMP/codex-mp.json")
[[ "$path_val" == "./plugins/me" ]] || { echo "FAIL: codex subpath=$path_val"; exit 1; }

echo "PASS: upsert-marketplace (codex)"
