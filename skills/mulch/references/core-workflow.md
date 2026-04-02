# Core Workflow

## Table of Contents
- [Initialization](#initialization)
- [Priming — Loading Context](#priming--loading-context)
- [Searching — Before Choosing an Approach](#searching--before-choosing-an-approach)
- [Recording — Writing Learnings](#recording--writing-learnings)
- [CLAUDE.md / AGENTS.md Integration](#claudemd--agentsmd-integration)
- [Domain Design Principles](#domain-design-principles)

---

## Initialization

When entering a project without `.mulch/`:

```bash
ml init                    # Creates .mulch/ with mulch.config.yaml and expertise/
```

This also sets `merge=union` in `.gitattributes` so parallel branches append-merge JSONL lines without conflicts.

### Adding Domains

```bash
ml add database            # Creates .mulch/expertise/database.jsonl
ml add api
ml add frontend
ml add testing
```

See [Domain Design Principles](#domain-design-principles) for how to choose domains.

### Provider Setup

```bash
ml setup claude            # Install Claude Code-specific hooks
ml setup cursor            # Or: cursor, codex, gemini, windsurf, aider
```

This installs provider-specific hooks that integrate mulch into the agent's workflow automatically.

### Generating Onboarding Snippets

```bash
ml onboard                 # Generates a CLAUDE.md or AGENTS.md snippet
```

This produces a ready-to-paste section that tells agents how to use mulch in this project. Review and customize the output before adding it to your project's instruction file.

---

## Priming — Loading Context

Priming loads accumulated expertise into the agent's context at the start of a session.

### Full Prime

```bash
ml prime                   # All domains, respects default token budget
ml prime --no-limit        # All domains, no budget cap
ml prime --budget 2000     # Limit output to ~2000 tokens
```

`ml prime` outputs AI-optimized markdown (or XML with `--format xml`) organized by domain and record type. It prioritizes records by confirmation score — records with successful outcomes float to the top.

### Domain-Specific Prime

```bash
ml prime database          # Only database domain
ml prime api testing       # Multiple specific domains
ml prime --exclude-domain legacy  # Everything except legacy
```

### File-Specific Prime

When touching unfamiliar files, prime with file paths to get records that reference those files:

```bash
ml prime --files src/handlers/sync.rs src/models/user.rs
```

This filters across all domains for records whose `--evidence-file` or file references match the given paths.

### Context-Aware Prime

```bash
ml prime --context "migrating the auth middleware to JWT"
```

Adds a context hint that influences which records get prioritized.

### Export

```bash
ml prime --export context.md    # Write to file instead of stdout
```

Useful for injecting into other tools or saving a snapshot. Note: multiple agents exporting to the same file path will race — use unique filenames per agent.

---

## Searching — Before Choosing an Approach

Before committing to an approach, search for prior decisions, conventions, or failures:

```bash
ml search "database migration strategy"
ml search "error handling" --domain api
ml search "race condition" --type failure
ml search "auth" --tag "security"
ml search "schema" --classification foundational
ml search "sync" --sort-by-score          # Rank by confirmation score
```

Search uses BM25 ranking across all domains by default. Results include record type, classification, and any outcomes.

**When to skip**: If you just ran `ml prime` and the knowledge is already in context, don't search again for the same thing.

### Filtering

```bash
ml search "caching" --domain api --type decision
ml search "deploy" --file "src/deploy/"
ml search "test" --format json              # Machine-readable output
```

---

## Recording — Writing Learnings

### The Learn-Record-Sync Pipeline

This is the end-of-task workflow:

#### Step 1: Learn

```bash
ml learn
```

Shows changed files since the last commit and suggests which domains might be relevant. This is a read-only command — it doesn't write anything.

#### Step 2: Record

Based on what `ml learn` suggests, record the insights. Example:

```bash
ml record database --type failure \
  --description "Running VACUUM inside a transaction causes silent corruption" \
  --resolution "Always run VACUUM outside transaction boundaries" \
  --classification tactical \
  --tags "sqlite,vacuum,corruption"
```

See [record-types](record-types.md) for all six record types, required fields, classification tiers, evidence flags, and linking.

#### Step 3: Sync

```bash
ml sync                    # Validates, stages .mulch/ changes, commits
```

Uses git's own locking for the commit. If multiple agents are syncing on the same branch, coordinate timing or use per-agent branches.

### Tag Discipline

Tags should describe the **triggering situation**, not just the topic:

```bash
# Good — tags describe when this knowledge applies
--tags "migration,schema-change,breaking"
--tags "refactoring,rename,api-surface"
--tags "debugging,memory-leak,profiling"

# Bad — too generic to be useful in search
--tags "database"
--tags "important"
```

---

## CLAUDE.md / AGENTS.md Integration

The project's CLAUDE.md (or AGENTS.md) should contain a lightweight mulch section that tells agents to use mulch. Generate one with:

```bash
ml onboard
```

The generated snippet covers the core loop (prime → search → record → sync). Customize it for your project's specific domains and conventions.

Run `ml onboard` to generate a ready-to-paste snippet tailored to this project's domains.

---

## Domain Design Principles

Domains should map to **coherent areas of expertise** that agents will query together.

### Good Domain Design

Group by technology or concern:
- `database` — all database knowledge (schema, queries, migrations, performance)
- `api` — endpoint design, error handling, authentication
- `frontend` — component patterns, state management, accessibility
- `testing` — test strategies, fixtures, CI integration
- `deploy` — deployment procedures, infrastructure, rollback

### Bad Domain Design

Don't group by file path:
- `src-handlers` — too granular, splits related knowledge
- `models-and-schemas` — mixes database and API concerns

Don't create domains that overlap heavily:
- `database` + `sql` + `migrations` — these should be one domain

### When to Add a Domain

Add a domain when you find yourself recording multiple related insights that don't fit existing domains. A domain with fewer than 3 records after several sessions might be too narrow — consider merging it.

See [cli-reference](cli-reference.md) for `ml query` flags.
