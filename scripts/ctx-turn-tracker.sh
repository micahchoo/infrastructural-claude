#!/usr/bin/env bash
# ctx-turn-tracker.sh — PostToolUse hook: accumulates tool calls into per-turn state
# Uses same category names as context-mode session events for consistency.
# Zero context injection — pure side-effect logging.

set +e
command -v jq >/dev/null 2>&1 || exit 0

STATE="/tmp/cc-ctx-turn-${PPID}.json"
input=$(cat)

# Tool name from env (set by Claude Code) or stdin fallback
tool_name="${TOOL_USE_NAME:-}"
[ -z "$tool_name" ] && tool_name=$(echo "$input" | jq -r '.tool_name // .tool_use_name // empty' 2>/dev/null)
[ -z "$tool_name" ] && exit 0

# Map tool name → bucket (mirrors context-mode category naming)
case "$tool_name" in
  Read)                              bucket="file_read" ;;
  Write|Edit|NotebookEdit)          bucket="file_write" ;;
  Glob|Grep)                         bucket="search" ;;
  Bash)                              bucket="bash" ;;
  Agent)                             bucket="subagent" ;;
  Skill)
    skill=$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
    bucket="skill:${skill:-unknown}"
    ;;
  WebFetch|WebSearch)                bucket="web" ;;
  mcp__foxhound__*)                  bucket="mcp:foxhound" ;;
  mcp__context__*)                   bucket="mcp:context" ;;
  mcp__plugin_context-mode_*)        bucket="mcp:ctx-mode" ;;
  mcp__playwright__*)                bucket="mcp:playwright" ;;
  mcp__*)                            bucket="mcp:other" ;;
  *)                                 bucket="other:${tool_name}" ;;
esac

# Initialize state if absent
[ -f "$STATE" ] || echo '{"tools":[]}' > "$STATE"

# Append bucket to turn tool list
tmp=$(mktemp)
jq --arg b "$bucket" '.tools += [$b]' "$STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE"
