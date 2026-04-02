#!/usr/bin/env bash
# config-lens-structural.sh — Structural lens: hooks, skills, pipelines, plugins, wiring
# Analyzes how a Claude Code config directory is wired together
set +e

TARGET="${1:-$HOME/.claude}"
[[ -d "$TARGET" ]] || { echo "Usage: config-lens-structural.sh [claude-config-dir]"; exit 1; }
cd "$TARGET" || exit 1
ABS_TARGET=$(pwd)

echo "=== STRUCTURAL LENS: $(basename "$ABS_TARGET") ==="
echo ""

# --- Hooks ---
echo "=== HOOKS ==="
if [[ -f "settings.json" ]] && command -v jq &>/dev/null; then
  for event in SessionStart PreToolUse PostToolUse UserPromptSubmit PreCompact; do
    count=$(jq -r ".hooks.${event} // [] | [.[].hooks[]] | length" settings.json 2>/dev/null)
    [[ "$count" -gt 0 ]] || continue
    echo "$event ($count hooks):"
    jq -r "
      .hooks.${event}[] |
      (.matcher // \"(all)\") as \$m |
      .hooks[] |
      \$m + \" -> \" + .command
    " settings.json 2>/dev/null \
      | sed "s|$HOME/.claude/|./|g; s|$HOME/|~/|g" \
      | sed 's|node "[^"]*\\/||; s|"$||' \
      | sed 's/^/  /'
  done
  total_hooks=$(jq '[.hooks // {} | .[] | .[].hooks[]] | length' settings.json 2>/dev/null)
  echo "total: ${total_hooks:-0} hooks across $(jq '.hooks // {} | keys | length' settings.json 2>/dev/null) events"
else
  echo "  (no settings.json or jq unavailable)"
fi
echo ""

# --- Skills ---
echo "=== SKILLS ==="
if [[ -d "skills" ]]; then
  skill_count=0
  while IFS= read -r skill_dir; do
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    skill_count=$((skill_count + 1))
    name=$(awk '/^---$/{c++; next} c==1 && /^name:/{sub(/^name: */, ""); print; exit}' "${skill_dir}/SKILL.md" 2>/dev/null)
    echo "  ${name:-$(basename "$skill_dir")}"
  done < <(find skills -mindepth 1 -maxdepth 1 -type d | sort)
  echo "total: $skill_count"
else
  echo "  (no skills/ directory)"
fi
echo ""

# --- Pipelines ---
echo "=== PIPELINES ==="
if [[ -f "pipelines.yaml" ]]; then
  # Parse pipeline names (2-space indent) and their stage skills (8-space indent)
  awk '
    /^  - name:/ {
      if (pipe != "") print "  " pipe ": " stages
      pipe = $3; stages = ""
    }
    /^        skill:/ {
      if (stages != "") stages = stages " -> "
      stages = stages $2
    }
    /^    description:/ && pipe != "" && stages == "" {
      # Capture description for pipelines without skill refs yet
    }
    END { if (pipe != "") print "  " pipe ": " (stages != "" ? stages : "(no skill refs)") }
  ' pipelines.yaml 2>/dev/null
  pipeline_count=$(grep -c '^\s\s- name:' pipelines.yaml 2>/dev/null || echo 0)
  echo "total: $pipeline_count"
else
  echo "  (no pipelines.yaml)"
fi
echo ""

# --- Plugins ---
echo "=== PLUGINS ==="
if [[ -f "plugins/installed_plugins.json" ]] && command -v jq &>/dev/null; then
  jq -r '.plugins | to_entries[] | "  " + .key + " (" + (.value[0].version // "?") + ")"' \
    plugins/installed_plugins.json 2>/dev/null
  plugin_count=$(jq '.plugins | length' plugins/installed_plugins.json 2>/dev/null)
  echo "total: ${plugin_count:-0}"
  # Overrides
  if [[ -f "plugin-override-guidebook.md" ]]; then
    override_count=$(grep -c '^ *|.*| *reapply' plugin-override-guidebook.md 2>/dev/null || echo 0)
    echo "active overrides: $override_count"
  fi
else
  echo "  (no installed_plugins.json or jq unavailable)"
fi
echo ""

# --- MCP Servers ---
echo "=== MCP SERVERS ==="
mcp_count=0
if [[ -d "mcp-servers" ]]; then
  while IFS= read -r srv; do
    [[ -d "$srv" ]] || continue
    echo "  $(basename "$srv") (local)"
    mcp_count=$((mcp_count + 1))
  done < <(find mcp-servers -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi
if command -v jq &>/dev/null && [[ -f "settings.json" ]]; then
  jq -r '.mcpServers // {} | keys[]' settings.json 2>/dev/null | while read -r srv; do
    echo "  $srv (settings.json)"
    mcp_count=$((mcp_count + 1))
  done
fi
echo "total: $mcp_count"
echo ""

# --- Cross-references ---
echo "=== CROSS-REFERENCES ==="

# Hook scripts count
if [[ -f "settings.json" ]] && command -v jq &>/dev/null; then
  hook_script_count=$(jq -r '[.. | .command? // empty] | unique | length' settings.json 2>/dev/null)
  echo "unique hook commands: ${hook_script_count:-0}"
fi

# Pipeline-referenced skills
if [[ -f "pipelines.yaml" ]]; then
  pipeline_skills=$(grep '^\s*skill:' pipelines.yaml 2>/dev/null | awk '{print $2}' | sort -u)
  pipeline_skill_count=$(echo "$pipeline_skills" | grep -c . 2>/dev/null || echo 0)
  echo "pipeline-referenced skills: $pipeline_skill_count"

  # Orphan detection
  if [[ -d "skills" ]]; then
    orphans=""
    while IFS= read -r skill_dir; do
      sname=$(basename "$skill_dir")
      [[ -f "${skill_dir}/SKILL.md" ]] || continue
      if ! echo "$pipeline_skills" | grep -qx "$sname" 2>/dev/null; then
        orphans="$orphans $sname"
      fi
    done < <(find skills -mindepth 1 -maxdepth 1 -type d | sort)
    orphan_count=$(echo "$orphans" | wc -w)
    if [[ "$orphan_count" -gt 0 ]]; then
      echo "skills not in any pipeline ($orphan_count):$orphans"
    fi
  fi
fi

# CLAUDE.md sections
if [[ -f "CLAUDE.md" ]]; then
  section_count=$(grep -c '^##' CLAUDE.md 2>/dev/null || echo 0)
  echo "CLAUDE.md sections: $section_count"
fi
echo ""
