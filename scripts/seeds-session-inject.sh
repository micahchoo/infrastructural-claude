#!/usr/bin/env bash
# seeds-session-inject.sh — SessionStart hook that injects seeds context
# If .seeds/ exists, primes issue context and summarizes ready/blocked work.
set +e

# Only run if seeds directory exists in the working directory
[[ -d ".seeds" ]] || exit 0

# Check if sd CLI is available
command -v sd >/dev/null 2>&1 || exit 0

# Prime and summarize
READY=$(sd ready 2>/dev/null | head -5)
BLOCKED=$(sd blocked 2>/dev/null | head -3)

READY_COUNT=$(sd ready 2>/dev/null | wc -l)
BLOCKED_COUNT=$(sd blocked 2>/dev/null | wc -l)

if [[ "$READY_COUNT" -gt 0 || "$BLOCKED_COUNT" -gt 0 ]]; then
  cat <<EOF
<seeds-context>
Issues: ${READY_COUNT} ready, ${BLOCKED_COUNT} blocked.
${READY:+Ready work:
$READY}
${BLOCKED:+Blocked:
$BLOCKED}
Use sd prime for full context. Use sd ready to pick next task.
</seeds-context>
EOF
fi
