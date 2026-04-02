#!/usr/bin/env bash
# Update the Active Overrides table in the guidebook when overrides are re-applied.
# Usage: update-override-version.sh <plugin-name> <new-version>
# Example: update-override-version.sh superpowers 5.0.6

set -euo pipefail

GUIDEBOOK="$HOME/.claude/plugin-override-guidebook.md"
DOTFILES_GUIDEBOOK="$HOME/homelab-scripts/dotfiles/claude-code/.claude/plugin-override-guidebook.md"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <plugin-name> <new-version>"
  echo "Example: $0 superpowers 5.0.6"
  exit 1
fi

PLUGIN="$1"
NEW_VERSION="$2"
TODAY="$(date +%Y-%m-%d)"

if [[ ! -f "$GUIDEBOOK" ]]; then
  echo "Error: Guidebook not found at $GUIDEBOOK"
  exit 1
fi

# Update all table rows matching this plugin: replace the "Last Applied" column
# Table format: | plugin | `file` | type | version (date) |
if ! grep -q "^| ${PLUGIN} " "$GUIDEBOOK"; then
  echo "Error: No overrides found for plugin '$PLUGIN' in guidebook"
  exit 1
fi

sed -i "s/^| ${PLUGIN} \(|.*|\) [^ |]* ([^)]*) |/| ${PLUGIN} \1 ${NEW_VERSION} (${TODAY}) |/" "$GUIDEBOOK"

# Verify the update worked
if grep "^| ${PLUGIN} " "$GUIDEBOOK" | grep -q "${NEW_VERSION}"; then
  echo "Updated $PLUGIN → $NEW_VERSION ($TODAY) in guidebook"
else
  echo "Warning: sed replacement may have failed. Check $GUIDEBOOK manually."
  exit 1
fi

# Sync to dotfiles if the directory exists
if [[ -d "$(dirname "$DOTFILES_GUIDEBOOK")" ]]; then
  cp "$GUIDEBOOK" "$DOTFILES_GUIDEBOOK"
  echo "Synced guidebook to dotfiles"
fi
