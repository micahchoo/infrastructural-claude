---
name: memory-blindspots
mode: detect-gaps
layer: L1
trigger: transcripts > 0
priority: 4
---

## What This Checks

Some error patterns and recurring topics bypass the failure journal entirely (tool failures that don't go through Bash, approach changes decided in conversation). Transcripts capture these. Topics discussed repeatedly without a memory file represent a knowledge gap.

## Steps

1. **Grep transcripts** for error patterns the journal missed:
   ```bash
   # Tool failures and approach changes that bypass Bash
   grep -rn '"error\|"failed\|"doesn.t work\|"broke\|"wrong approach' \
     ~/.claude/projects/*/memory/../*.jsonl 2>/dev/null | tail -30
   ```

2. **Compare** transcript errors against failure journal categories — if a pattern appears 3+ times in transcripts but has no journal category, **add one** to `scripts/failure-journal-hook.sh`:
   ```bash
   # Dream-added: <date>
   # Source: transcript blind spot detection
   if echo "$s" | grep -qiE '<pattern>'; then
     category="<name>"; subcategory="<subcategory>"; severity="<level>"; return
   fi
   ```

3. **Check memory coverage** — topics discussed repeatedly in transcripts that have no memory file. Create the memory if the topic is durable (not ephemeral debugging):
   ```markdown
   ---
   name: <topic_slug>
   description: <pattern observed across sessions>
   type: feedback
   ---
   <finding>
   ```

## Eval Checkpoints

`[eval: completeness]` Checked all project memory directories for coverage gaps — not just the most active project.

`[eval: target]` Identified genuinely missing knowledge (decisions made but not recorded, recurring questions without answers), not just suggested more memory files for completeness's sake.

## Improvement Writes

- Add failure-journal categories for transcript-only error patterns
- Create memory files for recurring undocumented topics

## Digest Section

```
### Memory blind spots
- Transcript patterns → new journal categories: N
- Recurring topics → new memory files: N
```

## Recovery

- **On projects with no memory directory**: **degrade** — skip project, note as "no memory dir" in digest (this is itself a blindspot finding).
- **On uncertain gaps** (unclear if knowledge is missing or just not needed): **degrade** — note as "potential gap" rather than creating speculative memory files.
