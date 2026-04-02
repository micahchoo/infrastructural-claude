#!/usr/bin/env bash
# observability-scan.sh — SessionStart health check for the ~/.claude infrastructure.
# Runs 5 detection classes against the three principles (P1/P2/P3).
# Output: one line per finding, prefixed by severity and class.
#
# Usage: bash observability-scan.sh [--quiet]
#   --quiet: only show critical/high findings

set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
# Skip archived content — not expected to have consumers
ARCHIVE_DIR="$CLAUDE_DIR/archive"
QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

findings=()
add() {
  local severity="$1" class="$2" msg="$3"
  if $QUIET && [[ "$severity" != "CRITICAL" && "$severity" != "HIGH" ]]; then
    return
  fi
  findings+=("[$severity] $class: $msg")
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLASS 1: ORPHAN DETECTION — files/dirs nothing references
# ═══════════════════════════════════════════════════════════════════════════════

# Check fragments/ for unreferenced files
if [ -d "$CLAUDE_DIR/fragments" ]; then
  orphan_count=0
  while IFS= read -r frag; do
    base=$(basename "$frag")
    # Search everything except fragments/ itself for references to this file
    refs=$(grep -rl --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' \
      "$base" "$CLAUDE_DIR" 2>/dev/null \
      | grep -v "^$CLAUDE_DIR/fragments/" \
      | grep -v "^$CLAUDE_DIR/autoresearch/findings" \
      | head -1 || true)
    if [ -z "$refs" ]; then
      orphan_count=$((orphan_count + 1))
    fi
  done < <(find "$CLAUDE_DIR/fragments" -name '*.md' -type f 2>/dev/null)
  if (( orphan_count > 5 )); then
    add "HIGH" "orphan" "fragments/: $orphan_count unreferenced files (write-only outputs with no consumer)"
  elif (( orphan_count > 0 )); then
    add "MODERATE" "orphan" "fragments/: $orphan_count unreferenced files"
  fi
fi

# Check agents/ for orphaned definitions
if [ -d "$CLAUDE_DIR/agents" ]; then
  agent_count=$(find "$CLAUDE_DIR/agents" -name '*.md' -type f 2>/dev/null | wc -l)
  if (( agent_count > 0 )); then
    # Check if any skill or config references agents/
    refs=$(grep -rl "agents/" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null | head -1 || true)
    if [ -z "$refs" ]; then
      add "MODERATE" "orphan" "agents/: $agent_count agent definitions with no consumers"
    fi
  fi
fi

# Check for orphaned workspace artifacts
if [ -d "$CLAUDE_DIR/quality-linter-workspace" ]; then
  # Check if the eval set is linked from the skill
  if ! grep -q "quality-linter-workspace" "$CLAUDE_DIR/skills/quality-linter/SKILL.md" 2>/dev/null; then
    add "MODERATE" "orphan" "quality-linter-workspace/evals/ not linked from skills/quality-linter/SKILL.md"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CLASS 2: DEAD REFERENCE DETECTION — refs to things that don't exist
# ═══════════════════════════════════════════════════════════════════════════════

# Check plans for references to nonexistent scripts
for plan in "$CLAUDE_DIR"/plans/*.md "$CLAUDE_DIR"/docs/superpowers/plans/*.md; do
  [ -f "$plan" ] || continue
  # Extract unique script references from this plan
  while IFS= read -r script_path; do
    if [ -n "$script_path" ] && [ ! -f "$CLAUDE_DIR/$script_path" ]; then
      add "HIGH" "dead-ref" "$(basename "$plan") references $script_path which doesn't exist"
    fi
  done < <(grep -oP 'scripts/[a-z0-9_-]+\.sh' "$plan" 2>/dev/null | sort -u || true)
done

# Check SKILL.md references to nonexistent reference files
for skill_dir in "$CLAUDE_DIR"/skills/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill_name=$(basename "$skill_dir")
  while IFS= read -r ref_path; do
    if [ -n "$ref_path" ] && [ ! -f "$skill_dir/$ref_path" ]; then
      add "MODERATE" "dead-ref" "$skill_name/SKILL.md references $ref_path which doesn't exist"
    fi
  done < <(grep -oP 'references/[a-z0-9_-]+\.md' "$skill_dir/SKILL.md" 2>/dev/null | sort -u || true)
done

# ═══════════════════════════════════════════════════════════════════════════════
# CLASS 3: UNWIRED INFRASTRUCTURE — scripts/configs not connected to triggers
# ═══════════════════════════════════════════════════════════════════════════════

# Check for scripts that exist but aren't referenced in settings.json hooks
if [ -f "$CLAUDE_DIR/settings.json" ] && [ -d "$CLAUDE_DIR/scripts" ]; then
  settings_content=$(cat "$CLAUDE_DIR/settings.json")
  while IFS= read -r script; do
    base=$(basename "$script")
    # Skip helper scripts that are called by other scripts (not hooks)
    case "$base" in
      sd-*.sh|codebook-gap.sh|post-implementation-audit.sh|codebase-analytics.sh) continue ;;
    esac
    if ! echo "$settings_content" | grep -q "$base" 2>/dev/null; then
      # Check if another hook script sources/calls it
      called_by=$(grep -rl "$base" "$CLAUDE_DIR/scripts" 2>/dev/null | grep -v "$script" | head -1 || true)
      if [ -z "$called_by" ]; then
        add "MODERATE" "unwired" "scripts/$base exists but isn't referenced in settings.json or called by another script"
      fi
    fi
  done < <(find "$CLAUDE_DIR/scripts" -name '*.sh' -type f 2>/dev/null)
fi

# Check anti-pattern-report.txt for unresolved findings
if [ -f "$CLAUDE_DIR/.claude/anti-pattern-report.txt" ]; then
  finding_count=$(grep -c '^\[' "$CLAUDE_DIR/.claude/anti-pattern-report.txt" 2>/dev/null || true)
  if (( ${finding_count:-0} > 0 )); then
    add "MODERATE" "unwired" "anti-pattern-report.txt has $finding_count open findings not surfaced at session start"
  fi
elif [ -f "$CLAUDE_DIR/anti-pattern-report.txt" ]; then
  finding_count=$(grep -c '^\[' "$CLAUDE_DIR/anti-pattern-report.txt" 2>/dev/null || true)
  if (( ${finding_count:-0} > 0 )); then
    add "MODERATE" "unwired" "anti-pattern-report.txt has $finding_count open findings not surfaced at session start"
  fi
fi

# Check .context-freshness for missing hashes
if [ -d "$CLAUDE_DIR/.context-freshness" ]; then
  # Check if foxhound has a hash
  if [ ! -f "$CLAUDE_DIR/.context-freshness/foxhound.hash" ]; then
    add "MODERATE" "unwired" ".context-freshness/ has no foxhound.hash — most-used MCP server staleness not tracked"
  fi
  # Check if freshness script is wired as a hook
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    if ! grep -q "context-index-freshness" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
      add "HIGH" "unwired" "context-index-freshness.sh exists but isn't wired as a SessionStart hook"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CLASS 4: DUAL-INSTANCE DETECTION — duplicated infra that should be unified
# ═══════════════════════════════════════════════════════════════════════════════

# Check for multiple .seeds/ instances
seeds_instances=()
while IFS= read -r seeds_dir; do
  seeds_instances+=("$seeds_dir")
done < <(find "$CLAUDE_DIR" -name '.seeds' -type d -not -path '*/node_modules/*' -not -path '*/variants/*' 2>/dev/null)

if (( ${#seeds_instances[@]} > 1 )); then
  locations=$(printf '%s\n' "${seeds_instances[@]}" | sed "s|$CLAUDE_DIR/||g" | tr '\n' ', ' | sed 's/,$//')
  add "HIGH" "dual-instance" "Multiple .seeds/ instances found: $locations — issues may be tracked in the wrong instance"
fi

# Check for duplicate skill trees (plugins vs skills)
if [ -d "$CLAUDE_DIR/plugins/cognitive-guardrails/skills" ]; then
  plugin_skills=$(find "$CLAUDE_DIR/plugins/cognitive-guardrails/skills" -name 'SKILL.md' 2>/dev/null | wc -l)
  if (( plugin_skills > 0 )); then
    add "MODERATE" "dual-instance" "plugins/cognitive-guardrails/ has $plugin_skills skill files — unclear if active copies or install artifacts"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CLASS 5: STALENESS DETECTION — artifacts with no completion tracking
# ═══════════════════════════════════════════════════════════════════════════════

# Check for active plans not tracked in seeds
if [ -d "$CLAUDE_DIR/docs/superpowers/plans" ]; then
  for plan in "$CLAUDE_DIR"/docs/superpowers/plans/*.md; do
    [ -f "$plan" ] || continue
    base=$(basename "$plan" .md)
    # Skip archived plans
    [[ "$plan" == *"/archive/"* ]] && continue
    # Check if any seeds issue references this plan
    if [ -f "$CLAUDE_DIR/.seeds/issues.jsonl" ]; then
      if ! grep -q "$base" "$CLAUDE_DIR/.seeds/issues.jsonl" 2>/dev/null; then
        add "MODERATE" "stale" "Active plan $(basename "$plan") has no corresponding seeds issue for tracking"
      fi
    fi
  done
fi

# Check for plans referencing work from >7 days ago with no completion marker
for plan in "$CLAUDE_DIR"/plans/*.md; do
  [ -f "$plan" ] || continue
  # Check if plan has unchecked boxes (incomplete work)
  unchecked=$(grep -c '^\- \[ \]' "$plan" 2>/dev/null || true)
  checked=$(grep -c '^\- \[x\]' "$plan" 2>/dev/null || true)
  if (( ${unchecked:-0} > 0 && ${checked:-0} > 0 )); then
    # Partially complete plan
    age_days=$(( ($(date +%s) - $(stat -c %Y "$plan" 2>/dev/null || echo "$(date +%s)")) / 86400 ))
    if (( age_days > 3 )); then
      add "MODERATE" "stale" "$(basename "$plan"): $unchecked unchecked tasks, last modified ${age_days}d ago"
    fi
  fi
done

# Check mcp-servers for untracked code
if [ -d "$CLAUDE_DIR/mcp-servers" ]; then
  for server_dir in "$CLAUDE_DIR"/mcp-servers/*/; do
    [ -d "$server_dir" ] || continue
    server_name=$(basename "$server_dir")
    # Check if tracked in git
    if ! git -C "$CLAUDE_DIR" ls-files --error-unmatch "mcp-servers/$server_name" &>/dev/null 2>&1; then
      # Check for test directory
      if [ ! -d "$server_dir/test" ] && [ ! -d "$server_dir/tests" ] && [ ! -d "$server_dir/__tests__" ]; then
        add "HIGH" "stale" "mcp-servers/$server_name/: untracked in git and has no tests"
      else
        add "MODERATE" "stale" "mcp-servers/$server_name/: untracked in git"
      fi
    fi
  done
fi

# Check for core scripts without tests
for core_script in "$CLAUDE_DIR"/autoresearch/grade.py "$CLAUDE_DIR"/autoresearch/run_ab.py "$CLAUDE_DIR"/autoresearch/harvest.py; do
  [ -f "$core_script" ] || continue
  base=$(basename "$core_script" .py)
  # Check for any test file
  test_file=$(find "$CLAUDE_DIR/autoresearch" -name "test_${base}*" -o -name "${base}_test*" 2>/dev/null | head -1 || true)
  if [ -z "$test_file" ]; then
    commits=$(git -C "$CLAUDE_DIR" log --oneline -- "autoresearch/$base.py" 2>/dev/null | wc -l || echo 0)
    if (( commits > 2 )); then
      add "HIGH" "stale" "autoresearch/$base.py: $commits commits, no test file — core eval infrastructure untested"
    fi
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

if (( ${#findings[@]} == 0 )); then
  echo "Observability: all clear"
  exit 0
fi

# Count by severity
critical=0 high=0 moderate=0
for f in "${findings[@]}"; do
  case "$f" in
    *CRITICAL*) critical=$((critical + 1)) ;;
    *HIGH*) high=$((high + 1)) ;;
    *MODERATE*) moderate=$((moderate + 1)) ;;
  esac
done

echo "Observability: ${#findings[@]} findings (${critical} critical, ${high} high, ${moderate} moderate)"
for f in "${findings[@]}"; do
  echo "  $f"
done
