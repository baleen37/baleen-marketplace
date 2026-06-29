#!/usr/bin/env bash
# e2e: discover-plugins → upsert-marketplace 로 만든 marketplace.json 이
# 실제로 설치 가능한 형태인지 검증한다.
#
# 회귀 방지 대상: sub-path 플러그인(모노레포 하위 디렉터리)의 source 가
# git-subdir + path 가 아니면, 클라이언트가 리포 루트를 통째로 받아
# skills/ 가 한 단계 묻혀 "Skills (0)" 으로 로드된다 (issue: create-pr 미인식).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCOVER="$ROOT/scripts/discover-plugins.sh"
UPSERT="$ROOT/scripts/upsert-marketplace.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ── 가짜 모노레포 체크아웃: 하위 디렉터리에 플러그인 2개 ──────────────────────
CO="$TMP/checkout"
mkdir -p "$CO/plugins/me/.claude-plugin" "$CO/plugins/me/skills/create-pr" \
         "$CO/plugins/jira/.claude-plugin"
echo '{"name":"me","version":"9.9.9"}'   > "$CO/plugins/me/.claude-plugin/plugin.json"
echo '{"name":"jira","version":"9.9.9"}' > "$CO/plugins/jira/.claude-plugin/plugin.json"
echo 'placeholder'                       > "$CO/plugins/me/skills/create-pr/SKILL.md"

cat > "$TMP/sources.json" <<'EOF'
{ "bstack": { "repo": "baleen37/bstack", "paths": ["plugins/*"] } }
EOF
echo '{"name":"bstack","plugins":[]}' > "$TMP/mp.json"

# ── discover → upsert ───────────────────────────────────────────────────────
SOURCES_JSON="$TMP/sources.json" bash "$DISCOVER" bstack "$CO" \
  | SOURCES_JSON="$TMP/sources.json" bash "$UPSERT" bstack "$TMP/mp.json"

# ── 불변식: sub-path 플러그인은 git-subdir + leading-./없는 path ─────────────
for n in me jira; do
  src=$(jq -r --arg n "$n" '.plugins[]|select(.name==$n)|.source.source' "$TMP/mp.json")
  [[ "$src" == "git-subdir" ]] \
    || { echo "FAIL: $n source.source=$src (expected git-subdir)"; exit 1; }
  p=$(jq -r --arg n "$n" '.plugins[]|select(.name==$n)|.source.path' "$TMP/mp.json")
  [[ "$p" == "plugins/$n" ]] \
    || { echo "FAIL: $n source.path=$p (expected plugins/$n, no leading ./)"; exit 1; }
  [[ "$p" != ./* ]] \
    || { echo "FAIL: $n source.path has leading ./ : $p"; exit 1; }
done
echo "PASS: e2e marketplace.json schema (git-subdir)"

# ── 회귀 가드: 깨진 형식(url+path / 상대경로)이 다시 새어나오지 않는지 ────────
# url 타입은 path 를 무시하므로 클라이언트가 리포 루트를 통째로 받는다.
bad_url=$(jq -r '[.plugins[]|select(.source.source=="url" and (.source|has("path")))]|length' "$TMP/mp.json")
[[ "$bad_url" == "0" ]] \
  || { echo "FAIL: $bad_url plugin(s) use url+path (path is ignored → root clone)"; exit 1; }
# URL 기반 marketplace 에서 상대경로 source 는 플러그인 파일이 다운로드되지 않는다.
bad_rel=$(jq -r '[.plugins[]|select((.source|type)=="string" and (.source|startswith("./")))]|length' "$TMP/mp.json")
[[ "$bad_rel" == "0" ]] \
  || { echo "FAIL: $bad_rel plugin(s) use relative-path source in a git marketplace"; exit 1; }
echo "PASS: e2e no broken source forms (url+path / relative)"
