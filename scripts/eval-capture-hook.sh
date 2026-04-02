#!/usr/bin/env bash
# eval-capture-hook.sh — PostToolUse hook for Skill invocations
# Captures eval checkpoint coverage: which bias/eval skills fired during this session
# Used by close-loop gate to aggregate pipeline decision quality
set +e
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
skill_name=$(echo "$input" | jq -r '.tool_input.skill // .input.skill // empty' 2>/dev/null)
[ -z "$skill_name" ] && exit 0

# --- Pipeline stage eval nudge (runs for ALL skills) ---
PIPELINE_STATE="/tmp/pipeline-state.json"
if [[ -f "$PIPELINE_STATE" ]]; then
  p_stage=$(jq -r '.stage // empty' "$PIPELINE_STATE" 2>/dev/null)
  p_pipeline=$(jq -r '.pipeline // empty' "$PIPELINE_STATE" 2>/dev/null)
  if [[ -n "$p_stage" && -n "$p_pipeline" ]]; then
    # Dedupe: only nudge once per stage (keyed on pipeline+stage)
    STAGE_NUDGE_FLAG="/tmp/eval-stage-nudge-${PPID}-${p_pipeline}-${p_stage}"
    if [[ ! -f "$STAGE_NUDGE_FLAG" ]]; then
      cat <<NUDGE
<context_guidance>
Pipeline stage '$p_stage' in '$p_pipeline' completed. If this stage had an [eval: expect] checkpoint, grade it now with expect/capture/grade before proceeding to the next stage.
</context_guidance>
NUDGE
      touch "$STAGE_NUDGE_FLAG"
    fi
  fi
fi

# --- Eval checkpoint logging (only for eval/bias skills) ---
case "$skill_name" in
  eval-protocol|bias:*) ;;
  *) exit 0 ;;
esac

# Session-scoped eval log (matches integration-state session scope)
EVAL_LOG="/tmp/eval-capture-${PPID}.jsonl"

# Read pipeline context if available
pipeline=""
stage=""
if [[ -f "$PIPELINE_STATE" ]]; then
  pipeline=$(jq -r '.pipeline // empty' "$PIPELINE_STATE" 2>/dev/null)
  stage=$(jq -r '.stage // empty' "$PIPELINE_STATE" 2>/dev/null)
fi

# Append checkpoint record
echo "{\"skill\":\"$skill_name\",\"pipeline\":\"$pipeline\",\"stage\":\"$stage\",\"ts\":$(date +%s)}" >> "$EVAL_LOG"

# Summary for close-loop gate: count checkpoints this session
total=$(wc -l < "$EVAL_LOG" 2>/dev/null | tr -d ' ')
bias_count=$(grep -c '"bias:' "$EVAL_LOG" 2>/dev/null || echo 0)
eval_count=$(grep -c '"eval-protocol"' "$EVAL_LOG" 2>/dev/null || echo 0)

# Only emit guidance after meaningful accumulation (3+ checkpoints)
if [[ "$total" -ge 3 ]]; then
  # Check if we already nudged this session
  NUDGE_FLAG="/tmp/eval-nudge-${PPID}"
  if [[ ! -f "$NUDGE_FLAG" ]]; then
    echo "<eval-coverage session-checkpoints=\"$total\" bias=\"$bias_count\" eval-protocol=\"$eval_count\">"
    echo "Eval coverage accumulating. At pipeline completion, aggregate grades: cat $EVAL_LOG"
    echo "</eval-coverage>"
    touch "$NUDGE_FLAG"
  fi
fi

exit 0
