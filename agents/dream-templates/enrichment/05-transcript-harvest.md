---
name: transcript-harvest
mode: enrichment
layer: L1
trigger: transcripts > 0
priority: 5
---

## What This Checks

Users say "remember this" or give corrections during sessions, but these sometimes don't get saved as memory files. Transcripts are the source of truth for what was discussed. This template greps narrowly for unsaved signal.

## Steps

1. **Grep for explicit remember requests** that may not have been saved:
   ```bash
   grep -rn '"remember\|"don.t forget\|"going forward\|"from now on' \
     ~/.claude/projects/*/memory/../*.jsonl 2>/dev/null | tail -30
   ```

2. **Grep for corrections/feedback patterns**:
   ```bash
   grep -rn '"no,\|"stop doing\|"don.t do\|"instead of\|"not like that' \
     ~/.claude/projects/*/memory/../*.jsonl 2>/dev/null | tail -30
   ```

3. For each finding: **check** if a memory file already captures it by grepping existing memories for key phrases.

4. If not captured: **create** the memory file following the auto-memory format:
   ```markdown
   ---
   name: <topic_slug>
   description: <one-line description>
   type: feedback|user|project|reference
   ---
   <content with absolute dates>
   ```

5. **Update** the project's MEMORY.md index with a pointer to the new file.

## Eval Checkpoints

`[eval: depth]` Extracted non-obvious patterns (corrections, approach changes, repeated failures), not just surface-level tool usage.

`[eval: boundary]` New memories don't duplicate existing ones — checked foxhound/memory search before writing.

## Improvement Writes

- Create memory files for unsaved "remember" requests
- Create feedback memories for uncaptured corrections
- Update MEMORY.md indexes

## Digest Section

```
### Transcript signal
- Transcripts scanned: N | New memories created: N
```

## Recovery

- **On unparseable transcripts** (truncated, corrupt JSONL): **degrade** — skip file, note in digest.
- **On duplicate detection** (proposed memory already exists): **resume** — skip that memory, continue with others. Note dedup count in digest.
