---
name: history-patterns
mode: detect-gaps
layer: L1
trigger: history_lines > 100
priority: 3
---

## What This Checks

`~/.claude/history.jsonl` contains user prompts with project/session metadata. Slash-command usage reveals which skills are actively used, which are unused, and which projects drive the most activity. Skills never invoked (via slash or hooks/agents) may be dead weight.

## Steps

1. **Analyze skill usage patterns** from slash commands in prompt history:
   ```bash
   # Dream-added: 2026-03-24 — history.jsonl has {display, project, sessionId, timestamp}
   # Skill invocations appear as /skill-name in the display field
   jq -r '.display' ~/.claude/history.jsonl 2>/dev/null | \
     grep -oP '^/[a-zA-Z][a-zA-Z0-9_-]+' | sort | uniq -c | sort -rn | head -20
   echo "--- Project activity ---"
   jq -r '.project' ~/.claude/history.jsonl 2>/dev/null | \
     sed 's|.*/||' | sort | uniq -c | sort -rn | head -10
   ```

2. **Cross-reference** available skills against slash-invoked skills AND hook/agent references to find truly unused skills:
   ```bash
   invoked=$(jq -r '.display' ~/.claude/history.jsonl 2>/dev/null | \
     grep -oP '^/[a-zA-Z][a-zA-Z0-9_-]+' | sed 's|^/||' | sort -u)
   all_skills=$(ls skills/*/SKILL.md 2>/dev/null | sed 's|skills/||;s|/SKILL.md||' | sort)
   # Never slash-invoked
   never=$(comm -23 <(echo "$all_skills") <(echo "$invoked"))
   # Check each for hook/agent references
   for skill in $never; do
     refs=$(grep -rl "$skill" settings.json agents/ scripts/ 2>/dev/null | wc -l)
     [ "$refs" -eq 0 ] && echo "TRULY UNUSED: $skill ($(wc -l < skills/$skill/SKILL.md) lines)"
   done
   ```

3. **Write gap findings**:
   - Skills never invoked → note as potential dead skills in mulch
   - Recurring failure clusters around a workflow → create a failure-journal category
   - Skill usage shifts → record as a mulch reference for trend tracking:
     ```bash
     ml record agents-dream --type reference --name "dream-history-<date>" \
       --description "History analysis: top skills: <list>. Never used: <list>. Trend: <observation>" \
       --classification observational \
       --tags "source:dream-history,lifecycle:active"
     ```

## Eval Checkpoints

`[eval: depth]` Identified behavioral patterns (repeated approach failures, tool preference shifts, recurring corrections), not just command frequency counts.

`[eval: boundary]` Pattern observations were written as mulch records with evidence links, not hardcoded into scripts or CLAUDE.md.

## Improvement Writes

- Record skill usage trends to mulch
- Flag never-used skills for investigation
- Create failure-journal categories for workflow-specific failure clusters

## Digest Section

```
### History patterns
- Sessions analyzed: N | Skills tracked: N
- Abandoned workflows detected: N
- Never-used skills: N
```

## Recovery

- **On history.jsonl missing or empty**: **degrade** — skip template, note "no history data" in digest.
- **On insufficient data** (< 50 history entries): **degrade** — skip, note "insufficient history for pattern detection" in digest.
