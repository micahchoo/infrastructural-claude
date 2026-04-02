# CLI Reference

## Table of Contents
- [Global Flags](#global-flags)
- [Initialization and Setup](#initialization-and-setup)
- [Issue Management](#issue-management)
- [Dependencies and Blockers](#dependencies-and-blockers)
- [Labels](#labels)
- [Templates](#templates)
- [Agent Integration](#agent-integration)
- [Health and Utility](#health-and-utility)

---

## Global Flags

Available on all commands:

| Flag | Description |
|---|---|
| `-v`, `--version` | Show version |
| `-q`, `--quiet` | Suppress non-essential output |
| `--verbose` | Extra detail |
| `--timing` | Show execution time |
| `--json` | Machine-readable JSON output |

ANSI colors respect `NO_COLOR`.

---

## Initialization and Setup

### sd init

Initialize `.seeds/` in the current project.

```bash
sd init
```

### sd onboard

Add seeds section to CLAUDE.md / AGENTS.md.

```bash
sd onboard
```

---

## Issue Management

### sd create --title \<text\>

Create a new issue.

```bash
sd create --title "Add retry logic"
sd create --title "Fix auth crash" --type bug --priority 0
sd create --title "Add dark mode" --type feature --priority 3 \
  --description "Support system preference detection" \
  --assignee "agent-1"
```

| Flag | Description |
|---|---|
| `--title` | Issue title (required) |
| `--type` | `task`, `bug`, `feature`, `chore` |
| `--priority` | 0-4 (0=critical, 4=backlog) |
| `--description` | Detailed description |
| `--assignee` | Who owns this issue |

### sd show \<id\>

Show full issue details.

```bash
sd show seeds-a1b2
```

### sd list

List issues with filters.

```bash
sd list
sd list --status open
sd list --status in_progress
sd list --status closed
sd list --type bug
sd list --assignee "agent-1"
sd list --label "urgent"
sd list --limit 10
sd list --all              # Include closed
```

### sd ready

Open issues with no unresolved blockers or dependencies.

```bash
sd ready
```

### sd update \<id\>

Update issue fields.

```bash
sd update seeds-a1b2 --status in_progress
sd update seeds-a1b2 --title "New title"
sd update seeds-a1b2 --priority 1
sd update seeds-a1b2 --assignee "agent-2"
sd update seeds-a1b2 --description "Updated description"
```

### sd close \<id\> \[id2...\]

Close one or more issues.

```bash
sd close seeds-a1b2 --reason "Implemented in PR #42"
sd close seeds-a1b2 seeds-c3d4 --reason "Both fixed by auth refactor"
```

| Flag | Description |
|---|---|
| `--reason` | Why the issue was closed (recommended) |

### sd blocked

Show all blocked issues.

```bash
sd blocked
```

### sd stats

Project statistics.

```bash
sd stats
sd stats --json
```

---

## Dependencies and Blockers

### sd dep add \<issue\> \<depends-on\>

```bash
sd dep add seeds-a1b2 seeds-c3d4    # a1b2 depends on c3d4
```

### sd dep remove \<issue\> \<depends-on\>

```bash
sd dep remove seeds-a1b2 seeds-c3d4
```

### sd dep list \<issue\>

```bash
sd dep list seeds-a1b2
```

### sd block \<id\> --by \<blocker-id\>

```bash
sd block seeds-a1b2 --by seeds-c3d4
```

### sd unblock \<id\>

```bash
sd unblock seeds-a1b2 --from seeds-c3d4
sd unblock seeds-a1b2 --all
```

---

## Labels

### sd label add \<id\> \<label\>

```bash
sd label add seeds-a1b2 "urgent"
```

### sd label remove \<id\> \<label\>

```bash
sd label remove seeds-a1b2 "urgent"
```

### sd label list \<id\>

```bash
sd label list seeds-a1b2
```

### sd label list-all

```bash
sd label list-all
```

---

## Templates

### sd tpl create --name \<text\>

```bash
sd tpl create --name "Release Checklist"
```

### sd tpl step add \<id\> --title \<text\>

```bash
sd tpl step add tpl-a1b2 --title "{prefix}: Run tests"
```

### sd tpl list

```bash
sd tpl list
```

### sd tpl show \<id\>

```bash
sd tpl show tpl-a1b2
```

### sd tpl pour \<id\> --prefix \<text\>

Instantiate template into issues with dependencies.

```bash
sd tpl pour tpl-a1b2 --prefix "v2.1"
```

### sd tpl status \<id\>

Show convoy completion status.

```bash
sd tpl status tpl-a1b2
```

---

## Agent Integration

### sd prime

Output AI agent context.

```bash
sd prime
sd prime --compact
```

---

## Health and Utility

### sd doctor

```bash
sd doctor              # Read-only health check
sd doctor --fix        # Auto-fix (dedup, schema repair)
```

### sd sync

Stage and commit `.seeds/` changes.

```bash
sd sync
sd sync --dry-run
sd sync --status
```

### sd upgrade

```bash
sd upgrade             # Upgrade to latest
sd upgrade --check     # Check for updates (dry run)
```

### sd completions \<shell\>

```bash
sd completions bash
sd completions zsh
sd completions fish
```

### sd migrate-from-beads

Import `.beads/issues.jsonl` into `.seeds/`.

```bash
sd migrate-from-beads
```
