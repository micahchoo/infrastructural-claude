#!/usr/bin/env bash
# skill-closeloop-hook.sh — PostToolUse hook for Skill invocations
# Injects mulch/seeds close-loop actions + simplify review after relevant skills
set +e

command -v jq >/dev/null 2>&1 || exit 0

FRAGMENT_DIR="$HOME/.claude/fragments"
INTEGRATION_STATE="/tmp/integration-state-${PPID}.json"

input=$(cat)
skill_name=$(echo "$input" | jq -r '.tool_input.skill // .input.skill // empty' 2>/dev/null)
[ -z "$skill_name" ] && exit 0
skill_name="${skill_name##*:}"

# --- Integration state helpers ---
[[ ! -f "$INTEGRATION_STATE" ]] && echo '{}' > "$INTEGRATION_STATE"
istate_get() { jq -r ".$1 // empty" "$INTEGRATION_STATE" 2>/dev/null; }
istate_set() {
  local tmp; tmp=$(mktemp)
  jq ".$1 = $2" "$INTEGRATION_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$INTEGRATION_STATE"
}

# --- Simplify fragment injection ---
inject_simplify() {
  local fragment="$FRAGMENT_DIR/simplify-review.md"
  if [[ -f "$fragment" ]] && [[ "$(istate_get simplify_injected)" != "true" ]]; then
    echo "<review-integration name=\"simplify\">"
    cat "$fragment"
    echo "</review-integration>"
    istate_set "simplify_injected" "true"
  fi
}

# --- Check if model has uncommitted work (for review-own-work detection) ---
has_own_work() {
  local branch
  branch=$(git branch --show-current 2>/dev/null)
  [[ "$branch" != "main" && "$branch" != "master" ]] && return 0
  git diff --quiet HEAD 2>/dev/null && return 1
  return 0
}

# --- Per-skill actions ---
case "$skill_name" in
  brainstorming)
    if [[ "$(istate_get brainstorm_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"brainstorming-closeloop\">"
      echo "Record Locked Decisions as mulch records:"
      echo "  For each Locked Decision in the spec:"
      echo "    ml record <domain> --type decision \\"
      echo "      --title \"<the decision>\" \\"
      echo "      --rationale \"<why this was chosen>\" \\"
      echo "      --classification foundational \\"
      echo "      --tags \"scope:<module>,source:brainstorming,lifecycle:active\""
      echo "  Skip if no .mulch/ directory exists."
      echo "</skill-integration>"
      istate_set "brainstorm_closeloop" "true"
    fi
    ;;

  interactive-pr-review|requesting-code-review)
    echo "<skill-integration name=\"review-closeloop\">"
    echo "If the same finding category appeared 3+ times across recent reviews,"
    echo "consider proposing a new anti-pattern rule:"
    echo "  Edit ~/.claude/anti-pattern-rules.jsonl to add a candidate rule:"
    echo '  {"id":"<name>","pattern":"<regex>","severity":2,"source":"pr-review","status":"candidate","added":"'"$(date +%Y-%m-%d)"'"}'
    echo "</skill-integration>"
    ;;&

  writing-plans)
    if [[ "$(istate_get writingplans_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"writing-plans-closeloop\">"
      echo "1. Verify plan has an Artifact Manifest block."
      echo "   If missing, add one before proceeding."
      echo "2. Run baseline audit: bash ~/.claude/scripts/post-implementation-audit.sh <plan-file> --baseline"
      echo "3. Record structural conventions as mulch records:"
      echo "    ml record <domain> --type convention \\"
      echo "      --classification tactical \\"
      echo "      --tags \"scope:<module>,source:writing-plans,lifecycle:active\""
      echo "  Skip if no .mulch/ directory exists."
      echo "</skill-integration>"
      istate_set "writingplans_closeloop" "true"
    fi
    ;;

  executing-plans)
    if [[ "$(istate_get executingplans_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"executing-plans-closeloop\">"
      echo "Close loops:"
      echo "  - Deferred tasks: sd create --title \"<summary>\" --description \"mulch-ref: <domain>:<id>\""
      echo "    Then: sd label add <id> \"deferred\""
      echo "  - Completed tasks: sd close <id> --reason \"...\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      inject_simplify
      istate_set "executingplans_closeloop" "true"
    fi
    ;;

  requesting-code-review)
    if [[ "$(istate_get codereview_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"code-review-closeloop\">"
      echo "1. Run ml outcome for decisions that scoped this work:"
      echo "    ml search \"scope:<module> source:brainstorming\""
      echo "    ml outcome <domain> <id> --status success/failure"
      echo "2. Run post-implementation audit if a plan file exists:"
      echo "    bash ~/.claude/scripts/post-implementation-audit.sh --discover"
      echo "3. Close failure-mode loop: check for resolved failures this session:"
      echo "    ml search \"type:failure lifecycle:active\" --domain failure"
      echo "    For each resolved failure: ml outcome failure <id> --status success --notes \"<fix>\""
      echo "    Then ask: is this generalizable? If yes, propose a candidate anti-pattern rule via /failure-capture"
      echo "  Skip mulch commands if no .mulch/ directory exists."
      echo "</skill-integration>"
      inject_simplify
      istate_set "codereview_closeloop" "true"
    fi
    ;;

  verification-before-completion)
    inject_simplify
    ;;

  interactive-pr-review)
    # Only inject simplify when reviewing own work
    if has_own_work; then
      inject_simplify
    fi
    ;;

  handoff)
    if [[ "$(istate_get handoff_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"handoff-closeloop\">"
      echo "Before writing HANDOFF.md:"
      echo "  1. Assumption check: ml search \"assumption source:brainstorming\""
      echo "     Record failed assumptions: ml outcome <domain> <id> --status failure"
      echo "  2. README seam check: bash ~/.claude/scripts/readme-seam-check.sh"
      echo "  3. Seeds cross-reference: sd list --status in_progress"
      echo "  Skip if respective tools (.mulch/, .seeds/, readme-seam-check.sh) don't exist."
      echo "</skill-integration>"
      istate_set "handoff_closeloop" "true"
    fi
    ;;

  strategic-looping)
    if [[ "$(istate_get strategiclooping_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"strategic-looping-closeloop\">"
      echo "Close loops after iteration:"
      echo "  - Deferred iterations: sd create --title \"<summary>\" --type task"
      echo "    Then: sd label add <id> \"deferred-iteration\""
      echo "  - Completed work: sd close <id> --reason \"outcome:success — <what was done>\""
      echo "  - Check for next: bash ~/.claude/scripts/sd-next.sh"
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "strategiclooping_closeloop" "true"
    fi
    ;;

  check-handoff)
    if [[ "$(istate_get checkhandoff_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"check-handoff-closeloop\">"
      echo "After validating handoff state:"
      echo "  - Update stale issues: sd update <id> --status open (if assumption invalidated)"
      echo "  - Claim resumed work: bash ~/.claude/scripts/sd-claim.sh <id>"
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "checkhandoff_closeloop" "true"
    fi
    ;;

  shadow-walk)
    if [[ "$(istate_get shadowwalk_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"shadow-walk-closeloop\">"
      echo "After UX audit:"
      echo "  - Major/critical findings: sd create --title \"UX: <finding>\" --type bug"
      echo "    Then: sd label add <id> \"ux-gap\""
      echo "  - Resolved findings: sd close <id> --reason \"outcome:success — <fix>\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "shadowwalk_closeloop" "true"
    fi
    ;;

  pattern-advisor)
    if [[ "$(istate_get patternadvisor_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"pattern-advisor-closeloop\">"
      echo "After architectural recommendation:"
      echo "  - Pattern gaps discovered: sd create --title \"Pattern gap: <domain>\" --type task"
      echo "    Then: sd label add <id> \"pattern-gap\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "patternadvisor_closeloop" "true"
    fi
    ;;

  pattern-extraction-pipeline)
    if [[ "$(istate_get patternextraction_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"pattern-extraction-closeloop\">"
      echo "After extraction/enrichment/audit:"
      echo "  - Close resolved issues: sd close <id> --reason \"outcome:success — <what was enriched>\""
      echo "  - New gaps found: sd create --title \"Enrich: <codebook>\" --type task"
      echo "    Then: sd label add <id> \"patterns,enrichment\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "patternextraction_closeloop" "true"
    fi
    ;;

  hybrid-research)
    if [[ "$(istate_get hybridresearch_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"hybrid-research-closeloop\">"
      echo "After research completion:"
      echo "  - Resolved research issues: sd close <id> --reason \"outcome:success — <finding>\""
      echo "  - Follow-up work identified: sd create --title \"<follow-up>\" --type task"
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "hybridresearch_closeloop" "true"
    fi
    ;;

  characterization-testing)
    if [[ "$(istate_get chartesting_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"characterization-testing-closeloop\">"
      echo "After characterization tests written:"
      echo "  - Close investigation issues: sd close <id> --reason \"outcome:success — behavior documented\""
      echo "  - Surprises found: sd create --title \"Unexpected: <behavior>\" --type bug"
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "chartesting_closeloop" "true"
    fi
    ;;

  chat-archive-ner-tuning)
    if [[ "$(istate_get nertuning_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"ner-tuning-closeloop\">"
      echo "After NER tuning iteration:"
      echo "  - Close tuning issues: sd close <id> --reason \"outcome:success — precision/recall improved\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "nertuning_closeloop" "true"
    fi
    ;;

  failure-capture)
    if [[ "$(istate_get failurecapture_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"failure-capture-closeloop\">"
      echo "After failure capture:"
      echo "  - Unresolved failures: sd create --title \"[SNAG] <description>\" --type bug --labels failure-mode"
      echo "  - Resolved failures: ml outcome failure <record-id> --status success --notes \"<fix>\""
      echo "  - Generalizable? Propose candidate anti-pattern rule."
      echo "  Skip mulch/seeds commands if no .mulch/ or .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "failurecapture_closeloop" "true"
    fi
    ;;

  eval-protocol)
    if [[ "$(istate_get evalprotocol_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"eval-protocol-closeloop\">"
      echo "After eval harness run:"
      echo "  - Close eval issues: sd close <id> --reason \"outcome:success — grades: <summary>\""
      echo "  Skip seeds commands if no .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "evalprotocol_closeloop" "true"
    fi
    ;;

  product-design)
    if [[ "$(istate_get productdesign_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"product-design-closeloop\">"
      echo "After product design phase completes:"
      echo "  - Record design decisions: ml record <domain> --type decision \\"
      echo "      --title \"<design choice>\" \\"
      echo "      --rationale \"<why this was chosen>\" \\"
      echo "      --classification foundational \\"
      echo "      --tags \"scope:<section>,source:product-design,lifecycle:active\""
      echo "  - Close design issues: sd close <id> --reason \"outcome:success — design spec produced\""
      echo "  Skip mulch/seeds commands if no .mulch/ or .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "productdesign_closeloop" "true"
    fi
    ;;

  quality-linter)
    if [[ "$(istate_get qualitylinter_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"quality-linter-closeloop\">"
      echo "After QA evaluation or design completes:"
      echo "  - Record force clusters: ml record <force-cluster> --type convention \\"
      echo "      --description \"<force cluster description>\" \\"
      echo "      --classification tactical \\"
      echo "      --tags \"scope:<module>,source:quality-linter,lifecycle:discovered\""
      echo "  - Close QA issues: sd close <id> --reason \"outcome:success — assessment produced\""
      echo "  - Codebook gaps: sd create --title \"Codebook gap: <cluster>\" --labels \"force-cluster,codebook-gap\""
      echo "  Skip mulch/seeds commands if no .mulch/ or .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "qualitylinter_closeloop" "true"
    fi
    ;;

  research-protocol)
    if [[ "$(istate_get researchprotocol_closeloop)" != "true" ]]; then
      echo "<skill-integration name=\"research-protocol-closeloop\">"
      echo "After research synthesis completes:"
      echo "  - Record novel findings: ml record <domain> --type reference \\"
      echo "      --description \"<finding summary>\" \\"
      echo "      --classification observational \\"
      echo "      --tags \"scope:<domain>,source:research-protocol,lifecycle:active\""
      echo "  - Close research issues: sd close <id> --reason \"outcome:success — synthesis produced\""
      echo "  Skip mulch/seeds commands if no .mulch/ or .seeds/ directory exists."
      echo "</skill-integration>"
      istate_set "researchprotocol_closeloop" "true"
    fi
    ;;
esac

# ─── Failure journal sweep (Component 2: checkpoint at skill boundaries) ───
# Reads the session's failure journal and injects a contextualized prompt
# for high+medium failure-likelihood skills. Fires once per session.
JOURNAL="/tmp/failure-journal-${PPID}.jsonl"
FAILURE_SWEEP_SKILLS="executing-plans|hybrid-research|research-protocol|characterization-testing|shadow-walk|quality-linter|pattern-extraction-pipeline|strategic-looping|writing-plans|requesting-code-review|interactive-pr-review|seam-identification|pattern-advisor"

if [[ "$skill_name" =~ ^($FAILURE_SWEEP_SKILLS)$ ]] && \
   [[ "$(istate_get failure_sweep_done)" != "true" ]] && \
   [[ -f "$JOURNAL" ]]; then

  # Count signals
  total=$(wc -l < "$JOURNAL" 2>/dev/null || echo 0)
  errors=$(jq -r 'select(.is_error == true) | .category' "$JOURNAL" 2>/dev/null | wc -l)
  snags=$(grep -c '"snag":true' "$JOURNAL" 2>/dev/null || echo 0)
  retries=$(grep -c '"retry":true' "$JOURNAL" 2>/dev/null || echo 0)
  criticals=$(jq -r 'select(.severity == "critical") | .cmd' "$JOURNAL" 2>/dev/null | wc -l)

  # Only inject if there's something worth reviewing
  if [[ "$errors" -gt 0 ]] || [[ "$snags" -gt 0 ]]; then
    # Extract top failures (unique categories, max 5)
    top_failures=$(jq -r 'select(.severity == "error" or .severity == "critical") | "\(.category)/\(.subcategory): \(.cmd | .[0:60])"' "$JOURNAL" 2>/dev/null | sort -u | head -5)
    snag_descs=$(jq -r 'select(.snag == true) | .desc | .[0:80]' "$JOURNAL" 2>/dev/null | head -3)

    echo "<failure-sweep skill=\"$skill_name\">"
    echo "Session failure journal: $total commands logged, $errors errors, $snags [SNAG]s, $retries retries."

    if [[ "$criticals" -gt 0 ]]; then
      echo "CRITICAL failures detected — review before proceeding."
    fi

    if [[ -n "$top_failures" ]]; then
      echo "Top failures:"
      echo "$top_failures" | while read -r line; do echo "  - $line"; done
    fi

    if [[ -n "$snag_descs" ]] && [[ "$snags" -gt 0 ]]; then
      echo "Model-flagged deviations:"
      echo "$snag_descs" | while read -r line; do echo "  - $line"; done
    fi

    echo ""
    echo "The record-extractor agent handles failure recording at pipeline close."
    echo "For mid-session failures, invoke /failure-capture manually."
    echo "</failure-sweep>"

    istate_set "failure_sweep_done" "true"
  fi
fi

exit 0
