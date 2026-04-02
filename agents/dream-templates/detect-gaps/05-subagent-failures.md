---
name: subagent-failures
mode: detect-gaps
layer: L2
trigger: always
priority: 5
---

## What This Checks

Subagent failure journal entries (`/tmp/failure-journal-subagent.jsonl`) capture classified failures from plugin agents and ad-hoc dispatches. Recurring patterns (same agent + same failure category across sessions) indicate structural problems that need fixing — not one-off issues.

## Steps

1. **Read** subagent failure journal entries:
   ```bash
   cat /tmp/failure-journal-subagent.jsonl 2>/dev/null | jq -s '.' 2>/dev/null
   ```
   If empty or missing, skip with "no subagent failures recorded."

2. **Cluster** entries by `(agent_name, category)` pairs. Count occurrences.

3. **Identify repeat offenders** — same agent failing the same way 2+ times:
   - `tool-denied` repeat → agent definition needs tools list update or dispatch needs `mode:`
   - `missing-context` repeat → dispatch prompt template needs enrichment
   - `silent-degradation` repeat → agent may need expanded tool access
   - `prompt-quality` repeat → skill dispatching this agent needs prompt improvement

4. **For repeat offenders**, create seeds issues:
   ```bash
   sd create --title "Subagent $agent_name: recurring $category failures" \
     --type task --priority low \
     --labels "subagent-health,dream-detect-gaps" \
     --body "Agent '$agent_name' has failed with category '$category' $count times. Evidence in /tmp/failure-journal-subagent.jsonl. Remediation: $hint"
   ```

5. **Write mulch record** summarizing this cycle's findings:
   ```bash
   ml record agents-dream --type reference \
     --title "dream-subagent-failures-$(date +%Y-%m-%d)" \
     --tags "source:dream-detect-gaps,lifecycle:active" \
     --description "Subagent failure analysis: N entries, M repeat offenders, K seeds created"
   ```

## Recovery

- **No journal file**: Degrade — report "no data" in digest, skip remaining steps.
- **jq parse error**: Resume — try line-by-line processing with `while read`.
- **Seeds creation fails**: Escalate — report in digest, don't retry.

## Eval Checkpoints

`[eval: completeness]` Every entry in the journal was counted toward cluster analysis — none silently skipped.

`[eval: execution]` Seeds issues were actually created for repeat offenders, not just described.

`[eval: boundary]` Only created seeds for patterns with 2+ occurrences — did not create noise from single failures.

`[eval: resilience]` Handled missing journal file gracefully without error.

## Digest Section

```
### Subagent failures
- Entries analyzed: N | Unique agents: M
- Repeat offenders: K (list agent:category pairs)
- Seeds created: J
- Top failure category: <category> (N occurrences)
```
