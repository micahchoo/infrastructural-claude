#!/usr/bin/env bash
# pipeline-stage-hook.sh — PreToolUse hook for Skill invocations
# Detects if the invoked skill is a pipeline stage, writes state for the status line
set +e
command -v jq >/dev/null 2>&1 || exit 0

PIPELINES="$HOME/.claude/pipelines.yaml"
CACHE="/tmp/pipeline-lookup-cache"
STATE="/tmp/pipeline-state.json"

# Read hook input from stdin
input=$(cat)

# Extract skill name from the hook payload
# The Skill tool provides the skill name in the input field
skill_name=$(echo "$input" | jq -r '.tool_input.skill // .input.skill // empty' 2>/dev/null)
[ -z "$skill_name" ] && exit 0

# Strip plugin prefix if present (e.g., "superpowers:brainstorming" → "brainstorming")
skill_name="${skill_name##*:}"

# --- Build/refresh cache if needed ---
if [ ! -f "$CACHE" ] || [ "$PIPELINES" -nt "$CACHE" ]; then
  # Generate flat lookup: skill_name → pipeline_name:stage_order:stage_name
  python3 -c "
import yaml, sys
with open('$PIPELINES') as f:
    data = yaml.safe_load(f)
for p in data.get('pipelines', []):
    pname = p['name']
    stages = sorted(p.get('stages', []), key=lambda s: s.get('order', 0))
    stage_names = '|'.join(s['name'] for s in stages)
    for s in stages:
        skill = s.get('skill', '')
        if skill:
            print(f\"{skill}\t{pname}\t{s['order']}\t{s['name']}\t{stage_names}\")
" > "$CACHE" 2>/dev/null
fi

# --- Lookup skill in cache ---
match=$(grep -m1 "^${skill_name}	" "$CACHE" 2>/dev/null)
[ -z "$match" ] && exit 0

# Parse match
pipeline=$(echo "$match" | cut -f2)
order=$(echo "$match" | cut -f3)
stage=$(echo "$match" | cut -f4)
all_stages=$(echo "$match" | cut -f5)

# --- Write state ---
cat > "$STATE" <<EOF
{"pipeline":"$pipeline","stage":"$stage","order":$order,"stages":"$all_stages","ts":$(date +%s)}
EOF

# --- Integration state (session-scoped dedup for pipeline gates) ---
INTEGRATION_STATE="/tmp/integration-state-${PPID}.json"

# Initialize if absent
[[ ! -f "$INTEGRATION_STATE" ]] && echo '{}' > "$INTEGRATION_STATE"

# Helpers
istate_get() { jq -r ".$1 // empty" "$INTEGRATION_STATE" 2>/dev/null; }
istate_set() {
  local tmp
  tmp=$(mktemp)
  jq ".$1 = $2" "$INTEGRATION_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$INTEGRATION_STATE"
}
istate_reset() { echo '{}' > "$INTEGRATION_STATE"; }

# Count total stages in this pipeline
total_stages=$(echo "$all_stages" | awk -F'|' '{print NF}')

# =====================================================================
# Gate: context-init (fires at first stage of research-type pipelines)
# Primes mulch/seeds, syncs deps — things that need to happen once per pipeline
# =====================================================================
CONTEXT_INIT_PIPELINES="brainstorm-to-ship|research-loop|pattern-extraction|debugging-loop|skill-creation"

if [[ "$order" -eq 1 ]] && echo "$pipeline" | grep -qE "^($CONTEXT_INIT_PIPELINES)$"; then
  if [[ "$(istate_get mulch_primed)" != "true" ]]; then
    gate_msg=""
    if [[ -d ".mulch" ]] || [[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/.mulch" ]]; then
      gate_msg="${gate_msg}  - mulch: run \`ml search \"<topic relevant to this pipeline>\"\` for prior decisions/conventions\n"
    fi
    if [[ -d ".seeds" ]] || [[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/.seeds" ]]; then
      gate_msg="${gate_msg}  - seeds: run \`sd ready\` to find unblocked work\n"
    fi
    # Check for package manifests (sync_deps)
    for manifest in package.json Cargo.toml pyproject.toml go.mod; do
      if [[ -f "$manifest" ]] || [[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/$manifest" ]]; then
        gate_msg="${gate_msg}  - deps: run foxhound \`sync_deps(root)\` to index project dependencies\n"
        break
      fi
    done
    if [[ -n "$gate_msg" ]]; then
      # --- Gate-enforcer dispatch (context-init) ---
      needs_mulch="false"
      needs_seeds="false"
      needs_deps="false"
      echo "$gate_msg" | grep -q "mulch" && needs_mulch="true"
      echo "$gate_msg" | grep -q "seeds" && needs_seeds="true"
      echo "$gate_msg" | grep -q "deps" && needs_deps="true"
      project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
      cat <<DISPATCH_EOF
<agent-dispatch name="gate-enforcer">
Agent tool call ready — dispatch now:

  name: "gate-enforcer"
  prompt: "Gate mode: context-init. Pipeline: ${pipeline}.
           Actions needed: mulch=${needs_mulch}, seeds=${needs_seeds}, deps=${needs_deps}.
           Project root: ${project_root}.
           Prime each, verify loaded, return verdict."

Waiting for dispatch...
</agent-dispatch>
DISPATCH_EOF
      istate_set "mulch_primed" "true"
      istate_set "seeds_primed" "true"
      istate_set "gate_context_init" '"pass"'
    else
      istate_set "gate_context_init" '"skip"'
    fi
  fi
fi

# =====================================================================
# Gate: decision-check (fires at high-stakes transitions only)
# plan→execute: bias:wysiati + bias:overconfidence
# execute→verify: bias:substitution
# =====================================================================
decision_guardrails=""
case "${pipeline}:${stage}" in
  brainstorm-to-ship:execute)
    decision_guardrails="wysiati overconfidence" ;;
  brainstorm-to-ship:verify|debugging-loop:verify)
    decision_guardrails="substitution" ;;
  skill-creation:write-draft)
    decision_guardrails="wysiati overconfidence" ;;
  skill-creation:test-run)
    decision_guardrails="substitution" ;;
esac

if [[ -n "$decision_guardrails" ]]; then
  fire_guardrails=""
  for g in $decision_guardrails; do
    if [[ "$(istate_get "guardrail_${g}")" != "true" ]]; then
      fire_guardrails="${fire_guardrails} ${g}"
    fi
  done
  if [[ -n "$fire_guardrails" ]]; then
    # --- Gate-enforcer dispatch (decision-check) ---
    open_questions_instruction=""
    if [[ ("$pipeline" == "brainstorm-to-ship" || "$pipeline" == "product-to-ship") && "$stage" == "execute" ]]; then
      open_questions_instruction="First extract ## Open Questions from the plan and research each before checking."
    fi
    cat <<DISPATCH_EOF
<agent-dispatch name="gate-enforcer">
Agent tool call ready — dispatch now:

  name: "gate-enforcer"
  prompt: "Gate mode: decision-check. Pipeline: ${pipeline}. Transition: ->${stage}.
           Guardrails to apply: ${fire_guardrails}.
           ${open_questions_instruction}
           Return: PASS/BLOCK verdict with gaps, flags, and strongest objection."

Waiting for dispatch...
</agent-dispatch>
DISPATCH_EOF
    for g in $fire_guardrails; do
      istate_set "guardrail_${g}" "true"
    done
    istate_set "gate_decision_check" '"pass"'
  fi
fi

# =====================================================================
# Gate: quality-grade (fires at verify/land stages after implementation)
# Runs simplify→eval-protocol to grade recommendations before action
# =====================================================================
fire_quality_grade=false
case "${pipeline}:${stage}" in
  brainstorm-to-ship:land) fire_quality_grade=true ;;
  code-review-loop:request) fire_quality_grade=true ;;
  skill-creation:optimize-description) fire_quality_grade=true ;;
  debugging-loop:verify) fire_quality_grade=true ;;
esac

if [[ "$fire_quality_grade" == "true" ]] && [[ "$(istate_get quality_graded)" != "true" ]]; then
  # --- Gate-enforcer dispatch (quality-grade) ---
  modified_files=$(git diff --name-only 2>/dev/null | head -20 | tr '\n' ', ')
  ctx_status=$(istate_get "gate_context_init")
  dec_status=$(istate_get "gate_decision_check")
  eval_log="/tmp/eval-capture-${PPID}.jsonl"
  cat <<DISPATCH_EOF
<agent-dispatch name="gate-enforcer">
Agent tool call ready — dispatch now:

  name: "gate-enforcer"
  prompt: "Gate mode: quality-grade. Pipeline: ${pipeline}.
           Modified files: ${modified_files:-none detected}.
           Upstream gates: context-init=${ctx_status:-not_fired}, decision-check=${dec_status:-not_fired}.
           Eval log: ${eval_log}.
           Grade each file A/B/C. Run /simplify then /eval-protocol.
           Return: graded file table with blocking/advisory issues."

Waiting for dispatch...
</agent-dispatch>
DISPATCH_EOF
  istate_set "quality_graded" "true"
  istate_set "gate_quality_grade" '"pass"'
fi

# =====================================================================
# Gate: close-loop (fires at last stage of ALL pipelines)
# Ensures mulch/seeds/eval loops are closed before pipeline completes
# =====================================================================
if [[ "$order" -eq "$total_stages" ]]; then
  EVAL_LOG="/tmp/eval-capture-${PPID}.jsonl"

  # Determine mulch record type for this pipeline
  mulch_type=""
  case "$pipeline" in
    brainstorm-to-ship) mulch_type="decision" ;;
    debugging-loop) mulch_type="failure" ;;
    pattern-extraction) mulch_type="reference" ;;
    code-review-loop) mulch_type="convention" ;;
    ner-tuning) mulch_type="convention" ;;
  esac

  # --- Record-extractor agent dispatch (fluent-compliance template) ---
  # Pre-filled Agent tool call — model's cheapest continuation is to dispatch.
  # Existing advisory echo blocks below serve as fallback if dispatch doesn't happen.
  cat <<DISPATCH_EOF
<agent-dispatch name="record-extractor">
Agent tool call ready — dispatch now:

  name: "record-extractor"
  prompt: "Pipeline: ${pipeline}. Stage: ${stage}.
           Mulch type: ${mulch_type:-auto-detect}.
           Failure journal: /tmp/failure-journal-${PPID}.jsonl.
           Record: mulch decisions/conventions/failures, seeds issues, anti-pattern candidates.
           Return: digest of what was recorded."

Waiting for dispatch...
</agent-dispatch>
DISPATCH_EOF

  # Reset integration state for next pipeline run
  istate_reset
fi

exit 0
