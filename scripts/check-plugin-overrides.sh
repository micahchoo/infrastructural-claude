#!/usr/bin/env bash
# Check if any active plugin versions differ from override base snapshots.
# Fires at SessionStart — warns when an override's .marketplace-base.md no longer
# matches the active plugin cache, meaning overrides may need re-evaluation.

SKILLS_DIR="$HOME/.claude/skills"
MARKETPLACES_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins"
CACHE_DIR="$HOME/.claude/plugins/cache/claude-plugins-official"
STATE_FILE="$HOME/.claude/.plugin-override-check-state"

# Build a snapshot key from all base file mtimes + active cache dir mtimes.
# Changes to either side will trigger a re-check.
compute_state() {
  local base_mtimes cache_mtimes
  base_mtimes=$(find "$SKILLS_DIR" -name '.marketplace-base.*' -exec stat -c %Y {} \; 2>/dev/null | sort | tr '\n' ':')
  cache_mtimes=$(stat -c %Y "$CACHE_DIR" 2>/dev/null || echo 0)
  echo "${base_mtimes}${cache_mtimes}"
}

current_state=$(compute_state)
if [[ -f "$STATE_FILE" && "$(cat "$STATE_FILE" 2>/dev/null)" == "$current_state" ]]; then
  exit 0
fi

# Find the active (non-orphaned) cache version dir for a plugin
find_active_version_dir() {
  local plugin_cache_dir="$1"
  for version_dir in "$plugin_cache_dir"/*/; do
    [[ -d "$version_dir" ]] || continue
    [[ -f "${version_dir}.orphaned_at" ]] && continue
    echo "$version_dir"
    return 0
  done
  return 1
}

warnings=()

# Check superpowers skills (skills/*/.marketplace-base.md)
superpowers_active=$(find_active_version_dir "$CACHE_DIR/superpowers")
if [[ -n "$superpowers_active" ]]; then
  active_ver=$(basename "${superpowers_active%/}")

  # Active-mode overrides: re-apply local to cache, emit cherry-pick notice if version changed.
  # Active-mode skills are excluded from the drift-warning loop below.
  declare -a active_skill_names=()
  for state_file in "$SKILLS_DIR"/*/.override-state; do
    [[ -f "$state_file" ]] || continue
    mode=$(grep '^mode=' "$state_file" 2>/dev/null | cut -d= -f2)
    [[ "$mode" == "active" ]] || continue
    skill_name=$(basename "$(dirname "$state_file")")
    local_skill="${SKILLS_DIR}/${skill_name}/SKILL.md"
    cache_skill="${superpowers_active}skills/${skill_name}/SKILL.md"
    [[ -f "$local_skill" && -f "$cache_skill" ]] || continue

    active_skill_names+=("$skill_name")

    stored_ver=$(grep '^upstream_version=' "$state_file" 2>/dev/null | cut -d= -f2)
    if [[ "$active_ver" != "$stored_ver" ]]; then
      pending_file="${SKILLS_DIR}/${skill_name}/.marketplace-upstream-pending.md"
      cp "$cache_skill" "$pending_file"
      line_count=$(diff "$pending_file" "$local_skill" 2>/dev/null | grep -c '^[<>]' || echo "?")
      warnings+=("cherry-pick review: ${skill_name} (v${stored_ver}→v${active_ver}): ~${line_count} lines changed — run: override-ctl.sh delta ${skill_name}")
      sed -i "s/^upstream_version=.*/upstream_version=${active_ver}/" "$state_file"
    fi

    # Always re-apply local override to cache (idempotent)
    cp "$local_skill" "$cache_skill"
  done

  # Drift-warning loop for tracking-mode skills (existing behavior)
  for base_file in "$SKILLS_DIR"/*/.marketplace-base.md; do
    [[ -f "$base_file" ]] || continue
    skill_dir=$(dirname "$base_file")
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    skill_name=$(basename "$skill_dir")

    # Skip active-mode skills — they use cherry-pick review, not drift warnings
    is_active=false
    for active_name in "${active_skill_names[@]:-}"; do
      [[ "$active_name" == "$skill_name" ]] && is_active=true && break
    done
    [[ "$is_active" == "true" ]] && continue

    active_cache="${superpowers_active}skills/${skill_name}/SKILL.md"
    [[ -f "$active_cache" ]] || continue
    if ! diff -q "$base_file" "$active_cache" >/dev/null 2>&1; then
      warnings+=("superpowers/${skill_name}: base snapshot differs from active version ${active_ver}")
    fi
  done
fi

# Check marketplace-path overrides (plugins/marketplaces/.../skills/*/.marketplace-base.md)
if [[ -d "$MARKETPLACES_DIR" ]]; then
  for base_file in "$MARKETPLACES_DIR"/*/skills/*/.marketplace-base.md; do
    [[ -f "$base_file" ]] || continue
    skill_name=$(basename "$(dirname "$base_file")")
    plugin_name=$(echo "$base_file" | sed "s|${MARKETPLACES_DIR}/||" | cut -d/ -f1)
    plugin_active=$(find_active_version_dir "$CACHE_DIR/${plugin_name}")
    [[ -n "$plugin_active" ]] || continue
    active_cache="${plugin_active}skills/${skill_name}/SKILL.md"
    [[ -f "$active_cache" ]] || continue
    if ! diff -q "$base_file" "$active_cache" >/dev/null 2>&1; then
      active_ver=$(basename "$plugin_active")
      warnings+=("${plugin_name}/${skill_name}: base snapshot differs from active version ${active_ver}")
    fi
  done
fi

# Check agent overrides (agents/.marketplace-base-*.md)
agents_active=$(find_active_version_dir "$CACHE_DIR/superpowers")
if [[ -n "$agents_active" ]]; then
  for base_file in "$HOME/.claude/agents"/.marketplace-base-*.md; do
    [[ -f "$base_file" ]] || continue
    agent_name=$(basename "$base_file" | sed 's/^\.marketplace-base-//;s/\.md$//')
    active_cache="${agents_active}agents/${agent_name}.md"
    [[ -f "$active_cache" ]] || continue
    if ! diff -q "$base_file" "$active_cache" >/dev/null 2>&1; then
      active_ver=$(basename "$agents_active")
      warnings+=("superpowers/agents/${agent_name}: base snapshot differs from active version ${active_ver}")
    fi
  done
fi

echo "$current_state" > "$STATE_FILE"

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "IMPORTANT: Plugin overrides may need re-evaluation (run override-audit.sh):"
  for w in "${warnings[@]}"; do
    echo "  - $w"
  done
fi
