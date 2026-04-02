---
name: writing-plans
description: >-
  Use when you have a spec or requirements for a multi-step task, before
  touching code. Do NOT trigger for: reviewing or verifying completed work
  (use requesting-code-review); open-ended design exploration before you have
  requirements (use brainstorming); executing an already-written plan (use
  executing-plans).
---

> **Gate:** Input Validation must pass before planning begins.

# Writing Plans

Write comprehensive implementation plans assuming the engineer has zero context for the codebase. Document everything they need: which files to touch, code, testing, docs to check, how to verify. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume a skilled developer who knows almost nothing about the toolset or problem domain, and isn't great at test design.

Announce at start: "I'm using the writing-plans skill to create the implementation plan."

Save plans to: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (user preferences override this default).

Step 0 handles worktree setup. If brainstorming already created a worktree, Step 0 auto-skips.

---

## Scope Check

Before defining scope from scratch, check for product-design output. If `product-plan/` or `product/` exists with artifacts:
- Read `product-plan/instructions/` for milestone requirements — each milestone maps to one execution wave
- Read `product-plan/sections/*/types.ts` as interface extraction input
- Read `product-plan/sections/*/tests.md` to seed TDD task structure
- Read `product-plan/design-system/` for token constraints
- Locked Decisions from brainstorming and product-design constrain the plan — don't re-derive what's already specced
`[eval: boundary]`

If the spec covers multiple independent subsystems that weren't broken out during brainstorming, suggest separate plans — one per subsystem, each producing working, testable software on its own.

Check whether any two tasks optimise for opposing goals (throughput vs correctness, for instance). If so, the plan has a contradiction — resolve before creating tasks.

## Architecture Context

Before planning, check for existing architecture docs from codebase-diagnostics:
- `docs/architecture/subsystems.md` → subsystem boundaries often map to task boundaries
- `docs/architecture/risk-map.md` → prioritize highest-risk subsystems first
- Stale architecture docs → note stale sections as open questions in the plan

## Input Validation (Brainstorm Gate)

Before planning, verify the brainstorm output is sound. Each criterion must reference specific identifiers — file paths, function names, section titles, counts. "The brainstorm is thorough" is not verifiable.

- Every component referenced in the brainstorm exists in the codebase (verified by `test -f` or Glob) or is explicitly marked "Create:" in the design doc. `[eval: feasibility]`
- Checked existing indexed sources, mulch, and codebase for prior art — the problem may already be solved. For underrepresented domains: has a reference implementation been studied? `[eval: scavenge]`
- Each requirement from the user's original request appears as a named item in the design doc's requirements section. Count: requirements in request vs in design doc. `[eval: completeness]`
- Design doc contains "Alternatives Considered" with at least 2 named alternatives and a sentence per alternative stating why it was rejected — referencing a specific tradeoff, not a quality judgment. `[eval: shape]`

On failure: return to brainstorming with specific gaps identified. Don't plan on a foundation you can't verify.

---

## Step 0: Worktree Setup

Skip if `git rev-parse --show-toplevel` shows you're already in a worktree.

### Directory Selection (priority order)
1. Check existing: `ls -d .worktrees worktrees 2>/dev/null` — use what's there (`.worktrees` wins)
2. Check CLAUDE.md: `grep -i "worktree.*director" CLAUDE.md 2>/dev/null`
3. Ask user: offer `.worktrees/` (project-local, hidden) or `~/.config/superpowers/worktrees/<project>/` (global)

### Safety Verification
Verify directory is git-ignored: `git check-ignore -q .worktrees 2>/dev/null`. If not ignored, add to `.gitignore` and commit first.

### Create & Verify
```bash
git status --porcelain  # must be empty or stash first
git worktree add "$WORKTREE_DIR/$BRANCH_NAME" -b "$BRANCH_NAME"
cd "$WORKTREE_DIR/$BRANCH_NAME"

# Auto-detect project setup
[ -f package.json ] && npm install
[ -f Cargo.toml ] && cargo build
[ -f requirements.txt ] && pip install -r requirements.txt
[ -f pyproject.toml ] && poetry install
[ -f go.mod ] && go mod download

# Verify clean baseline — run project tests
# If tests fail: report failures, ask whether to proceed
```

---

## Flow Map Preamble

If the design doc contains a `## Flow Map` (from brainstorming's Flow Mapping phase), carry it into the plan as a `## Flow Map` preamble before Task 1. This is what executing-plans' Entry Gate validates against and what subagents receive as context.

For Standard-without-brainstorming tasks, the flow map file at `docs/architecture/flows/` serves as the preamble source.

**Feed-forward from prior retros.** Before decomposing tasks, check for plan retro patterns: `ml search "plan retro"` and `ml search "<pipeline-or-feature-name> retro"`. Extract feed-forward items about missing subtasks — patterns like "tasks touching new components need a wiring subtask", "type guard/factory tasks always accompany entity work", "store creation without companion test = incomplete task". Keep these as a checklist and apply during decomposition: for each task, check whether any known missing-subtask pattern applies and add the subtask if so. If no prior retros exist, proceed without delay.

**Task decomposition follows flow, not component.** One task per flow node being changed. Task boundaries align with flow boundaries — upstream contract in, downstream contract out:
- Multiple files serving the same flow node → one task
- One file in multiple flow positions → may split into multiple tasks

`[eval: flow-position]` `[eval: standard-adhoc-artifact]`

---

## File Structure

Before defining tasks, map out which files will be created or modified and what each is responsible for. This is where decomposition gets locked in.

- Design units with clear boundaries and well-defined interfaces. One clear responsibility per file.
- Prefer smaller, focused files — you reason best about code you can hold in context, and edits are more reliable when files are focused.
- Files that change together should live together. Split by responsibility, not technical layer.
- In existing codebases, follow established patterns. If a file has grown unwieldy, including a split in the plan is reasonable.

This structure informs task decomposition. Each task should produce self-contained changes that make sense independently.

## Contract Extraction for Subagents

After mapping file structure, extract contract context for subagent tasks. `<contracts>` blocks supersede `<interfaces>` blocks — contracts are a superset (signatures + behavioral expectations). `extract-interfaces.sh` remains available for mechanical extraction but its output feeds into contracts.

For tasks at flow boundaries, extract upstream and downstream contracts:

```markdown
<contracts>
**Upstream (node-a → this-node):**
- `functionName(param: Type): ReturnType`
- Behavioral invariant: <what's always true about the input>

**Downstream (this-node → node-b):**
- `functionName(param: Type): ReturnType`
- Behavioral invariant: <what's always true about the output>
</contracts>
```

For tasks that create contracts consumed by later tasks, add a "Wave 0" skeleton step that writes type definitions before implementation. For each contract between tasks, state what the producer assumes and what the consumer assumes — reconcile if they differ.

`[eval: completeness]` `[eval: sequence]`

### Domain-Codebook Annotations for UI Tasks

When a task involves UI interaction patterns, add a `Codebooks:` annotation. Executing-plans subagents co-load referenced codebooks via `get_docs("domain-codebooks", "<codebook-name>")`.

| Task involves | Annotation |
|---|---|
| Drag, pan, scroll, touch handling | `Codebooks: gesture-disambiguation` |
| Focus traps, tab order, keyboard nav | `Codebooks: focus-management-across-boundaries` |
| Virtual scroll, large lists, viewport culling | `Codebooks: virtualization-vs-interaction-fidelity` |
| Canvas selection, hit-test, snapping, mode FSM | `Codebooks: interactive-spatial-editing` |
| Optimistic updates, rollback, stale state | `Codebooks: optimistic-ui-vs-data-consistency` |
| Pen/touch/mouse discrimination | `Codebooks: input-device-adaptation` |
| Inline text editing, IME, canvas text | `Codebooks: text-editing-mode-isolation` |
| Undo/redo in collaborative context | `Codebooks: undo-under-distributed-state` |

Detection is keyword-based on task description, not file extension. A task can have multiple annotations.
`[eval: codebook-annotation]`

---

## Task Granularity

Each step is one action (2-5 minutes): write the failing test → run it to confirm failure → implement minimal code → run tests to confirm pass → commit.

## Plan Document Header

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Use executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Flow Name] — [Node Name] [CHANGE SITE]

**Flow position:** Step M of K in <flow name> (node-a → **this-node** → node-c)
**Upstream contract:** Receives <type/shape> from <upstream node>
**Downstream contract:** Produces <type/shape> for <downstream node>
**Skill:** `superpowers:test-driven-development` (or `none` if no skill applies)
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

Task success conditions must be specific — file paths, function names, test names, command output. Every task needs a `Run:` command with `Expected:` output.
`[eval: operationalize]`

For translating QA artifact signals into architectural force pairs, load `quality-linter/references/force-cluster-protocol.md`.

### Skill Annotations

Every task declares which skill governs its execution:
- Implementation tasks with testable code → `superpowers:test-driven-development`
- Frontend/UI component tasks → `frontend-design:frontend-design`
- Investigation/research tasks → `superpowers:hybrid-research`
- Behavior documentation tasks → `superpowers:characterization-testing`
- Debugging tasks → `superpowers:systematic-debugging`
- Review tasks → `superpowers:requesting-code-review`
- Config/script tasks with no test framework → `none`

If unsure, annotate `none`.
`[eval: annotation]`

---

## Execution Waves

After defining tasks, analyze dependencies and group into waves:
- **Wave 0**: Interface/contract creation (if any tasks create types others consume)
- **Wave 1+**: Independent tasks in the same wave; dependent tasks in later waves
- Annotate: `Wave N: Tasks [X, Y] (parallel) — depends on Wave N-1 completing`

**Flow-aware wave ordering** when the plan has a flow map:
- Upstream nodes with unchanged contracts can parallelize with downstream unchanged-contract nodes
- Change-site tasks wait for upstream verification
- Downstream tasks adapting to new contracts wait for the change-site task

`[eval: shape]` `[eval: efficiency]`

---

## Open Questions

Every plan includes an Open Questions section after Execution Waves. For each task or wave, surface what you don't know yet — assumptions not verified, APIs not checked, behaviors you're guessing about.

When the plan has a flow map, include a **Flow Contracts** subsection first:

```markdown
### Flow Contracts
- Q: Does <upstream> ever pass additional fields beyond <expected>? (assumed no — verify)
- Q: Can <downstream> handle <edge case>? (contract ambiguity)
```

Structure:
```markdown
## Open Questions

### Wave 1
- **Task 1: [name]**
  - Q: Does the existing handler support concurrent calls? (assumed yes, not verified)
  - Q: What's the error format returned by the API? (need to check docs)
    - Sub-Q: Does it differ between v1 and v2 endpoints?
- **Task 2: [name]**
  - (none — fully specified)
```

Questions must be concrete and answerable — not "is this a good idea?" but "does X return Y?". Nest sub-questions when a question branches. Mark fully-specified tasks explicitly. Questions depending on earlier wave outcomes should say so.

These questions get researched via `hybrid-research` before execution begins. Tier them: **Blocking** (must answer before execution) vs **Exploratory** (answerable during implementation).

`[eval: open-questions]` `[eval: answerable]`

---

## Artifact Manifest

Every plan ends with an Artifact Manifest block. The post-implementation audit script reads this to verify all claimed work exists on disk.

```
<!-- PLAN_MANIFEST_START -->
| File | Action | Marker |
|------|--------|--------|
| `path/to/file` | create/patch/wire/delete | `literal grep -F string` |
<!-- PLAN_MANIFEST_END -->
```

Actions: **create** (file must exist), **patch** (file exists AND contains the marker), **wire** (config entry exists AND its target exists), **delete** (file must NOT exist). Markers must be specific to this change, not pre-existing content. For `wire` markers containing paths, use `$HOME` not `~`.

After writing the plan: `bash ~/.claude/scripts/post-implementation-audit.sh <plan-file> --baseline`

`[eval: manifest]` `[eval: coverage]`

---

## Plan Review Loop

After writing the complete plan:

1. Dispatch a plan-document-reviewer subagent (see `plan-document-reviewer-prompt.md`) with the plan path and spec path — not your session history. Keeps the reviewer focused on the plan.
2. If issues found: fix them, re-dispatch reviewer
3. If approved: proceed to execution handoff

When review fixes modify early-wave tasks, check whether later waves depend on changed assumptions. Propagate fixes forward. For pause-gate decision criteria (when to revise vs continue), load `strategic-looping/references/checkpoints.md`.
`[eval: propagation]`

- Same agent that wrote the plan fixes it (preserves context)
- If loop exceeds 3 iterations, surface to human
- Reviewers are advisory — explain disagreements if you believe feedback is incorrect

## Plan Verification

After review, run structural verification:

1. **File existence**: Do all `Modify:` entries reference files that exist? (`test -f` or Glob)
2. **Task completeness**: Every task has Files, Steps, and a verification command?
3. **Dependency acyclicity**: Can tasks be ordered without circular dependencies?
4. **Requirement coverage**: Each requirement from the design doc maps to ≥1 task?
5. **Scope sanity**: No task modifies >5 files (split if so)

Max 2 iterations to fix issues. If still failing, surface to user.

`[eval: feasibility]` `[eval: shape]` `[eval: completeness]`

---

## Structural Conventions

After writing the plan, before the review loop, record conventions that should persist beyond this plan — module organization patterns, error handling approaches, test strategies, API design patterns. Skip mechanical choices (file naming, variable naming).

```bash
ml record <domain> --type convention \
  --description "<the convention>" \
  --classification tactical \
  --tags "scope:<module>,assumption:none,source:writing-plans,spec:<plan-path>,deferred:none,lifecycle:active,<situation-tags>" \
  --evidence-file "<plan-path>"
```

Check `ml search "scope:<module>"` first. Use `--supersedes` if updating.
`[eval: provenance]`

---

## Execution Handoff

After saving the plan:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Ready to execute?"**

If the harness has subagents: use executing-plans (fresh subagent per task + two-phase review). If not: execute in current session using executing-plans in Sequential Mode.

If the brainstorming design doc contains "Locked Decisions", treat them as constraints — don't re-open without user approval.

Before finalizing, list key assumptions (about APIs, data shapes, existing behavior, environment). These get verified at each review gate during execution — stale assumptions are the #1 cause of rework.
`[eval: assumption-check]`
