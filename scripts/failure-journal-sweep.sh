#!/usr/bin/env bash
# failure-journal-sweep.sh — PreCompact hook
# Reads failure journal, surfaces unresolved errors as seeds/mulch candidates.
# Zero cost on clean sessions. Fires once per compaction cycle.
set +e

JOURNAL="/tmp/failure-journal-${PPID}.jsonl"
[ -f "$JOURNAL" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Count actionable entries (error/critical severity, or retries, or snags)
actionable=$(jq -c 'select(.severity == "error" or .severity == "critical" or .retry == true or .snag == true)' "$JOURNAL" 2>/dev/null | wc -l)
[ "$actionable" -eq 0 ] && exit 0

# Extract top 5 most severe entries
entries=$(jq -c 'select(.severity == "error" or .severity == "critical" or .retry == true or .snag == true)' "$JOURNAL" 2>/dev/null | tail -5)

echo "<failure-journal-sweep count=\"$actionable\">"
echo "Session has $actionable unresolved failure signals. Top entries:"
echo "$entries" | jq -r '"  - [\(.severity)] \(.cmd | split(" ") | .[0]): \(.error_line[:80])" // "  - [\(.severity)] \(.cmd | split(" ") | .[0])"' 2>/dev/null
echo ""
echo "To promote before session ends:"

# Check for .seeds/
if [ -d ".seeds" ] || [ -d "$HOME/.claude/.seeds" ]; then
  echo "  Seeds: sd create --title \"Failure: <description>\" --type bug --labels \"failure-mode\""
fi

# Check for .mulch/
if [ -d ".mulch" ] || [ -d "$HOME/.claude/.mulch" ]; then
  echo "  Mulch: ml record failure --type failure --description \"<what failed>\" --classification tactical"
fi

echo "</failure-journal-sweep>"
