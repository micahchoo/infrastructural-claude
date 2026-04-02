#!/usr/bin/env bash
# override-audit.sh — Plugin override drift detection and value assessment
# Usage: override-audit.sh [--verbose] [--json]

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
MARKETPLACES_DIR="${CLAUDE_DIR}/plugins/marketplaces/claude-plugins-official/plugins"
CACHE_DIR="${CLAUDE_DIR}/plugins/cache/claude-plugins-official"

# --- Helpers ---

# Returns the first active (non-orphaned) cache file matching the given search
find_active_cache() {
  local search_dir="$1"
  local path_pattern="$2"
  while IFS= read -r f; do
    local version_dir="${f%/skills/*}"
    version_dir="${version_dir%/agents/*}"
    if [[ ! -f "${version_dir}/.orphaned_at" ]]; then
      echo "$f"
      return 0
    fi
  done < <(find "$search_dir" -path "$path_pattern" 2>/dev/null)
  return 1
}

# When sourced (by override-ctl.sh), only function definitions load — skip execution.
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

set -euo pipefail

verbose=false
json_output=false
show_delta=false
for arg in "$@"; do
  case "$arg" in
    --verbose) verbose=true ;;
    --json) json_output=true ;;
    --delta) show_delta=true; verbose=true ;;
  esac
done

# --- Discovery ---

declare -a names=()
declare -A paths=()
declare -A bases=()
declare -A caches=()

discover_overrides() {
  # 1. skills/ overrides (superpowers plugin)
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "${skill_dir}SKILL.md" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    local cache
    cache=$(find_active_cache "$CACHE_DIR/superpowers" "*/skills/${skill_name}/SKILL.md" || true)

    names+=("$skill_name")
    paths["$skill_name"]="${skill_dir}SKILL.md"
    bases["$skill_name"]="${skill_dir}.marketplace-base.md"
    caches["$skill_name"]="${cache:-}"
  done

  # 2. marketplace-path overrides (only if .marketplace-base.md exists — that marks it as an override)
  [ -d "$MARKETPLACES_DIR" ] || return 0
  for base_file in "$MARKETPLACES_DIR"/*/skills/*/.marketplace-base.md; do
    [ -f "$base_file" ] || continue
    local skill_parent skill_file plugin_path plugin_name skill_name key cache
    skill_parent=$(dirname "$base_file")
    skill_file="${skill_parent}/SKILL.md"
    [ -f "$skill_file" ] || continue
    skill_name=$(basename "$skill_parent")
    plugin_path=$(echo "$skill_parent" | sed "s|${MARKETPLACES_DIR}/||" | cut -d/ -f1)
    plugin_name="$plugin_path"
    key="${plugin_name}:${skill_name}"
    cache=$(find_active_cache "$CACHE_DIR/${plugin_name}" "*/skills/${skill_name}/SKILL.md" || true)

    names+=("$key")
    paths["$key"]="$skill_file"
    bases["$key"]="$base_file"
    caches["$key"]="${cache:-}"
  done

  # 3. agent overrides (detect by .marketplace-base-*.md presence)
  for base_file in "$CLAUDE_DIR"/agents/.marketplace-base-*.md; do
    [ -f "$base_file" ] || continue
    local agent_name
    agent_name=$(basename "$base_file" | sed 's/^\.marketplace-base-//;s/\.md$//')
    local override_file="${CLAUDE_DIR}/agents/${agent_name}.md"
    [ -f "$override_file" ] || continue
    local key="agents:${agent_name}"
    local cache
    cache=$(find_active_cache "$CACHE_DIR/superpowers" "*/agents/${agent_name}.md" || true)

    names+=("$key")
    paths["$key"]="$override_file"
    bases["$key"]="$base_file"
    caches["$key"]="${cache:-}"
  done

  # 4. file-level overrides in skills/ (scripts/, references/, etc.)
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")

    # Find .marketplace-base.* files (excluding .marketplace-base.md which is SKILL.md)
    while IFS= read -r base_file; do
      [ -f "$base_file" ] || continue
      local base_name base_dir filename override_file rel_path key cache
      base_name=$(basename "$base_file")
      base_dir=$(dirname "$base_file")
      filename="${base_name#.marketplace-base.}"

      # Skip .marketplace-base.md (handled by section 1)
      [ "$filename" = "md" ] && continue

      override_file="${base_dir}/${filename}"
      [ -f "$override_file" ] || continue

      rel_path="${override_file#${skill_dir}}"
      key="file:${skill_name}/${rel_path}"

      # Search all plugin caches for this file
      cache=$(find_active_cache "$CACHE_DIR" "*/skills/${skill_name}/${rel_path}" || true)

      names+=("$key")
      paths["$key"]="$override_file"
      bases["$key"]="$base_file"
      caches["$key"]="${cache:-}"
    done < <(find "$skill_dir" -name '.marketplace-base.*' -not -name '.marketplace-base.md' 2>/dev/null)
  done
}

# --- Classification ---

classify_override() {
  local name="$1"
  local override_path="${paths[$name]}"
  local base_path="${bases[$name]}"
  local cache_path="${caches[$name]}"

  # LOCAL-ONLY: no marketplace base — not an override, skip
  if [ ! -f "$base_path" ]; then
    echo "SKIP"
    return
  fi

  # No cache found
  if [ -z "$cache_path" ] || [ ! -f "$cache_path" ]; then
    echo "ORPHANED"
    return
  fi

  # Base matches cache — no upstream changes
  if diff -q "$base_path" "$cache_path" >/dev/null 2>&1; then
    echo "CURRENT"
    return
  fi

  # DRIFTED — sub-classify
  # Count lines from our override that now appear in marketplace (adoption signal)
  local adopted_count=0
  local override_unique
  override_unique=$(diff "$base_path" "$override_path" 2>/dev/null | grep "^> " | sed 's/^> //' || true)

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^---$ ]] && continue
    [[ ${#line} -lt 10 ]] && continue
    if grep -qF -- "$line" "$cache_path" 2>/dev/null; then
      ((adopted_count++)) || true
    fi
  done <<< "$override_unique"

  # Check section-level overlap (divergence signal)
  local override_sections upstream_sections overlap_count
  override_sections=$(diff "$base_path" "$override_path" 2>/dev/null | grep -E "^[<>].*## " | sed 's/^[<>] *//' | sort -u || true)
  upstream_sections=$(diff "$base_path" "$cache_path" 2>/dev/null | grep -E "^[<>].*## " | sed 's/^[<>] *//' | sort -u || true)
  overlap_count=0
  if [ -n "$override_sections" ] && [ -n "$upstream_sections" ]; then
    overlap_count=$(comm -12 <(echo "$override_sections") <(echo "$upstream_sections") 2>/dev/null | wc -l || echo 0)
  fi

  if [ "$adopted_count" -gt 3 ]; then
    echo "DRIFTED:adopted(${adopted_count})"
  elif [ "$overlap_count" -gt 0 ]; then
    echo "DRIFTED:diverged(${overlap_count})"
  else
    echo "DRIFTED:orthogonal"
  fi
}

# --- Cross-reference staleness ---

check_cross_references() {
  local name="$1"
  local override_path="${paths[$name]}"
  local stale=()

  # File-level overrides (scripts, etc.) don't have skill cross-references
  if [[ "$name" == file:* ]]; then
    echo "N/A"
    return
  fi

  # Extract skill references from Integration tables (| skill-name | ...)
  # and explicit invocations (invoke X skill, route to X, /skill-name)
  local refs=""

  # Integration table entries: | skill-name | (first column, hyphenated names)
  local table_refs
  table_refs=$(grep -E '^\| [a-z][-a-z]+ \|' "$override_path" 2>/dev/null |
    sed -E 's/^\| ([a-z][-a-z]+) \|.*/\1/' | sort -u || true)

  # Explicit /skill-name invocations (but not /path/to/file)
  local slash_refs
  slash_refs=$(grep -oE '`/[a-z][-a-z]+`' "$override_path" 2>/dev/null |
    sed 's|`/||;s|`||' | sort -u || true)

  refs=$(printf '%s\n%s' "$table_refs" "$slash_refs" | grep -v '^$' | sort -u)

  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    [ ${#ref} -lt 4 ] && continue
    if [ ! -d "$SKILLS_DIR/$ref" ] && \
       ! find "$CACHE_DIR" -path "*/skills/${ref}/SKILL.md" -print -quit 2>/dev/null | grep -q .; then
      stale+=("$ref")
    fi
  done <<< "$refs"

  local eval_count
  eval_count=$(grep -c '\[eval:' "$override_path" 2>/dev/null || true)
  eval_count=${eval_count:-0}

  if [ ${#stale[@]} -gt 0 ]; then
    echo "STALE(${stale[*]})"
  else
    echo "OK(${eval_count}evals)"
  fi
}

# --- Value assessment ---

assess_value() {
  local status="$1"
  case "$status" in
    CURRENT|LOCAL-ONLY) echo "ACTIVE" ;;
    DRIFTED:adopted*) echo "REVIEW:may-be-redundant" ;;
    DRIFTED:diverged*) echo "REVIEW:merge-needed" ;;
    DRIFTED:orthogonal) echo "AUTO-MERGE:safe" ;;
    ORPHANED) echo "REVIEW:skill-removed" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# --- Output ---

main() {
  discover_overrides

  local has_drift=false has_review=false
  local total=${#names[@]}
  local total_overrides=0

  for name in "${names[@]}"; do
    local status xrefs value
    status=$(classify_override "$name")
    xrefs=$(check_cross_references "$name")
    value=$(assess_value "$status")

    if $json_output; then
      [[ "$status" == "SKIP" ]] && continue
      printf '{"name":"%s","status":"%s","xrefs":"%s","value":"%s"}\n' \
        "$name" "$status" "$xrefs" "$value"
      continue
    fi

    # Skip local-only skills (not overrides)
    [[ "$status" == "SKIP" ]] && continue
    ((total_overrides++)) || true

    local icon="✓"
    case "$status" in
      CURRENT) icon="✓" ;;
      DRIFTED:orthogonal) icon="↑"; has_drift=true ;;
      DRIFTED:adopted*) icon="⚠"; has_review=true ;;
      DRIFTED:diverged*) icon="⚠"; has_review=true ;;
      ORPHANED) icon="✗"; has_review=true ;;
    esac

    if $verbose || [[ "$status" != "CURRENT" ]]; then
      printf "%s %-40s %-30s xrefs:%-20s %s\n" "$icon" "$name" "$status" "$xrefs" "$value"
    fi

    # --delta: show what the override uniquely adds vs current marketplace
    if $show_delta && [ -f "${bases[$name]}" ]; then
      local override_path="${paths[$name]}"
      local base_path="${bases[$name]}"
      local cache_path="${caches[$name]}"
      # Compare against marketplace (if drifted) or base (if current)
      local compare_to="$base_path"
      [ -n "$cache_path" ] && [ -f "$cache_path" ] && compare_to="$cache_path"

      echo "  ┌─ Override adds (not in marketplace):"
      local delta_lines delta_count
      delta_lines=$(diff "$compare_to" "$override_path" 2>/dev/null | grep "^> " | sed 's/^> //' | \
        grep -vE '^\s*$|^---$|^```|^\| *[-:]' | grep -E '\S{10,}' || true)
      delta_count=$(echo "$delta_lines" | grep -c . || echo 0)
      echo "$delta_lines" | head -20 | while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf "  │ %s\n" "$line"
      done
      if [ "$delta_count" -gt 20 ]; then
        printf "  │ ... and %d more lines\n" "$((delta_count - 20))"
      fi
      echo "  └─ ($delta_count unique lines)"
      echo "  EVALUATE: Would a fresh agent using the current marketplace version"
      echo "  miss something important without these additions?"
      echo ""
    fi
  done

  # Summary for SessionStart (non-verbose, non-json)
  if ! $verbose && ! $json_output; then
    if $has_review; then
      echo "Overrides: ${total_overrides} tracked. ⚠ Action needed — run override-audit.sh --verbose"
    elif $has_drift; then
      echo "Overrides: ${total_overrides} tracked. ↑ Safe drift — run override-audit.sh --verbose"
    else
      echo "Overrides: ${total_overrides} tracked, all current."
    fi
  fi
}

main
