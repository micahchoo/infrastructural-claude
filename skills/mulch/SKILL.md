---
name: mulch
description: >-
  Project expertise management with the mulch CLI — structured JSONL records
  that accumulate across sessions and live in git. Use this skill whenever
  working in a project with .mulch/, when initializing mulch in a new project,
  when recording learnings after completing work, when deciding which record
  type or classification to use, when running maintenance (compact, prune,
  doctor), when tracking outcomes of applied decisions, or when setting up
  mulch for a new agent provider. Also use when the user says "mulch",
  "record expertise", "project learnings", "ml record", "ml prime",
  "expertise domains", or asks about structuring project knowledge for agents.
  NOT for: general git operations, documentation writing, or
  knowledge-base tools unrelated to mulch.
---

# Mulch — Project Expertise Management

Mulch stores typed expertise as JSONL records in `.mulch/expertise/<domain>.jsonl`. Six record types, three classification tiers, advisory locking, and atomic writes. Everything is git-tracked — clone a repo and agents have the project's accumulated knowledge immediately.

## Decision Framework

Pick the right command based on what you're doing:

| You need to... | Command | Reference |
|---|---|---|
| **Start a session** | `ml prime` or `ml prime --files <paths>` | [core-workflow](references/core-workflow.md) |
| **Check before choosing an approach** | `ml search "<what you're doing>"` | [core-workflow](references/core-workflow.md) |
| **Record what you learned** | `ml learn` → `ml record <domain> --type <type>` | [core-workflow](references/core-workflow.md), [record-types](references/record-types.md) |
| **Track if a decision worked** | `ml outcome <domain> <id> --status success/failure` | [record-types](references/record-types.md) |
| **Check domain health** | `ml status`, `ml doctor` | [maintenance](references/maintenance.md) |
| **Clean up stale records** | `ml compact`, `ml prune` | [maintenance](references/maintenance.md) |
| **Review expertise changes** | `ml diff HEAD~3` or `ml diff main..feature` | [maintenance](references/maintenance.md) |
| **Record in bulk (session end)** | `ml record <domain> --batch file.json` | [concurrency](references/concurrency.md) |
| **Initialize for a new project** | `ml init` → `ml add <domain>` | [core-workflow](references/core-workflow.md) |
| **Look up a specific flag** | See full CLI | [cli-reference](references/cli-reference.md) |

## Session Lifecycle

```
┌─ Session Start ──────────────────────────────────┐
│  ml prime                                         │
│  (or ml prime --files <paths> for specific files) │
└──────────────────────────┬───────────────────────┘
                           ▼
┌─ Before Choosing Approach ───────────────────────┐
│  ml search "<what you're doing>"                  │
│  Skip if you just primed and knowledge is fresh   │
└──────────────────────────┬───────────────────────┘
                           ▼
┌─ During Work ────────────────────────────────────┐
│  ml prime --files <paths> when touching new files │
│  ml search "<specific question>" as needed        │
└──────────────────────────┬───────────────────────┘
                           ▼
┌─ After Completing Work ──────────────────────────┐
│  ml learn          (see what changed, get hints)  │
│  ml record ...     (write learnings — see below)  │
│  ml outcome ...    (track if prior advice worked) │
│  ml sync           (validate, stage, commit)      │
└──────────────────────────────────────────────────┘
```

### Phase Checkpoints

**Cycles 2+:** Abbreviated checkpoints only — skip full lifecycle. Full form on cycle 1.

`[eval: prior-art-checked]` ml search was run before choosing an approach, or explicitly skipped because prime was just run and knowledge is fresh.

## Recording: What's Worth Keeping

Not everything deserves a record. Before writing, ask:

1. **Would a fresh agent benefit from knowing this?** If the insight is obvious from reading the code, skip it.
2. **Is this durable or ephemeral?** Temporary workarounds → observational classification. Architectural truths → foundational.
3. **Which type fits?** See [record-types](references/record-types.md) for the decision tree.

### Recording Well

```bash
ml record api --type failure \
  --description "Race condition when two agents call /sync concurrently" \
  --resolution "Add mutex guard around the sync endpoint handler" \
  --classification tactical \
  --tags "concurrency,api,race-condition" \
  --evidence-file "src/handlers/sync.rs"
```

**Tag the triggering situation**, not just the topic. Tags like `"refactoring,rename"` or `"migration,schema-change"` help future agents find records when they're doing similar work.

`[eval: type-justified]` Record type matches the content: conventions describe repeatable patterns, decisions explain a choice with rationale, failures capture what went wrong and the resolution. Classification (foundational/tactical/observational) reflects durability, not importance.

`[eval: record-written]` ml record succeeded with a valid type, classification, and at least one tag.

## Closing the Feedback Round

The most important gap in a write-only expertise system is validation. After applying a recorded decision or pattern:

```bash
# Check what you applied
ml search "the pattern you used"

# After verifying it worked (or didn't)
ml outcome <domain> <record-id> --status success --notes "Applied in PR #42, no issues"
ml outcome <domain> <record-id> --status failure --notes "Caused regression in X"
```

Records with outcomes get higher confirmation scores, which `ml prime` uses to prioritize what it surfaces. See [record-types → Outcome Tracking](references/record-types.md#outcome-tracking).

`[eval: feedback-closed]` ml outcome was called on at least one record that was applied during the session, with a success or failure status.

## Maintenance

Expertise rots without maintenance. See [maintenance](references/maintenance.md) for the full schedule and playbook.

## Initialization

When entering a project without `.mulch/`:

```bash
ml init                              # Creates .mulch/ structure
ml add <domain>                      # Add domains by concern, not by file
ml setup claude                      # Install provider-specific hooks
ml onboard                           # Generate CLAUDE.md/AGENTS.md snippet
```

**Domain design**: Group by technology or concern (e.g., `database`, `api`, `frontend`, `testing`), not by file path. A domain should map to a coherent area of expertise that agents will query together.

See [core-workflow → Initialization](references/core-workflow.md#initialization).

## Multi-Agent & Concurrency

All read commands are fully safe for parallel use. Write commands use advisory file locking. Batch recording (`--batch`, `--stdin`) is available for atomic multi-record writes. See [concurrency](references/concurrency.md) for swarm patterns and edge cases.

