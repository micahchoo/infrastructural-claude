---
name: executing-plans
description: >-
  Use when you have a written implementation plan to execute. Supports two modes:
  Subagent Mode (fresh subagent per task with two-phase review, for platforms with
  subagent support like Claude Code) and Sequential Mode (single-agent execution
  with review checkpoints). Do NOT trigger for: parallel dispatch of independent
  investigations without review stages (use dispatching-parallel-agents); orchestrating
  3+ tasks across multiple sessions (use strategic-looping with executing-plans);
  creating or writing implementation plans (use writing-plans); creating or modifying
  skills (use skill-creator).
---

# Executing Plans

Load plan, review critically, execute all tasks, report when complete.

Announce at start: "I'm using the executing-plans skill to implement this plan."

**Mode selection:** If your harness has subagents (Claude Code, Codex, or similar), use **Subagent Mode**. Otherwise, use **Sequential Mode**.

**Context init** before the first task:
- If the project has `package.json`/`Cargo.toml`/`pyproject.toml`: run `sync_deps(root)` so foxhound has the current dep index.
- If HANDOFF.md has a `## Knowledge State` section: note indexed packages, productive tiers, and gaps. Address critical gaps (missing docs) via `context add` before dispatching tasks. `[eval: no-rediscovery]`
- If the project has `feature_list.json` (acceptance criteria): count passing/total — this is the progress metric. Work one `passes:false` item at a time. Never remove or edit feature descriptions — only flip `passes: false` to `passes: true`. `[eval: single-feature]` `[eval: feature-progress]`
- If `init.sh` exists: run it to bootstrap the dev environment.
- If Playwright MCP is available and the project has a UI: browser-verify each feature using `browser_navigate` + `browser_snapshot` + interaction tools before marking complete. Code-level tests alone are insufficient for UI features. `[eval: browser-verified]`

Before each task: `search_packages` → `get_docs` for library APIs the task touches (2-4 keyword queries). Also `search("<what this task is doing>", project_root=root)` to surface prior decisions and failures — include results in the subagent's `<files_to_read>` (Subagent Mode) or use to inform your approach (Sequential Mode).

---

## Brownfield Gates

Two gates bracket the implementation. They apply to both modes.

### Entry Gate (before first task)

**Skip condition:** If brainstorming occurred in the same session and `git diff --name-only` shows no changes to files in the flow map, skip to step 2 — the flow map was just derived from this state.

Steps 1 and 2 can run in parallel — contract verification (reading signatures) and characterization testing (exercising runtime behavior) are independent. If step 1 finds drift, re-scope step 2 targets.

1. **Flow Map Validation** — If the plan has a `## Flow Map` preamble, validate it against the actual codebase. For each node:
   - Verify file exists and contains the described function/handler
   - Check for behavioral stubs: constant returns regardless of input, dead parameters (accepted but never read), identity passthroughs, empty bodies, silent error swallowing (catch-log-no-rethrow). A stub changes scope from "modify" to "implement." Also check delegation chains — if a node delegates, verify the delegate isn't itself a stub (transitive incompleteness).
   - Verify upstream contract matches actual function signature/API shape
   - Verify downstream contract matches what the next node actually accepts
   - Flag drift if architecture changed between brainstorming and execution
   This is targeted verification against a known map, not open-ended discovery. Use `get_docs` for version-specific API docs where relevant.
   `[eval: flow-map-present]`

2. **Flow-Scoped Characterization Testing** — Invoke `characterization-testing` scoped to the flow, not just the component:
   - **Flow-level test:** Exercise the full flow from trigger to outcome. Locks observable behavior.
   - **Contract-level tests:** At each flow boundary the plan touches, assert the contract.
   These are your safety net — they tell you what your changes break. If characterization reveals behavioral stubs (no observable effect, constant returns, silent error swallowing), flag for plan scope revision — the plan assumed working code at those nodes.
   `[eval: safety-net]`

3. **Open Questions Research** — If the plan has an `## Open Questions` section (including Flow Contracts questions), run `hybrid-research` on each unanswered question. Update plan tasks with findings. Don't dispatch tasks that depend on unresolved questions.
   `[eval: open-questions-researched]`

**Gate check:** All three must hold before proceeding — flow map validated, characterization tests passing, open questions resolved (or marked "accepted risk" with rationale).

Before executing, pause for two bias checks:
- `bias:wysiati` — What flow paths haven't we verified?
- `bias:overconfidence` — For each contract claim in the flow map, how do we know it matches actual code?


### Pre-Completion Gate (after all tasks, before final review)

After all implementation tasks finish but before dispatching the final code reviewer. Steps 1 and 3 can run in parallel.

The purpose: diff implemented state against the flow map and verify contracts hold.

1. **Flow Map Diff** — Compare the implemented codebase against the plan's flow map:
   - Does each flow node still exist at its declared path?
   - Do contracts match? (Planned changes = expected. Unplanned = drift.)
   - New connections not in flow map? (Unplanned coupling)
   - Flow map connections that no longer exist? (Broken wiring)
   - Were new stubs introduced? Check new/modified nodes for behavioral presence — scaffolded-but-empty functions are introduced incompleteness.

   Produce a **structured diff table**, not a narrative:

   | Node | Expected (flow map) | Actual | Status |
   |------|-------------------|--------|--------|
   | node-a | description | description | planned ✓ |
   | node-b | old behavior | new behavior | planned ✓ (intentional) |
   | node-c | handle errors | catch-log-no-rethrow | stub ⚠ |

   `[eval: flow-diff]`

2. **Build Missing Wiring** — If the diff shows gaps (planned connections that don't exist yet), implement them. Small concrete wiring tasks; escalate if larger than expected.
   `[eval: gaps-resolved]`

3. **Contract Verification Tests** —
   - Re-run flow-level + contract-level tests as regression (confirming existing contracts hold)
   - Write new contract tests for intentionally modified boundaries
   - Verify downstream nodes handle new contracts correctly
   `[eval: contract-preservation]` `[eval: regression-check]`

**Gate check:** Flow map diff produced (intentional changes confirmed, no unplanned drift), all gaps resolved, all contract tests passing.

Before review: `bias:substitution` — Did we solve the actual problem stated in the plan's Goal, or substitute an easier one?

**Claim verification** (optional, high-value for complex tasks): dispatch gate-enforcer in `claim-verification` mode to independently verify subagent claims.

**Subsequent invocations:** `[SNAG]` check + proceed. Full gate on fresh session only.

---

## Sequential Mode

Single-agent execution with review checkpoints. Use when subagents aren't available.

### Step 0: Brownfield Entry Gate
Follow the Entry Gate above. Don't proceed until the gate check passes.

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically — informed by Entry Gate research and characterization tests
3. If concerns: raise them with your human partner before starting
4. If no concerns: create TodoWrite and proceed

### Step 2: Execute Tasks

Mid-execution check: `bias:sunk-cost` — Would a fresh agent with a handoff continue this plan, or restructure? Check at every pause gate or when 2+ tasks hit unexpected friction.
`[eval: pivot-or-persist]`

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Record decisions/failures to mulch if worth capturing; close/create seeds issues as appropriate
5. Mark as completed

After each task: did it reveal anything that changes the approach for remaining tasks? If yes, update the plan notes before starting the next one. Learning without updating is drift. For convergence discipline and quality ratcheting across iterations, load `strategic-looping/references/convergence.md`.
`[eval: propagation]`

**Deferred items flow to seeds.** When a plan task gets deferred during execution, create a seeds issue with "deferred" label, wire dependencies (`sd dep add` for issue blockers, `mulch-ref:` for decision blockers), and back-link in mulch.
`[eval: deferred-capture]`

### Step 2.5: Brownfield Pre-Completion Gate
Follow the Pre-Completion Gate above. Don't proceed until the gate check passes.

After all tasks complete, flag: "Plan at `<path>` appears fully executed — recommend archiving to `plans/archive/`." Don't auto-archive.
`[eval: cleanup]`

### Step 3: Complete Development
After Pre-Completion Gate passes, use `finishing-a-development-branch` to verify tests, present options, and execute choice.

---

## Subagent Mode

Dispatch a fresh subagent per task with two-phase review (spec compliance first, then code quality).

The reason for subagents: isolated context keeps each task focused and preserves your context for coordination. You construct exactly what each subagent needs — they never inherit your session history.

### Context Budget

Keep orchestrator at ~15% context usage. Subagents get 100% fresh.

The orchestrator's job is coordination, not implementation. Don't read implementation files, test files, or subagent output directly. If a subagent reports issues, dispatch a new subagent to investigate.

Subagent prompts include `<files_to_read>` with everything they need: plan file, interfaces (from `~/.claude/scripts/extract-interfaces.sh`), referenced docs from brainstorming, and foxhound search results. When the plan has a `## Flow Map`, include it alongside each task so the subagent knows where its work sits in the flow, what it receives from upstream, and what it must produce downstream.

**Trajectory narrative:** Each subagent prompt opens with a `<trajectory>` block — one paragraph synthesizing how the project reached this point. Draw from: the design doc's Locked Decisions (what was debated and settled), the flow map preamble (system shape and intent), and any assumptions flagged as shaky during brainstorming or entry gate. The subagent needs to distinguish load-bearing tasks from incidental ones, and trajectory is what makes that possible. Keep it to 3-5 sentences — the cost of a handoff is proportional to the gap between your context and the subagent's reconstruction ability.

Track only: success/failure, files created/modified, commit hash.
`[eval: efficiency]` `[eval: approach]`

### Wave-Based Dispatch

If the plan includes Execution Waves, dispatch by wave. Without explicit waves, infer them: scan task descriptions for file-path mentions, build a dependency graph from shared files, topologically sort into waves. Tasks touching disjoint files → same wave. Tasks where one's output is another's input → sequential waves. Fall back to sequential if dependencies are ambiguous.

For each wave:
1. Read wave structure from plan (or inferred grouping)
2. **Cluster detection:** Scan tasks for clusters — tasks sharing a concern category (error-handling, validation, type-safety, naming, performance, testing, security, architecture) AND spatial proximity (same file or directory subtree). Dispatch one agent per cluster instead of one per task. Cluster agents read broadly across the cluster's files before making targeted changes — this produces more coherent fixes.
3. Dispatch all tasks/clusters in parallel
4. Wait for all tasks in the wave to complete
5. **Stuck detection:** Track task identity across dispatch attempts. If a subagent returns BLOCKED or fails on the same task twice, mark it `[SNAG] stuck: <task>` and skip to the next task or escalate to the user. Don't retry with the same context a third time.
6. **Backpressure verification:** After each task, run project verification (test suite, type-check, lint) scoped to changed files. A task is only complete when verification passes. If it fails after a fix attempt, apply stuck detection.
   `[eval: backpressure]` `[eval: no-infinite-retry]`
7. Cross-wave integration check: do outputs from this wave satisfy inputs for the next wave?
8. Record decisions/failures to mulch; close/create seeds issues as appropriate
9. Proceed to next wave

Within a wave, tasks are independent (use dispatching-parallel-agents). Across waves, tasks are sequential.
`[eval: sequence]` `[eval: completeness]`

### Model Selection

Use the least powerful model that can handle each role:
- **Mechanical tasks** (isolated functions, clear specs, 1-2 files): fast, cheap model. Most tasks are mechanical when the plan is well-specified.
- **Integration tasks** (multi-file coordination, pattern matching, debugging): standard model.
- **Architecture/design/review tasks**: most capable model.

### Handling Implementer Status

Subagents report one of four statuses:

**DONE:** Proceed to spec compliance review.

**DONE_WITH_CONCERNS:** Read concerns first. If about correctness/scope, address before review. If observations ("this file is getting large"), note and proceed.

**NEEDS_CONTEXT:** Provide missing context and re-dispatch.

**BLOCKED:** Assess the blocker — context problem (provide more, re-dispatch same model), reasoning limit (re-dispatch with more capable model), too large (break into pieces), or plan is wrong (escalate to user). If the implementer says it's stuck, something needs to change.

### Prompt Templates

- `./implementer-prompt.md` — Dispatch implementer subagent
- `./spec-reviewer-prompt.md` — Dispatch spec compliance reviewer
- `./code-quality-reviewer-prompt.md` — Dispatch code quality reviewer

See `references/example-workflow.md` for a complete walkthrough and `references/process-diagram.md` for the full flowchart.

### Why Subagent Mode

Fresh context per task eliminates confusion. Parallel-safe. Two-stage review (spec then quality) catches issues early — more subagent invocations but cheaper than debugging later. Subagents can ask questions before and during work, surfacing problems early.

---

## When to Stop

Stop executing and ask for help when you hit a blocker (missing dependency, test fails, instruction unclear), the plan has critical gaps, you don't understand an instruction, or verification fails repeatedly. For pause-gate signal-to-action mapping (quality declining? foundation weak? early learnings?), load `strategic-looping/references/checkpoints.md`. Ask for clarification rather than guessing. If a partner updates the plan based on your feedback, return to the review step.

`[eval: assumption-check]` At each review gate, revisit the plan's key assumptions. If any assumption has been invalidated by implementation evidence, flag it before proceeding — don't execute against stale premises.

Never start implementation on main/master without explicit user consent — this is the one thing that can't be easily undone.
