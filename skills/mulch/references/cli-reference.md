# CLI Reference

## Table of Contents
- [Global Flags](#global-flags)
- [Initialization and Setup](#initialization-and-setup)
- [Reading Expertise](#reading-expertise)
- [Writing Expertise](#writing-expertise)
- [Outcome Tracking](#outcome-tracking)
- [Maintenance](#maintenance)
- [Utility](#utility)

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

ANSI colors respect the `NO_COLOR` environment variable.

---

## Initialization and Setup

### ml init

Initialize `.mulch/` in the current project.

```bash
ml init
```

Creates: `mulch.config.yaml`, `expertise/` directory, `.gitattributes` entry (`merge=union`).

### ml add \<domain\>

Add a new expertise domain.

```bash
ml add database
ml add api
```

Creates: `.mulch/expertise/<domain>.jsonl`

### ml setup \[provider\]

Install provider-specific hooks.

```bash
ml setup claude            # Claude Code
ml setup cursor            # Cursor
ml setup codex             # Codex
ml setup gemini            # Gemini
ml setup windsurf          # Windsurf
ml setup aider             # Aider
```

### ml onboard

Generate a CLAUDE.md or AGENTS.md snippet for this project.

```bash
ml onboard
```

---

## Reading Expertise

### ml prime \[domains...\]

Output AI-optimized expertise context.

```bash
ml prime                   # All domains
ml prime database api      # Specific domains
ml prime --files src/a.rs src/b.rs  # File-specific records
ml prime --budget 2000     # Token budget limit
ml prime --no-limit        # No budget cap
ml prime --context "doing X"  # Context hint for prioritization
ml prime --exclude-domain legacy  # Skip a domain
ml prime --format xml      # XML output (default: markdown)
ml prime --export file.md  # Write to file
```

### ml query \[domain\]

Query expertise records.

```bash
ml query                   # All domains
ml query database          # Specific domain
ml query --all             # All records, all domains
ml query database --classification foundational
ml query database --file "src/db/"
ml query database --outcome-status success
ml query database --sort-by-score
ml query database --format json
```

### ml search \[query\]

Search records across domains with BM25 ranking.

```bash
ml search "migration strategy"
ml search "auth" --domain api
ml search "error" --type failure
ml search "deploy" --tag "production"
ml search "schema" --classification foundational
ml search "cache" --file "src/cache/"
ml search "retry" --sort-by-score
ml search "api" --format json
```

### ml learn

Show changed files and suggest domains for recording.

```bash
ml learn
```

Read-only. No file writes. Use at end of task to identify what's worth recording.

### ml ready

Show recently added or updated records.

```bash
ml ready
ml ready --since "3 days"
ml ready --domain api
ml ready --limit 10
```

---

## Writing Expertise

### ml record \<domain\> --type \<type\>

Record a new expertise entry.

See [record-types](../references/record-types.md) for type-specific required fields and examples.

**Common flags for all record types:**

| Flag | Description |
|---|---|
| `--classification <tier>` | `foundational`, `tactical`, or `observational` |
| `--tags "a,b,c"` | Comma-separated tags |
| `--relates-to "domain:mx-hash"` | Link to related record |
| `--supersedes "domain:mx-hash"` | Replace an older record |
| `--evidence-file "path"` | Anchor to a file |
| `--evidence-commit "hash"` | Anchor to a commit |
| `--evidence-issue "url"` | Anchor to an issue |
| `--evidence-bead "..."` | Custom evidence |
| `--force` | Skip duplicate detection |
| `--dry-run` | Preview without writing |

**Batch recording:**

```bash
ml record <domain> --batch file.json    # From JSON file
ml record <domain> --stdin              # From stdin
ml record <domain> --batch file.json --dry-run  # Preview
```

### ml edit \<domain\> \<id\>

Edit an existing record by ID or 1-based index.

```bash
ml edit database mx-abc123
ml edit database 3         # 3rd record in domain
```

### ml delete \<domain\> \[id\]

Delete records.

```bash
ml delete database mx-abc123
ml delete database --records mx-abc123,mx-def456
ml delete database --all-except mx-abc123
ml delete database mx-abc123 --dry-run
```

---

## Outcome Tracking

### ml outcome \<domain\> \<id\>

Append an outcome to a record or view existing outcomes.

**Record an outcome:**
```bash
ml outcome api mx-abc123 --status success --notes "Worked in PR #42"
ml outcome api mx-abc123 --status failure --notes "Caused regression"
ml outcome api mx-abc123 --status success --duration "2h" --agent "claude-opus"
```

**View outcomes:**
```bash
ml outcome api mx-abc123   # No --status flag = view mode
```

---

## Maintenance

### ml status

Show expertise freshness and domain health.

```bash
ml status
ml status --json
```

### ml doctor

Run health checks.

```bash
ml doctor                  # Read-only report
ml doctor --fix            # Auto-fix issues
```

### ml validate

Schema validation across all files.

```bash
ml validate
```

### ml compact \[domain\]

Analyze and apply compactions.

```bash
ml compact --analyze                # Read-only analysis
ml compact database --analyze       # Specific domain
ml compact --auto                   # Apply safe compactions
ml compact --auto --dry-run         # Preview
ml compact --auto --min-group 3     # Minimum group size
ml compact --auto --max-records 100 # Limit records processed
ml compact --apply <id>             # Apply specific compaction
ml compact --apply <id> --dry-run   # Preview specific
```

### ml prune

Remove stale tactical/observational entries.

```bash
ml prune                   # Interactive
ml prune --dry-run         # Preview only
```

### ml diff \[ref\]

Show expertise changes between git refs.

```bash
ml diff HEAD~3
ml diff main..feature
ml diff v1.0..v2.0
```

### ml sync

Validate, stage, and commit `.mulch/` changes.

```bash
ml sync
```

---

## Utility

### ml upgrade

Upgrade mulch to the latest version.

```bash
ml upgrade                 # Upgrade
ml upgrade --check         # Dry run — just check for updates
```

### ml completions \<shell\>

Output shell completion script.

```bash
ml completions bash
ml completions zsh
ml completions fish
```
