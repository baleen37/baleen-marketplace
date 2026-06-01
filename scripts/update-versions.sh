#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_JSON="${MARKETPLACE_JSON:-.claude-plugin/marketplace.json}"
DRY_RUN="${DRY_RUN:-false}"
COMMIT_MESSAGE_PREFIX="${COMMIT_MESSAGE_PREFIX:-chore: update plugin versions}"

IFS=',' read -r -a MARKETPLACE_FILES <<< "$MARKETPLACE_JSON"

for i in "${!MARKETPLACE_FILES[@]}"; do
  MARKETPLACE_FILES[i]=$(echo "${MARKETPLACE_FILES[$i]}" | xargs)
  if [[ -z "${MARKETPLACE_FILES[$i]}" ]]; then
    echo "ERROR: Empty marketplace file path in MARKETPLACE_JSON=$MARKETPLACE_JSON" >&2
    exit 1
  fi
  if [[ ! -f "${MARKETPLACE_FILES[$i]}" ]]; then
    echo "ERROR: Marketplace file not found: ${MARKETPLACE_FILES[$i]}" >&2
    exit 1
  fi
done

CHANGED=false
CHANGE_LOG=""
CACHE_REPOS=()
CACHE_RELEASES=()
LATEST=""

extract_repo() {
  local url="$1"
  local repo=""

  if [[ "$url" == https://github.com/* ]]; then
    repo="${url#https://github.com/}"
  elif [[ "$url" == git@github.com:* ]]; then
    repo="${url#git@github.com:}"
  fi

  repo="${repo%.git}"
  repo="${repo%/}"
  echo "$repo"
}

fetch_latest_release() {
  local repo="$1"
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local fetched

  if [[ -n "$token" ]]; then
    fetched=$(curl -sf -H "Authorization: Bearer $token" "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name | ltrimstr("v")')
  else
    fetched=$(curl -sf "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name | ltrimstr("v")')
  fi

  if [[ -z "$fetched" || "$fetched" == "null" ]]; then
    LATEST=""
    return 1
  fi

  LATEST="$fetched"
}

cache_get() {
  local repo="$1"
  local i

  for i in "${!CACHE_REPOS[@]}"; do
    if [[ "${CACHE_REPOS[$i]}" == "$repo" ]]; then
      LATEST="${CACHE_RELEASES[$i]}"
      return 0
    fi
  done

  LATEST=""
  return 1
}

cache_put() {
  CACHE_REPOS+=("$1")
  CACHE_RELEASES+=("$2")
}

latest_for_repo() {
  local repo="$1"

  if cache_get "$repo"; then
    return 0
  fi

  if fetch_latest_release "$repo"; then
    cache_put "$repo" "$LATEST"
    return 0
  fi

  return 1
}

for marketplace_file in "${MARKETPLACE_FILES[@]}"; do
  # Read all plugins with a source block; url/git may be absent or unsupported.
  PLUGINS=$(jq -c '.plugins[] | select(.source != null)' "$marketplace_file")
  UPDATED=$(cat "$marketplace_file")

  if [[ -z "$PLUGINS" ]]; then
    continue
  fi

  while IFS= read -r plugin; do
    NAME=$(echo "$plugin" | jq -r '.name')
    URL=$(echo "$plugin" | jq -r '.source.url // .source.git // empty')
    CURRENT_VERSION=$(echo "$plugin" | jq -r '.version')

    if [[ -z "$URL" ]]; then
      continue
    fi

    REPO=$(extract_repo "$URL")
    if [[ -z "$REPO" ]]; then
      echo "WARNING: Could not extract GitHub repo for $NAME ($URL), skipping."
      continue
    fi

    if ! latest_for_repo "$REPO"; then
      echo "WARNING: Could not fetch latest release for $NAME ($REPO), skipping."
      continue
    fi

    echo "$NAME: current=$CURRENT_VERSION latest=$LATEST"

    if [[ "$LATEST" != "$CURRENT_VERSION" ]]; then
      UPDATED=$(echo "$UPDATED" | jq --arg name "$NAME" --arg ver "$LATEST" --indent 2 \
        '(.plugins[] | select(.name == $name) | .version) |= $ver')
      CHANGED=true
      CHANGE_LOG="${CHANGE_LOG:+$CHANGE_LOG, }$NAME $CURRENT_VERSION->$LATEST"
    fi
  done <<< "$PLUGINS"

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$UPDATED" != "$(cat "$marketplace_file")" ]]; then
      echo "DRY_RUN: would update $marketplace_file"
    fi
  else
    echo "$UPDATED" > "$marketplace_file"
  fi
done

if [[ "$CHANGED" == "false" ]]; then
  echo "No version changes detected."
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN: changes: $CHANGE_LOG"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "${MARKETPLACE_FILES[@]}"

if git diff --cached --quiet; then
  echo "No diff after update, skipping commit."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE_PREFIX ($CHANGE_LOG)"
git push
