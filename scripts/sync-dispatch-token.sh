#!/usr/bin/env bash
# Sync the current gh auth token as CROSS_REPO_DISPATCH_TOKEN to all plugin repos.
# Run this after `gh auth login` or `gh auth refresh` to keep secrets up to date.
#
# Usage: bash scripts/sync-dispatch-token.sh
set -euo pipefail

REPOS=(
  "baleen37/memmem"
  "baleen37/everything-agent"
)

TOKEN=$(gh auth token)
if [ -z "$TOKEN" ]; then
  echo "ERROR: No gh auth token found. Run 'gh auth login' first."
  exit 1
fi

# Verify the token has repo scope (needed for cross-repo dispatch)
SCOPES=$(gh auth status 2>&1 | grep "Token scopes" | head -1)
if ! echo "$SCOPES" | grep -q "repo"; then
  echo "ERROR: Token does not have 'repo' scope. Scopes: $SCOPES"
  exit 1
fi

for REPO in "${REPOS[@]}"; do
  echo "Setting CROSS_REPO_DISPATCH_TOKEN in $REPO..."
  echo "$TOKEN" | gh secret set CROSS_REPO_DISPATCH_TOKEN -R "$REPO"
  echo "  Done."
done

echo ""
echo "Token synced to ${#REPOS[@]} repos."
echo "Verify with: gh secret list -R <repo>"
