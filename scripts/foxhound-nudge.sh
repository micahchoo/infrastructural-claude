#!/usr/bin/env bash
# foxhound-nudge.sh — PreToolUse(Skill) hook that nudges toward foxhound search
# for research/analysis skills if foxhound hasn't been called this session.
# Parallel to context-mcp-nudge.sh but for discovery-layer searches.
set +e
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME="${TOOL_USE_NAME:-}"
[[ "$TOOL_NAME" == "Skill" ]] || exit 0

INPUT=$(cat)
SKILL_NAME=$(echo "$INPUT" | jq -r '.skill // empty' 2>/dev/null)
[[ -z "$SKILL_NAME" ]] && exit 0

# Research/analysis skills that should use foxhound
RESEARCH_SKILLS="hybrid-research|pattern-advisor|system-design|characterization-testing|adversarial-api-testing|seam-identification|shadow-walk|strategic-looping|research-protocol|product-design|quality-linter"

if echo "$SKILL_NAME" | grep -qE "$RESEARCH_SKILLS"; then
  # Check session-level dedup flag
  FOXHOUND_FLAG="/tmp/foxhound-session-$$"
  if [[ ! -f "$FOXHOUND_FLAG" ]]; then
    echo "Foxhound: This is a research/analysis skill. Use search(\"<topic>\", project_root=root) for broad discovery across patterns, references, ecosystem, and project expertise before narrowing to specific sources."
    touch "$FOXHOUND_FLAG"
  fi
fi
