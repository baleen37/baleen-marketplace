#!/usr/bin/env bash
set -euo pipefail

SOURCE_NAME="${1:?source name required}"
CHECKOUT_DIR="${2:?checkout dir required}"
SOURCES_JSON="${SOURCES_JSON:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sources.json}"

# sources.json에 등록된 source만 허용 (allowlist)
if ! jq -e --arg s "$SOURCE_NAME" 'has($s)' "$SOURCES_JSON" >/dev/null; then
  echo "ERROR: unknown source: $SOURCE_NAME (not in sources.json)" >&2
  exit 1
fi

PATTERNS=()
while IFS= read -r pattern; do
  PATTERNS+=("$pattern")
done < <(jq -r --arg s "$SOURCE_NAME" '.[$s].paths[]' "$SOURCES_JSON")

emit() {  # dir 안에 plugin.json이 있으면 JSONL 한 줄 출력
  local dir="$1" rel manifest
  manifest="$dir/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || return 0
  rel="${dir#"$CHECKOUT_DIR"/}"; [[ "$rel" == "$dir" ]] && rel="."
  jq -c --arg path "$rel" '{name, version, path: $path}' "$manifest"
}

for pat in "${PATTERNS[@]}"; do
  if [[ "$pat" == "./" || "$pat" == "." ]]; then
    emit "$CHECKOUT_DIR"
  else
    # glob 확장 (예: plugins/*)
    shopt -s nullglob
    for d in "$CHECKOUT_DIR"/$pat; do
      [[ -d "$d" ]] && emit "$d"
    done
    shopt -u nullglob
  fi
done
