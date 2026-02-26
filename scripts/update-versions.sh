#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_JSON="${MARKETPLACE_JSON:-.claude-plugin/marketplace.json}"
DRY_RUN="${DRY_RUN:-false}"
COMMIT_MESSAGE_PREFIX="${COMMIT_MESSAGE_PREFIX:-chore: update plugin versions}"

# Read all plugins with a github url source
PLUGINS=$(jq -c '.plugins[] | select(.source.url != null)' "$MARKETPLACE_JSON")

if [[ -z "$PLUGINS" ]]; then
  echo "No version changes detected."
  exit 0
fi

UPDATED=$(cat "$MARKETPLACE_JSON")
CHANGED=false
CHANGE_LOG=""

while IFS= read -r plugin; do
  NAME=$(echo "$plugin" | jq -r '.name')
  URL=$(echo "$plugin" | jq -r '.source.url')
  CURRENT_VERSION=$(echo "$plugin" | jq -r '.version')

  # Extract owner/repo from https://github.com/owner/repo.git
  REPO=$(echo "$URL" | sed 's|https://github.com/||;s|\.git$||')

  # Fetch latest release tag via GitHub API (no auth needed for public repos)
  if ! LATEST=$(curl -sf "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name | ltrimstr("v")'); then
    echo "WARNING: Could not fetch latest release for $NAME ($REPO), skipping."
    continue
  fi

  if [[ -z "$LATEST" || "$LATEST" == "null" ]]; then
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

if [[ "$CHANGED" == "false" ]]; then
  echo "No version changes detected."
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY_RUN: would update $MARKETPLACE_JSON with: $CHANGE_LOG"
  exit 0
fi

echo "$UPDATED" > "$MARKETPLACE_JSON"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$MARKETPLACE_JSON"

if git diff --cached --quiet; then
  echo "No diff after update, skipping commit."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE_PREFIX ($CHANGE_LOG)"
git push
