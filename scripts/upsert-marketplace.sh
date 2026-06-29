#!/usr/bin/env bash
set -euo pipefail

SOURCE_NAME="${1:?source name required}"
MP="${2:?marketplace json path required}"
SOURCES_JSON="${SOURCES_JSON:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sources.json}"

REPO=$(jq -r --arg s "$SOURCE_NAME" '.[$s].repo' "$SOURCES_JSON")
URL="https://github.com/${REPO}.git"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(jq -r '.name' <<<"$line")
  version=$(jq -r '.version' <<<"$line")
  path=$(jq -r '.path' <<<"$line")
  src_path=$([[ "$path" == "." ]] && echo "" || echo "./$path")

  MPDATA=$(cat "$MP")
  if jq -e --arg n "$name" '.plugins[] | select(.name==$n)' <<<"$MPDATA" >/dev/null; then
    # 갱신
    jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
      (.plugins[] | select(.name==$n)) |= (.version=$v | .source.url=$u | (if $p=="" then .source|=del(.path) else .source.path=$p end))
    ' <<<"$MPDATA" > "$MP"
  else
    # 추가
    jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
      .plugins += [ ({name:$n, version:$v, source:{url:$u}} | (if $p=="" then . else .source.path=$p end)) ]
    ' <<<"$MPDATA" > "$MP"
  fi
done
