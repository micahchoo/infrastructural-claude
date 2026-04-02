#!/usr/bin/env bash
# rules-inject.sh — PreToolUse hook for Edit/Write
# Injects matching scoped rules from .claude/rules/ when editing files.
# Rules are markdown files with YAML frontmatter (scope, priority, source).
# Three matching dimensions: glob scope, directory-mirror, unscoped (always match).

set -euo pipefail
shopt -s extglob globstar

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
RULES_DIR="$PROJECT_ROOT/.claude/rules"
[[ -d "$RULES_DIR" ]] || exit 0

# Convert FILE to relative path from PROJECT_ROOT
if [[ "$FILE" == "$PROJECT_ROOT"/* ]]; then
  RELPATH="${FILE#"$PROJECT_ROOT"/}"
else
  RELPATH="$FILE"
fi

# --- Frontmatter parser ---
parse_frontmatter() {
  awk '/^---$/ { if (++c == 2) exit; next } c == 1 { print }' "$1"
}

# --- Index management ---
PROJECT_HASH=$(echo "$PROJECT_ROOT" | md5sum | cut -d' ' -f1)
INDEX="/tmp/rules-index-${PROJECT_HASH}.json"

# Check if index is stale
index_stale=0
if [[ ! -f "$INDEX" ]]; then
  index_stale=1
else
  while IFS= read -r -d '' mdfile; do
    if [[ "$mdfile" -nt "$INDEX" ]]; then
      index_stale=1
      break
    fi
  done < <(find "$RULES_DIR" -name '*.md' -print0 2>/dev/null)
fi

# Rebuild index if stale
if [[ "$index_stale" -eq 1 ]]; then
  entries=()
  while IFS= read -r -d '' mdfile; do
    # Skip _meta.json and non-md files
    relrule="${mdfile#"$RULES_DIR"/}"
    fm=$(parse_frontmatter "$mdfile")

    # Extract scope — handle both scalar and array (|| true to avoid set -e exit on no match)
    scope_raw=$(echo "$fm" | grep -E '^scope:' | head -1 | sed 's/^scope: *//' || true)
    # Extract priority (default 5)
    priority=$(echo "$fm" | grep -E '^priority:' | head -1 | sed 's/^priority: *//' || true)
    priority="${priority:-5}"
    # Extract source
    source=$(echo "$fm" | grep -E '^source:' | head -1 | sed 's/^source: *//' || true)
    source="${source:-unknown}"

    # Clean up quoted strings (remove surrounding quotes)
    scope_raw="${scope_raw#\"}"
    scope_raw="${scope_raw%\"}"
    scope_raw="${scope_raw#\'}"
    scope_raw="${scope_raw%\'}"

    # Compute directory-mirror scope for rules in subdirectories
    dir_scope=""
    ruledir=$(dirname "$relrule")
    if [[ "$ruledir" != "." ]]; then
      # rules/src/api.md → src/api/**, rules/src/api/auth.md → src/api/auth/**
      rulename=$(basename "$relrule" .md)
      dir_scope="${ruledir}/${rulename}/**"
    fi

    # Read body (everything after second ---)
    body=$(awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$mdfile" | sed '/^$/d' | head -20)
    # Escape for JSON
    body=$(echo "$body" | jq -Rs '.')

    # Handle scope arrays: ["glob1", "glob2"]
    if [[ "$scope_raw" == "["* ]]; then
      # Parse array items
      scope_json=$(echo "$scope_raw" | jq -c '.' 2>/dev/null || echo '[]')
    elif [[ -n "$scope_raw" ]]; then
      scope_json=$(echo "$scope_raw" | jq -Rs 'rtrimstr("\n")' 2>/dev/null)
    else
      scope_json='""'
    fi

    entries+=("{\"file\":$(echo "$relrule" | jq -Rs 'rtrimstr("\n")'),\"scope\":${scope_json},\"dir_scope\":$(echo "$dir_scope" | jq -Rs 'rtrimstr("\n")'),\"priority\":${priority},\"source\":$(echo "$source" | jq -Rs 'rtrimstr("\n")'),\"body\":${body}}")
  done < <(find "$RULES_DIR" -name '*.md' -print0 2>/dev/null)

  # Write index
  printf '[' > "$INDEX"
  for i in "${!entries[@]}"; do
    [[ $i -gt 0 ]] && printf ',' >> "$INDEX"
    printf '%s' "${entries[$i]}" >> "$INDEX"
  done
  printf ']' >> "$INDEX"
fi

# --- Match rules against RELPATH ---
matched=()

count=$(jq 'length' "$INDEX")
for ((i=0; i<count; i++)); do
  rule=$(jq -c ".[$i]" "$INDEX")
  scope=$(echo "$rule" | jq -r '.scope')
  dir_scope=$(echo "$rule" | jq -r '.dir_scope')
  priority=$(echo "$rule" | jq -r '.priority')
  match_scope=""

  # Check glob scope
  if [[ "$scope" == "["* ]]; then
    # Array of globs
    while IFS= read -r glob; do
      glob=$(echo "$glob" | sed 's/^"//;s/"$//')
      if [[ -n "$glob" ]] && [[ "$RELPATH" == $glob ]]; then
        match_scope="$glob"
        break
      fi
    done < <(echo "$scope" | jq -r '.[]' 2>/dev/null)
  elif [[ -n "$scope" ]]; then
    if [[ "$RELPATH" == $scope ]]; then
      match_scope="$scope"
    fi
  fi

  # Check directory-mirror scope
  if [[ -z "$match_scope" && -n "$dir_scope" ]]; then
    if [[ "$RELPATH" == $dir_scope ]]; then
      match_scope="$dir_scope"
    fi
  fi

  # Unscoped rules at top-level of rules/ always match
  if [[ -z "$match_scope" && -z "$scope" && -z "$dir_scope" ]]; then
    match_scope="*"
  fi

  if [[ -n "$match_scope" ]]; then
    # Count slashes for specificity (more slashes = narrower)
    slash_count=$(echo "$match_scope" | tr -cd '/' | wc -c)
    matched+=("${slash_count}:${priority}:${i}")
  fi
done

[[ ${#matched[@]} -eq 0 ]] && exit 0

# Sort: more slashes first (narrower), then higher priority
IFS=$'\n' sorted=($(for m in "${matched[@]}"; do echo "$m"; done | sort -t: -k1,1nr -k2,2nr))
unset IFS

# --- Emit context_guidance ---
echo "<context_guidance>"
for entry in "${sorted[@]}"; do
  idx="${entry##*:}"
  rule=$(jq -c ".[$idx]" "$INDEX")
  source=$(echo "$rule" | jq -r '.source')
  scope=$(echo "$rule" | jq -r 'if .scope | type == "array" then .scope | join(", ") elif .scope != "" then .scope else .dir_scope end')
  priority=$(echo "$rule" | jq -r '.priority')
  body=$(echo "$rule" | jq -r '.body')

  if [[ -z "$scope" ]]; then
    echo "<scoped_rule source=\"${source}\" priority=\"${priority}\">"
  else
    echo "<scoped_rule source=\"${source}\" scope=\"${scope}\" priority=\"${priority}\">"
  fi
  echo "$body"
  echo "</scoped_rule>"
done
echo "</context_guidance>"

exit 0
