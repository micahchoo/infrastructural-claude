#!/usr/bin/env bash
# transcript-signal-extract.sh — Stage 1 signal extraction from Claude Code transcripts
# Scans recent transcripts for high-value events: errors, corrections, agent failures,
# approach changes, SNAGs. Outputs structured JSONL to /tmp/transcript-signals.jsonl.
#
# Usage: bash transcript-signal-extract.sh [--days N] [--subagents-only]
#   --days N          Look back N days (default: 7)
#   --subagents-only  Only scan subagent transcripts
#
# Transcript format (JSONL per line):
#   type: user|assistant|progress|system|tool_use|tool_result
#   message.content[]: array of {type: text|tool_use|tool_result, ...}
#   For assistant: message.content[].type == "tool_use" has {name, input, id}
#   For user: message.content[].type == "tool_result" has {tool_use_id, is_error, content}
set +e
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

DAYS=7
SUBAGENTS_ONLY=false
OUTPUT="/tmp/transcript-signals.jsonl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --subagents-only) SUBAGENTS_ONLY=true; shift ;;
    *) shift ;;
  esac
done

> "$OUTPUT"  # truncate

# --- Find transcripts ---
if [[ "$SUBAGENTS_ONLY" == "true" ]]; then
  transcripts=$(find ~/.claude/projects/ -name '*.jsonl' -mtime -"$DAYS" -path '*/subagents/*' 2>/dev/null)
else
  transcripts=$(find ~/.claude/projects/ -name '*.jsonl' -mtime -"$DAYS" 2>/dev/null)
fi

total=$(echo "$transcripts" | grep -c . 2>/dev/null || echo 0)
[[ "$total" -eq 0 ]] && { echo '{"summary":"no transcripts found","days":'$DAYS'}' > "$OUTPUT"; exit 0; }

processed=0
signals=0

extract_signals() {
  local file="$1"
  local project
  project=$(echo "$file" | sed 's|.*\.claude/projects/||' | cut -d/ -f1)
  local is_subagent="false"
  echo "$file" | grep -q '/subagents/' && is_subagent="true"
  local session_id
  session_id=$(basename "$file" .jsonl)

  # --- Signal 1: Tool errors (is_error in tool_result content blocks) ---
  grep '"type":"user"' "$file" 2>/dev/null | jq -c '
    .message.content[]? |
    select(.type == "tool_result" and .is_error == true) |
    {content: (.content // "" | tostring[:500])}
  ' 2>/dev/null | while IFS= read -r err; do
    content=$(echo "$err" | jq -r '.content')
    # Skip benign errors (grep no match, test failures)
    echo "$content" | grep -qiE 'denied|permission|not allowed|not available|cannot access' && {
      jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg project "$project" --arg session "$session_id" \
        --argjson subagent "$is_subagent" \
        --arg signal "tool-error-permission" \
        --arg content "$content" \
        '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, excerpt: ($content[:300])}' \
        >> "$OUTPUT"
      return
    }
    echo "$content" | grep -qiE 'Traceback|Error:|FAIL|exception|stack trace' && {
      jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg project "$project" --arg session "$session_id" \
        --argjson subagent "$is_subagent" \
        --arg signal "tool-error" \
        --arg content "$content" \
        '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, excerpt: ($content[:300])}' \
        >> "$OUTPUT"
    }
  done

  # --- Signal 2: Agent dispatches and their results ---
  # Extract Agent tool_use blocks
  grep '"type":"assistant"' "$file" 2>/dev/null | jq -c '
    .message.content[]? |
    select(.type == "tool_use" and .name == "Agent") |
    {id: .id, subagent_type: .input.subagent_type, agent_name: .input.name,
     prompt_len: (.input.prompt | length), mode: .input.mode,
     prompt_excerpt: (.input.prompt[:200])}
  ' 2>/dev/null | while IFS= read -r agent; do
    agent_name=$(echo "$agent" | jq -r '.agent_name // .subagent_type // "unnamed"')
    mode=$(echo "$agent" | jq -r '.mode // "none"')
    prompt_len=$(echo "$agent" | jq -r '.prompt_len')
    prompt_excerpt=$(echo "$agent" | jq -r '.prompt_excerpt')

    # Flag: no mode set
    [[ "$mode" == "none" || "$mode" == "null" ]] && {
      jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg project "$project" --arg session "$session_id" \
        --argjson subagent "$is_subagent" \
        --arg signal "agent-no-mode" \
        --arg agent "$agent_name" \
        --argjson prompt_len "$prompt_len" \
        '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, agent: $agent, prompt_len: $prompt_len}' \
        >> "$OUTPUT"
    }

    # Flag: very short prompt
    [[ "$prompt_len" -lt 50 ]] && {
      jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg project "$project" --arg session "$session_id" \
        --argjson subagent "$is_subagent" \
        --arg signal "agent-short-prompt" \
        --arg agent "$agent_name" \
        --arg excerpt "$prompt_excerpt" \
        '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, agent: $agent, excerpt: $excerpt}' \
        >> "$OUTPUT"
    }
  done

  # --- Signal 3: User corrections (imperative/second-person only) ---
  # Filters out "No X exists" factual statements. Requires imperative verbs or
  # second-person address to distinguish corrections from descriptions.
  grep '"type":"user"' "$file" 2>/dev/null | jq -r '
    .message.content // .message | if type == "object" then .content else . end |
    if type == "string" then . elif type == "array" then . else "" end | tostring
  ' 2>/dev/null | grep -iE "^(no[, ]+(don.t|stop|that.s|I (said|told|asked|meant|want))|don.t |stop |wrong[, ]+(you|it|that)|not what I|that.s not what|incorrect[, ]+(you|it|the))" | head -10 | while IFS= read -r correction; do
    jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg project "$project" --arg session "$session_id" \
      --argjson subagent "$is_subagent" \
      --arg signal "user-correction" \
      --arg content "$correction" \
      '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, excerpt: ($content[:200])}' \
      >> "$OUTPUT"
  done

  # --- Signal 4: [SNAG] markers in assistant text ---
  # Filter out documentation references to [SNAG] — only keep actual SNAG events.
  # Real SNAGs start with "[SNAG]" or "- [SNAG]", not embedded in tables/docs.
  grep '"type":"assistant"' "$file" 2>/dev/null | jq -r '
    .message.content[]? | select(.type == "text") | .text // ""
  ' 2>/dev/null | grep '\[SNAG\]' | grep -vE '^\||\*\*\[SNAG\]|`\[SNAG\]`|vocabulary|channel|example|template' | while IFS= read -r snag; do
    jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg project "$project" --arg session "$session_id" \
      --argjson subagent "$is_subagent" \
      --arg signal "snag" \
      --arg content "$snag" \
      '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, excerpt: ($content[:300])}' \
      >> "$OUTPUT"
  done

  # --- Signal 5: Approach changes in assistant text ---
  grep '"type":"assistant"' "$file" 2>/dev/null | jq -r '
    .message.content[]? | select(.type == "text") | .text // ""
  ' 2>/dev/null | grep -iE 'let me try a different|that didn.t work|instead,? (let me|I.ll)|changing approach|alternative approach' | head -5 | while IFS= read -r pivot; do
    jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg project "$project" --arg session "$session_id" \
      --argjson subagent "$is_subagent" \
      --arg signal "approach-change" \
      --arg content "$pivot" \
      '{ts: $ts, project: $project, session: $session, is_subagent: $subagent, signal: $signal, excerpt: ($content[:300])}' \
      >> "$OUTPUT"
  done
}

# --- Process transcripts ---
echo "$transcripts" | while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  extract_signals "$file"
  ((processed++))
done

# --- Summary ---
signals=$(wc -l < "$OUTPUT" 2>/dev/null || echo 0)
echo "Processed: $total transcripts ($DAYS days). Extracted: $signals signals → $OUTPUT" >&2
