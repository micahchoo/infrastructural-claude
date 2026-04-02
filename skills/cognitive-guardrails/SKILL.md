---
name: cognitive-guardrails
description: Cognitive self-checks at decision points — bias interrupts, reasoning-quality gates, and strategic frameworks. Invoke with a check name as argument (e.g., "wysiati", "overconfidence", "artifact-challenge", "decompose"). Use when CLAUDE.md's Cognitive Guardrails section fires, when you catch yourself rationalizing, when strategic-looping or executing-plans hits a gate, or when any skill's [eval:] tag references a guardrail. 15 checks in two families — 11 bias interrupts (evidence gaps, substitution, overconfidence, reframing, source diversity, compound probability, sunk costs, success criteria, friction decisions, learning transfer, vague self-grading) and 4 strategic frameworks (artifact-challenge, decompose, invert, leverage).
---

# Cognitive Guardrails

Micro-interventions at decision points. Each check is a pause-and-reflect operation — ask the question, act on the answer, then continue.

## Usage

Invoke with the check name as argument: `Skill("cognitive-guardrails", args: "wysiati")`

If invoked without an argument, read the trigger table below and select the relevant check for your current situation. If no check applies, say so and continue — don't force a check.

## Trigger Table

| Check | When to fire | Question |
|-------|-------------|----------|
| `wysiati` | Before acting on evidence | What's missing from this picture? |
| `substitution` | After analysis or plan | Did I answer the actual question, or an easier one? |
| `overconfidence` | When building on factual claims | How do I know this? What's my source? |
| `reframe` | When reaching a conclusion | What's the strongest counter-argument? |
| `availability` | After 3+ searches from few source types | What haven't I looked at? |
| `conjunction` | When assessing compound likelihood | Am I following narrative plausibility or actual probability? |
| `sunk-cost` | Deep into execution, plan feels locked | Would a fresh agent with no history continue this path? |
| `criteria-precommit` | Before starting any evaluate/measure loop | Have I defined "acceptable" before running, or will I rationalize whatever I get? |
| `pivot-or-persist` | When encountering friction during execution | Am I making an explicit continue/pivot decision, or silently persisting? |
| `propagation` | After completing a task in a multi-task sequence | Did insights from completed work actually update my approach to remaining work? |
| `operationalize` | When making an evaluative claim | Am I citing specific, verifiable identifiers — or vague quality judgments? |
| `artifact-challenge` | Before acting on a completed plan/spec/design doc | Have I stress-tested this artifact's premises and assumptions? |
| `decompose` | When selecting an approach | What are the actual constraints vs. inherited assumptions? |
| `invert` | When evaluating a design or plan | What guarantees failure? What should be removed, not added? |
| `leverage` | When prioritizing among options | What's the ONE thing that makes everything else easier or unnecessary? |

**Already checked this trigger in this session?** Reference the prior result instead of re-running the full check.

**Check families:** Checks 1-11 are *bias interrupts* — they catch reasoning errors. Checks 12-15 are *strategic frameworks* — they improve what you're reasoning about. Use bias interrupts at reasoning-quality moments (gates, claims, evidence). Use strategic frameworks at approach-selection moments (brainstorming, plan creation, prioritization).

## Check Procedures

### wysiati
*What You See Is All There Is — Kahneman*

Ask: **What evidence would change my conclusion, and have I looked for it?**

Actions:
- List 2-3 things you'd expect to find if your conclusion were wrong
- Check at least one: `search_memories` for prior decisions, foxhound for unconsidered approaches, the codebase for counter-evidence
- If you find disconfirming evidence, state it before proceeding — don't bury it

### substitution
*Answering an easier question than the one asked*

Ask: **Restate the original question. Does my answer address it, or a related-but-different question?**

Actions:
- Write the original question in one sentence
- Write what your analysis actually answers in one sentence
- If they differ, name the gap and redirect

### overconfidence
*Treating uncertain beliefs as established facts*

Ask: **For each factual claim I'm building on: is this from docs, code, or memory? Or am I guessing?**

Actions:
- Tag each key claim: `[verified: source]` or `[assumed]`
- For any `[assumed]` claim that load-bears on the decision: look it up before proceeding
- If you can't verify and the claim matters, say so explicitly

### reframe
*Confirmation bias — seeking only supporting evidence*

Ask: **What's the strongest argument against my current recommendation?**

Actions:
- State the best counter-argument in its strongest form (steelman, don't strawman)
- If the counter-argument is stronger than your position, switch
- If it's weaker but non-trivial, acknowledge it in your response

### availability
*Over-weighting easily recalled information*

Ask: **Am I searching broadly, or just the sources that come to mind first?**

Actions:
- List which source types you've checked (code, docs, mulch, foxhound tiers, external)
- Identify at least one source type you haven't checked
- Query it before finalizing

### conjunction
*Narrative plausibility masking low compound probability*

Ask: **If this plan requires steps A, B, and C to all work: what's the actual probability?**

Actions:
- List the independent conditions that must hold
- Estimate probability for each (even roughly: likely/uncertain/unlikely)
- If 3+ "uncertain" conditions must all hold, flag the compound risk

### sunk-cost
*Continuing because of investment, not because of trajectory*

Ask: **Ignore everything done so far. Given what I know now, would I start this approach?**

Actions:
- If no: state what you'd do instead and why. Propose the pivot.
- If yes: continue, but note what signal would trigger re-evaluation
- The test is not "can this still work" but "is this still the best path"

### criteria-precommit
*Retroactive goal-setting — defining "good enough" to match what you got*

Ask: **Have I written down what success looks like before running the loop?**

Actions:
- Before any measure/evaluate/grade cycle: write the success criteria in concrete terms
- "Good quality" is not a criterion. "3+ alternatives with rejection reasons citing specific tradeoffs" is.
- After the loop: compare results to pre-committed criteria, not to your post-hoc feelings about them

### pivot-or-persist
*Silent persistence — continuing without deciding to continue*

Ask: **I hit friction. Am I making an explicit decision, or just... continuing?**

Actions:
- Name the friction: what went wrong, what's harder than expected
- State the options: continue current path, pivot to alternative, escalate to user
- Choose one with a stated reason — "continuing because X" not just continuing
- If you can't articulate why you're continuing, that's the signal to pivot

### propagation
*Learning without updating — completing tasks without transferring insights*

Ask: **What did I learn from the last task, and how does it change the remaining ones?**

Actions:
- Name one concrete insight from the completed work
- Check remaining tasks: does any need to change based on this insight?
- If yes, update the task description or approach before starting it
- If no insight transfers, that's fine — but the check must happen

### operationalize
*Vague self-grading — "this looks good" passing as evaluation*

Ask: **Can someone verify my evaluative claim without re-doing my work?**

Actions:
- Replace quality adjectives with specific identifiers: file paths, function names, counts, grep-able strings
- "The tests are thorough" → "12 test cases covering all 3 error branches in handler.ts:45-80"
- If you can't operationalize the claim, it's not a claim — it's an impression. Say so.

---

## Strategic Frameworks

These help you think about *what to do*, not *how you're thinking*. Use at approach-selection moments.

### artifact-challenge
*Unchallenged artifacts — plans and specs that pass review without stress-testing*

Ask: **Have I tried to break this artifact before acting on it?**

Apply 5 techniques, depth-calibrated by artifact size:
- **Quick** (<1000 words, <5 requirements): techniques 1+4 only, max 3 findings
- **Standard** (1000-3000 words, moderate complexity): techniques 1-4
- **Deep** (>3000 words, >10 requirements, or high-stakes domain): all 5, multi-pass on major decisions

Techniques:
1. **Premise challenging:** What is this artifact taking as given? Would a different starting premise lead to a fundamentally different design?
2. **Assumption surfacing:** List unstated assumptions. For each: what happens if it's wrong?
3. **Decision stress-testing:** For each key decision: what breaks if load/scale/edge-cases exceed expectations?
4. **Simplification pressure:** What can be removed while preserving the core value? What's earning its complexity?
5. **Alternative blindness:** Name one approach the artifact doesn't consider. Why was it excluded — by analysis or by oversight?

Output: list findings, tag each `blocking` (must address) or `advisory` (note and proceed).

### decompose
*First-principles breakdown — inherited assumptions masking actual constraints*

Ask: **What are the real constraints here, and which ones did I inherit without examining?**

Actions:
- List every constraint you're operating under
- For each: is this a physics-of-the-problem constraint, or a convention/habit/prior-decision?
- For inherited constraints: would violating them actually break something, or just feel wrong?
- **Ghost check:** Are any constraints ghosts? A ghost = a past constraint baked into the current approach that no longer applies. Ask "why can't we do X?" — if nobody can point to a current requirement, it's a ghost. Ghost constraints lock out options nobody thinks are available.
- Rebuild from the genuine constraints upward — the design may look different

### invert
*Inversion — solving forward when solving backward would reveal more*

Ask: **What guarantees failure? What should be removed rather than added?**

Actions:
- List 3 things that would guarantee this approach fails
- Check whether any of those conditions are currently true or trending true
- List what could be removed (features, abstractions, steps) that would improve the outcome
- Prefer subtraction over addition — complexity removed is more durable than complexity managed

### leverage
*Leverage — spreading effort evenly when one action dominates*

Ask: **What's the ONE thing that makes everything else easier or unnecessary?**

Actions:
- List candidate actions with their downstream effects
- For each: does completing this make 2+ other things easier or unnecessary?
- Identify the domino — the action with the highest downstream multiplier
- If no clear domino exists, that's a signal the decomposition needs work

## Cross-References

**Bias interrupts:**
- **brainstorming**: `reframe` and `substitution` fire during approach selection; `criteria-precommit` before any eval loop in the design phase
- **writing-plans**: `overconfidence` on architectural claims; `operationalize` on plan validation criteria
- **pattern-advisor**: `overconfidence` on pattern recommendations; `availability` on which codebooks were consulted
- **research-protocol**: `wysiati` before fan-out; `availability` during source selection; `propagation` after each research track completes
- **strategic-looping**: `sunk-cost` and `pivot-or-persist` at every pause-and-reflect gate; `propagation` between tasks
- **executing-plans**: `pivot-or-persist` when friction is encountered; `propagation` between tasks
- **eval-protocol**: `criteria-precommit` before grading; `operationalize` on all evaluative claims
- **hybrid-research**: `wysiati` before concluding investigation; `availability` on source diversity

**Strategic frameworks:**
- **brainstorming**: `decompose` during approach exploration; `leverage` when prioritizing which approach to recommend; `invert` when evaluating design proposals
- **writing-plans**: `artifact-challenge` on the spec before planning; `leverage` when sequencing execution waves
- **executing-plans**: `artifact-challenge` at Entry Gate on the plan document; `invert` when a task approach isn't working
- **gate-enforcer**: `artifact-challenge` wired into decision-check gate at plan→execute transitions

## When NOT to Use

- Don't force a check when none applies — that's its own form of substitution
- Don't invoke multiple checks in sequence as a ritual — pick the one that matches your situation
- If a check doesn't change your behavior, note that briefly and move on — the goal is reflection, not ceremony

`[eval: behavior-change]` The check produced a concrete action (looked something up, restated a question, named a counter-argument) — not just "I considered this and I'm fine."
`[eval: right-check]` The check invoked matched the actual cognitive situation — not a random selection from the list.
