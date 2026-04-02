# Template Format Specification

Every dream template follows this structure:

```markdown
---
name: <kebab-case-name>
mode: enrichment|detect-gaps|integrate
layer: L0|L1|L2|L3|L4|L5|cross
trigger: always|<bash expression against orient variables>
priority: <int, lower runs first within mode>
---

## What This Checks
<one paragraph: what signal this template reads and why it matters>

## Steps
<numbered steps with bash snippets>

## Improvement Writes
<bullet list of what this template changes in the infrastructure>

## Digest Section
<the exact digest block this template contributes>

## Recovery

- **On [specific failure]**: [action — degrade/resume/escalate]
```

**Note:** Templates should include `[eval: category]` checkpoints in or after the Steps section. These are testable assertions about what the template should have achieved. Format: `` `[eval: category]` followed by an assertion ``.

## Trigger Conditions

The router's orient phase sets bash variables. Templates reference them:

| Variable | Source | Example |
|---|---|---|
| `unreviewed_records` | mulch records without outcomes | `unreviewed_records > 0` |
| `uncategorized` | failure journal uncategorized entries | `uncategorized > 0` |
| `memory_files` | total memory files across projects | `memory_files > 5` |
| `stale_memory_files` | memory files unmodified 30+ days | `stale_memory_files > 5` |
| `project_count` | number of project memory dirs | `project_count > 1` |
| `transcripts` | recent transcript files since last run | `transcripts > 0` |
| `closed_seeds` | closed seeds without mulch records | `closed_seeds > 0` |
| `log_errors` | error/timeout lines in hook logs | `log_errors > 0` |
| `history_lines` | lines in history.jsonl | `history_lines > 100` |

`always` means the template runs unconditionally.

## Adding New Templates

1. Create a `.md` file in the appropriate mode directory
2. Use the next available priority number (check existing files)
3. Include all required sections (What This Checks, Steps, Improvement Writes, Digest Section, Recovery) and `[eval:]` checkpoints
4. The router discovers templates automatically — no router changes needed
