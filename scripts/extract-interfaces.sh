#!/bin/bash
# Extract public API surface from source files for subagent context
# Usage: extract-interfaces.sh file1.ts file2.py ...
# Output: formatted interface block for embedding in subagent prompts
echo "<interfaces>"
echo "<!-- Key types and contracts extracted from codebase. -->"
echo "<!-- Subagent should use these directly — no codebase exploration needed. -->"
echo ""
for file in "$@"; do
  [ -f "$file" ] || continue
  EXPORTS=$(grep -nE "^export |^interface |^type [A-Z]|^class |^def |^async def |^function |^pub fn |^pub struct |^pub enum " "$file" 2>/dev/null | head -20)
  if [ -n "$EXPORTS" ]; then
    echo "From $file:"
    echo '```'
    echo "$EXPORTS"
    echo '```'
    echo ""
  fi
done
echo "</interfaces>"
