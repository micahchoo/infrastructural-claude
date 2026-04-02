#!/usr/bin/env bash
# context-pressure.sh — PreCompact hook that warns about context pressure
# PreCompact fires when context window is being compacted, meaning it's full.
# This is the most reliable signal of context pressure — no percentage guessing.
set +e

cat <<'EOF'
<context-pressure level="critical">
Context is being compacted — you are running low on context window.
If substantial work remains, invoke the handoff skill NOW to write HANDOFF.md.
Do not start new tasks — preserve continuity for the next session.
</context-pressure>
EOF

# Checkpoint mulch state before context loss
if [[ -d ".mulch" ]] && command -v ml >/dev/null 2>&1; then
  echo "<context-pressure-checkpoint system=\"mulch\">If you have in-flight learnings not yet recorded, run ml learn and ml record --tags context-pressure now — context compression will lose unrecorded insights.</context-pressure-checkpoint>"
fi

# Checkpoint seeds state before context loss
if [[ -d ".seeds" ]] && command -v sd >/dev/null 2>&1; then
  IN_PROGRESS=$(sd list --status in_progress 2>/dev/null | wc -l)
  if [[ "$IN_PROGRESS" -gt 0 ]]; then
    echo "<context-pressure-checkpoint system=\"seeds\">${IN_PROGRESS} issues in_progress. Run sd update on each with current state before context is lost.</context-pressure-checkpoint>"
  fi
fi
