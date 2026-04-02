# Fluent Compliance: Writing Skill Instructions That Models Actually Follow

## The Core Insight

LLMs are completion engines, not rule-followers. Instructions work only insofar as they make the desired completion the path of least resistance. When a rule adds friction without removing alternatives, the model routes around it — not defiantly, but because routing around it produces more fluent text.

**Design principle: make the desired behavior the lowest-token-cost continuation.**

Every instruction has a compliance cost — the tokens, mode switches, or anti-fluent actions required to follow it vs. skip it. Skills fail when the cost of complying exceeds the cost of rationalizing non-compliance.

## Three Failure Modes

### 1. Prohibition Without a Channel

A rule that suppresses a thought without giving it somewhere to go creates a choice: follow the rule and lose context, or violate the rule to preserve it. The model picks whichever is locally cheaper.

**Anti-pattern:** "One test at a time."
**Fix:** "One test at a time — `it.skip` the rest so they're preserved but not executed."

Every prohibition needs a constructive alternative. The alternative gives the suppressed information somewhere to land, so compliance doesn't mean losing it.

### 2. Attention Decay Across Repetitions

The first cycle gets full discipline. The second gets shortcuts. Rules that assume the model brings the same rigor to cycle N as cycle 1 are fragile. The model's own output from earlier cycles increasingly dominates the attention distribution, diluting the original instructions.

**Anti-pattern:** Same 10-step checklist enforced identically on every iteration.
**Fix:** Full rigor on cycle 1, abbreviated checklist on subsequent cycles, comprehensive review at the boundary (after all cycles complete).

Repetitive work is where compliance drifts, so that's where skills need to be most ergonomic — reduce friction on the nth iteration, not just the first.

### 3. Unacknowledged Edge Cases

When a rule has no answer for a real situation, the model rationalizes through it. "Test passes immediately? Fix the test." But negative assertions before a feature exists can't fail and can't be fixed — they're correct tests in the wrong phase. Unaddressed edge cases are implicit permission to improvise, and improvisation under a rigid skill is where mistakes happen.

**Anti-pattern:** Rules that cover the common case and leave edge cases unmentioned.
**Fix:** Explicitly name the edge cases and say what to do. "If the test can't meaningfully fail yet because the feature doesn't exist, mark it as `[pending]` and move to implementation."

## Design Heuristics

### Templates Over Mandates

A template with sections to fill in is cheaper to follow than a behavioral rule to remember.

| Mandate (expensive) | Template (cheap) |
|---------------------|------------------|
| "Always include error handling" | Provide a scaffold with `## Error Cases` already present — model fills blanks |
| "Document your assumptions" | `# Assumptions: ___` in the output format — blank-filling is the model's natural mode |

**Unification with channels:** A template can simultaneously serve as both a mandate replacement AND a channel for suppressed thought. `[source A: <date>, position: <claim>] vs [source B: <date>, position: <claim>]` replaces the mandate ("record contradictions") and channels the suppressed information (where to put the contradiction). When you can collapse a mandate-fix and a channel-fix into one template, do it — one construct, two violations resolved.

### Channels for Suppressed Thoughts

Every "don't do X" needs a "put X here instead."

| Suppression only | With channel |
|-----------------|-------------|
| "Don't work on other tasks" | "Don't work on other tasks — `# PARKED:` for things to return to" |
| "Don't guess at the answer" | "Don't guess — instead write `[UNKNOWN: what I'd need to verify]`" |

**Standard channel vocabulary:** Rather than inventing a bespoke channel for each prohibition, establish a small vocabulary and reference it. This amortizes the cognitive cost across the entire skill tree:

| Channel | Use for |
|---------|---------|
| `[SNAG] description` | Unexpected behavior, conflicts, surprises — emitted inline when they happen |
| `[PARKED: topic]` | Work or thoughts to return to later in this session |
| `[DEFERRED: topic]` | Work explicitly pushed to a future session or issue |
| `[UNKNOWN: what I'd need to verify]` | Claims the model can't confirm — prevents silent guessing |
| `[PENDING: condition]` | Valid work that can't proceed yet — not wrong, just early |

Define the vocabulary once at the tree level. Individual prohibitions then just say "→ `[PARKED]`" instead of each inventing their own channel. One-time cost, tree-wide payoff.

### Front-Load Critical Rules

Instructions compete with generated content for attention. As output grows, early instructions lose relative salience. Place the rules most critical to correctness in the first 50 lines. Nice-to-haves go later.

**Ordering principle:** Sort rules by the cost of violation, not by logical sequence. A formatting preference violated is cheap; a safety check skipped is expensive. The expensive ones go first.

**Forward-reference as lightweight front-loading:** When moving a rule would strip it from its explanatory context, a 1-line forward-reference near the top is strictly lighter than relocation. "**Enforcement:** Every line of production code must have a failing test first. (See Final Rule section.)" raises salience without losing the reasoning that surrounds the rule in its original position. The model sees the constraint early; the explanation remains where it makes sense.

**Authoring bias — conclusion gravity:** Critical rules tend to gravitate to the end of skills because they feel like the conclusion of a reasoning chain ("...and therefore, never do X"). This is a predictable bias: 9 of 33 files in a recent audit placed their most expensive rule last. When you finish writing a skill, check whether the last section is actually the most important one. If so, add a forward-reference at the top.

### Graceful Degradation Across Repetitions

Design for the reality that cycle N gets less attention than cycle 1.

- **Cycle 1:** Full procedure, all checks
- **Cycles 2-N:** Abbreviated — only the steps that vary between cycles
- **Boundary (after all cycles):** Comprehensive review covering what the abbreviated cycles may have missed

This isn't lowering standards — it's allocating the model's finite attention budget where it has the most impact.

**Append-not-restructure:** You don't need to restructure a skill into parallel paths (a cycle-1 section and a cycles-2+ section). A single line appended after the full checklist is sufficient:

> **Abbreviated form (cycles 2+):** Steps X–Y only. Full form only if previous cycle failed.

The model reads both the full and abbreviated form and picks the cheaper continuation — which is exactly the core principle. No restructuring needed; one line after the existing checklist does the job.

### Externalize to Infrastructure

The most reliable rule is one that doesn't depend on the model's attention at all.

| Prompt-based (fragile) | Infrastructure-based (reliable) |
|------------------------|-------------------------------|
| "Remember to run tests before committing" | Hook that blocks commit tool unless test output is in context |
| "Check for bias in your reasoning" | PreToolUse hook that injects a guardrail prompt at tool boundaries |
| "Don't skip the review step" | Executing-plans skill with mandatory review gate between tasks |

Move rules from "the model must choose to comply" to "the infrastructure won't let the model proceed without complying." Prompt-level instructions should handle nuance and judgment; infrastructure should handle discipline.

**Text-then-infrastructure staging:** Externalization isn't always all-or-nothing. When a rule could be a hook but you haven't built one yet, ship the text fix first (1-line insert, ships immediately) and build the hook later (more durable, prevents drift). These are stages, not alternatives:

1. **Text fix (MVP):** Add a concrete action to the skill — "Run `ctx stats` after each task" instead of "estimate your context usage." Cheaper to follow than a vague mandate; ships in minutes.
2. **Infrastructure (graduation):** Build the hook that enforces it automatically. The text fix remains as documentation of intent; the hook makes compliance structural.

Don't wait for infrastructure to fix a compliance problem. The text fix reduces violations immediately while you build the durable solution.

### Manage Prohibition Density

Each prohibition constrains the model's continuation space. When prohibitions accumulate, the aggregate "compliant path" becomes expensive enough that the model rationalizes through the weakest link. This is superlinear, not additive — three prohibitions don't cost 3x, they cost more, because each one further narrows the space of fluent continuations.

**Heuristic:** If a skill has more than ~3 prohibitions, audit for compound pressure. Signs:

- The model follows most rules but consistently violates the same one (the weakest link)
- Transcript review shows rationalized exceptions clustering around the same prohibition
- The model follows all rules early but starts combining or skipping the cheapest-to-skip ones late

**Remediation options:**

1. **Convert prohibitions to templates** — a scaffold with the right structure makes "don't do X" unnecessary because X has no slot
2. **Merge related prohibitions** — "don't skip review AND don't self-approve AND don't merge without CI" → one gate that blocks the merge tool until review + CI are confirmed
3. **Externalize the most-violated one** — if one prohibition consistently fails, it's the weakest link; move it to infrastructure

## The Litmus Test

For any instruction you're about to write, ask:

> Imagine the model is 2000 tokens into following this skill. It hits this rule. Is following the rule *easier* than producing a plausible-sounding continuation that skips it?

If not, the rule needs reshaping. Options:
1. **Make it a template** (blank-filling is always easy)
2. **Add a channel** (give suppressed information somewhere to go)
3. **Move it earlier** (closer to the start = higher salience) — or add a forward-reference
4. **Externalize it** (hook or gate instead of instruction) — or ship a text fix now, hook later
5. **Accept graceful degradation** (full check on first pass, abbreviated on later passes) — one appended line is enough
6. **Reduce prohibition density** (merge, convert, or externalize if >3 prohibitions)

## Relationship to "Explain the Why"

Skill-creator's existing guidance — "explain the reasoning so the model understands why the thing you're asking for is important" — is necessary but not sufficient. Understanding *why* helps the model weight a rule higher. But the *shape* of the instruction matters as much as the reasoning behind it.

A well-explained rule that's structurally expensive to follow will still get rationalized away under attention pressure. Explaining the why raises the salience of the rule; fluent compliance reduces the cost of following it. You need both.

## Recognizing Compliance Failure in Transcripts

When reviewing skill test runs, these patterns indicate a fluency-compliance mismatch:

- **Late-stage shortcuts:** The model follows the procedure carefully at first, then starts combining or skipping steps
- **Phantom compliance:** The model produces output that looks like it followed the rule but on closer inspection didn't (e.g., a "review" section that just restates the work rather than actually reviewing it)
- **Rationalized exceptions:** The model explains why this particular case doesn't need the check — especially when the explanation is plausible but the rule was meant to apply anyway
- **Format drift:** Structured output matches the template early but gradually diverges as the model's own momentum takes over
- **Weakest-link clustering:** Multiple prohibitions present, but violations cluster on the same one — the cheapest to skip

Each of these is a signal that the rule is structurally too expensive at the point where it failed, not that the model "forgot" or "didn't understand."

## Remediation Patterns

When auditing an existing skill tree for compliance issues, these patterns cover ~95% of fixes:

| Pattern | Weight | When to use |
|---------|--------|-------------|
| **1-line channel insert** | 1 line | After any "don't" — add where the suppressed thought goes |
| **1-line abbreviated form** | 1 line | After any checklist — add "Cycles 2+: steps X–Y only" |
| **1-line forward-reference** | 1 line | Near the top — add pointer to a critical rule buried late |
| **1-line decision rule** | 1 line | After an edge-case gap — add "If X, then Y; otherwise Z" |
| **Template block** | 2–3 lines | Replace behavioral mandate with scaffold to fill in |
| **Replace vague with concrete** | 0 net | Change "estimate X" to "run `command` to check X" |

Fixes are almost always additive (append after offending text), not structural. Average weight across a 61-violation audit was 1.4 lines per fix. This means compliance remediation is low-risk — no restructuring, no regressions, and it can be batched.
