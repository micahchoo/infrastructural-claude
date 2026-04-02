---
name: failure-journal
mode: detect-gaps
layer: L2
trigger: uncategorized > 0
priority: 1
---

## What This Checks

Failure journal entries with `category == "uncategorized"` represent gaps in the detection system. Recurring uncategorized patterns should become named categories with classify() branches in the hook script.

## Steps

1. **Read** uncategorized failure journal entries across recent sessions:
   ```bash
   find /tmp -name 'failure-journal-*.jsonl' 2>/dev/null | \
     xargs jq -r 'select(.category == "uncategorized")' 2>/dev/null
   ```

2. **Cluster** uncategorized entries by error pattern similarity.

3. **Name** recurring clusters and **write** new classify() branches directly into `scripts/failure-journal-hook.sh`. Insert before the catch-all, mark with date:
   ```bash
   # New category: <name>/<subcategory>
   # Pattern: <regex that matches these entries>
   # Evidence: <N entries across M sessions>
   # Dream-added: <date>
   if echo "$s" | grep -qiE '<pattern>'; then
     category="<name>"; subcategory="<subcategory>"; severity="<level>"; return
   fi
   ```

4. **Review** candidate anti-pattern rules in `~/.claude/anti-pattern-rules.jsonl` (status: "candidate").

5. **Promote** candidates that appeared in 2+ sessions to "active":
   ```json
   {"id":"<name>","status":"active","promoted_by":"dream-detect-gaps","promoted":"<date>"}
   ```

## Eval Checkpoints

`[eval: completeness]` Every uncategorized failure-journal entry was reviewed and either categorized or explicitly deferred — none silently skipped.

`[eval: execution]` New classify() branches were actually inserted into `scripts/failure-journal-hook.sh`, not just described in the digest.

`[eval: depth]` Clusters are based on root-cause similarity (why it failed), not just surface string matching (what the error message says).

## Improvement Writes

- Add classify() branches to `scripts/failure-journal-hook.sh`
- Promote candidate anti-pattern rules to active
- All additions marked with `# Dream-added: <date>`

## Digest Section

```
### Failure journal
- Uncategorized reviewed: N | New categories written: N
- Rules promoted: N | Coverage delta: +N categories
```

## Recovery

- **On corrupt journal entries** (malformed JSON): **resume** — skip corrupt lines, continue. Note skipped count.
- **On failure-journal-hook.sh not found**: **escalate** — this is a structural problem. Note in digest, don't attempt to create the file.
- **On zero uncategorized entries**: **degrade** — skip template (trigger should prevent this, but handle gracefully). Note "no signal" in digest.
