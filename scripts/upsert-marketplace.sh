#!/usr/bin/env bash
set -euo pipefail

SOURCE_NAME="${1:?source name required}"
MP="${2:?marketplace json path required}"
SOURCES_JSON="${SOURCES_JSON:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sources.json}"
FORMAT="${FORMAT:-claude}"

REPO=$(jq -r --arg s "$SOURCE_NAME" '.[$s].repo' "$SOURCES_JSON")
URL="https://github.com/${REPO}.git"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(jq -r '.name' <<<"$line")
  version=$(jq -r '.version' <<<"$line")
  path=$(jq -r '.path' <<<"$line")
  # git-subdir 의 path 는 leading ./ 없이 (docs 예시: "tools/claude-plugin")
  src_path=$([[ "$path" == "." ]] && echo "" || echo "$path")

  MPDATA=$(cat "$MP")

  if [[ "$FORMAT" == "codex" ]]; then
    if jq -e --arg n "$name" '.plugins[] | select(.name==$n)' <<<"$MPDATA" >/dev/null; then
      # 갱신: version + source.{source,url,path} 업데이트, policy/category 보존
      jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
        (.plugins[] | select(.name==$n)) |= (
          .version=$v |
          .source.url=$u |
          (if $p=="" then .source.source="git" | .source|=del(.path)
           else .source.source="git-subdir" | .source.path=$p end)
        )
      ' <<<"$MPDATA" > "$MP"
    else
      # 추가: default policy 포함
      jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
        .plugins += [
          {name:$n, source:{source:"git", url:$u}, version:$v,
           policy:{installation:"AVAILABLE", authentication:"ON_INSTALL"}}
          | (if $p=="" then . else .source.source="git-subdir" | .source.path=$p end)
        ]
      ' <<<"$MPDATA" > "$MP"
    fi
  else
    if jq -e --arg n "$name" '.plugins[] | select(.name==$n)' <<<"$MPDATA" >/dev/null; then
      # 갱신
      jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
        (.plugins[] | select(.name==$n)) |= (.version=$v | .source.url=$u | (if $p=="" then .source.source="git" | .source|=del(.path) else .source.source="git-subdir" | .source.path=$p end))
      ' <<<"$MPDATA" > "$MP"
    else
      # 추가
      jq --arg n "$name" --arg v "$version" --arg u "$URL" --arg p "$src_path" --indent 2 '
        .plugins += [ ({name:$n, version:$v} | (if $p=="" then .source={source:"git", url:$u} else .source={source:"git-subdir", url:$u, path:$p} end)) ]
      ' <<<"$MPDATA" > "$MP"
    fi
  fi
done
