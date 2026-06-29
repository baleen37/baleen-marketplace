#!/usr/bin/env bash
# smoke: 실제 클라이언트가 git-subdir source 로 me 플러그인을 설치했을 때
# 스킬이 로드되는지(Skills > 0) 끝단까지 확인한다.
#
# 회귀 대상: source 가 url+path 면 path 가 무시돼 bstack 리포 루트가 통째로
# 받아지고, skills/ 가 plugins/me/skills/ 로 묻혀 "Skills (0)" 이 된다
# (create-pr 등 me 스킬 전부 미인식).
#
# 외부 의존(claude CLI, github 네트워크)이 없으면 SKIP — CI 안전.
# user-scope 플러그인 상태를 임시로 건드리므로 반드시 trap 으로 정리한다.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v claude >/dev/null 2>&1 || { echo "SKIP: smoke (claude CLI not found)"; exit 0; }
git ls-remote https://github.com/baleen37/bstack.git HEAD >/dev/null 2>&1 \
  || { echo "SKIP: smoke (bstack.git unreachable)"; exit 0; }

MP_NAME="bstack-smoke"
TMP=$(mktemp -d)
cleanup() {
  claude plugin uninstall "me@$MP_NAME"        >/dev/null 2>&1 || true
  claude plugin marketplace remove "$MP_NAME"  >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

# git-subdir 형식 marketplace.json (수정된 파이프라인이 산출하는 형태)
mkdir -p "$TMP/.claude-plugin"
jq -n --arg name "$MP_NAME" '{
  name: $name,
  owner: { name: "smoke", email: "smoke@example.com" },
  plugins: [ {
    name: "me",
    source: { source: "git-subdir",
              url: "https://github.com/baleen37/bstack.git",
              path: "plugins/me" }
  } ]
}' > "$TMP/.claude-plugin/marketplace.json"

claude plugin marketplace add "$TMP"             >/dev/null 2>&1 \
  || { echo "FAIL: marketplace add"; exit 1; }
claude plugin install "me@$MP_NAME" --scope user >/dev/null 2>&1 \
  || { echo "FAIL: plugin install"; exit 1; }

skills=$(claude plugin details me 2>/dev/null \
           | grep -oE 'Skills \([0-9]+\)' | grep -oE '[0-9]+' | head -1)
[[ "${skills:-0}" -ge 1 ]] \
  || { echo "FAIL: me Skills=${skills:-0} (expected >=1 — git-subdir path 미적용 회귀)"; exit 1; }

# create-pr 가 실제로 인식되는지(원래 신고된 증상)까지 확인
if claude plugin details me 2>/dev/null | grep -q 'create-pr'; then
  echo "PASS: smoke install (me Skills=$skills, create-pr present)"
else
  echo "FAIL: me installed but create-pr skill missing"; exit 1
fi
