---
name: transcript-mining
mode: detect-gaps
layer: L1
trigger: transcripts > 0
priority: 6
---

## What This Checks

Transcript signals extracted by `scripts/transcript-signal-extract.sh` reveal structural problems invisible to hook-level logging: subagent permission denials, user corrections, approach pivots, and [SNAG] events. Recurring patterns across sessions indicate systemic issues.

## Steps

1. **Run extraction** on transcripts since last dream run:
   ```bash
   days_since=$(( ($(date +%s) - $(stat -c %Y /tmp/.dream-last-run-detect-gaps 2>/dev/null || echo 0)) / 86400 + 1 ))
   bash ~/.claude/scripts/transcript-signal-extract.sh --days "$days_since"
   ```

2. **Read** extracted signals:
   ```bash
   cat /tmp/transcript-signals.jsonl 2>/dev/null | jq -s '.' 2>/dev/null
   ```
   If empty or missing, skip with "no transcript signals extracted."

3. **Cluster by signal type** and count:
   ```bash
   jq -r '.signal' /tmp/transcript-signals.jsonl | sort | uniq -c | sort -rn
   ```

4. **Analyze each signal type for repeat patterns:**

   **agent-no-mode** — Group by agent name. Agents with 5+ occurrences need `mode:` added to their dispatch pattern or agent definition.

   **tool-error-permission** — Group by project and subagent status. Subagent permission denials indicate missing `mode: "bypassPermissions"` in dispatch or missing tool pre-approvals.

   **user-correction** — Each unique correction is a behavioral signal. Check if it's already captured in a memory file. If not, create one.

   **snag** — Real [SNAG] events with context. Check if the underlying issue was resolved (search seeds, mulch). Unresolved SNAGs become seeds issues.

   **approach-change** — Pivots indicate friction points. Cluster by cause (permission denied → pivot, format mismatch → pivot, tool failure → pivot). Permission-caused pivots correlate with tool-error-permission signals.

   **agent-short-prompt** — Agents dispatched with <50 char prompts. Group by agent name — repeat offenders indicate skill dispatch templates need enrichment.

5. **For repeat patterns (3+ occurrences across sessions)**, create seeds issues:
   ```bash
   sd create --title "Transcript pattern: $signal_type for $agent_or_project" \
     --type task --priority low \
     --labels "transcript-mining,dream-detect-gaps" \
     --body "Pattern: $description. Count: $count across $sessions sessions. Evidence in /tmp/transcript-signals.jsonl"
   ```

6. **For user corrections not yet in memory**, create memory files:
   ```bash
   # Only for corrections that appear 2+ times (confirmed pattern, not one-off)
   ```

7. **Write mulch record** summarizing findings:
   ```bash
   ml record agents-dream --type reference \
     --title "dream-transcript-mining-$(date +%Y-%m-%d)" \
     --tags "source:dream-detect-gaps,lifecycle:active" \
     --description "Transcript mining: N signals, M patterns, K seeds created, J memories written"
   ```

## Recovery

- **Extraction script fails**: Degrade — report "extraction failed" in digest, skip remaining steps.
- **No signals extracted**: Degrade — report "no signals" in digest. This is normal for short intervals.
- **Seeds creation fails**: Escalate — report in digest, don't retry.

## Eval Checkpoints

`[eval: completeness]` Every signal type with 3+ entries was analyzed for patterns — none silently skipped.

`[eval: execution]` Seeds issues were actually created for repeat patterns, not just described.

`[eval: boundary]` Only created seeds for patterns with 3+ occurrences — did not create noise from rare events.

`[eval: idempotence]` Checked for existing seeds issues before creating duplicates.

`[eval: resilience]` Handled missing transcript-signals.jsonl gracefully without error.

## Digest Section

```
### Transcript mining
- Signals extracted: N (from M transcripts, D days)
- By type: agent-no-mode: A | tool-error-permission: B | tool-error: C | snag: D | user-correction: E | approach-change: F | agent-short-prompt: G
- Repeat patterns found: K
- Seeds created: J | Memories written: L
- Top finding: <most actionable pattern>
```
