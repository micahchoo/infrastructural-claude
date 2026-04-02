# Issue Lifecycle

## Table of Contents
- [Status Flow](#status-flow)
- [Updating Issues](#updating-issues)
- [Closing Issues](#closing-issues)
- [Dependencies](#dependencies)
- [Blockers](#blockers)
- [Labels](#labels)
- [Priority Scale](#priority-scale)

---

## Status Flow

```
open → in_progress → closed
  ↑                    │
  └────────────────────┘  (reopen by updating status back to open)
```

Issues start as `open`. Move to `in_progress` when claimed, then `closed` when done.

---

## Updating Issues

```bash
sd update seeds-a1b2 --status in_progress
sd update seeds-a1b2 --assignee "agent-1"
sd update seeds-a1b2 --priority 0           # Escalate to critical
sd update seeds-a1b2 --title "Revised title"
sd update seeds-a1b2 --description "Updated description"
```

Multiple fields can be updated in one call:

```bash
sd update seeds-a1b2 --status in_progress --assignee "agent-1"
```

---

## Closing Issues

```bash
sd close seeds-a1b2 --reason "Implemented with exponential backoff in PR #42"
```

Close multiple issues at once:

```bash
sd close seeds-a1b2 seeds-c3d4 --reason "Both resolved by the auth refactor"
```

The `--reason` is optional but strongly recommended — it's the permanent record of what was done.

---

## Dependencies

Dependencies express "A depends on B" — issue A won't appear in `sd ready` until B is closed.

### Add

```bash
sd dep add seeds-a1b2 seeds-c3d4    # a1b2 depends on c3d4
```

### Remove

```bash
sd dep remove seeds-a1b2 seeds-c3d4
```

### List

```bash
sd dep list seeds-a1b2               # Show all deps for this issue
```

### Effect on Ready

When issue B (the dependency) is closed, issue A automatically becomes eligible for `sd ready` (assuming no other unresolved deps or blockers).

---

## Blockers

Blockers are semantically distinct from dependencies — they represent unexpected obstacles rather than planned ordering.

### Block

```bash
sd block seeds-a1b2 --by seeds-c3d4    # a1b2 is blocked by c3d4
```

### Unblock

```bash
sd unblock seeds-a1b2 --from seeds-c3d4   # Remove specific blocker
sd unblock seeds-a1b2 --all               # Clear all blockers
```

### View Blocked Issues

```bash
sd blocked                               # All blocked issues across the project
```

Use **dependencies** when you know upfront that A needs B done first. Use **blockers** when you discover mid-work that something else must happen first. Both remove the issue from `sd ready` until resolved.

---

## Labels

Labels are freeform tags for categorizing issues. Use `sd label add/remove/list` to manage them, `sd label list-all` to see all labels in use, and `sd list --label "urgent"` to filter. See [cli-reference](../references/cli-reference.md) for full syntax.

---

## Priority Scale

Lower number = higher priority (0=critical through 4=backlog). See the priority table in SKILL.md. When `sd ready` returns multiple issues, prefer the lowest priority value.

```bash
sd update seeds-a1b2 --priority 1                      # Escalate to high
```
