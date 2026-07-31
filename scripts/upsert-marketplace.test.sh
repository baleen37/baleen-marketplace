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
# sub-path 엔트리는 git-subdir 타입이어야 클라이언트가 path 로 sparse-clone 한다
src=$(jq -r '.plugins[] | select(.name=="me") | .source.source' "$TMP/mp.json")
[[ "$src" == "git-subdir" ]] || { echo "FAIL: me source.source=$src (expected git-subdir)"; exit 1; }
# path 는 leading ./ 없이 (docs 예시: "tools/claude-plugin")
p=$(jq -r '.plugins[] | select(.name=="me") | .source.path' "$TMP/mp.json")
[[ "$p" == "plugins/me" ]] || { echo "FAIL: me source.path=$p (expected plugins/me)"; exit 1; }

# 기존 갱신: me 버전 변경 + source 타입 유지
echo '{"name":"me","version":"17.29.0","path":"plugins/me"}' \
  | SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" bstack "$TMP/mp.json"
ver=$(jq -r '.plugins[] | select(.name=="me") | .version' "$TMP/mp.json")
[[ "$ver" == "17.29.0" ]] || { echo "FAIL: version not updated: $ver"; exit 1; }
src=$(jq -r '.plugins[] | select(.name=="me") | .source.source' "$TMP/mp.json")
[[ "$src" == "git-subdir" ]] || { echo "FAIL: me source.source after update=$src (expected git-subdir)"; exit 1; }
p=$(jq -r '.plugins[] | select(.name=="me") | .source.path' "$TMP/mp.json")
[[ "$p" == "plugins/me" ]] || { echo "FAIL: me source.path after update=$p (expected plugins/me)"; exit 1; }

# 루트 플러그인은 Claude가 지원하는 HTTPS URL source로 생성하고 기존 엔트리도 마이그레이션한다
echo '{"name":"memmem","version":"1.11.3","path":"."}' \
  | SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" memmem "$TMP/mp.json"
src=$(jq -r '.plugins[] | select(.name=="memmem") | .source.source' "$TMP/mp.json")
[[ "$src" == "url" ]] || { echo "FAIL: memmem source.source=$src (expected url)"; exit 1; }
url=$(jq -r '.plugins[] | select(.name=="memmem") | .source.url' "$TMP/mp.json")
[[ "$url" == "https://github.com/baleen37/memmem.git" ]] || { echo "FAIL: memmem source.url=$url"; exit 1; }

echo '{"name":"memmem","version":"1.11.4","path":"."}' \
  | SOURCES_JSON="$TMP/sources.json" bash "$SCRIPT" memmem "$TMP/mp.json"
src=$(jq -r '.plugins[] | select(.name=="memmem") | .source.source' "$TMP/mp.json")
[[ "$src" == "url" ]] || { echo "FAIL: updated memmem source.source=$src (expected url)"; exit 1; }
url=$(jq -r '.plugins[] | select(.name=="memmem") | .source.url' "$TMP/mp.json")
[[ "$url" == "https://github.com/baleen37/memmem.git" ]] || { echo "FAIL: updated memmem source.url=$url"; exit 1; }
has_repo=$(jq '.plugins[] | select(.name=="memmem") | .source | has("repo")' "$TMP/mp.json")
[[ "$has_repo" == "false" ]] || { echo "FAIL: updated memmem root entry should have no repo"; exit 1; }

echo "PASS: upsert-marketplace (claude)"

# ── Codex FORMAT=codex ──────────────────────────────────────────────────────
# 신규 엔트리: memmem (path=".") → Codex는 루트 repo source를 "url"로 인식한다
cat > "$TMP/codex-mp.json" <<'EOF'
{"name":"baleen-marketplace","plugins":[]}
EOF

echo '{"name":"memmem","version":"1.11.4","path":"."}' \
  | SOURCES_JSON="$TMP/sources.json" FORMAT=codex bash "$SCRIPT" memmem "$TMP/codex-mp.json"

src_source=$(jq -r '.plugins[0].source.source' "$TMP/codex-mp.json")
[[ "$src_source" == "url" ]] || { echo "FAIL: codex source.source=$src_source (expected url)"; exit 1; }
src_url=$(jq -r '.plugins[0].source.url' "$TMP/codex-mp.json")
[[ "$src_url" == "https://github.com/baleen37/memmem.git" ]] || { echo "FAIL: codex url=$src_url"; exit 1; }
has_path=$(jq '.plugins[0].source | has("path")' "$TMP/codex-mp.json")
[[ "$has_path" == "false" ]] || { echo "FAIL: codex root entry should have no path, got has_path=$has_path"; exit 1; }
default_policy=$(jq -r '.plugins[0].policy.installation' "$TMP/codex-mp.json")
[[ "$default_policy" == "AVAILABLE" ]] || { echo "FAIL: codex default policy=$default_policy"; exit 1; }

# 기존 갱신: policy/category 보존 확인
cat > "$TMP/codex-mp2.json" <<'EOF'
{"name":"baleen-marketplace","plugins":[
  {"name":"memmem","source":{"source":"url","url":"https://github.com/baleen37/memmem.git"},"version":"1.11.3","category":"Productivity","policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"}}
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
src_source=$(jq -r '.plugins[0].source.source' "$TMP/codex-mp2.json")
[[ "$src_source" == "url" ]] || { echo "FAIL: codex source.source after update=$src_source (expected url)"; exit 1; }

# sub-path 엔트리: me (path="plugins/me") → git-subdir + leading ./ 없는 path
echo '{"name":"me","version":"17.28.1","path":"plugins/me"}' \
  | SOURCES_JSON="$TMP/sources.json" FORMAT=codex bash "$SCRIPT" bstack "$TMP/codex-mp.json"

src_val=$(jq -r '.plugins[] | select(.name=="me") | .source.source' "$TMP/codex-mp.json")
[[ "$src_val" == "git-subdir" ]] || { echo "FAIL: codex me source.source=$src_val (expected git-subdir)"; exit 1; }
path_val=$(jq -r '.plugins[] | select(.name=="me") | .source.path' "$TMP/codex-mp.json")
[[ "$path_val" == "plugins/me" ]] || { echo "FAIL: codex subpath=$path_val (expected plugins/me)"; exit 1; }

echo "PASS: upsert-marketplace (codex)"

# 현재 bstack 발견 결과로 갱신하면 퇴역 항목만 제거하고 다른 source 항목은 보존한다.
for format in claude codex; do
  cat > "$TMP/removal-$format.json" <<'EOF'
{"name":"baleen-marketplace","plugins":[
  {"name":"memmem","source":{"source":"url","url":"https://github.com/baleen37/memmem.git"},"version":"1.13.1"},
  {"name":"me","source":{"source":"git-subdir","url":"https://github.com/baleen37/bstack.git","path":"plugins/me"},"version":"17.38.0"},
  {"name":"jira","source":{"source":"git-subdir","url":"https://github.com/baleen37/bstack.git","path":"plugins/jira"},"version":"17.38.1"},
  {"name":"notion","source":{"source":"git-subdir","url":"https://github.com/baleen37/bstack.git","path":"plugins/notion"},"version":"17.38.1"},
  {"name":"slack","source":{"source":"git-subdir","url":"https://github.com/baleen37/bstack.git","path":"plugins/slack"},"version":"17.38.1"}
]}
EOF

  FORMAT="$format" bash "$SCRIPT" bstack "$TMP/removal-$format.json" \
    < "$ROOT/scripts/fixtures/bstack-current.jsonl"

  names=$(jq -c '[.plugins[].name] | sort' "$TMP/removal-$format.json")
  expected='["autoresearch","datadog","me","memmem"]'
  [[ "$names" == "$expected" ]] \
    || { echo "FAIL: $format source sync names=$names expected=$expected"; exit 1; }
  memmem_version=$(jq -r '.plugins[] | select(.name=="memmem") | .version' "$TMP/removal-$format.json")
  [[ "$memmem_version" == "1.13.1" ]] \
    || { echo "FAIL: $format other-source entry changed"; exit 1; }

  : | FORMAT="$format" bash "$SCRIPT" bstack "$TMP/removal-$format.json"
  names=$(jq -c '[.plugins[].name] | sort' "$TMP/removal-$format.json")
  [[ "$names" == '["memmem"]' ]] \
    || { echo "FAIL: $format empty source sync names=$names expected=[\"memmem\"]"; exit 1; }
done

echo "PASS: upsert-marketplace removes retired source entries"
