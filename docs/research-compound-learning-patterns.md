# Compound Learning Across Sequential Design Phases

Research findings on tech-agnostic patterns for how learning compounds across phases.
Date: 2026-03-31

---

## 1. Double-Loop Learning (Argyris & Schon, 1978)

### Core Mechanism
Single-loop learning corrects errors within existing rules. Double-loop learning modifies the rules themselves. The thermostat analogy: single-loop turns on heat when temp drops below 69F; double-loop asks "why am I set to 69F?"

The learning happens at two levels:
- **Loop 1**: Actions produce outcomes; mismatches trigger corrective action within existing governing variables (goals, assumptions, decision rules)
- **Loop 2**: Mismatches trigger re-examination of the governing variables themselves

Argyris identified two behavioral models:
- **Model I** (default): Unilateral control, minimize losing, suppress negative feelings, be rational. Produces "organizational defensive routines" — patterns that prevent embarrassment/threat but also prevent learning. Self-sealing.
- **Model II** (required for double-loop): Valid information, free and informed choice, internal commitment. Requires making reasoning explicit and testable.

The critical insight: **organizations resist double-loop learning not from ignorance but from skilled incompetence** — people are highly skilled at Model I defensive reasoning, and that skill actively prevents the deeper learning.

### Failure Modes
1. **Skilled incompetence**: People are too good at defending existing assumptions. The better they are at single-loop (smart professionals especially), the worse they are at double-loop.
2. **Espoused theory vs theory-in-use gap**: Organizations say they want to question assumptions (espoused) but their actual behavioral patterns (theory-in-use) punish it. This gap is invisible to participants.
3. **Organizational defensive routines**: Policies/practices that prevent embarrassment or threat, but simultaneously prevent learning. Self-reinforcing: discussing the routine is itself threatening.
4. **Undiscussability**: The most important governing variables are often undiscussable, and the fact that they're undiscussable is itself undiscussable.

### Structures That Make It Actually Happen
- **External facilitation**: Someone outside the system who can name the defensive routines without being subject to them
- **Action science methodology**: Record actual conversations, compare to espoused theories, identify gaps
- **Publicly testing assumptions**: The minimum structural requirement — any process that forces "here's what I assumed, here's why, here's how you could show me I'm wrong"
- **Separating the person from the governing variable**: "This assumption may need changing" vs "you were wrong"

### Minimal Viable Version
A structured moment at phase boundaries where participants must articulate: (1) what governing variables/assumptions drove decisions in the last phase, (2) which of those should be re-examined before the next phase. The act of making assumptions explicit is itself the intervention. Writing beats talking — it forces precision and creates an artifact.

Historical precedent: The Western Approaches Tactical Unit (WATU) in WWII successfully practiced double-loop learning by continuously revising anti-submarine tactical doctrine as new technology emerged. Key enabler: they had explicit doctrine documents that could be revised, not just tacit practice.

---

## 2. After-Action Reviews (US Army)

### Core Mechanism
Four questions, applied immediately after an event by the participants themselves:
1. **What was planned?** (Intent and expected outcome)
2. **What actually happened?** (Observed outcome — factual, not evaluative)
3. **Why was there a difference?** (Root cause analysis of the gap)
4. **What will we do differently next time?** (Concrete action, owned by participants)

The mechanism is the **gap between intent and outcome**. Not "what went wrong" (blame-oriented) but "what was the difference between plan and reality" (learning-oriented). This reframe is load-bearing.

Key structural features:
- **Participants review their own performance** — recommendations for others are explicitly not produced
- **No blame, no reprimands** — antithetical to purpose. The AAR is forward-looking.
- **Facilitator-led** (formal) or **team-leader-led** (informal/short-cycle)
- **Cascaded in larger operations** — each level reviews its own performance within the larger event
- **Occurs within a cycle**: intent → planning → preparation → action → review → (feeds next intent)

### Evidence on Effectiveness
- Adopted across all US military services and widely in business as knowledge management tool
- NHS (UK) adopted AARs for patient safety. Prof. Aidan Halligan (UCLH, 2011): "Healthcare is dominated by the extreme, the unknown and the very improbable with high impact consequences... Educating staff on the use of AAR enables team working and cues behaviours through allowing an emotional mastery of the moment and learning after doing."
- Key finding: AARs work because the learning is **carried forward by the same participants** who will execute the next action. No translation loss to a different team.

### Failure Modes
1. **Blame culture**: If participants fear consequences, they self-censor. The gap analysis becomes fiction.
2. **Conducted too late**: Temporal distance degrades memory and emotional engagement. Must happen close to the event.
3. **No action follow-through**: If "what will we do differently" doesn't actually change the next plan, the process becomes ritual.
4. **Confusion with debriefs or post-mortems**: AARs are distinct — they begin with intended vs actual comparison (not open-ended discussion), and are strictly about participants' own actions (not producing recommendations for others).
5. **Skipping for "successful" events**: Some of the richest learning comes from events that went well — understanding *why* it worked is as valuable as understanding failure.

### Minimal Viable Version
Three elements after any completed phase: (1) one sentence on what was intended, (2) one sentence on what actually happened, (3) one concrete change for next time. Written by the same person/team who will do the next phase. The constraint is that item 3 must be **specific and actionable**, not aspirational.

---

## 3. Design Rationale Capture (Rittel, Conklin, Toulmin)

### Core Mechanism
Capture not just the decision, but the **decision space**: what alternatives were considered, what arguments supported/opposed each, and what criteria resolved the choice. The canonical framework is IBIS (Issue-Based Information System, Kunz & Rittel, 1970):
- **Issue**: A question to be resolved
- **Position**: A possible resolution to the issue
- **Argument**: Evidence for or against a position (pro or con)

This creates a graph of reasoning, not just a log of decisions.

Toulmin's model adds structure to arguments: Claim → Data → Warrant → Backing → Qualifier → Rebuttal. The rebuttal is critical — it captures the conditions under which the argument fails.

Software implementations: gIBIS (graphical IBIS), Compendium, QOC (Questions Options Criteria), DRL (Decision Representation Language), DRIM (Design Recommendation and Intent Model).

### Rationale Capture Methods (Lee, 1997)
| Method | How | Advantage | Cost |
|--------|-----|-----------|------|
| **Reconstruction** | Record raw (video), restructure later | Doesn't disrupt designer | High cost, bias of reconstructor |
| **Record-and-replay** | Capture as it unfolds (video, chat, email) | Preserves real discussion | Low structure, hard to search |
| **Methodological byproduct** | Rationale falls out of a structured design process | Low marginal cost | Hard to design the right schema |
| **Apprentice** | System with knowledge base asks questions when confused | Active elicitation | Requires rich prior KB |

### Design Rationale Decay — Why Captured Rationale Stops Being Useful
This is the central unsolved problem in the field. Key factors:

1. **Capture overhead kills compliance**: If capturing rationale is separate from doing design, it gets skipped under time pressure. The "methodological byproduct" approach (rationale as side-effect of the design process) is the only one with sustainable capture rates, but it's hardest to design.
2. **Retrieval problem**: Captured rationale is only useful if you can find the relevant rationale when you need it. As rationale accumulates, search/navigation becomes the bottleneck. Semi-formal representations (IBIS-style) outperform both informal (free text) and formal (logic-based) because they balance human readability with machine searchability.
3. **Context erosion**: Rationale captured at time T assumes contextual knowledge that may not exist at time T+N. The "why" made sense to people who shared the design context but is opaque to newcomers. Rationale needs **grounding** — explicit links to the specific constraints and context that made the argument valid.
4. **Granularity mismatch**: Too coarse (just decisions) loses the reasoning. Too fine (every micro-decision) creates noise that buries the important reasoning. The useful granularity is **issues that had genuine alternatives** — where the team actually deliberated.

### Applications That Work
Design rationale has proven value for: verification (does the design reflect intent?), evaluation (comparing alternatives), maintenance (what must change when constraints change?), reuse (adapting past designs), teaching (onboarding newcomers), and communication (shared understanding during design).

### Minimal Viable Version
For each significant design decision, capture: (1) the question being answered, (2) the options considered (minimum 2), (3) which was chosen and the single strongest reason why, (4) what would have to change for the rejected option to become correct. Item 4 is the highest-value element — it's the cheapest form of rationale that survives context erosion because it specifies concrete conditions, not abstract reasoning.

---

## 4. Toyota A3 / PDCA / Improvement Kata

### Core Mechanism — PDCA
Plan-Do-Check-Act (Shewhart/Deming cycle). Based on the scientific method: hypothesis → experiment → evaluation.

- **Plan**: Establish objectives and processes for desired results
- **Do**: Execute the plan (small scale initially)
- **Check/Study**: Compare actual results to expected. Deming preferred "Study" — emphasis on prediction vs reality, not just pass/fail
- **Act/Adjust**: If Check reveals a gap, adjust the approach. If successful, standardize.

The compound learning mechanism: **each cycle's Check phase generates the knowledge that improves the next cycle's Plan phase**. The "ramp" metaphor — PDCA is not a flat circle but an upward spiral. Each cycle raises the baseline.

Deming's critical distinction: Check is not about success/failure of implementation. It's about **comparing predictions to results to revise the theory**. The theory revision is where institutional learning lives.

### A3 Thinking
A3 (named for the paper size) forces the entire problem → analysis → countermeasure → follow-up onto a single page. The constraint is the mechanism:
- Left side: problem statement, current condition, root cause analysis
- Right side: target condition, countermeasures, implementation plan, follow-up
- The A3 is a **communication tool** (boundary object) — it must be legible to anyone, forcing clarity

### Toyota Kata (Rother, 2009)
Mike Rother's research identified the behavioral pattern behind Toyota's PDCA practice:

**Improvement Kata** (4 steps):
1. Understand the direction/challenge
2. Grasp the current condition
3. Define the next target condition
4. Move toward target condition iteratively, uncovering obstacles along the way

**Coaching Kata**: A manager's routine for developing people practicing the Improvement Kata. Five questions asked repeatedly:
1. What is the target condition?
2. What is the actual condition now?
3. What obstacles are preventing you from reaching the target condition?
4. What is your next step? (What do you expect?)
5. When can we go and see what we learned from taking that step?

The key insight: **the kata is not about solutions but about developing the skill of working through uncertainty**. The competitive advantage is not the solutions Toyota finds but the routine by which they find them. Solutions are perishable; the improvement capability compounds.

### Institutional vs Individual Learning Mechanism
The Check→Plan feedback works at institutional level through:
1. **Standardized work as baseline**: Each cycle's "Act" standardizes what was learned. The standard becomes the new baseline for the next cycle's "Plan." Without standardization, each cycle starts from scratch.
2. **The A3 as institutional memory**: A3s are archived and retrievable. New problems start by searching for related prior A3s. The rationale is embedded in the format.
3. **Coaching chains**: Managers coach direct reports using the Kata. The coaching pattern propagates upward — managers are coached on their coaching. This creates institutional learning that survives personnel changes.
4. **OPDCA variant**: Observe-Plan-Do-Check-Act. The added "Observe the current condition" prevents planning from prior assumptions rather than current reality.

### Failure Modes
1. **PDCA without the "Study"**: Treating Check as a binary pass/fail instead of a theory-revision step. This produces single-loop learning only.
2. **Skipping standardization**: If Act doesn't produce a new standard, the learning evaporates. "We'll do better next time" without specifying how.
3. **A3 as bureaucratic form**: When the A3 becomes a compliance document rather than a thinking tool. The single-page constraint only works if it forces genuine synthesis.
4. **Kata without coaching**: Individual practice without a coach degrades. The Coaching Kata is as important as the Improvement Kata.

### Minimal Viable Version
After each phase: (1) what did we predict would happen, (2) what actually happened, (3) what does the difference teach us about our model of how this works, (4) what's our new standard/baseline going into the next phase. The critical element is item 3 — this is where single-loop becomes double-loop. The prediction-vs-reality comparison is the scientific method applied to process improvement.

---

## 5. Cognitive Load at Handoff Boundaries

### Core Mechanism — Distributed Cognition (Hutchins, 1995)
Edwin Hutchins demonstrated that cognition is distributed across people, artifacts, and environments — not contained in individual brains. The unit of analysis is the cognitive system (team + tools + environment), not the individual.

Key insight for handoffs: **what transfers between phases is not "information" but a cognitive system's state**. The receiving phase needs not just the outputs but the representational infrastructure that makes those outputs meaningful.

### Information Loss at Phase Transitions
Research from healthcare, aviation, and military domains converges on the same finding: **handoffs are where systems fail**.

**Healthcare — SBAR** (Situation, Background, Assessment, Recommendation):
Developed by the US Navy for submarine operations, adopted by aviation, then healthcare (Kaiser Permanente, 2002). The structured handoff protocol:
- **S**ituation: What is going on with the patient?
- **B**ackground: What is the clinical background/context?
- **A**ssessment: What do I think the problem is?
- **R**ecommendation: What do I think should be done?

Evidence: SBAR reduced communication failures in healthcare handoffs. The mechanism is that it forces the **sender to do the cognitive work of synthesis** rather than dumping raw data on the receiver. "Assessment" and "Recommendation" are interpretive — they transfer not just data but the sender's mental model.

**Aviation — Crew Resource Management (CRM)**:
Handoff failures in aviation traced to:
1. Information asymmetry between outgoing and incoming operators
2. Loss of "the story" — the narrative understanding of why the current state exists
3. Recency bias — only the most recent events transfer, losing the trajectory

**Key research finding** (from distributed cognition studies): The cost of a handoff is proportional to the **gap between the outgoing party's representational state and the incoming party's ability to reconstruct it**. Artifacts that preserve intermediate representations (not just conclusions) dramatically reduce this gap.

### Perry's Framework (Brunel University, 1998)
Mark Perry's analysis of distributed cognition in handoffs identified that information is decomposed into a "problem space" at handoff points. The critical finding: **the decomposition itself introduces distortion** — the act of breaking a holistic understanding into transferable chunks loses the relationships between chunks.

### Failure Modes
1. **Data transfer without model transfer**: Handing off outputs without the reasoning that produced them. The receiver has answers but can't evaluate or extend them.
2. **Implicit context assumption**: The sender assumes shared context that the receiver lacks. Most dangerous when sender and receiver are from the same organization (false assumption of shared understanding).
3. **Narrative loss**: The chronological/causal story of how the current state was reached is lost. Only the current state transfers, not the trajectory. This prevents the receiver from extrapolating.
4. **Formalization collapse**: Over-formalizing handoffs strips the tacit knowledge. Under-formalizing loses the explicit knowledge. Both fail differently.

### Minimal Viable Version
At each phase boundary: (1) the output artifact itself, (2) a one-paragraph narrative of how the current state was reached (trajectory, not just position), (3) the top 3 things the receiver should know that aren't obvious from the artifact. Item 2 is highest-value — it's the cheapest form of model transfer. Item 3 catches the implicit context that the sender is best positioned to surface.

---

## 6. Feed-Forward vs Feedback

### Core Mechanism — Control Theory
Three control paradigms (from engineering, applicable across domains):

**Open-loop control**: Execute a pre-defined plan without monitoring. No correction.

**Feedback (closed-loop) control**: Measure output, compare to desired state, correct errors after they occur. The canonical example: thermostat measures temperature, adjusts heating.
- Requires: ability to measure output, and fast enough response time
- Advantage: handles unknown disturbances — doesn't need to predict what went wrong, just that something did
- Disadvantage: always reactive — error must occur before correction begins

**Feed-forward control**: Measure disturbances before they affect the system and apply preemptive correction. Example: measure that a door opened and turn on heat before the room cools.
- Requires: a **mathematical model** of how disturbances affect the system, AND ability to measure disturbances
- Advantage: can prevent errors entirely rather than correcting after the fact
- Disadvantage: fails catastrophically for unmeasured/unpredicted disturbances. If the model is wrong, the correction is wrong.

### The Discrimination
| | Feedback | Feed-forward |
|---|---------|-------------|
| **When it acts** | After error is measured | Before error occurs |
| **What it requires** | Output measurement | Disturbance measurement + system model |
| **Handles novel disturbances?** | Yes (reacts to any deviation) | No (only predicted disturbances) |
| **Error must occur first?** | Yes | No |
| **Model required?** | No (just compare output to target) | Yes (must predict effect of disturbance) |
| **Robustness** | High (self-correcting) | Low (brittle to model errors) |

### In Organizational Learning
- **Feedback** = AARs, retrospectives, post-mortems, any "learn from what happened" process
- **Feed-forward** = applying patterns from past cycles to predict and prevent issues in future cycles. Requires a model of "what kinds of errors occur and when"

The critical finding from control theory: **pure feed-forward is rare and fragile**. Practical systems combine both. The optimal approach:
1. Use feed-forward for **known, predictable disturbances** (based on patterns from prior cycles)
2. Use feedback for **novel/unexpected disturbances** (where no model exists yet)
3. Feed-forward improves over time as feedback cycles build the model

### Physiological Analog
The human body uses feed-forward: heart rate increases *before* physical exertion begins (anticipatory regulation via the central autonomic network). But feedback loops provide adaptation to the actual exertion encountered. Neither alone is sufficient.

### Which Is More Effective?
- For **recurring, predictable errors**: Feed-forward dominates. If you know a handoff always loses X, build X into the handoff protocol.
- For **novel, unpredictable errors**: Feedback is the only option. You can't prevent what you can't model.
- For **compound learning**: The progression is feedback → model building → feed-forward. Early cycles are feedback-heavy (learning what goes wrong). Later cycles become feed-forward-heavy (preventing what you've learned goes wrong).

Feed-forward is "seldom practiced due to the difficulty and expense of developing the mathematical model required" (ISA). This maps to organizational learning: building good predictive models of where things go wrong is expensive. Most organizations default to feedback because it's cheaper and more robust, even though feed-forward would be more effective for known failure modes.

### Failure Modes
1. **Pure feed-forward without feedback**: Brittle. When the model is wrong (and it will be), there's no correction mechanism.
2. **Pure feedback without feed-forward**: Inefficient. Re-learning the same lessons each cycle. No compound effect.
3. **Feed-forward based on wrong model**: Worse than no intervention — the "correction" introduces new errors.

### Minimal Viable Version
Maintain a short list (5-10 items) of "things that went wrong in prior phases." Before each new phase, review the list and check whether any apply. This is the cheapest feed-forward: a lookup table of known failure modes used as a pre-flight checklist. The list grows via feedback (adding new items after each phase's AAR).

---

## 7. Boundary Objects (Star & Griesemer, 1989)

### Core Mechanism
A boundary object sits between communities of practice and enables coordination **without requiring consensus**. It is:
- **Plastic enough** to adapt to local needs of different parties
- **Robust enough** to maintain common identity across sites
- **Weakly structured in common use**, strongly structured in individual-site use

Star and Griesemer identified four types:
1. **Repositories**: Ordered collections indexed in a standardized way (libraries, databases). Each community contributes and retrieves differently.
2. **Ideal types**: Abstracted descriptions that don't accurately represent any one community's view but are recognizable to all (diagrams, models, maps).
3. **Coincident boundaries**: Objects with the same boundaries but different internal contents for each community (a state boundary means different things to geologists vs politicians).
4. **Standardized forms**: Common formats that enable information to travel between communities (forms, templates, protocols).

The key property: **interpretive flexibility** — the same object means different things to different communities, but this ambiguity is functional, not a defect. It allows coordination without forcing shared understanding.

Wenger (1998) extended this: boundary objects link communities of practice. He identified **brokers** — people who participate in multiple communities and can translate between them.

### At Design-Implementation Handoffs
The handoff artifact must be a boundary object: readable by the design community (who produced it) and the implementation community (who will consume it). Neither community fully understands the other's interpretation, and **this is fine** as long as the object's structure constrains interpretation enough to maintain coherence.

Charlotte Lee extended boundary objects to handle "periods of unstandardized and destabilized practice" — when the communities' relationship is new or changing. In these periods, boundary objects need more structure (closer to standardized forms) because there's less shared context to fill in the gaps.

Bechky (2003): Boundary objects "allow an actor's local understanding to be reframed in the context of a wider collective activity." This reframing, not information transfer, is the core function.

### What Makes a Good Boundary Object at Design→Implementation Handoff
1. **Contains both intent and constraint**: Intent speaks to designers ("this is what we wanted"), constraints speak to implementers ("these are the boundaries within which you can operate")
2. **Supports local annotation**: Each community can add their own structure without corrupting the shared core
3. **Has visible seams**: The places where interpretation diverges should be findable, not hidden
4. **Survives without its creators**: The object must be interpretable without the design team present to explain it

### Failure Modes
1. **Over-specification**: Too rigid to allow implementers' legitimate local interpretation. Forces a single reading where flexibility is needed.
2. **Under-specification**: Too vague to constrain interpretation. Communities diverge without realizing it.
3. **Treating boundary objects as information transfer**: They're coordination devices, not data pipes. If you think the goal is "transfer all design knowledge to implementers," you'll over-specify and create brittle artifacts.
4. **Ignoring the broker role**: Boundary objects need human brokers who participate in both communities. Without brokers, the interpretive flexibility degenerates into interpretive chaos.
5. **Freezing the object too early**: Boundary objects need to evolve as the relationship between communities develops. A design doc frozen at handoff becomes stale as implementation reveals new constraints.

### Minimal Viable Version
The handoff artifact should have: (1) a shared core that both communities agree describes reality (the "immutable" content), (2) designated zones where each community is expected to add their own interpretation (the "plastic" parts), (3) a named person who participates in both communities and can mediate when interpretations diverge (the broker). The artifact structure matters less than the explicit acknowledgment that it will be read differently by different communities.

---

## Cross-Cutting Synthesis

### The Compound Learning Stack
These seven patterns form a stack when applied to sequential phases:

```
Phase N                          Phase N+1
  |                                 |
  +--[AAR: intent vs outcome]--+    |
  |                            |    |
  +--[DR: decision + rejected  |    |
  |   alternatives + conditions|    |
  |   for reversal]            |    |
  |                            v    |
  |              [Feed-forward list] --> Pre-flight check
  |                            |    |
  +--[Boundary Object]---------+--> Handoff artifact
  |   (plastic + robust)       |    |
  |                            |    |
  +--[PDCA: prediction vs      |    |
  |   reality → theory update] |    |
  |                            |    |
  +--[Double-loop check:       |    |
      which assumptions to     |    |
      re-examine?]             +--> Next phase Plan
```

### Three Levels of Compound Effect
1. **Within-phase** (PDCA): Cycles within a phase improve execution
2. **Between-phase** (AAR + Feed-forward): Each phase's learning improves the next phase's plan
3. **Across-cycles** (Double-loop): After multiple phases, question whether the overall approach/assumptions need revision

### The Minimal Compound Learning Protocol
At each phase boundary, five things (each one sentence):
1. **Prediction vs reality**: What did we expect? What happened? (PDCA Check)
2. **Key decision + reversal condition**: What was the biggest decision and what would make us reverse it? (Design Rationale)
3. **Known failure modes for next phase**: What went wrong before that could go wrong again? (Feed-forward)
4. **Trajectory narrative**: How did we get here, in one paragraph? (Handoff/Distributed Cognition)
5. **Assumption check**: What assumption from the original plan should we re-examine? (Double-loop)

The boundary object carrying this is a **standardized form** (Star's type 4) — structured enough to travel between phases, plastic enough for each phase's participants to add their interpretation.

### Key Researchers for Further Reading
- **Argyris & Schon**: *Organizational Learning* (1978), *Theory in Practice* (1974)
- **Rittel & Kunz**: "Issues as Elements of Information Systems" (1970)
- **Conklin**: *Dialogue Mapping* (2005) — IBIS made practical
- **Star & Griesemer**: "Institutional Ecology, Translations and Boundary Objects" (1989)
- **Hutchins**: *Cognition in the Wild* (1995)
- **Rother**: *Toyota Kata* (2009)
- **Deming**: *Out of the Crisis* (1986)
- **Wenger**: *Communities of Practice* (1998)
- **Bechky**: "Sharing Meaning Across Occupational Communities" (2003)
- **Lee (1997)**: Design rationale capture methods taxonomy
- **Perry (1998)**: Distributed cognition in information handoffs (Brunel University)
- **Toulmin**: *The Uses of Argument* (1958)
