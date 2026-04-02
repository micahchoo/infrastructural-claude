#!/usr/bin/env bash
# codebook-gap.sh — Record or query codebook gaps against the skill tree's seeds
# Usage:
#   codebook-gap.sh record "Force: X vs Y" "description..." [--labels label1,label2]
#   codebook-gap.sh list
#   codebook-gap.sh bump <id>
set +e

SKILL_TREE="$HOME/.claude"
ACTION="${1:-list}"
shift 2>/dev/null

case "$ACTION" in
  record)
    title="$1"
    desc="$2"
    shift 2 2>/dev/null
    (cd "$SKILL_TREE" && sd create \
      --type feature \
      --title "$title" \
      --description "$desc" \
      --labels "codebook-gap${1:+,${1#--labels }}" \
      --priority 3)
    ;;

  list)
    (cd "$SKILL_TREE" && sd list --labels codebook-gap 2>/dev/null) || \
      echo "No codebook gaps recorded yet."
    ;;

  bump)
    # Append a hit to an existing gap's description
    id="$1"
    hit_note="Hit again $(date +%Y-%m-%d) from $(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
    (cd "$SKILL_TREE" && sd comment "$id" "$hit_note" 2>/dev/null) || \
      echo "Could not bump $id — check the issue ID."
    ;;

  *)
    echo "Usage: codebook-gap.sh {record|list|bump} [args...]"
    exit 1
    ;;
esac
