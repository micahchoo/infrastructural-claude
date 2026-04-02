# Maintenance and Hygiene

## Table of Contents
- [Health Monitoring](#health-monitoring)
- [Validation](#validation)
- [Compaction](#compaction)
- [Pruning](#pruning)
- [Reviewing Changes](#reviewing-changes)
- [Recently Added Records](#recently-added-records)
- [Editing and Deleting](#editing-and-deleting)
- [Maintenance Schedule](#maintenance-schedule)

---

## Health Monitoring

### Status

Quick overview of expertise freshness and domain health:

```bash
ml status                  # Human-readable summary
ml status --json           # Machine-readable health metrics
```

Shows per-domain record counts, last-updated timestamps, and freshness indicators. Use this to spot neglected domains or domains that are growing too large.

### Doctor

Deeper health checks with optional auto-fix:

```bash
ml doctor                  # Read-only: report issues
ml doctor --fix            # Auto-fix: deduplicate, repair schema issues
```

**When to run `--fix`**:
- After merging branches that both added records (deduplication)
- After a crash that may have left partial writes
- When `ml validate` reports schema errors

Doctor checks for:
- Duplicate records (same content, different IDs)
- Schema violations
- Orphaned `relates-to` / `supersedes` references
- Records with invalid classification values
- Stale lock files

---

## Validation

Schema validation across all expertise files:

```bash
ml validate                # Reports any schema violations
```

Checks every JSONL line against the record schema (via Ajv). Reports:
- Missing required fields for a record type
- Invalid field values
- Malformed JSON lines
- Unknown record types

Run after manual edits to `.jsonl` files or after `ml doctor --fix` to confirm everything is clean.

---

## Compaction

As domains accumulate records, some become redundant — superseded patterns, duplicate conventions, failures that were resolved and re-recorded. Compaction identifies and consolidates these.

### Analyze (read-only)

```bash
ml compact --analyze                # All domains
ml compact database --analyze       # Specific domain
```

Shows groups of records that could be compacted: near-duplicates, superseded chains, records that could merge. Review before applying.

### Auto Compact

```bash
ml compact --auto                   # Apply safe automatic compactions
ml compact --auto --dry-run         # Preview what would change
ml compact --auto --min-group 3     # Only compact groups of 3+ similar records
ml compact --auto --max-records 100 # Limit how many records are processed
```

Auto-compact merges obvious duplicates and removes superseded records. It's conservative — when in doubt, it leaves records alone.

### Apply Specific Compaction

```bash
ml compact --apply <compaction-id>  # Apply a specific compaction from --analyze output
ml compact --apply <id> --dry-run   # Preview first
```

---

## Pruning

Removes stale records based on classification tier and age:

```bash
ml prune                   # Interactive: shows what would be removed, asks for confirmation
ml prune --dry-run         # Preview only, no changes
```

**Pruning order**:
1. `observational` records older than their shelf life (weeks)
2. `tactical` records older than their shelf life (months)
3. `foundational` records are **never** auto-pruned

Records with recent outcomes or high confirmation scores resist pruning — the system recognizes they're still actively useful even if old.

**When to prune**:
- Quarterly, or when `ml status` shows many stale records
- After a major refactor that invalidated old patterns
- When `ml prime` output feels noisy with irrelevant records

---

## Reviewing Changes

### Diff Between Git Refs

See what expertise changed between commits or branches:

```bash
ml diff HEAD~3             # Changes in last 3 commits
ml diff main..feature      # Changes between branches
ml diff v1.0..v2.0         # Changes between tags
```

Shows added, modified, and removed records per domain. Useful for:
- Code review: understanding what expertise a PR adds
- Post-merge: verifying expertise from parallel branches merged cleanly
- Release notes: summarizing what the team learned this cycle

---

## Recently Added Records

See what was recently recorded:

```bash
ml ready                   # Default: recent records
ml ready --since "3 days"  # Records from the last 3 days
ml ready --domain api      # Only API domain
ml ready --limit 10        # Cap output
```

Useful at session start to see what other agents (or you in prior sessions) recorded recently.

---

## Editing and Deleting

### Edit

Modify an existing record by ID or 1-based index:

```bash
ml edit database mx-abc123           # By record ID
ml edit database 3                   # By 1-based index (3rd record)
```

Opens the record for editing. Common edits:
- Promoting classification (`tactical` → `foundational`)
- Updating a resolution after learning more
- Adding evidence flags retroactively
- Fixing typos or clarifying descriptions

### Delete

Remove records:

```bash
ml delete database mx-abc123         # Delete specific record
ml delete database --records mx-abc123,mx-def456   # Delete multiple
ml delete database --all-except mx-abc123,mx-def456  # Keep only these
ml delete database --dry-run mx-abc123   # Preview
```

**Prefer `--supersedes` over delete** when a record is being replaced — this preserves history and the link between old and new knowledge.

---

## Maintenance Schedule

| Frequency | Action | Command |
|---|---|---|
| **Every session** | Check recent additions | `ml ready` |
| **Every few sessions** | Check domain health | `ml status` |
| **After branch merges** | Deduplicate | `ml doctor --fix` |
| **When domains feel bloated** | Analyze compaction | `ml compact --analyze` |
| **Monthly** | Prune stale records | `ml prune` |
| **After major refactors** | Validate schema | `ml validate` |
| **During PR review** | Review expertise changes | `ml diff main..HEAD` |

### Signs a Domain Needs Attention

- **`ml status` shows 0 updates in weeks**: Domain may be abandoned or its concern absorbed elsewhere
- **`ml prime` output is noisy**: Too many low-value records — run `ml compact --analyze` and `ml prune --dry-run`
- **`ml doctor` reports issues**: Schema violations or orphaned references — run `ml doctor --fix`
- **Many records with `failure` outcomes**: The domain's conventions/patterns may need revision, not just more records
