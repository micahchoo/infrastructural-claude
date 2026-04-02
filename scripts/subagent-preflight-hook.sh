#!/usr/bin/env bash
# subagent-preflight-hook.sh — PreToolUse:Agent advisory validation
# Checks dispatch quality and writes preflight record for postflight correlation.
# Advisory only — never blocks. Emits warnings as system-reminder.
set +e
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$tool_name" != "Agent" ]] && exit 0

# Extract dispatch parameters
prompt=$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null)
agent_name=$(echo "$input" | jq -r '.tool_input.name // .tool_input.subagent_type // "unnamed"' 2>/dev/null)
mode=$(echo "$input" | jq -r '.tool_input.mode // empty' 2>/dev/null)
has_mode=$([[ -n "$mode" ]] && echo "true" || echo "false")

prompt_length=${#prompt}
warnings=()

# Check 1: Mode specified?
if [[ "$has_mode" == "false" ]]; then
  warnings+=("No permission mode set — agent may hit permission prompts")
fi

# Check 2: Prompt length
if [[ "$prompt_length" -lt 50 ]]; then
  warnings+=("Dispatch prompt is very short ($prompt_length chars) — may lack sufficient context")
fi

# Write preflight record for postflight correlation
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ts_compact=$(date -u +%Y%m%d%H%M%S)
preflight_file="/tmp/subagent-preflight-${agent_name}-${ts_compact}.json"

jq -n \
  --arg ts "$ts" \
  --arg agent "$agent_name" \
  --argjson prompt_length "$prompt_length" \
  --argjson has_mode "$has_mode" \
  --argjson warnings "$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)" \
  '{timestamp: $ts, agent_name: $agent, prompt_length: $prompt_length, has_mode: $has_mode, warnings: $warnings}' \
  > "$preflight_file" 2>/dev/null

# Emit warnings (advisory, never blocks)
if [[ ${#warnings[@]} -gt 0 ]]; then
  warning_text=""
  for w in "${warnings[@]}"; do
    warning_text="${warning_text}\n- ${w}"
  done
  echo "<system-reminder>Subagent preflight ($agent_name):${warning_text}</system-reminder>"
fi

exit 0
