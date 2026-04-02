#!/usr/bin/env bash
# apply-file-overrides.sh — Copy local file-level overrides into plugin cache
#
# Scans skills/<name>/ and plugins/marketplaces/ for non-SKILL.md files that
# have .marketplace-base.* snapshots (indicating they're overrides), then copies
# the override into the corresponding plugin cache location.
#
# Usage: apply-file-overrides.sh [--verbose] [--dry-run]
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
CACHE_DIR="${CLAUDE_DIR}/plugins/cache/claude-plugins-official"
MARKETPLACES_DIR="${CLAUDE_DIR}/plugins/marketplaces/claude-plugins-official/plugins"

verbose=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --verbose) verbose=true ;;
    --dry-run) dry_run=true ;;
  esac
done

applied=0
skipped=0
failed=0

log() { $verbose && echo "$@" >&2 || true; }

# --- Resolve cache target for a file override ---
# Given: skill name, relative path within the skill dir (e.g. scripts/improve_description.py)
# Finds: the corresponding file in plugins/cache/
resolve_cache_target() {
  local skill_name="$1"
  local rel_path="$2"

  # Search all plugin cache dirs for this skill + file
  local target
  target=$(find "$CACHE_DIR" -path "*/skills/${skill_name}/${rel_path}" 2>/dev/null | sort | tail -1)
  echo "${target:-}"
}

# --- Apply overrides from skills/<name>/ ---
apply_skills_overrides() {
  [ -d "$SKILLS_DIR" ] || return 0

  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")

    # Scan for .marketplace-base.* files (not .marketplace-base.md which is for SKILL.md)
    while IFS= read -r base_file; do
      [ -f "$base_file" ] || continue

      local base_name base_dir filename rel_path override_file
      base_name=$(basename "$base_file")
      base_dir=$(dirname "$base_file")

      # Extract original filename: .marketplace-base.foo.py -> foo.py
      filename="${base_name#.marketplace-base.}"

      # Skip .marketplace-base.md (SKILL.md override, handled by existing system)
      [ "$filename" = "md" ] && continue

      override_file="${base_dir}/${filename}"
      [ -f "$override_file" ] || { log "  SKIP $override_file (override file missing)"; ((skipped++)) || true; continue; }

      # Build relative path from skill dir
      rel_path="${override_file#${skill_dir}}"

      # Find cache target
      local cache_target
      cache_target=$(resolve_cache_target "$skill_name" "$rel_path")
      if [ -z "$cache_target" ]; then
        log "  SKIP $rel_path (no cache target found for skill $skill_name)"
        ((skipped++)) || true
        continue
      fi

      # Check if override differs from cache
      if diff -q "$override_file" "$cache_target" >/dev/null 2>&1; then
        log "  OK   $skill_name/$rel_path (already applied)"
        ((skipped++)) || true
        continue
      fi

      # Apply override
      if $dry_run; then
        echo "WOULD APPLY: $override_file -> $cache_target"
      else
        if cp "$override_file" "$cache_target" 2>/dev/null; then
          log "  APPLY $skill_name/$rel_path"
          ((applied++)) || true
        else
          log "  FAIL  $skill_name/$rel_path (copy failed)"
          ((failed++)) || true
        fi
      fi
    done < <(find "$skill_dir" -name '.marketplace-base.*' -not -name '.marketplace-base.md' 2>/dev/null)
  done
}

# --- Apply overrides from plugins/marketplaces/ ---
apply_marketplace_overrides() {
  [ -d "$MARKETPLACES_DIR" ] || return 0

  for plugin_dir in "$MARKETPLACES_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    local plugin_name
    plugin_name=$(basename "$plugin_dir")

    while IFS= read -r base_file; do
      [ -f "$base_file" ] || continue

      local base_name base_dir filename rel_from_plugin override_file
      base_name=$(basename "$base_file")
      base_dir=$(dirname "$base_file")
      filename="${base_name#.marketplace-base.}"

      [ "$filename" = "md" ] && continue

      override_file="${base_dir}/${filename}"
      [ -f "$override_file" ] || { ((skipped++)) || true; continue; }

      # Build relative path from plugin skills dir
      rel_from_plugin="${override_file#${plugin_dir}}"

      # Find cache target — search by plugin name + relative path
      local cache_target
      cache_target=$(find "$CACHE_DIR/${plugin_name}" -path "*/${rel_from_plugin}" 2>/dev/null | sort | tail -1)
      if [ -z "$cache_target" ]; then
        log "  SKIP ${plugin_name}/${rel_from_plugin} (no cache target)"
        ((skipped++)) || true
        continue
      fi

      if diff -q "$override_file" "$cache_target" >/dev/null 2>&1; then
        log "  OK   ${plugin_name}/${rel_from_plugin} (already applied)"
        ((skipped++)) || true
        continue
      fi

      if $dry_run; then
        echo "WOULD APPLY: $override_file -> $cache_target"
      else
        if cp "$override_file" "$cache_target" 2>/dev/null; then
          log "  APPLY ${plugin_name}/${rel_from_plugin}"
          ((applied++)) || true
        else
          log "  FAIL  ${plugin_name}/${rel_from_plugin}"
          ((failed++)) || true
        fi
      fi
    done < <(find "$plugin_dir" -name '.marketplace-base.*' -not -name '.marketplace-base.md' 2>/dev/null)
  done
}

# --- Main ---
apply_skills_overrides
apply_marketplace_overrides

if [ $applied -gt 0 ] || [ $failed -gt 0 ]; then
  echo "File overrides: ${applied} applied, ${skipped} current, ${failed} failed"
elif $verbose; then
  echo "File overrides: all ${skipped} current"
fi
