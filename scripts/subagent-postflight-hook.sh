#!/usr/bin/env bash
# subagent-postflight-hook.sh — PostToolUse:Agent failure classifier
# Classifies agent results against 7-category taxonomy.
# Writes structured JSONL. Emits remediation for severity >= high.
set +e
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$tool_name" != "Agent" ]] && exit 0

# Extract result and dispatch info
result=$(echo "$input" | jq -r '.tool_result // empty' 2>/dev/null)
agent_name=$(echo "$input" | jq -r '.tool_input.name // .tool_input.subagent_type // "unnamed"' 2>/dev/null)
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
is_error=$(echo "$input" | jq -r '.is_error // false' 2>/dev/null)

result_length=${#result}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- Load preflight record (best-effort, newest match) ---
preflight_file=$(ls -t /tmp/subagent-preflight-${agent_name}-*.json 2>/dev/null | head -1)
preflight_warnings="[]"
if [[ -f "$preflight_file" ]]; then
  preflight_warnings=$(jq -r '.warnings // []' "$preflight_file" 2>/dev/null)
  # Clean up preflight file
  rm -f "$preflight_file" 2>/dev/null
fi

# --- Classify against 7-category taxonomy ---
categories=()
severity="success"
hints=()

# 1. tool-denied (critical)
if echo "$result" | grep -qiE 'denied|not allowed|permission denied|tool.*not available|does not have.*permission'; then
  categories+=("tool-denied")
  severity="critical"
  hints+=("Specify mode: 'bypassPermissions' or add tools to agent definition")
fi

# 2. timeout (critical)
if [[ -z "$result" ]] || echo "$result" | grep -qiE 'timeout|timed out|ETIMEDOUT|exceeded.*time'; then
  if [[ -z "$result" ]]; then
    categories+=("timeout")
    severity="critical"
    hints+=("Reduce scope or increase timeout")
  fi
fi

# 3. missing-context (high)
if echo "$result" | grep -qiE "I don.t have access|couldn.t find|no context for|not available in my context|I cannot access|file.* not found"; then
  categories+=("missing-context")
  [[ "$severity" != "critical" ]] && severity="high"
  hints+=("Include file contents or summaries in the dispatch prompt")
fi

# 4. context-overflow (high)
if echo "$result" | grep -qiE 'context.*limit|context.*window|running out of.*space|token limit|truncat'; then
  categories+=("context-overflow")
  [[ "$severity" != "critical" ]] && severity="high"
  hints+=("Summarize context before dispatching, or split into smaller tasks")
fi

# 5. silent-degradation (moderate)
if echo "$result" | grep -qiE "I couldn.t|skipping|unable to|I was unable|I cannot|not able to|falling back"; then
  # Only flag if not already caught by a more specific category
  if [[ ${#categories[@]} -eq 0 ]]; then
    categories+=("silent-degradation")
    [[ "$severity" == "success" ]] && severity="moderate"
    hints+=("Check if agent had the tools it needed")
  fi
fi

# 6. tool-error (moderate)
if echo "$result" | grep -qiE 'Traceback|stack trace|Error:|ERROR|failed to|exit code [1-9]|non-zero exit|exception'; then
  if [[ ${#categories[@]} -eq 0 ]] || [[ ! " ${categories[*]} " =~ " tool-denied " ]]; then
    categories+=("tool-error")
    [[ "$severity" == "success" ]] && severity="moderate"
    hints+=("Check tool availability and input format")
  fi
fi

# 7. prompt-quality (low) — only from preflight warnings + result signals
if echo "$preflight_warnings" | jq -e 'length > 0' >/dev/null 2>&1; then
  if echo "$result" | grep -qiE 'clarif|what do you mean|could you specify|not sure what|ambiguous'; then
    categories+=("prompt-quality")
    [[ "$severity" == "success" ]] && severity="low"
    hints+=("Add task verb, success criteria, and sufficient context")
  fi
fi

# Also flag is_error from Claude Code itself
if [[ "$is_error" == "true" ]] && [[ ${#categories[@]} -eq 0 ]]; then
  categories+=("tool-error")
  [[ "$severity" == "success" ]] && severity="moderate"
  hints+=("Agent returned an error — check tool_result for details")
fi

# --- Skip if no failures detected ---
[[ ${#categories[@]} -eq 0 ]] && exit 0

# --- Write to subagent failure journal ---
journal="/tmp/failure-journal-subagent.jsonl"
prompt_excerpt=$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null | head -c 200)
result_excerpt=$(echo "$result" | head -c 500)

jq -n \
  --arg ts "$ts" \
  --arg agent "$agent_name" \
  --arg subtype "$subagent_type" \
  --argjson categories "$(printf '%s\n' "${categories[@]}" | jq -R . | jq -s .)" \
  --arg severity "$severity" \
  --argjson preflight_warnings "$preflight_warnings" \
  --arg prompt_excerpt "$prompt_excerpt" \
  --arg result_excerpt "$result_excerpt" \
  '{timestamp: $ts, agent_name: $agent, subagent_type: $subtype, categories: $categories, severity: $severity, preflight_warnings: $preflight_warnings, prompt_excerpt: $prompt_excerpt, result_excerpt: $result_excerpt}' \
  >> "$journal" 2>/dev/null

# --- Emit remediation for severity >= high ---
if [[ "$severity" == "critical" || "$severity" == "high" ]]; then
  hint_text=""
  for h in "${hints[@]}"; do
    hint_text="${hint_text}\n- ${h}"
  done
  cat_text=$(IFS=', '; echo "${categories[*]}")
  echo "<system-reminder>Subagent failure ($agent_name): [$cat_text] severity=$severity${hint_text}</system-reminder>"
fi

exit 0
