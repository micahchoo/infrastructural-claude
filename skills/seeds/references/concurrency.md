# Concurrency and Multi-Agent Safety

## Table of Contents
- [How It Works](#how-it-works)
- [Command Safety Levels](#command-safety-levels)
- [Multi-Agent Patterns](#multi-agent-patterns)
- [Health Checks](#health-checks)

---

## How It Works

Seeds uses three mechanisms for safe concurrent access:

### Advisory File Locking

Write commands acquire a `.lock` file (`O_CREAT|O_EXCL`) before modifying JSONL files.

- Retry: 100ms intervals with jitter
- Timeout: 30 seconds
- Stale threshold: locks older than 30 seconds are auto-removed

### Atomic Writes

All mutations:
1. Write to a temporary file under lock
2. Atomically rename into place

A crash mid-write never corrupts the data file.

### Git Merge Strategy and Dedup

`sd init` sets `merge=union` in `.gitattributes` for all JSONL files. Parallel branches merge cleanly without manual conflict resolution. After merges, duplicate issue IDs may appear — seeds resolves this by **last occurrence wins** on read. `sd doctor --fix` can clean up the duplicates on disk.

---

## Command Safety Levels

| Safety Level | Commands | Notes |
|---|---|---|
| **Fully safe** (read-only) | `list`, `show`, `ready`, `blocked`, `stats`, `prime`, `dep list`, `label list`, `label list-all`, `tpl list`, `tpl show`, `tpl status` | No file writes. Any number of agents, any time. |
| **Safe** (locked writes) | `create`, `update`, `close`, `dep add`, `dep remove`, `block`, `unblock`, `label add`, `label remove`, `tpl create`, `tpl step add`, `tpl pour` | Acquire lock before writing. Multiple agents can write concurrently — lock serializes access. |
| **Serialize** (setup ops) | `init`, `onboard` | Modify config or external files. Run once during setup. |

---

## Multi-Agent Patterns

### Same-Worktree Agents

Multiple agents sharing one working directory:

```bash
# Agent A                          # Agent B
sd ready                           sd ready
sd update seeds-a1b2 --status      sd update seeds-c3d4 --status
  in_progress                        in_progress
# ... work ...                     # ... work ...
sd close seeds-a1b2 --reason "..." sd close seeds-c3d4 --reason "..."
sd sync                            sd sync  # coordinate timing
```

Locks ensure data integrity. Both agents can write simultaneously — if they target the same file, one waits for the other (up to 30s).

### Branch-Per-Agent

Each agent in its own worktree/branch:

1. Each agent creates/updates/closes issues in its branch
2. On merge, `merge=union` appends all JSONL lines
3. Dedup-on-read resolves any duplicate IDs
4. `sd doctor --fix` cleans up if needed

### Claiming Work

To avoid two agents grabbing the same issue:

```bash
# Agent claims by setting assignee + status atomically
sd update seeds-a1b2 --status in_progress --assignee "agent-1"
```

With advisory locking, the update is serialized. If two agents race to claim, one will see the issue already in_progress after the other's write completes.

---

## Health Checks

```bash
sd doctor              # Read-only health report
sd doctor --fix        # Auto-fix issues (dedup, schema repair)
```

**When to run `--fix`**:
- After merging branches that both modified issues
- After a crash that may have left partial writes
- When `sd list` shows unexpected duplicates

### Sync Status

```bash
sd sync --status       # Check if .seeds/ has uncommitted changes
sd sync --dry-run      # Preview what would be committed
```
