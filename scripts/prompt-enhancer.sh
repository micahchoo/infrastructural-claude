#!/usr/bin/env bash
# prompt-enhancer.sh — UserPromptSubmit hook
# Uses Haiku to bridge the gap between raw codebase analytics and user intent.
# Value: things a small model can derive cheaply that would cost the large model
# multiple tool calls — intent→file mapping, relevance filtering, change connection.
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COOLDOWN_FILE="/tmp/prompt-enhancer-last-run"
COOLDOWN_SECONDS=120

# --- Read hook input from stdin ---
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '
  .message.content // .message // .prompt.content // .prompt // empty
' 2>/dev/null)

[[ -z "$PROMPT" ]] && exit 0

# --- Gate 1: Too short ---
WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')
[[ "$WORD_COUNT" -lt 3 ]] && exit 0

# --- Gate 2: Skip acknowledgments and simple responses ---
if echo "$PROMPT" | grep -qiE '^\s*(yes|no|ok|y|n|sure|thanks|thank you|lgtm|looks good|correct|right|agreed|done|perfect|great|nice|cool|fine|got it|ship it|merge it|go ahead|do it|approved|nope|nah|yep|yeah|sounds good|all good|good|k)\s*[.!]?\s*$'; then
  exit 0
fi

# --- Gate 3: Skip slash commands ---
echo "$PROMPT" | grep -qE '^\s*/' && exit 0

# --- Gate 4: Cooldown ---
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_RUN=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  [[ $((NOW - LAST_RUN)) -lt $COOLDOWN_SECONDS ]] && exit 0
fi

# --- Gate 5: Must be inside a git repo ---
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# --- Gather COMPRESSED analytics (not the full 6.8KB) ---
# Only feed Haiku what it needs for disambiguation: changes, churn, structure
ANALYTICS=""

# Working changes — most valuable for intent mapping
CHANGES=$(git diff --name-status 2>/dev/null | head -15)
STAGED=$(git diff --cached --name-status 2>/dev/null | head -10)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -5)
if [[ -n "$CHANGES" || -n "$STAGED" || -n "$UNTRACKED" ]]; then
  ANALYTICS+="CHANGES:\n"
  [[ -n "$STAGED" ]] && ANALYTICS+="$STAGED\n"
  [[ -n "$CHANGES" ]] && ANALYTICS+="$CHANGES\n"
  [[ -n "$UNTRACKED" ]] && ANALYTICS+="$(echo "$UNTRACKED" | sed 's/^/??\t/')\n"
fi

# Recent commits — intent context
ANALYTICS+="RECENT:\n$(git log --oneline -5 2>/dev/null)\n"

# Hot files — what's being actively worked
ANALYTICS+="CHURN:\n$(git log --since='2 weeks ago' --max-count=500 --pretty=format: --name-only 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -rn | head -8)\n"

# Structure — top-level dirs only
ANALYTICS+="DIRS:\n$(ls -d */ 2>/dev/null | head -12)\n"

# --- Build focused Haiku prompt ---
HAIKU_PROMPT="You are a codebase-aware prompt pre-processor. Given a user's message to a coding assistant and compressed codebase signals, output ONLY:

1. FILES: 1-5 most relevant file paths (from changes, churn, or structure)
2. INTENT: One sentence mapping vague references ('this', 'it', 'the bug') to specific artifacts
3. SKILL: If a specific skill clearly applies, one line: 'skill: <name> — <why>' using:
   systematic-debugging (bugs), hybrid-research (multi-file investigation), brainstorming (new features), writing-plans (multi-step implementation), portainer-deploy (deploy/ship), interactive-pr-review (PR review), gha (CI failures), obsidian-cli (vault operations)

Output nothing else. No preamble. No explanation. If the prompt is already specific, output only the FILES line.

USER: ${PROMPT}

${ANALYTICS}"

# --- Enhance with Haiku (5s timeout via claude -p) ---
ENHANCED=$(timeout 8 claude -p --model claude-haiku-4-5-20251001 "$HAIKU_PROMPT" 2>/dev/null)

[[ -z "$ENHANCED" || ${#ENHANCED} -lt 10 ]] && exit 0

# --- Record cooldown ---
date +%s > "$COOLDOWN_FILE"

# --- Return as hook context ---
echo "$ENHANCED"
