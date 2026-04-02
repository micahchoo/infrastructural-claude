#!/usr/bin/env bash
# Foxhound MCP health check — verify index exists and is queryable.
FOXHOUND_DIR="$HOME/.claude/mcp-servers/foxhound"
[ -d "$FOXHOUND_DIR" ] || { echo "Foxhound: NOT INSTALLED at $FOXHOUND_DIR"; exit 0; }

IDX_COUNT=$(find "$FOXHOUND_DIR" -name '*.db' -o -name '*.idx' -o -name '*.json' 2>/dev/null | wc -l)
if [ "$IDX_COUNT" -eq 0 ]; then
  echo "Foxhound: WARNING — no index files found in $FOXHOUND_DIR"
else
  echo "Foxhound: healthy ($IDX_COUNT index files)"
fi
