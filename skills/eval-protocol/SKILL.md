---
name: eval-protocol
description: >-
  Agent decision-quality protocol — expect/capture/grade primitives for checking
  whether the right tool, approach, or research target was chosen at workflow
  phase transitions. Use for: phase gates between workflow stages, decision
  routing eval harnesses, transcript grading, or embedding checkpoints in skills.
  NOT for: pytest/unit tests, ML metrics, LLM output eval, performance benchmarks,
  or code review — this evaluates agent decisions, not code correctness.
---

# Eval Protocol

A protocol for evaluating decision quality at any point in any workflow. Not a workflow itself — a set of primitives that other skills embed.

## Core Concept

Every agent decision has a shape: tool selection, approach direction, research target, output structure. This protocol defines how to specify what "correct" looks like, observe what actually happened, and grade the gap.

The pattern mirrors cognitive guardrails (micro-interventions at decision points) but evaluates **correctness** rather than **bias**. Where guardrails ask "are you thinking right?", eval-protocol asks "did you do it right?"

**Discrimination over conformance:** A good expectation passes when decisions are good and fails when they're bad. Before writing expectations, ask: "Would a lazy or wrong approach also pass this?" If yes, sharpen it. The categories below help you *think about* different decision dimensions, not impose a labeling scheme.

## The Three Primitives

### 1. Expect — Define What Correct Looks Like

Before a decision point, state expectations as testable assertions. Each expectation has a `text` (what should be true), a `category` (what kind of decision), and optionally a `weight` (how much it matters).

When designing criteria, resist substituting what's easy to measure for what actually matters. Checking "used the right tool" is simpler than "chose the right approach" — measurability shouldn't replace importance.

Categories of decisions you can evaluate:

| Category | What It Checks | Example |
|----------|---------------|---------|
| `tool` | Right tool for the job | "Used Grep not Bash grep for content search" |
| `approach` | Right strategy or sequence | "Read file before proposing edits" |
| `target` | Right thing to investigate | "Searched for the error message, not the function name" |
| `shape` | Output meets structural requirements | "Plan has independently testable tasks" |
| `boundary` | Respects constraints | "Didn't modify files outside the target directory" |
| `efficiency` | Reasonable resource use | "Found the answer within 3 tool calls" |
| `completeness` | Touched everything that needed touching | "Merge updated aliases AND all referencing daily notes" |
| `resilience` | Works when context has changed | "Handles entity no longer in scan by rebuilding from saved metadata" |
| `idempotence` | Safe to re-run without side effects | "Running merge twice doesn't create duplicate entries" |
| `context` | Right rules for this specific situation | "Cross-archive matching uses relaxed thresholds; same-archive does not" |
| `execution` | Tool used correctly, not just chosen correctly | "Grep pattern matches class imports, not just the string 'Config'" |
| `depth` | Investigation went deep enough (strongest discriminator — agents check breadth naturally but skip depth; when in doubt, check depth) | "At least one source was read beyond its summary/abstract" |
| `sequence` | Compound decision chain is sound | "5 sequential Greps should have been 1 Agent subagent dispatch" |
| `recovery` | Failure triggers the right next action | "On gate failure, generates targeted remediation queries, not blind retry" |
| `feasibility` | Plan is executable with available tools | "Every task uses tools the agent actually has access to" |

**Writing good expectations:**

Expectations should be objective and binary — a grader (or script) can determine pass/fail without subjective judgment. If you can't write it as a pass/fail check, it's feedback, not an expectation.

More importantly, expectations should **discriminate** — they should fail when the decision is wrong, not just when the formatting is wrong. Test the decision, not the label.

```
Good: "Used Read tool (not cat via Bash) to read the config file"
Bad:  "Read the config file well"

Good: "Grep pattern uses regex to match 'import.*Config', not literal string 'Config'"
Bad:  "Used Grep tool" (too easy to pass — doesn't test execution quality)

Good: "Searched in src/ directory, not root"
Bad:  "Searched in the right place"

Good: "Produced a plan with ≤8 tasks where no task depends on more than 2 others"
Bad:  "Plan is reasonable size"

Good: "On research gate failure, generated 2+ targeted follow-up queries addressing specific gaps"
Bad:  "Has error handling" (passes even with blind retry)
```

**The discrimination test:** Before finalizing an expectation, imagine a mediocre approach. Would it pass? If yes, the expectation needs sharpening.

### 2. Capture — Observe the Decision

After the decision point, record what actually happened. For tool decisions, this is the tool call itself. For approach decisions, it's the sequence of actions. For research decisions, it's what was searched and where.

Capture formats:

- **Inline** (lightweight): Note the decision in your reasoning. Sufficient for single checkpoints embedded in other skills.
- **Structured** (for harnesses): Write to `eval_metadata.json` with the schema from `references/schemas.md`. Use when running formal eval suites.
- **Transcript** (for post-hoc): The conversation transcript itself is the capture. Grader agents read it to extract decisions.

### 3. Grade — Compare Actual vs Expected

For each expectation, determine `passed` (boolean) and `evidence` (what you observed). Three grading modes:

When grading, ask what evidence would flip a pass to a fail (or vice versa) — self-grading is especially prone to leniency.

- **Self-grade** (fastest): The agent evaluates its own decision before proceeding. Works for obvious checks like "did I use Read instead of cat?" Low overhead, catches mechanical errors.
- **Script-grade** (most reliable): A script checks the output programmatically. Best for structural/shape expectations. Write scripts that read outputs and return pass/fail.
- **Agent-grade** (most flexible): A separate agent reads the transcript and evaluates. Best for approach and target decisions that require judgment. Use the grading schema from `references/schemas.md`.

## Embedding in Skills

### As a Phase Gate

Insert between phases of any multi-phase skill. The eval checkpoint prevents phase transition until expectations pass.

```
Phase 1: Research
  ↓
  [eval-checkpoint: target expectations]
  "Did I search the right things? Did I find sources, not just confirmations?"
  ↓
Phase 2: Plan
  ↓
  [eval-checkpoint: shape expectations]
  "Does the plan have the right structure? Are tasks independent?"
  ↓
Phase 3: Execute
```

### Harvesting Skill Checkpoints

When invoked at a phase gate by another skill (strategic-looping, executing-plans, etc.), collect `[eval: tag]` checkpoints from skills that fired in the preceding phase. These become **additional expectations** alongside any ad-hoc ones you generate — they don't replace ad-hoc expectations.

How to harvest:
1. Identify which skills were invoked since the last gate (from conversation history or Active Skills in handoff).
2. For each skill, extract its `[eval: tag] description` lines.
3. Convert each to an expectation: the description text becomes the `text`, the tag name hints at `category` (e.g., `[eval: depth]` → category `depth`, `[eval: no-rediscovery]` → category `efficiency`).
4. Grade these alongside your ad-hoc expectations. Report them separately so the invoking skill can see which of its own checkpoints passed/failed.

This gives `[eval:]` checkpoints a **runtime consumer** — they're no longer just self-check reminders. The ad-hoc expectations still handle decision quality that no skill anticipated; the harvested checkpoints handle properties the skills themselves defined as success criteria.

### As a Wrapper

Wrap any operation with before/after expectations:

```
[expect]: "Will use Glob to find test files, not ls or find"
[expect]: "Will search in tests/ directory first"
  ↓
  (agent does the thing)
  ↓
[grade]: Check expectations against what happened
[report]: Surface any failures before continuing
```

### As a Retrospective

After a workflow completes, evaluate the full transcript:

```
[capture]: Read the transcript
[grade]: Against expectations defined post-hoc
[report]: What would have gone better with different decisions?
```

### As a Compound Sequence Check

Individual decisions may be correct but the sequence wrong. Evaluate the decision *chain*, not just each link:

```
[expect-sequence]:
  "Research phase used ≤3 search rounds before converging"
  "Did not repeat the same query with minor variations >2 times"
  "Escalated from Grep to Agent subagent when initial searches returned >5 files"
```

Compound checks catch the pattern where every individual tool call is defensible but the overall approach is inefficient or misdirected — five correct Greps when one Agent dispatch would have been faster.

**Sequence escalation rules** (common patterns to check):
- 3+ sequential Greps on related terms → should have been one Agent(Explore) dispatch
- Research query repeated with minor rewording → converge or change strategy, don't rephrase
- Same tool called with incrementally wider scope → start broad, narrow down (not the reverse)
- Edit → test → fail → edit same section → should step back and re-read surrounding code

### With Recovery Paths

Expectations should include what to do on failure. A gate that says "fail" without remediation is a dead end — the agent retries blindly or gives up.

```
[expect]: "Research found ≥3 sources from different domains"
[on-fail]: Generate 2+ targeted follow-up queries addressing the specific gap
           (e.g., if all sources are Stack Overflow, query for official docs and academic papers)
           Maximum 2 retry rounds before escalating to user

[expect]: "Plan tasks are independent (no circular dependencies)"
[on-fail]: Identify the dependency cycle, propose task reordering or splitting
           Do not just remove the dependency — restructure the work
```

Recovery paths transform expectations from passive checks into active course-correction. The difference between "your plan has a circular dependency" and "tasks 3→5→3 form a cycle; split task 5 into 5a (prep, no deps) and 5b (integration, depends on 3)."

**Partial failure recovery patterns:**
- **Rollback**: Undo the partial change, restore previous state, then retry with corrected approach. Use when partial application leaves inconsistent state (e.g., merge updated primary but not references).
- **Resume**: Mark completed steps, skip them on retry, continue from the failure point. Use when steps are independent and earlier results are valid.
- **Degrade**: Proceed with reduced scope, annotate what was skipped, flag for manual follow-up. Use when the failure is in a non-critical path and blocking would waste more than it saves.
- **Escalate**: Stop, surface the failure with context, ask the user. Use when recovery requires judgment the agent can't make (ambiguous merge targets, conflicting constraints).

## Formal Eval Harnesses

For formal testing (not just inline checkpoints), define an eval suite in `evals.json` with test prompts and expectations, spawn subagents with each prompt, and grade against expectations. See `references/schemas.md` for JSON structures — compatible with skill-creator's viewer and aggregation scripts.

## When NOT to Use This

- **Subjective quality**: "Is the code clean?" isn't an eval-protocol question. Use code review.
- **Already verified**: If a test suite covers it, don't duplicate with eval expectations.
- **Trivial decisions**: Don't checkpoint every tool call. Reserve for phase transitions and decisions that have downstream consequences.
- **Single-shot tasks**: If there's no iteration loop, inline self-grading is sufficient. Don't build a harness for one run.

Wrong tool chosen at gate? → `[PARKED: tool_name — reason]`, proceed with correct tool.

`[eval: completeness]` Every expectation includes an on-fail recovery path, not just pass/fail.
