---
name: cross-project-memory
mode: integrate
layer: L1
trigger: project_count > 1
priority: 1
---

## What This Checks

Knowledge stays siloed in project-specific memory directories. The same failure may be solved in project A while project B still hits it. Duplicated memories waste index space and risk contradictions.

## Steps

**Note:** The dream-agent runs a shared memory scan during orient. Read `/tmp/dream-memory-scan.json` for the file list instead of re-scanning project dirs.

1. **Discover** all project memory directories and read every memory file:
   ```bash
   for dir in ~/.claude/projects/*/memory/; do
     project=$(basename "$(dirname "$dir")")
     echo "=== PROJECT: $project ==="
     for f in "$dir"*.md; do
       [ -f "$f" ] && [ "$(basename "$f")" != "MEMORY.md" ] && \
         echo "--- $(basename "$f") ---" && cat "$f"
     done
   done
   ```

2. **Compare** across projects: same failures, same workarounds, same feedback?

3. **Surface** transferable solutions: if project A solved X and project B still has X, write that finding to both projects.

4. **Deduplicate** — same memory in multiple projects → consolidate into a single authoritative version in the global memory dir, remove project duplicates.

5. **Write** cross-project memory files for findings:
   ```markdown
   ---
   name: cross_<slug>
   description: <pattern found across projects A and B>
   type: feedback
   ---
   <finding and recommendation>
   **Source projects:** A, B
   **Evidence:** mulch records <ids>
   ```

## Eval Checkpoints

`[eval: completeness]` All project memory directories were scanned for transferable patterns — not just the two most recent.

`[eval: execution]` Cross-project memories were actually written as files, not just identified in the digest.

`[eval: boundary]` Didn't modify project-specific memories without justification — cross-project findings go in global memory or both projects, not overwrite one project's version.

## Improvement Writes

- Write cross-project memory files
- Remove duplicated memories from project dirs
- Transfer solutions between projects

## Digest Section

```
### Cross-project
- Projects scanned: N | Patterns found: N
- Cross-project memories written: N | Duplicates consolidated: N
- Solutions transferred: N
```

## Recovery

- **On conflicting patterns across projects** (project A says "always X", project B says "never X"): **escalate** — write both versions with context, flag for user resolution. Don't auto-resolve contradictions.
- **On single-project patterns** (found in only one project, no cross-project signal): **degrade** — skip. Integration requires ≥2 projects as evidence.
- **On shared memory scan missing** (/tmp/dream-memory-scan.json absent): **resume** — fall back to inline directory scan.
