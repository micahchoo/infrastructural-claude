#!/usr/bin/env bash
# sd-claim.sh — Atomic task claim for multi-agent seeds workflows
# Checks issue isn't already in_progress, then sets status + assignee atomically.
set -euo pipefail

ASSIGNEE="${USER:-agent}"
ISSUE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assignee) ASSIGNEE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sd-claim <issue-id> [--assignee <name>]"
      echo "  Atomically claims a task: sets status=in_progress + assignee."
      echo "  Fails if already in_progress (prevents double-claim)."
      echo "  Default assignee: \$USER ($USER)"
      exit 0 ;;
    *)
      if [[ -z "$ISSUE_ID" ]]; then
        ISSUE_ID="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi ;;
  esac
done

[[ -z "$ISSUE_ID" ]] && { echo "Usage: sd-claim <issue-id> [--assignee <name>]" >&2; exit 1; }

# Find sd binary
SD_BIN="${HOME}/.bun/bin/sd"
command -v "$SD_BIN" >/dev/null 2>&1 || SD_BIN="sd"
command -v "$SD_BIN" >/dev/null 2>&1 || { echo "sd (seeds) not found" >&2; exit 1; }

# Check current status
CURRENT=$("$SD_BIN" show "$ISSUE_ID" --json 2>/dev/null) || { echo "Issue $ISSUE_ID not found" >&2; exit 1; }
STATUS=$(echo "$CURRENT" | jq -r '.status')
CURRENT_ASSIGNEE=$(echo "$CURRENT" | jq -r '.assignee // "none"')

if [[ "$STATUS" == "in_progress" ]]; then
  echo "CLAIM FAILED: $ISSUE_ID already in_progress (assignee: $CURRENT_ASSIGNEE)" >&2
  exit 1
fi

if [[ "$STATUS" == "closed" ]]; then
  echo "CLAIM FAILED: $ISSUE_ID is closed" >&2
  exit 1
fi

# Claim: update status + assignee
"$SD_BIN" update "$ISSUE_ID" --status in_progress --assignee "$ASSIGNEE" 2>/dev/null || {
  echo "CLAIM FAILED: sd update failed for $ISSUE_ID" >&2
  exit 1
}

echo "CLAIMED: $ISSUE_ID assigned to $ASSIGNEE (was: $STATUS)"
