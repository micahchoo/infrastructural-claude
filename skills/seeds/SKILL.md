---
name: seeds
description: >-
  Git-native issue tracking with the seeds CLI — JSONL-backed issues that live
  in .seeds/ and are tracked in git. Use this skill whenever working in a
  project with .seeds/, when initializing seeds in a new project, when creating
  or managing issues, when setting up dependencies or blockers between issues,
  when using templates to scaffold recurring work, when finding ready work for
  agents, or when integrating seeds with agent workflows. Also use when the
  user says "seeds", "sd create", "sd list", "sd ready", "issue tracker",
  "create an issue", "what's ready to work on", "block this on", or asks
  about git-native issue tracking for agents. NOT for: GitHub Issues, Jira,
  Linear, or other external issue trackers.
---

# Seeds — Git-Native Issue Tracking

Seeds stores issues as JSONL in `.seeds/issues.jsonl` — one JSON object per line, fully diffable and mergeable via git. Part of the overstory/mulch ecosystem, replacing beads with zero-dependency JSONL storage.

## Decision Framework

| You need to... | Command | Reference |
|---|---|---|
| **Initialize in a project** | `sd init` | [core-workflow](references/core-workflow.md) |
| **Create an issue** | `sd create --title "..." --type task` | [core-workflow](references/core-workflow.md) |
| **Find work to do** | `sd ready` | [core-workflow](references/core-workflow.md) |
| **See all issues** | `sd list` | [core-workflow](references/core-workflow.md) |
| **Update issue status** | `sd update <id> --status in_progress` | [issue-lifecycle](references/issue-lifecycle.md) |
| **Close an issue** | `sd close <id> --reason "..."` | [issue-lifecycle](references/issue-lifecycle.md) |
| **Add a dependency** | `sd dep add <issue> <depends-on>` | [issue-lifecycle](references/issue-lifecycle.md) |
| **Block/unblock** | `sd block <id> --by <blocker>` | [issue-lifecycle](references/issue-lifecycle.md) |
| **Use templates** | `sd tpl create`, `sd tpl pour` | [templates](references/templates.md) |
| **Commit changes** | `sd sync` | [core-workflow](references/core-workflow.md) |
| **Agent context** | `sd prime` | [core-workflow](references/core-workflow.md) |
| **Look up a flag** | See full CLI | [cli-reference](references/cli-reference.md) |

## Agent Workflow

```
┌─ Session Start ──────────────────────────────────┐
│  sd prime                  (load issue context)   │
│  sd ready                  (find unblocked work)  │
└──────────────────────────┬───────────────────────┘
```

`[eval: context-loaded]` sd prime output parsed and sd ready output contains at least one actionable issue ID that the agent can reference by number.

```
                           ▼
┌─ Claim Work ─────────────────────────────────────┐
│  sd update <id> --status in_progress              │
│  sd update <id> --assignee "agent-name"           │
└──────────────────────────┬───────────────────────┘
```

`[eval: task-claimed]` Targeted issue status is `in_progress` and assignee field is set (verified by `sd list --status in_progress` containing the issue ID).

```
                           ▼
┌─ Do the Work ────────────────────────────────────┐
│  (normal development)                             │
│  sd create --title "..." if new issues found      │
│  sd dep add / sd block if blockers discovered     │
└──────────────────────────┬───────────────────────┘
```

`[eval: work-tracked]` Any newly discovered issues were created with `sd create` (verifiable via `sd list` showing new IDs), and any blockers were wired with `sd dep add` or `sd block`.

```
                           ▼
┌─ Complete ───────────────────────────────────────┐
│  sd close <id> --reason "what was done"           │
│  sd sync                  (commit .seeds/)        │
└──────────────────────────────────────────────────┘
```

`[eval: issue-closed]` The claimed issue status is `done` with a `--reason` that describes the outcome (verified by `sd list --status done` containing the issue ID and a non-empty reason string).

## Creating Good Issues

```bash
sd create --title "Add retry logic to mail client" \
  --type task --priority 1 \
  --description "Implement exponential backoff with jitter for transient SMTP failures"
```

```bash
# --- Issue scaffold (fill in blanks) ---
sd create \
  --title "___" \
  --type task \
  --priority 2 \
  --description "___" \
  --labels "___"
```

`[eval: issue-well-formed]` Created issue has all four fields populated: `--title` (concise action phrase), `--type` (task|bug|feature), `--priority` (0-4), and `--description` (specific enough to act on without further clarification).

**Priority scale**:
| Value | Label | Use |
|---|---|---|
| 0 | Critical | System-breaking, drop everything |
| 1 | High | Core functionality |
| 2 | Medium | Default — important but not urgent |
| 3 | Low | Nice-to-have |
| 4 | Backlog | Future consideration |

## Finding Ready Work

`sd ready` returns open issues with no unresolved blockers — the queue of actionable work. This is the primary command agents should use to find their next task.

```bash
sd ready              # All ready issues
sd list --status open # All open (including blocked)
sd blocked            # Only blocked issues
```

## Dependencies and Blockers

Seeds supports two relationship types:

- **Dependencies** (`sd dep`): Issue A depends on Issue B (B must close before A is ready)
- **Blockers** (`sd block`): Issue A is blocked by Issue B (same effect, different semantic — blockers imply an unexpected obstacle)

Both remove the issue from `sd ready` until resolved. See [issue-lifecycle](references/issue-lifecycle.md).

`[eval: dag-consistent]` After adding dependencies or blockers, `sd ready` no longer lists the blocked issue, and `sd blocked` does list it — confirming the dependency graph is wired correctly.

## Templates

For recurring multi-step work (e.g., "onboard a new service", "release checklist"), use templates to scaffold issues with dependencies pre-wired. See [templates](references/templates.md).

## Concurrency

All read commands are safe for parallel use. Write commands use advisory file locking with atomic writes. `merge=union` in gitattributes handles parallel branch merges; dedup-on-read resolves any duplicates. See [concurrency](references/concurrency.md).

