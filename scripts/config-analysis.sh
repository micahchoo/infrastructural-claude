#!/usr/bin/env bash
# config-analysis.sh — Combined config analysis across three lenses + benefit audit
# Orchestrates structural, content, and data lens scripts, then merges into
# a combined subsystem table and audits which skills/pipelines benefit from
# config self-awareness.
#
# Usage: config-analysis.sh [claude-config-dir]
set +e

TARGET="${1:-$HOME/.claude}"
[[ -d "$TARGET" ]] || { echo "Usage: config-analysis.sh [claude-config-dir]"; exit 1; }
cd "$TARGET" || exit 1
ABS_TARGET=$(pwd)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================================"
echo "  CONFIG ANALYSIS: $ABS_TARGET"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "================================================================"
echo ""

# --- Run lens scripts ---
if [[ -x "$SCRIPT_DIR/config-lens-structural.sh" ]]; then
  bash "$SCRIPT_DIR/config-lens-structural.sh" "$ABS_TARGET"
else
  echo "[WARN] config-lens-structural.sh not found at $SCRIPT_DIR"
fi

echo "----------------------------------------------------------------"
echo ""

if [[ -x "$SCRIPT_DIR/config-lens-content.sh" ]]; then
  bash "$SCRIPT_DIR/config-lens-content.sh" "$ABS_TARGET"
else
  echo "[WARN] config-lens-content.sh not found at $SCRIPT_DIR"
fi

echo "----------------------------------------------------------------"
echo ""

if [[ -x "$SCRIPT_DIR/config-lens-data.sh" ]]; then
  bash "$SCRIPT_DIR/config-lens-data.sh" "$ABS_TARGET"
else
  echo "[WARN] config-lens-data.sh not found at $SCRIPT_DIR"
fi

echo "================================================================"
echo ""

# --- Combined subsystem table ---
echo "=== COMBINED SUBSYSTEM MAP ==="
echo ""
printf "%-24s %-28s %-22s %s\n" "SUBSYSTEM" "STRUCTURAL" "CONTENT" "DATA"
printf "%-24s %-28s %-22s %s\n" "--------" "----------" "-------" "----"

# Helper: count files, get size
dir_size()  { [[ -d "$1" ]] && du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "-"; }
dir_words() { [[ -d "$1" ]] && find "$1" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' -exec cat {} + 2>/dev/null | wc -w || echo 0; }

# Compute metrics per subsystem
hook_count=0
skill_count=0
pipeline_count=0
plugin_count=0

if [[ -f "settings.json" ]] && command -v jq &>/dev/null; then
  hook_count=$(jq '[.hooks // {} | .[] | .[].hooks[]] | length' settings.json 2>/dev/null || echo 0)
fi
[[ -d "skills" ]] && skill_count=$(find skills -mindepth 1 -maxdepth 1 -type d -exec test -f {}/SKILL.md \; -print 2>/dev/null | wc -l)
[[ -f "pipelines.yaml" ]] && pipeline_count=$(grep -c '^\s\s- name:' pipelines.yaml 2>/dev/null || echo 0)
if [[ -f "plugins/installed_plugins.json" ]] && command -v jq &>/dev/null; then
  plugin_count=$(jq '.plugins | length' plugins/installed_plugins.json 2>/dev/null || echo 0)
fi

scripts_size=$(dir_size "scripts")
skills_words=$(dir_words "skills")
plugins_size=$(dir_size "plugins")
plugins_words=$(dir_words "plugins")
autoresearch_size=$(dir_size "autoresearch")
autoresearch_words=$(dir_words "autoresearch")
projects_size=$(dir_size "projects")
mcp_size=$(dir_size "mcp-servers")
filehistory_size=$(dir_size "file-history")
backups_size=$(dir_size "backups")
guardrails_words=0
[[ -d "plugins/cognitive-guardrails" ]] && guardrails_words=$(dir_words "plugins/cognitive-guardrails")

printf "%-24s %-28s %-22s %s\n" \
  "Control plane" "${hook_count} hooks, scripts/" "${scripts_size} scripts" "$(dir_size scripts)"
printf "%-24s %-28s %-22s %s\n" \
  "Skill workflows" "${skill_count} skills" "${skills_words} words" "$(dir_size skills)"
printf "%-24s %-28s %-22s %s\n" \
  "Knowledge plane" "queried via MCP" "${plugins_words} words (plugins)" "$plugins_size"
printf "%-24s %-28s %-22s %s\n" \
  "Pipeline orchestration" "${pipeline_count} pipelines" "1 YAML" "minimal"
printf "%-24s %-28s %-22s %s\n" \
  "Plugin lifecycle" "${plugin_count} plugins" "guidebook + overrides" "$plugins_size"
printf "%-24s %-28s %-22s %s\n" \
  "Eval framework" "isolated harness" "${autoresearch_words} words" "$autoresearch_size"
printf "%-24s %-28s %-22s %s\n" \
  "Session state" "runtime (N/A)" "JSONL transcripts" "$projects_size"
printf "%-24s %-28s %-22s %s\n" \
  "Knowledge infra" "2 MCP layers" "server code" "$mcp_size"
printf "%-24s %-28s %-22s %s\n" \
  "Safety nets" "2 scripts" "none" "${filehistory_size}+${backups_size}"
printf "%-24s %-28s %-22s %s\n" \
  "Cognitive guardrails" "bias-check plugins" "${guardrails_words} words" "minimal"
echo ""

# --- Benefit audit ---
echo "=== BENEFIT AUDIT: What benefits from config self-awareness ==="
echo ""

# Deterministic: grep each skill for config-awareness signals, classify by lens
STRUCTURAL_SIGNALS="hook|pipeline|plugin|wiring|settings\.json|MCP|harness|dispatch|subagent|extension.point"
CONTENT_SIGNALS="codebook|reference|pattern.library|knowledge.base|skill.tree|domain"
DATA_SIGNALS="session|history|transcript|file.history|cache|backup|state|snapshot"

echo "Skills with config-awareness signals:"
echo ""
printf "  %-30s %-14s %-14s %s\n" "SKILL" "STRUCTURAL" "CONTENT" "DATA"
printf "  %-30s %-14s %-14s %s\n" "-----" "----------" "-------" "----"

if [[ -d "skills" ]]; then
  while IFS= read -r skill_dir; do
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    sname=$(basename "$skill_dir")
    content=$(cat "${skill_dir}/SKILL.md" 2>/dev/null)

    s_match=$(echo "$content" | grep -oiE "$STRUCTURAL_SIGNALS" 2>/dev/null | wc -l)
    c_match=$(echo "$content" | grep -oiE "$CONTENT_SIGNALS" 2>/dev/null | wc -l)
    d_match=$(echo "$content" | grep -oiE "$DATA_SIGNALS" 2>/dev/null | wc -l)

    # Only show skills with at least one signal
    if [[ "$s_match" -gt 0 || "$c_match" -gt 0 || "$d_match" -gt 0 ]]; then
      s_label="-"; c_label="-"; d_label="-"
      [[ "$s_match" -gt 2 ]] && s_label="HIGH ($s_match)"
      [[ "$s_match" -gt 0 && "$s_match" -le 2 ]] && s_label="low ($s_match)"
      [[ "$c_match" -gt 2 ]] && c_label="HIGH ($c_match)"
      [[ "$c_match" -gt 0 && "$c_match" -le 2 ]] && c_label="low ($c_match)"
      [[ "$d_match" -gt 2 ]] && d_label="HIGH ($d_match)"
      [[ "$d_match" -gt 0 && "$d_match" -le 2 ]] && d_label="low ($d_match)"
      printf "  %-30s %-14s %-14s %s\n" "$sname" "$s_label" "$c_label" "$d_label"
    fi
  done < <(find skills -mindepth 1 -maxdepth 1 -type d | sort)
fi
echo ""

# Pipeline benefit audit
echo "Pipelines with config-awareness signals:"
echo ""
if [[ -f "pipelines.yaml" ]]; then
  # Extract pipeline name + description, check for signals
  awk '
    /^  - name:/ { pipe = $3 }
    /^    description:/ {
      desc = substr($0, index($0, "\"")+1)
      sub(/"$/, "", desc)
      print pipe "|" desc
    }
  ' pipelines.yaml 2>/dev/null | while IFS='|' read -r pipe desc; do
    s_match=$(echo "$desc" | grep -oiE "$STRUCTURAL_SIGNALS" 2>/dev/null | wc -l)
    c_match=$(echo "$desc" | grep -oiE "$CONTENT_SIGNALS" 2>/dev/null | wc -l)
    d_match=$(echo "$desc" | grep -oiE "$DATA_SIGNALS" 2>/dev/null | wc -l)

    if [[ "$s_match" -gt 0 || "$c_match" -gt 0 || "$d_match" -gt 0 ]]; then
      signals=""
      [[ "$s_match" -gt 0 ]] && signals="${signals}structural "
      [[ "$c_match" -gt 0 ]] && signals="${signals}content "
      [[ "$d_match" -gt 0 ]] && signals="${signals}data "
      echo "  $pipe: $signals"
      echo "    $desc"
    fi
  done
fi
echo ""

# Hook scripts that consume config state
echo "Hook scripts with config-awareness:"
echo ""
if [[ -d "scripts" ]]; then
  for script in scripts/*.sh; do
    [[ -f "$script" ]] || continue
    sname=$(basename "$script")
    signals=""
    grep -qiE 'settings\.json|hooks|pipeline' "$script" 2>/dev/null && signals="${signals}structural "
    grep -qiE 'skills/|SKILL\.md|codebook|reference' "$script" 2>/dev/null && signals="${signals}content "
    grep -qiE 'projects/|history|file-history|backup|cache' "$script" 2>/dev/null && signals="${signals}data "
    [[ -n "$signals" ]] && echo "  $sname: $signals"
  done
fi
echo ""

echo "=== INTERPRETATION ==="
echo ""
echo "HIGH structural = skill needs hook/pipeline/plugin wiring context"
echo "HIGH content    = skill needs knowledge plane awareness (codebooks, patterns)"
echo "HIGH data       = skill needs session/history/cache state awareness"
echo ""
echo "Skills/pipelines with HIGH in multiple columns are the strongest candidates"
echo "for receiving config-analysis snapshots as input context."
echo ""
