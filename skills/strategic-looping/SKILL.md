---
name: strategic-looping
description: >-
  Plan-execution coherence and iterative refinement for multi-step work. Use when executing plans with 3+ tasks, running iterative improvement loops (tune→measure→compare→decide), or any sustained work where cross-task learning and quality ratcheting matter. NOT for: single tasks, retry logic, automated test suites, the /loop command, or performance tuning.
---

# Strategic Looping

Iterative refinement discipline for multi-step work. Layer this on top of executing-plans. Two mechanisms: pause-and-reflect gates, and convergence protocols.

> **Runaway detection:** 2 consecutive flat iterations → change strategy. Cap: 3 iterations. (See Exit Criteria.)

**Init**: `mulch prime` if `.mulch/` exists (compact if 10+ records). At each pause gate, `get_docs` for upcoming task APIs.

## 1. Pause-and-Reflect Gates

Pause every 3 tasks (every 2 if < 6 total), at wave boundaries, after any surprising task, and before the final task.

At each gate, investigate — don't just ask "did anything break?"

1. **What did the last batch teach us?** Insights from completed tasks that change upcoming work — better patterns, useful abstractions, gotchas the plan missed. If the lesson changes the plan structure, update the plan before continuing.
2. **Are we still solving the right problem?** Has the problem shifted? Are we drifting from the original goal? Would a fresh agent do better from here? If yes, hand off with knowledge state (indexed packages, productive tiers, gaps).
3. **Forward-look**: Read the next 2-3 tasks. With what you now know, do you see risks, unmet preconditions, or a better ordering? If upcoming tasks modify code with unknown coupling, run characterization-testing first. If working in a domain with no pattern library, `sd tpl pour pattern-enrichment` to create tracking issues rather than running the full pipeline mid-task. Use `get_docs` for upcoming skill workflows and library APIs.
4. **Foxhound**: `search("<topic>", project_root=root)` for relevant expertise, prior decisions, or known pitfalls before the next iteration.
5. **Integration**: Run cross-component verification. Don't wait for "all done" to discover integration is broken.
5b. **Regression check**: If `feature_list.json` exists, verify 2-3 existing `passes:true` features haven't regressed since the last gate. Fix regressions before continuing — silent breakage compounds across iterations.
6. **Lesson propagation**: When a task reveals something (better approach, hidden constraint, failure mode), update ALL remaining task descriptions — not just the current one.
7. **Open questions**: Capture new questions that emerged during execution. Hybrid-research them before the next iteration — don't carry unresolved uncertainty forward.

7. **Code quality** (available on request, recommended for large changesets): Run `/simplify` (recommendations only) on code changed since the last gate, then `/eval-protocol` to grade each recommendation — surface only A/B-grade findings, deprioritize C-grade. Proactively recommend when 3+ files changed or 4+ tasks completed since last gate.

Then decide: continue, insert prep work, fix foundation, update remaining tasks, or stop and discuss with user. See `references/checkpoints.md` for the decision table and examples.

**Cognitive guardrails at each gate:**
- `bias:sunk-cost` — Would a fresh agent continue this plan? Completed work is not a reason to persist with a failing approach. If 2+ consecutive tasks hit unexpected friction, this check is mandatory.
- `bias:substitution` — Are you still solving the original problem, or have you substituted an easier one? Compare current task descriptions against the original goal statement.

`[eval: propagation]` Were lessons from completed tasks applied to remaining ones?
`[eval: guardrail]` At each gate, sunk-cost and substitution checks were performed — not skipped because "things are going fine."
`[eval: no-rediscovery]` When routing to handoff at a gate, knowledge state (indexed packages, productive tiers, gaps) was captured — not left for the next agent to re-discover.
`[eval: regression-clean]` When feature_list.json exists, existing `passes:true` features were spot-checked at each gate — regressions caught before compounding.

## 2. Convergence Protocols

The core discipline. For milestones, iterative loops, and plan completion.

### The Loop

Every iterative process follows this pattern:

```
measure → change → re-measure → compare → decide (continue / pivot / stop)
```

Strategic-looping provides the discipline to NOT skip the re-measure step, and to NOT repeat the same change when it didn't improve the metric.

### Quality Ratchet

1. **Pick a metric that fits the work** — test count, rubric score, finding count, error rate, coverage %, or whatever measures progress toward "done well."
2. **Establish a baseline** before the first iteration.
3. **After each iteration**, compare against baseline:
   - Metric improved → new level becomes the floor. Later regressions below it are treated as regressions.
   - Metric held → acceptable, but watch for stalls.
   - Two consecutive flat iterations → change strategy. Do not repeat the same approach a third time.
   - Metric declined → stop, diagnose, change approach before iterating again.
4. **Cap**: 3 iterations on the same gap without improvement → stop, reassess approach with user.

`[eval: convergence]` Did the quality metric improve or hold after this iteration?
`[eval: discipline]` Was the re-measure step actually performed, not skipped?

### Wiring Verification at Milestones

At milestone assessment, verify cross-component wiring — not just individual task completion:
- Pick 2 cross-component paths (e.g., "user action → API → database → response")
- Trace each through actual code — verify imports resolve and data flows correctly
- Individual tasks passing does not prove integration works

See `references/convergence.md` for the full protocol.

## 3. Iterative Loop Scaffolding

For processes like NER tuning, rubric improvement, skill refinement, or any tune-measure-compare loop:

1. **Define the metric** before starting. What number tells you whether the change helped?
2. **Measure baseline** before any changes. Record it explicitly.
3. **Make one change** per iteration. Multiple changes obscure which one mattered.
4. **Re-measure** immediately after the change. Do not batch changes and measure later.
5. **Compare** against baseline and previous iteration. Write down the delta.
6. **Decide**: continue (metric improved), pivot (metric flat/declined, try different approach), or stop (metric meets target or diminishing returns).

This is the scaffolding that prevents "I made changes and I think it's better" without evidence.

## Intensity

- **Light** (3-5 tasks, familiar code): gate at midpoint + before last task, convergence only at end
- **Standard** (5-10 tasks): full protocol
- **High** (10+ tasks, critical systems): gate every 2, convergence at multiple milestones

## Don't

- Loop without producing insight or measurable improvement
- Gate every task on convergence (that's what review loops are for)
- Skip the re-measure step because "the change obviously helped" — the point of the ratchet is evidence, not intuition
- Repeat the same approach after two flat iterations
- Revise the plan reflexively — only when evidence is clear. When revision is needed, return to `/writing-plans` rather than ad-hoc adjustments
- Execute parallelizable work sequentially — when iteration reveals independent tasks, dispatch via `/dispatching-parallel-agents`
