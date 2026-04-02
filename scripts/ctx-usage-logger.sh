#!/usr/bin/env bash
# ctx-usage-logger.sh — UserPromptSubmit hook: logs per-turn context usage to JSONL
# Computes delta between consecutive turns. Buckets tools from ctx-turn-tracker state.
# No context injection — append-only log for dream consumption.
#
# Log: ~/.claude/logs/ctx-usage.jsonl
# Schema: {ts, session, cwd, used_pct, delta_pct, tools:[bucket,...], model}
# Downstream: dream-templates/enrichment/ctx-usage-patterns.md

set +e
command -v jq >/dev/null 2>&1 || exit 0

STATE="/tmp/cc-ctx-turn-${PPID}.json"
CTX_FILE="/tmp/cc-ctx-usable"
PREV_FILE="/tmp/cc-ctx-prev-${PPID}"
LOG="$HOME/.claude/logs/ctx-usage.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read context %
[ -f "$CTX_FILE" ] || exit 0
used=$(cat "$CTX_FILE")
[[ "$used" =~ ^[0-9]+$ ]] || exit 0

# Read model from stdin if available
input=$(cat)
model=$(echo "$input" | jq -r '.model // empty' 2>/dev/null)
[ -z "$model" ] && model="unknown"

# CWD — prefer git root, fall back to PWD
cwd=$(git -C "${PWD:-/}" rev-parse --show-toplevel 2>/dev/null || echo "${PWD:-unknown}")

# Session = stable ID from PPID
session="${PPID}"

# Compute delta from previous turn
delta=0
if [ -f "$PREV_FILE" ]; then
  prev=$(cat "$PREV_FILE")
  [[ "$prev" =~ ^[0-9]+$ ]] && delta=$(( used - prev ))
fi

# Collect turn tools
tools="[]"
[ -f "$STATE" ] && tools=$(jq -c '.tools // []' "$STATE" 2>/dev/null)

# Log completed turn (only after first turn establishes baseline)
if [ -f "$PREV_FILE" ]; then
  entry=$(jq -n \
    --arg ts "$TS" \
    --arg session "$session" \
    --arg cwd "$cwd" \
    --arg model "$model" \
    --argjson used "$used" \
    --argjson delta "$delta" \
    --argjson tools "$tools" \
    '{ts:$ts,session:$session,cwd:$cwd,model:$model,used_pct:$used,delta_pct:$delta,tools:$tools}')
  echo "$entry" >> "$LOG"
fi

# Update baseline and reset turn state for next turn
echo "$used" > "$PREV_FILE"
echo '{"tools":[]}' > "$STATE"
