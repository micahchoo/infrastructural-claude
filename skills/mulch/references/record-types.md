# Record Types, Classification, and Metadata

## Table of Contents
- [The Six Record Types](#the-six-record-types)
- [Classification Tiers](#classification-tiers)
- [Evidence Flags](#evidence-flags)
- [Linking Records](#linking-records)
- [Outcome Tracking](#outcome-tracking)
- [Choosing the Right Type — Decision Tree](#choosing-the-right-type--decision-tree)

---

## The Six Record Types

### convention

A standing rule — "always do X" or "never do Y".

| Field | Required | Description |
|---|---|---|
| `content` | Yes | The convention text |

```bash
ml record api --type convention "All error responses must include a machine-readable error code"
ml record database --type convention "Use WAL mode for all SQLite connections"
```

Best for: coding standards, naming conventions, configuration rules, process requirements.

### pattern

A named, reusable approach to a recurring problem.

| Field | Required | Description |
|---|---|---|
| `--name` | Yes | Pattern name |
| `--description` | Yes | What the pattern does and when to use it |

```bash
ml record api --type pattern \
  --name "Pagination Cursor" \
  --description "Use cursor-based pagination for list endpoints. Encode the cursor as an opaque base64 token containing the sort key and ID."
```

Best for: design patterns, architectural approaches, named strategies that recur across the codebase.

### failure

Something that went wrong, paired with how to prevent it.

| Field | Required | Description |
|---|---|---|
| `--description` | Yes | What happened |
| `--resolution` | Yes | How to avoid or fix it |

```bash
ml record database --type failure \
  --description "VACUUM inside a transaction causes silent data corruption" \
  --resolution "Always run VACUUM outside transaction boundaries; add a lint rule to catch this"
```

Best for: bugs that could recur, gotchas, footguns, post-incident learnings.

### decision

An architectural or design choice with its rationale.

| Field | Required | Description |
|---|---|---|
| `--title` | Yes | The decision |
| `--rationale` | Yes | Why this choice was made |

```bash
ml record database --type decision \
  --title "SQLite over PostgreSQL" \
  --rationale "Local-only product with no network dependency acceptable. SQLite's single-writer model is fine for our concurrency profile."
```

Best for: technology choices, architecture decisions, trade-off resolutions. These are the records most likely to be `foundational` classification.

### reference

A pointer to a key file, endpoint, resource, or external system.

| Field | Required | Description |
|---|---|---|
| `--name` | Yes | What's being referenced |
| `--description` | Yes | Where it is and what it does |

```bash
ml record api --type reference \
  --name "Auth Middleware" \
  --description "JWT validation in src/middleware/auth.rs — handles access tokens, refresh tokens, and API key fallback"
```

Best for: important files, API endpoints, external service locations, configuration files. Note: these can become stale — use `observational` or `tactical` classification and re-validate periodically.

### guide

A step-by-step procedure for a recurring task.

| Field | Required | Description |
|---|---|---|
| `--name` | Yes | Guide name |
| `--description` | Yes | The procedure steps |

```bash
ml record deploy --type guide \
  --name "Production Rollback" \
  --description "1. Pause load balancer health checks\n2. Revert to previous container image\n3. Run smoke tests against staging\n4. Resume health checks\n5. Record outcome with ml outcome"
```

Best for: deployment procedures, debugging playbooks, onboarding steps, maintenance runbooks.

---

## Classification Tiers

Every record has a classification that governs its shelf life and pruning priority.

| Tier | Shelf Life | Use When |
|---|---|---|
| `foundational` | Indefinite | Architectural truths, core conventions, decisions unlikely to change |
| `tactical` | Months | Current-sprint relevant, specific approaches, active patterns |
| `observational` | Weeks | Temporary workarounds, speculative patterns, things to verify |

```bash
ml record api --type convention --classification foundational "REST endpoints use kebab-case paths"
ml record api --type pattern --classification tactical --name "Rate Limit Retry" --description "..."
ml record api --type failure --classification observational --description "..." --resolution "..."
```

**Default**: If omitted, mulch assigns a default based on record type. Decisions and conventions default to `foundational`. Patterns default to `tactical`. Failures and references default to `tactical`.

**Pruning impact**: `ml prune` removes stale `observational` records first, then old `tactical` records. `foundational` records are never auto-pruned.

### Promotion and Demotion

As records prove their value (via outcomes), consider promoting them:

```bash
ml edit <domain> <id>      # Opens the record for editing — change classification
```

A `tactical` pattern that has been confirmed successful 3+ times deserves `foundational`. An `observational` failure that keeps recurring should become `tactical` or `foundational`.

---

## Evidence Flags

Anchor records to specific code, commits, or issues to make them verifiable:

```bash
--evidence-file "src/handlers/sync.rs"          # File path
--evidence-commit "abc1234"                      # Git commit hash
--evidence-issue "https://github.com/org/repo/issues/42"  # Issue URL
--evidence-bead "..."                            # Evidence bead (custom)
```

Evidence flags help future agents verify whether a record is still relevant. A failure record with `--evidence-file` can be checked: does that file still exist? Has it changed since the record was written?

```bash
# Full example with evidence
ml record api --type failure \
  --description "Double-encoding query params in the search endpoint" \
  --resolution "Use url::form_urlencoded for all query string construction" \
  --evidence-file "src/handlers/search.rs" \
  --evidence-commit "d4e5f6a" \
  --classification tactical \
  --tags "encoding,url,search"
```

---

## Linking Records

### relates-to

Connect related records across domains:

```bash
ml record api --type pattern \
  --name "Auth Token Refresh" \
  --description "..." \
  --relates-to "database:mx-abc123"
```

The format is `domain:mx-hash`. Find record IDs with `ml query <domain> --format json`.

### supersedes

When a new record replaces an old one:

```bash
ml record api --type decision \
  --title "JWT over Session Cookies" \
  --rationale "Mobile clients can't maintain cookie jars reliably" \
  --supersedes "api:mx-old456"
```

The superseded record is kept for history but deprioritized in `ml prime` output.

---

## Outcome Tracking

Outcomes close the feedback round. After applying a recorded decision, pattern, or convention, track whether it worked:

### Recording an Outcome

```bash
# Success
ml outcome api mx-abc123 --status success --notes "Applied in PR #42, handled 10K concurrent users"

# Failure
ml outcome api mx-abc123 --status failure --notes "Caused memory leak under sustained load"

# With metadata
ml outcome api mx-abc123 --status success --duration "2h" --agent "claude-opus"
```

### Viewing Outcomes

```bash
ml outcome api mx-abc123   # View all outcomes for this record (no --status flag)
```

### Confirmation Scores

Records accumulate a confirmation score based on outcomes:
- Each `success` outcome increases the score
- Each `failure` outcome decreases it
- `ml prime` and `ml search --sort-by-score` use this score to prioritize

High-score records are surfaced first during priming. Low-score records signal that a convention or pattern may need revision — consider editing or superseding them.

### Success Rate

```bash
ml query api --outcome-status success   # Only records with successful outcomes
ml query api --outcome-status failure   # Only records with failed outcomes
ml query api --sort-by-score            # Ordered by confirmation score
```

---

## Choosing the Right Type — Decision Tree

```
Is this about what to always/never do?
  → Yes: convention

Is this a named approach you'd apply again?
  → Yes: pattern

Did something break?
  → Yes: failure (include --resolution)

Did you choose between alternatives?
  → Yes: decision (include --rationale)

Is this a pointer to where something lives?
  → Yes: reference

Is this a multi-step procedure?
  → Yes: guide
```

When in doubt:
- If it has a "because" → `decision`
- If it has a "don't" → `convention` or `failure`
- If it has steps → `guide`
- If you'd name it → `pattern`
