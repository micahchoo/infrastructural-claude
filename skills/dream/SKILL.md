---
name: dream
description: >-
  Run a principle-pipeline on accumulated knowledge. Three modes:
  enrichment (consolidate memory, raise baseline), detect-gaps
  (find missing detection categories, promote rules), integrate
  (surface cross-project patterns, resolve conflicts).
  Triggered proactively at session start when signal accumulates.
  Invoke as: /dream enrichment, /dream detect-gaps, /dream integrate.
---

## Usage

`/dream <mode>` where mode is one of:
- **enrichment** — consolidate memory, merge redundant records, raise the baseline
- **detect-gaps** — find missing detection categories, graduate candidate rules
- **integrate** — surface cross-project patterns, transfer solutions

## Workflow

1. Dispatch the dream-agent subagent with the specified mode:

```
Agent tool call:
  name: "dream-agent"
  subagent_type: "general-purpose"
  prompt: "Mode: <mode>. Run the <mode> workflow from your system prompt.
           Project root: <cwd>.
           Present orient summary, execute all writes directly,
           then return the digest of what you did."
```

2. Present the dream-agent's digest to the user (summary of changes already applied)
3. If the user wants to revert: `git checkout -- <files>` or `git diff` to review

## When Offered

A SessionStart hook (`dream-trigger-hook.sh`) counts accumulated signal and offers this skill when thresholds are met. You can also invoke it manually at any time.

## Modes Map to Principles

| Mode | Principle | What improves |
|------|-----------|---------------|
| enrichment | Baseline-enrichment | Memory quality, record hygiene, agent tuning |
| detect-gaps | Closing-the-loop | Detection categories, anti-pattern rules |
| integrate | Holistic-integration | Cross-project knowledge, solution transfer |

## Eval-Protocol Integration

Every dream template embeds `[eval:]` checkpoints that eval-protocol can harvest at phase gates. Key decision-quality checks:

| Category | Where it fires | What it catches |
|----------|---------------|-----------------|
| `depth` | validate-prior | Validation read artifact content, not just counted files |
| `idempotence` | validate-prior | Re-run safety — no double-counting or re-removal |
| `execution` | most templates | Actions taken (files written/deleted), not just logged |
| `completeness` | failure-journal, memory-consolidation | Full scan, not sampling |
| `boundary` | cross-project, coherence-fixes | Stayed in scope, minimal changes |
| `resilience` | all templates | Graceful handling of missing data |
| `target` | orient gate, seeds-bridge | Right things investigated |

Each template also has `## Recovery` paths (degrade/resume/escalate) so failures produce course-correction, not dead ends.

## Cognitive Guardrails Integration

Dream edits the systems that guide other sessions — it's "Loom-editing-the-Loom." Five guardrails fire at decision points within the dream-agent:

- `wysiati` — before removing artifacts (what context are you missing?)
- `overconfidence` — when grading dream ROI (self-grading without criteria is noise)
- `substitution` — when clustering failures (root cause vs. grep-ability?)
- `sunk-cost` — when keeping unfired artifacts (investment vs. likelihood?)
- `operationalize` — when writing digest metrics (specific enough to act on?)
