#!/usr/bin/env bash
# architecture-staleness.sh — Check architecture docs freshness against git state
# Called by codebase-diagnostics skill at Sweep start
# Reads _meta.json, compares stored git hashes against current state
# Exit code: number of stale docs found
set -euo pipefail

PROJECT_ROOT="${1:-.}"
META_FILE="$PROJECT_ROOT/docs/architecture/_meta.json"

if [[ ! -f "$META_FILE" ]]; then
  echo "NO_META"
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }

cd "$PROJECT_ROOT"
git rev-parse --is-inside-work-tree &>/dev/null || { echo "ERROR: not a git repo"; exit 1; }

STALE_COUNT=0

# Iterate over each doc entry in _meta.json
# Use process substitution (not pipe) so STALE_COUNT updates propagate to parent shell
while IFS=$'\t' read -r doc_path stored_hash source_globs; do
    # Skip if doc doesn't exist (may have been deleted)
    if [[ ! -f "docs/architecture/$doc_path" ]]; then
      echo "MISSING  $doc_path"
      STALE_COUNT=$((STALE_COUNT + 1))
      continue
    fi

    # Expand globs and get current git hash
    # shellcheck disable=SC2086
    current_hash=$(git log -1 --format=%H -- $source_globs 2>/dev/null || echo "NONE")

    if [[ "$current_hash" == "NONE" ]]; then
      echo "NO_SOURCE  $doc_path  (source files not found: $source_globs)"
    elif [[ "$current_hash" != "$stored_hash" ]]; then
      # Count commits behind
      # shellcheck disable=SC2086
      commits_behind=$(git rev-list --count "$stored_hash".."$current_hash" -- $source_globs 2>/dev/null || echo "?")
      echo "STALE  $doc_path  ($commits_behind commits behind)"
      STALE_COUNT=$((STALE_COUNT + 1))
    else
      echo "FRESH  $doc_path"
    fi
done < <(jq -r '.docs | to_entries[] | "\(.key)\t\(.value.git_hash)\t\(.value.source_glob | join(" "))"' "$META_FILE")

exit "$STALE_COUNT"
