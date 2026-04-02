---
name: product-strategy
description: >-
  Product lifecycle orchestration — the outer loop that wraps build pipelines with
  strategic thinking. Use when deciding WHAT to build and WHETHER what was built succeeded.
  Triggers on: "what should we build next", "prioritize the backlog", "who are our users",
  "competitive analysis", "measure success", "product roadmap", "are we building the right
  thing", "product review", "post-launch retrospective", "user research synthesis",
  "reprioritize", "define KPIs", "product vision". Also triggers when brainstorm-to-ship
  or product-to-ship completes and measurement is needed. Do NOT trigger for: designing
  a specific product's UI (use product-design); brainstorming a single feature (use
  brainstorming); writing implementation plans (use writing-plans); UX auditing code
  flows (use shadow-walk directly); or pure market research without product context
  (use hybrid-research).
---

# Product Strategy

The outer product lifecycle loop. Build pipelines (brainstorm-to-ship, product-to-ship)
answer "how do we build this?" — this skill answers "what should we build, for whom,
and did it work?"

This is the UX Engineer's strategic lens: bilingual in pixels and pointers, advocating
for user experience while respecting engineering constraints and business goals.

## When This Skill Fires

- **Discovery**: "Who are our users?", "What does the competitive landscape look like?"
- **Prioritization**: "What should we build next?", "Reprioritize the backlog"
- **Measurement**: "Did this feature succeed?", "Post-launch review"
- **Strategic pivot**: "Are we building the right thing?", "Product direction review"
- **Cycle start**: Beginning a new product initiative from scratch
- **Cycle close**: Build pipeline completed, need to evaluate outcomes

## When This Skill Does NOT Fire

- Designing a product's UI → `product-design`
- Brainstorming a single feature → `brainstorming`
- Implementation planning → `writing-plans`
- Auditing UX in existing code → `shadow-walk`
- Pure technical research → `hybrid-research`

## The Outer Loop

```
         ┌──────────────────────────────────────────────┐
         │           PRODUCT LIFECYCLE                   │
         │                                               │
         │   ┌──────────┐    ┌────────────┐             │
    ────►│   │ DISCOVER │───►│ STRATEGIZE │──┐          │
    │    │   └──────────┘    └────────────┘  │          │
    │    │     research        vision, KPIs   │          │
    │    │     personas        priorities     ▼          │
    │    │                              ┌──────────┐    │
    │    │                              │ DISPATCH │    │
    │    │                              └────┬─────┘    │
    │    │                                   │          │
    │    │              ┌────────────────────┘          │
    │    │              ▼                                │
    │    │   ╔═══════════════════════╗                   │
    │    │   ║  BUILD PIPELINE       ║                   │
    │    │   ║  brainstorm-to-ship   ║                   │
    │    │   ║  or product-to-ship   ║                   │
    │    │   ╚═══════════╤═══════════╝                   │
    │    │               │                               │
    │    │               ▼                               │
    │    │        ┌───────────┐    ┌────────────┐       │
    │    │        │  MEASURE  │───►│   LEARN    │       │
    │    │        └───────────┘    └─────┬──────┘       │
    │    │          signals,        synthesis,           │
    │    │          KPI eval        reprioritize         │
    │    └──────────────────────────────┘                │
    │                                   │                │
    └───────────────────────────────────┘
                    next cycle
```

Each phase can be entered independently. A user doing competitive analysis enters at
Discover. A user asking "did our launch succeed?" enters at Measure. The loop connects
them — you don't need to run the full cycle every time.

## Checklist

Create a task for each relevant phase and complete in order:

1. **Discover** — user/market research, personas, competitive analysis
2. **Strategize** — vision, KPIs, prioritization framework, roadmap
3. **Dispatch** — route to build pipeline with strategic context
4. **Measure** — post-build signal collection, KPI evaluation
5. **Learn** — synthesis, strategy update, next cycle trigger

**Abbreviated form (cycles 2+):** Skip Discover unless new research is needed. Start at
Strategize with updated inputs from the Learn phase.

---

## Phase 1: Discover

**Goal**: Build an evidence-based understanding of users, market, and opportunity before
committing to what to build.

Before starting fresh research, check what already exists: foxhound `search` for prior decisions and competitive intel, `ml search` for past product research, `sd list --label "strategic"` for the existing strategic backlog.

### 1a: User Research Synthesis

The useful personas are behavioral archetypes, not demographic profiles. A persona earns its place when it changes a design decision.

Work through these one at a time:
- Who uses this product today? (Or: who would use it?)
- What are they trying to accomplish? (Jobs-to-be-done, not features)
- Where do they get frustrated? (Pain points with evidence, not assumptions)
- What workarounds do they use? (Reveals unmet needs)
- What would make them switch from their current solution?

**Template — `product/strategy/personas/`:**
```markdown
# [Persona Name] — [Role/Archetype]

## Behavioral Profile
- **Primary job**: [what they're trying to accomplish]
- **Current tools**: [what they use today]
- **Pain points**: [specific frustrations, with evidence source]
- **Workarounds**: [what they do to cope]
- **Switch trigger**: [what would make them change]

## Design Implications
- [How this persona's needs shape product decisions]

## Evidence
- [Source: interview/survey/analytics/observation] — [date]
```

`[eval: persona-specificity]` Each persona includes specific behaviors and pain points
traceable to evidence — not demographic stereotypes or assumed needs. "Power user who
wants advanced features" fails. "Analyst who exports CSV weekly because the dashboard
doesn't support date-range comparison" passes.

### 1b: Competitive Landscape

Map the space, not just the players. What forces shape this market?

**Dispatch**: Use `hybrid-research` for competitive research — it handles multi-source
investigation. Frame the research as: "Map competitors in [domain], focusing on:
approach differences, unmet user needs, and technical differentiation."

**Template — `product/strategy/competitive-landscape.md`:**
```markdown
# Competitive Landscape — [Domain]

## Market Forces
- [Force 1]: [how it shapes product decisions]

## Competitors
### [Competitor Name]
- **Approach**: [how they solve the problem]
- **Strengths**: [specific capabilities]
- **Gaps**: [what users complain about — evidence source]
- **Differentiation opportunity**: [where we can be meaningfully different]

## Positioning
- [Where we sit in this landscape and why]
```

`[eval: competitive-differentiation]` Competitive analysis identifies specific
differentiators grounded in user needs — not generic "better UX" or "more features."
Each differentiator traces to a persona pain point from 1a.

### 1c: Opportunity Framing

Synthesize research into opportunity statements: "For [persona], who [pain point],
our product [differentiation] unlike [current alternatives]."

`bias:wysiati` — What user needs are you NOT seeing? What personas did you not talk to?
What competitors did you not analyze? Name the gaps explicitly before proceeding.

`bias:conjunction` — If the opportunity depends on multiple conditions being true
simultaneously (growing market AND underserved segment AND technical feasibility),
estimate each independently. Narrative coherence inflates compound probabilities.

---

## Phase 2: Strategize

**Goal**: Convert research into actionable strategy — vision, measurable goals,
prioritized roadmap.

### 2a: Product Vision

One paragraph that answers: What does this product do, for whom, and why now?
The vision constrains everything downstream — it's the "are we building the right
thing?" reference point.

Record the vision as a mulch decision (`scope:product,source:product-strategy,lifecycle:active`) so future sessions can reference it without re-deriving.

### 2b: Success Metrics (KPIs)

Every initiative needs measurable outcomes defined BEFORE building. "Ship it" is not
success. What changes in the world when this works?

**The three-layer model:**
| Layer | Question | Example |
|-------|----------|---------|
| **Outcome** | What user behavior changes? | "Users complete onboarding in <5 min" |
| **Output** | What did we ship? | "Onboarding flow with 3 steps" |
| **Activity** | What did we do? | "Designed 5 screens, wrote 12 tests" |

Most teams measure Activity and call it success. The interesting question is always
at the Outcome layer — what changed for the user? Output is supporting evidence.
Activity is noise.

**Template — each KPI:**
```markdown
### [KPI Name]
- **Metric**: [specific, measurable thing — number, ratio, time]
- **Baseline**: [current value, or "none" for new products]
- **Target**: [what success looks like]
- **Measurement method**: [how you'll actually measure it]
- **Leading indicator**: [early signal before the outcome metric moves]
- **Timeframe**: [when to evaluate]
```

`[eval: metric-measurability]` Every KPI has a specific measurement method and target
value. "Increase engagement" fails. "DAU/MAU ratio > 0.3 within 60 days, measured via
analytics event `session_start`" passes.

`bias:overconfidence` — How do you know this metric matters? What's the evidence that
moving this number improves user outcomes? If the answer is "it's standard" — that's
training data, not evidence. Look it up.

### 2c: Prioritization

Use a framework, not intuition. The framework makes trade-offs explicit and debatable.

Read `references/prioritization-frameworks.md` for RICE, Impact-Effort, and MoSCoW
with worked examples. Choose the framework that fits the decision context:

| Context | Framework | Why |
|---------|-----------|-----|
| Many competing features, need to rank | RICE | Forces quantification of reach and confidence |
| Quick triage, binary keep/cut | MoSCoW | Fast, stakeholder-friendly |
| Few options, need depth | Impact-Effort | Visual, good for small teams |
| Ongoing backlog management | Weighted scoring | Customizable dimensions |

Record each prioritization decision as a seed (`strategic,persona:<name>,kpi:<metric>` labels) with evidence, impact, and confidence.

`[eval: priority-evidence]` Each prioritized item cites specific research evidence from
Phase 1. "Users want this" without a source fails. "3/5 interviewed analysts mentioned
CSV export pain (1b, competitive gaps)" passes.

### 2d: Roadmap

The roadmap is a sequence of bets, not a promise. Each entry is:
- What we're betting on (feature/initiative)
- Why (which persona, which KPI)
- How we'll know it worked (success metric from 2b)
- What we're NOT doing (explicit trade-offs)

Write to `product/strategy/roadmap.md`. This feeds into brainstorming and product-design
as strategic context.

`bias:substitution` — Does this roadmap answer the user's actual strategic question, or
have you substituted "what's easy to build" for "what should we build"? Compare each
roadmap entry against the opportunity framing from 1c.

---

## Phase 3: Dispatch

**Goal**: Route to the right build pipeline with full strategic context.

This is the bridge between strategy and execution — the UXE translation layer.

### Routing Decision

| Signal | Route to | Why |
|--------|----------|-----|
| New product from scratch | `product-design` → `writing-plans` | Needs vision-to-handoff pipeline |
| New feature in existing product | `brainstorming` → `writing-plans` | Needs design within constraints |
| Multiple independent features | `seeds` + parallel dispatch | Needs DAG-aware scheduling |
| Redesign of existing area | `brainstorming` (brownfield) → `product-design` | Needs both discovery and design |

### Context Transfer

The downstream skill receives a **strategic brief** — not raw research, but the
distilled decisions that constrain the work:

```markdown
## Strategic Brief (from product-strategy)

**Target persona**: [name] — [one-line behavioral summary]
**Success metric**: [KPI name] — baseline [X], target [Y], timeframe [Z]
**Priority rationale**: [why this, why now — 1-2 sentences]
**Constraints**: [what's explicitly out of scope]
**Competitive context**: [1-sentence positioning vs. alternatives]
```

Attach this brief to the brainstorming or product-design invocation. It becomes a
Locked Decision that downstream skills must respect.

A strategic brief sitting in a file is not dispatch — the value comes from actually
invoking the downstream skill with it. After writing the brief, invoke the skill from
the routing table above and name it explicitly: "Invoking `product-design` with
strategic brief."

`[eval: context-transfer]` The downstream skill received persona, success metric,
priority rationale, and constraints — not just a feature description. The strategic
brief is present in the design doc or plan.

`[eval: dispatch-explicit]` The dispatch phase explicitly names and invokes the
downstream skill (product-design, brainstorming, or writing-plans) — producing a
strategic brief without routing to a named skill fails.

Before dispatching, ensure each roadmap item is tracked as a seed (`sd create` with `strategic,cycle:<N>` labels) so the build pipeline has traceability back to KPIs and personas.

---

## Phase 4: Measure

**Goal**: After a build cycle completes, evaluate outcomes against the success criteria
defined in Phase 2.

This phase fires when:
- A build pipeline (brainstorm-to-ship or product-to-ship) reaches `land` stage
- The user asks "did this work?" or "post-launch review"
- A KPI timeframe expires

### 4a: Signal Collection

Gather evidence from multiple signal types — quantitative alone lies, qualitative alone
doesn't scale.

| Signal Type | Source | Tool |
|-------------|--------|------|
| **Quantitative** | Analytics, metrics, usage data | User provides or `hybrid-research` |
| **Qualitative** | User feedback, support tickets, interviews | User provides |
| **UX audit** | Flow tracing through implemented code | `shadow-walk` dispatch |
| **Technical** | Performance, error rates, reliability | Codebase analysis |

**Dispatch shadow-walk** for UX signal: "Walk the [feature] flow from [persona]'s
perspective. Focus on: [success metric] — what in the flow supports or undermines it?"

### 4b: KPI Evaluation

For each KPI defined in Phase 2:

```markdown
### [KPI Name] — [PASS / PARTIAL / MISS]
- **Target**: [what we aimed for]
- **Actual**: [what happened]
- **Leading indicator**: [what the early signal showed]
- **Attribution confidence**: [H/M/L — how sure are we this was caused by our work?]
- **Surprises**: [anything unexpected — positive or negative]
```

`[eval: measurement-baseline]` Every KPI evaluation compares against the pre-defined
target from Phase 2, not a post-hoc rationalization. The Phase 2 document is referenced
by path.

`[eval: signal-diversity]` Measurement uses 2+ signal types. Pure analytics without
qualitative input fails. Pure opinion without data fails.

`bias:substitution` — Are you measuring what matters, or what's easy to measure? Compare
the measured KPIs against the Outcome layer from 2b. If you're only reporting Output or
Activity metrics, you've substituted.

### 4c: Record Outcomes

Record each outcome as a mulch decision (`outcome:<pass|partial|miss>,cycle:<N>` tags) capturing the initiative name, KPI delta, and key insight. Close related seeds with matching outcome reasons. This is what makes the next cycle's Discover phase useful — without recorded outcomes, strategy becomes folklore.

---

## Phase 5: Learn & Iterate

**Goal**: Synthesize measurement into strategic updates. Close the loop.

### 5a: Retrospective Synthesis

Three questions:
1. **What did we learn about our users?** Do personas need updating? Did we discover
   new pain points or validate assumptions?
2. **What did we learn about our product?** Did the solution address the actual problem?
   What surprised us?
3. **What did we learn about our process?** Did the build pipeline work? Were estimates
   accurate? Where did we waste effort?

### 5b: Strategy Update

- Update personas with new evidence
- Update competitive landscape if market shifted
- Reprioritize remaining roadmap items based on learnings
- Archive completed items, add new opportunities

### 5c: Next Cycle Trigger

Route the next iteration:
- **Iterate on same area** → return to Phase 2 (Strategize) with updated inputs
- **New area** → return to Phase 1 (Discover) for new research
- **Pause** → no immediate next cycle; strategy artifacts remain for future reference

`[eval: learning-propagation]` Insights from measurement update the strategy document
and seed priorities. "We learned X" without a corresponding change to personas, roadmap,
or backlog fails. Learning that doesn't propagate is wasted.

`bias:sunk-cost` — Would a fresh team, seeing only the measurement data, continue this
product direction? Past investment is not a reason to persist with a direction that
isn't working.

---

## The UXE Bridge

This isn't a phase — it's a lens applied throughout. The UX Engineer thinks in both
pixels and pointers, translating between three domains:

| Domain | Asks | This skill's job |
|--------|------|------------------|
| **User experience** | Is this usable? Delightful? Accessible? | Personas, shadow-walk dispatch, UX KPIs |
| **Engineering** | Is this feasible? Maintainable? Performant? | Architecture awareness via domain-codebooks, technical constraints in briefs |
| **Business** | Is this valuable? Viable? Differentiated? | Competitive analysis, outcome metrics, prioritization |

At every phase, ask: "Would the UX engineer, the engineering lead, and the PM all
sign off on this decision?" If any lens is missing, the decision is incomplete.

**Diffusion checkpoints** — these aren't formal gates, but questions to ask at
natural boundaries:
- Before dispatching to build: "Does the engineer understand WHY this matters to users?"
- After measurement: "Does the PM know WHERE the UX fell short?"
- During prioritization: "Does the designer know WHAT the technical constraints are?"

---

## Entry Modes

| User signal | Enter at | Skip |
|-------------|----------|------|
| "New product idea" | Phase 1 (Discover) | Nothing — full cycle |
| "Reprioritize the backlog" | Phase 2 (Strategize) | Discover (unless research is stale) |
| "We just shipped X" | Phase 4 (Measure) | Discover, Strategize, Dispatch |
| "What did we learn from launch?" | Phase 5 (Learn) | Earlier phases |
| "Product direction review" | Phase 2 + Phase 5 hybrid | Discover (unless research needed) |

If entering mid-cycle, check for existing artifacts:
- `product/strategy/personas/` — skip 1a if fresh
- `product/strategy/roadmap.md` — skip 2d if current
- `product/strategy/kpis.md` — needed for Phase 4

---

## Diffusion Map

How product-strategy thinking permeates other skills even when this skill is not
directly invoked:

| Skill | Diffusion point | What changes |
|-------|-----------------|--------------|
| **brainstorming** | After "explore project context" | Check for strategic brief; if present, constrain design space to align with persona needs and KPIs |
| **product-design** | Phase 1 Vision | If `product/strategy/` exists, load personas and competitive positioning instead of asking from scratch |
| **writing-plans** | Input Validation | If strategic brief attached, verify plan tasks trace to KPIs |
| **executing-plans** | Subagent context | Include persona context in `<files_to_read>` when task is user-facing |
| **shadow-walk** | Flow selection | If personas exist, prioritize flows that target primary persona's jobs-to-be-done |
| **requesting-code-review** | Review criteria | If KPIs defined, check whether implementation supports measurement |

---

## Key Principles

- **Evidence over intuition** — every strategic decision cites research, not assumption
- **Outcomes over outputs** — measure what changed for users, not what was shipped
- **Explicit trade-offs** — every "yes" implies a "no"; document both
- **Cyclical, not linear** — strategy is never "done"; each cycle informs the next
- **Three-lens validation** — UX, engineering, and business all need representation

