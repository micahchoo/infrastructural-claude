#!/usr/bin/env bash
# override-ctl.sh — Manage active plugin override state
# Usage:
#   override-ctl.sh activate <skill-name>    — apply local override to plugin cache
#   override-ctl.sh deactivate <skill-name>  — restore upstream to plugin cache
#   override-ctl.sh delta <skill-name>       — show upstream changes pending review
#   override-ctl.sh close-review <skill-name> — promote pending upstream to base

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
CACHE_DIR="${CLAUDE_DIR}/plugins/cache/claude-plugins-official"
AUDIT_SCRIPT="${CLAUDE_DIR}/scripts/override-audit.sh"

# Load find_active_cache helper from override-audit.sh
# shellcheck source=override-audit.sh
source "$AUDIT_SCRIPT"

cmd="${1:-}"
name="${2:-}"

if [[ -z "$cmd" || -z "$name" ]]; then
  echo "Usage: override-ctl.sh <activate|deactivate|delta|close-review> <skill-name>" >&2
  exit 1
fi

skill_dir="${SKILLS_DIR}/${name}"
state_file="${skill_dir}/.override-state"
base_file="${skill_dir}/.marketplace-base.md"
pending_file="${skill_dir}/.marketplace-upstream-pending.md"

# Find the active (non-orphaned) plugin cache SKILL.md for a superpowers skill
find_active_superpowers_skill() {
  find_active_cache "$CACHE_DIR/superpowers" "*/skills/${name}/SKILL.md" || true
}

cmd_activate() {
  if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
    echo "Error: ${skill_dir}/SKILL.md not found — nothing to activate" >&2
    exit 1
  fi

  local cache_skill_file
  cache_skill_file=$(find_active_superpowers_skill)
  if [[ -z "$cache_skill_file" ]]; then
    echo "Error: no active plugin cache found for skill '${name}'" >&2
    exit 1
  fi

  local cache_skill_dir
  cache_skill_dir=$(dirname "$cache_skill_file")
  local version_dir
  version_dir=$(dirname "$cache_skill_dir")
  version_dir=$(dirname "$version_dir")  # go up past skills/ dir
  local version
  version=$(basename "${version_dir%/}")

  # Save upstream SKILL.md as base snapshot (before overwriting cache)
  cp "$cache_skill_file" "$base_file"

  # Copy all non-SKILL.md supporting files from plugin cache → local dir (one-time sync)
  while IFS= read -r src; do
    local rel_path="${src#${cache_skill_dir}/}"
    local dest_dir
    dest_dir=$(dirname "${skill_dir}/${rel_path}")
    mkdir -p "$dest_dir"
    cp "$src" "${skill_dir}/${rel_path}"
  done < <(find "$cache_skill_dir" -type f -not -name "SKILL.md")

  # Apply local override to plugin cache (makes superpowers:name serve local)
  cp "${skill_dir}/SKILL.md" "$cache_skill_file"

  # Write state
  printf 'mode=active\nupstream_version=%s\n' "$version" > "$state_file"

  echo "Activated override for '${name}' (v${version})."
  echo "Both 'Skill(\"${name}\")' and 'Skill(\"superpowers:${name}\")' now serve local content."
}

cmd_deactivate() {
  if [[ ! -f "$state_file" ]]; then
    echo "No override state found for '${name}'" >&2
    exit 1
  fi

  local cache_skill_file
  cache_skill_file=$(find_active_superpowers_skill)
  if [[ -z "$cache_skill_file" ]]; then
    echo "Error: no active plugin cache found for skill '${name}'" >&2
    exit 1
  fi

  if [[ ! -f "$base_file" ]]; then
    echo "Error: no .marketplace-base.md found — cannot restore upstream content" >&2
    exit 1
  fi

  # Restore upstream content to plugin cache
  cp "$base_file" "$cache_skill_file"

  # Update state to tracking
  sed -i 's/^mode=.*/mode=tracking/' "$state_file"

  echo "Deactivated override for '${name}'. 'Skill(\"superpowers:${name}\")' now serves upstream."
}

cmd_delta() {
  if [[ -f "$pending_file" ]]; then
    echo "=== Upstream changes for '${name}' (pending cherry-pick review) ==="
    diff --color=always "${skill_dir}/SKILL.md" "$pending_file" || true
    echo ""
    echo "Run 'override-ctl.sh close-review ${name}' after cherry-picking."
  elif [[ -f "$base_file" ]]; then
    echo "No pending upstream review for '${name}'. Showing diff of local vs base:"
    diff --color=always "$base_file" "${skill_dir}/SKILL.md" || true
  else
    echo "No pending review and no base snapshot for '${name}'" >&2
    exit 1
  fi
}

cmd_close_review() {
  if [[ ! -f "$pending_file" ]]; then
    echo "No pending review to close for '${name}'" >&2
    exit 1
  fi

  cp "$pending_file" "$base_file"
  rm "$pending_file"
  echo "Review closed for '${name}'. Base updated to latest upstream."
}

case "$cmd" in
  activate)     cmd_activate ;;
  deactivate)   cmd_deactivate ;;
  delta)        cmd_delta ;;
  close-review) cmd_close_review ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Valid commands: activate, deactivate, delta, close-review" >&2
    exit 1
    ;;
esac
