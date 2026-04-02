# Concurrency and Multi-Agent Safety

## Table of Contents
- [How Locking Works](#how-locking-works)
- [Command Safety Levels](#command-safety-levels)
- [Swarm Patterns](#swarm-patterns)
- [Batch Recording](#batch-recording)
- [Edge Cases](#edge-cases)

---

## How Locking Works

Mulch uses three mechanisms to ensure safe concurrent access:

### Advisory File Locking

Write commands acquire a `.lock` file (`O_CREAT|O_EXCL`) before modifying any JSONL file.

- Retries every 50ms for up to 5 seconds
- Stale locks (older than 30 seconds) are automatically cleaned up
- Lock is per-file, not global — two agents can write to different domains simultaneously

### Atomic Writes

All JSONL mutations:
1. Write to a temporary file first
2. Atomically rename into place

A crash mid-write never corrupts the expertise file. The worst case is a lost write (the temp file is orphaned), not corruption.

### Git Merge Strategy

`ml init` sets `merge=union` in `.gitattributes` for all `.jsonl` files. This means:
- Parallel branches that both append records merge cleanly
- No manual merge conflict resolution needed for expertise files
- Run `ml doctor --fix` after merge to catch any duplicates

---

## Command Safety Levels

| Safety Level | Commands | Notes |
|---|---|---|
| **Fully safe** (read-only) | `prime`, `query`, `search`, `status`, `validate`, `learn`, `ready` | No file writes. Any number of agents, any time. |
| **Safe** (locked writes) | `record`, `edit`, `delete`, `compact`, `prune`, `doctor` | Acquire per-file lock before writing. Multiple agents can target the same domain — the lock serializes access automatically. |
| **Serialize** (setup ops) | `init`, `add`, `onboard`, `setup` | Modify config or external files (CLAUDE.md, git hooks). Run once during project setup, not during parallel agent work. |

---

## Swarm Patterns

### Same-Worktree Agents

Multiple agents sharing the same working directory (e.g., Claude Code team, parallel CI jobs):

```bash
# Every agent can safely do this in parallel:
ml prime                                    # Read context (safe)
ml record api --type pattern --name "..." --description "..."  # Locked write
ml search "error handling"                  # Read-only (safe)
```

Locks ensure correctness automatically. No coordination needed.

### Multi-Worktree / Branch-Per-Agent

Each agent works in its own git worktree with its own branch:

1. Each agent records normally in its worktree
2. On merge, `merge=union` combines all JSONL lines
3. After merge: `ml doctor --fix` to deduplicate if needed

This is the safest pattern for heavy parallel work — no lock contention at all.

Knowledge flows through git — `ml sync` commits, `git pull` on the next session picks up new expertise. No special synchronization protocol needed.

---

## Batch Recording

For recording multiple records atomically — particularly useful at session end:

```bash
# Array of records from a JSON file
ml record api --batch records.json

# From stdin
echo '[{"type":"convention","content":"Use UTC timestamps"}]' | ml record api --stdin

# Preview first
ml record api --batch records.json --dry-run
```

Batch recording uses file locking — safe for concurrent use. Invalid records are skipped; valid records in the same batch still succeed.

---

## Edge Cases

### Lock Timeout

If a lock cannot be acquired within 5 seconds, the command fails with an error. This means another agent (or process) is holding the lock for an unusually long time.

**What to do**:
1. Check for stuck processes: `ls -la .mulch/expertise/*.lock`
2. Stale locks (>30s old) are auto-cleaned, but you can manually remove: `rm .mulch/expertise/<domain>.jsonl.lock`
3. Retry the command

### ml sync Contention

`ml sync` uses git's own locking for commits. Multiple agents syncing on the same branch will contend on git's ref lock.

**Mitigation**:
- Coordinate sync timing (e.g., sync at end of task, not continuously)
- Use per-agent branches and merge periodically
- Have one agent responsible for syncing

### prime --export Race

Multiple agents exporting to the same file path will race — use unique filenames per agent.

### Corrupt JSONL After Force-Push

`ml doctor --fix` after a force-push resolves most issues. If records are truly lost, they'll need to be re-recorded.
