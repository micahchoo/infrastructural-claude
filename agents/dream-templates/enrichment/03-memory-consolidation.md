---
name: memory-consolidation
mode: enrichment
layer: L1
trigger: always
priority: 3
---

## What This Checks

Memory files (`~/.claude/projects/*/memory/*.md`) drift over time. Referenced files get deleted. Relative dates become meaningless. Redundant memories accumulate across projects. MEMORY.md indexes grow past the 200-line truncation limit.

## Steps

**Note:** The dream-agent runs a shared memory scan during orient. Read `/tmp/dream-memory-scan.json` for the file list instead of re-scanning project dirs.

1. **Read** all memory files across all project dirs:
   ```bash
   for dir in ~/.claude/projects/*/memory/; do
     project=$(basename "$(dirname "$dir")")
     for f in "$dir"*.md; do
       [ -f "$f" ] && [ "$(basename "$f")" != "MEMORY.md" ] && \
         echo "=== $project: $(basename "$f") ===" && cat "$f"
     done
   done
   ```

2. **Merge** redundant memory files — same topic split across files or projects → consolidate into one.

3. **Fix drifted facts** — if a memory references a file, function, or flag, verify it still exists:
   ```bash
   # For each claimed file path
   test -f "<path>" || echo "DRIFT: <path> no longer exists"
   # For each claimed function/flag
   grep -r "<name>" ~/.claude/ --include="*.sh" --include="*.md" -l || echo "DRIFT: <name> not found"
   ```
   Update or remove memories with drifted references.

4. **Convert relative dates** — scan for "yesterday", "last week", "recently", "today" and replace with absolute dates:
   ```bash
   git log -1 --format='%ai' -- "<memory-file-path>"
   ```

5. **Prune MEMORY.md index** — for each project's `MEMORY.md`:
   - Remove pointers to deleted or superseded memory files
   - Add pointers to new memory files that lack index entries
   - Keep total under 200 lines (the truncation limit)
   - Index entries should be one-line links with brief descriptions, not content

## Eval Checkpoints

`[eval: completeness]` Every project memory directory was included in the scan.

`[eval: execution]` Merged memories resulted in actual file consolidation (files written/deleted), not just notes about what could be merged.

`[eval: resilience]` Empty project memory directories and projects with only MEMORY.md were handled gracefully (skipped, not errored).

## Improvement Writes

- Merge redundant memory files (delete duplicates)
- Update or remove memories with drifted references
- Replace relative dates with absolute dates
- Prune MEMORY.md indexes

## Digest Section

```
### Memory files
- Files reviewed: N across M projects
- Merged: N | Drifted facts fixed: N | Dates converted: N
- Index entries pruned/added: N
```

## Recovery

- **On conflicting memories** (same topic, different facts across projects): **escalate** — note conflict in digest, don't auto-merge. Write both versions with a `CONFLICT:` prefix for user review.
- **On unreadable files** (permissions, encoding): **degrade** — skip file, note in digest.
- **On MEMORY.md over 200 lines after updates**: **degrade** — truncate index entries for superseded/completed projects first.
