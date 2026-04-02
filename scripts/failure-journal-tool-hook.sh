#!/usr/bin/env bash
# failure-journal-tool-hook.sh — Unified PostToolUse silent failure observer
# Replaces: failure-journal-{edit,write,mcp,agent}-hook.sh
# Zero context injection. Logs errors to session-scoped JSONL.
set +e
command -v jq >/dev/null 2>&1 || exit 0

JOURNAL="/tmp/failure-journal-${PPID}.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

input=$(cat)
is_error=$(echo "$input" | jq -r '.is_error // false' 2>/dev/null)
[[ "$is_error" != "true" ]] && exit 0

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
snippet=$(echo "$input" | jq -r '.tool_output // empty' 2>/dev/null | head -c 2000)

# Determine source from tool name
case "$tool_name" in
  Edit)   source="edit" ;;
  Write)  source="write" ;;
  Agent)  source="agent" ;;
  mcp__*) source="mcp" ;;
  *)      source="tool" ;;
esac

category="$source"; subcategory="unknown"; severity="error"

# Source-specific classification
case "$source" in
  edit)
    subcategory="failure"
    if echo "$snippet" | grep -qiE 'old_string not found|old_string.*not found in file'; then
      subcategory="stale-content"
    elif echo "$snippet" | grep -qiE 'permission denied|EACCES'; then
      subcategory="permission"
    elif echo "$snippet" | grep -qiE 'No such file|ENOENT'; then
      subcategory="file-not-found"
    fi
    ;;
  write)
    if echo "$snippet" | grep -qiE 'ENOENT|No such file|not found|does not exist'; then
      subcategory="path-error"
    elif echo "$snippet" | grep -qiE 'EACCES|Permission denied|EPERM|access denied'; then
      subcategory="permission"
    elif echo "$snippet" | grep -qiE 'ENOSPC|No space left|disk full'; then
      subcategory="disk-full"; severity="critical"
    fi
    ;;
  mcp)
    if echo "$snippet" | grep -qiE 'Connection closed|connection.*closed'; then
      subcategory="connection"
    elif echo "$snippet" | grep -qiE 'timeout|timed out|ETIMEDOUT'; then
      subcategory="timeout"
    elif echo "$snippet" | grep -qiE '\-32000|\-32602|JSON-RPC|json.rpc'; then
      subcategory="json-rpc"
    elif echo "$snippet" | grep -qiE 'empty result|no results|null result'; then
      subcategory="empty-result"; severity="warning"
    fi
    ;;
  agent)
    subcategory="failure"
    if echo "$snippet" | grep -qiE 'timeout|timed out'; then
      subcategory="timeout"
    elif echo "$snippet" | grep -qiE 'context.*overflow|context.*limit'; then
      subcategory="context-overflow"
    fi
    ;;
esac

error_line=$(echo "$snippet" | grep -iE 'error|FAIL|timeout|ENOENT|EACCES|ENOSPC|denied|refused|overflow|limit|closed|-320' | head -1 | head -c 200)

# Extract optional fields
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
agent_name=$(echo "$input" | jq -r '.tool_input.name // empty' 2>/dev/null)

jq -n --arg ts "$TS" --arg source "$source" \
  --arg category "$category" --arg subcategory "$subcategory" \
  --arg severity "$severity" --arg error_line "${error_line:-}" \
  --arg cwd "$(pwd)" --arg branch "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)" \
  --arg tool_name "$tool_name" --arg file "$file_path" --arg agent "$agent_name" \
  '{ts:$ts,source:$source,tool_name:$tool_name,category:$category,subcategory:$subcategory,severity:$severity,error_line:$error_line,cwd:$cwd,branch:$branch,is_error:true,file:$file,agent:$agent} | with_entries(select(.value != ""))' \
  >> "$JOURNAL" 2>/dev/null

exit 0
