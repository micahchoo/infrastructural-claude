# Core Workflow

## Table of Contents
- [Initialization](#initialization)
- [Creating Issues](#creating-issues)
- [Listing and Searching](#listing-and-searching)
- [Finding Ready Work](#finding-ready-work)
- [Agent Context — Prime](#agent-context--prime)
- [Syncing to Git](#syncing-to-git)
- [Project Statistics](#project-statistics)
- [CLAUDE.md Integration](#claudemd-integration)

---

## Initialization

```bash
sd init
```

Creates:
- `.seeds/config.yaml` — project name and version
- `.seeds/issues.jsonl` — issue storage
- `.seeds/templates.jsonl` — template storage
- `.seeds/.gitignore` — ignores `*.lock` files
- `.gitattributes` entries — `merge=union` for JSONL files

Run once per project. This is a serialize-level operation — don't run while other agents are actively writing.

---

## Creating Issues

### Basic

```bash
sd create --title "Add retry logic to mail client"
```

### With All Fields

```bash
sd create \
  --title "Add retry logic to mail client" \
  --type task \
  --priority 1 \
  --description "Implement exponential backoff with jitter for transient SMTP failures" \
  --assignee "agent-1"
```

### Issue Types

- `task` — work to be done (default)
- `bug` — something broken
- `feature` — new functionality
- `chore` — maintenance, cleanup

### ID Format

Issues get auto-generated IDs in the format `<project>-<hash>` (e.g., `seeds-a1b2`). The project prefix comes from `config.yaml`.

---

## Listing and Searching

### List All Open Issues

```bash
sd list                    # Open issues (default)
sd list --all              # All issues including closed
```

### Filter

```bash
sd list --status open
sd list --status in_progress
sd list --status closed
sd list --type bug
sd list --assignee "agent-1"
sd list --label "urgent"
sd list --limit 10
```

### Show Issue Details

```bash
sd show seeds-a1b2         # Full details including deps, blockers, labels
```

---

## Finding Ready Work

The most important command for agent workflows:

```bash
sd ready
```

Returns open issues with **no unresolved blockers or dependencies**. This is the work queue — issues that can actually be started right now.

See the agent workflow diagram in SKILL.md for the full find → claim → work → close cycle.

---

## Agent Context — Prime

Load issue context for the current session:

```bash
sd prime                   # Full context
sd prime --compact         # Condensed output
```

Outputs a summary of open issues, their priorities, dependencies, and blockers — designed for injection into agent context at session start.

---

## Syncing to Git

```bash
sd sync                    # Stage and commit .seeds/ changes
sd sync --dry-run          # Preview what would be committed
sd sync --status           # Show sync status (dirty/clean)
```

`sd sync` validates the data, stages all `.seeds/` files, and creates a commit. Uses git's own locking — coordinate timing if multiple agents sync on the same branch.

---

## Project Statistics

```bash
sd stats                   # Human-readable project summary
sd stats --json            # Machine-readable
```

Shows counts by status, type, priority, and assignee.

---

## CLAUDE.md Integration

Generate a ready-to-paste section:

```bash
sd onboard
```

Run `sd onboard` to generate a ready-to-paste snippet tailored to this project.
