#!/usr/bin/env bash
# sd-next.sh — DAG-aware task scheduler for seeds
# Wraps `sd ready --json`, sorts by priority (0=critical first), then created_at (oldest first).
# Returns the single best next task, or all independent tasks with --parallel.
set -euo pipefail

PARALLEL=false
JSON=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel) PARALLEL=true; shift ;;
    --json) JSON=true; shift ;;
    -h|--help)
      echo "Usage: sd-next [--parallel] [--json]"
      echo "  Returns highest-priority unblocked task from seeds."
      echo "  --parallel  Return all independent tasks (no shared deps)"
      echo "  --json      Output as JSON"
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Find sd binary
SD_BIN="${HOME}/.bun/bin/sd"
command -v "$SD_BIN" >/dev/null 2>&1 || SD_BIN="sd"
command -v "$SD_BIN" >/dev/null 2>&1 || { echo "sd (seeds) not found" >&2; exit 1; }

# Get ready issues as JSON
READY=$("$SD_BIN" ready --json 2>/dev/null) || { echo "No .seeds/ directory or sd ready failed" >&2; exit 1; }

# Check if empty
COUNT=$(echo "$READY" | jq 'length')
if [[ "$COUNT" -eq 0 ]]; then
  if $JSON; then
    echo '{"next":null,"count":0,"message":"No unblocked tasks"}'
  else
    echo "No unblocked tasks."
  fi
  exit 0
fi

# Filter out needs-triage items (created by automated systems, not yet human-approved)
READY=$(echo "$READY" | jq '[.[] | select(.labels // [] | map(select(. == "needs-triage")) | length == 0)]')

# Re-check count after filtering
COUNT=$(echo "$READY" | jq 'length')
if [[ "$COUNT" -eq 0 ]]; then
  if $JSON; then
    echo '{"next":null,"count":0,"message":"No unblocked tasks (some may need triage — run /triage)"}'
  else
    echo "No unblocked tasks. Some may need triage — run /triage to review."
  fi
  exit 0
fi

# Sort by priority (asc, 0=critical) then created_at (asc, oldest first)
SORTED=$(echo "$READY" | jq 'sort_by(.priority, .created_at)')

if $PARALLEL; then
  if $JSON; then
    echo "$SORTED" | jq "{next: ., count: ($COUNT), message: \"$COUNT independent tasks\"}"
  else
    echo "$SORTED" | jq -r '.[] | "[\(.id)] P\(.priority) \(.title)"'
  fi
else
  BEST=$(echo "$SORTED" | jq '.[0]')
  if $JSON; then
    echo "$BEST" | jq "{next: ., count: 1, message: \"Best task selected\"}"
  else
    ID=$(echo "$BEST" | jq -r '.id')
    TITLE=$(echo "$BEST" | jq -r '.title')
    PRIORITY=$(echo "$BEST" | jq -r '.priority')
    echo "[$ID] P$PRIORITY $TITLE"
  fi
fi
