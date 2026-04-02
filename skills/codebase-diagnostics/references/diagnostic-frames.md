# Diagnostic Frames

Six analytical frames threaded through the codebase-diagnostics pipeline. Each
frame's output feeds the next. Dispatch templates reference specific terms from
this vocabulary — agents use this file to understand what they're looking for.

## Pipeline

```
Origami + Watershed ──→ Stratigraphy ──→ Knot Theory ──→ Pruning ──→ Lock Picking
 (candidate seams)      (risk filter)    (quantify)      (readiness)  (sequence)
```

| Frame | Dimension | Pipeline role |
|-------|-----------|---------------|
| Origami | Space | Find candidate seams from structural crease patterns |
| Watershed | Flow | Find candidate seams from runtime flow basins |
| Stratigraphy | Time | Veto or reprice seams by temporal risk |
| Knot theory | Complexity | Quantify minimum work per seam |
| Pruning | Readiness | Gate: can the system absorb this cut? |
| Lock picking | Constraint order | Sequence: what order unlocks progress? |

Frames are **gates, not votes.** Any single frame can veto. "Scores well on 5
of 6" means nothing if the failing dimension is fatal.

---

## Origami (Space)

Maps stated architecture against actual dependency structure. A crease pattern
that doesn't flat-fold to the target architecture reveals structural
impossibilities.

**Used in:** Wave 2 (subsystem boundaries as fold lines), Wave 4 (feasibility
check against target architecture).

**Key concepts:**
- **Crease pattern:** The current dependency structure interpreted as fold lines.
- **Flat-foldability:** Can the current structure actually reach the target
  architecture through a sequence of folds (refactoring moves)?
- **Mountain/valley assignment:** Whether a boundary is a separation point
  (mountain fold, pulling apart) or an integration point (valley fold, bringing
  together).

**Where it breaks:** Origami assumes paper (code) is uniform. Real code has
variable thickness — some regions are much harder to fold than others. Combine
with stratigraphy to understand where the "paper" is thick.

---

## Watershed (Flow)

Traces how data and requests actually move through the system at runtime. Finds
natural drainage basins (subsystems defined by flow, not structure) and reveals
patterns invisible to static analysis.

**Used in:** Wave 2 (flow basins alongside structural boundaries), Wave 3
(behavior agent traces endorheic basins and stream capture).

**Key concepts:**
- **Flow basin:** All code touched by a single flow from entry to output.
  Natural subsystem boundaries sit at drainage divides between basins.
  **Validation caveat:** Wave 2 basins are hypothesized from static
  entry→output tracing, not confirmed by runtime analysis. Mark as
  `validated: false`. Full validation requires Phase 2 shadow-walk.
  Downstream agents must not treat hypothesized basins as ground truth.
- **Drainage density:** Flow paths per unit area. High density = many fine
  flows = tight coupling → refactor at function level. Low density = few major
  flows = coarse coupling → refactor at module level. Determines the
  *resolution* at which to analyze and refactor.
- **Endorheic basin:** A subsystem that accumulates state without flushing —
  growing caches, unbounded queues, log buffers, session stores that never
  expire. Trace data in but never out. Source of production incidents (memory,
  disk) invisible to static dependency analysis.
- **Stream capture:** One module gradually absorbs responsibilities from adjacent
  modules. The captured flow looks natural in the current architecture — only
  flow tracing + temporal analysis (era markers from stratigraphy) reveals it
  as territory captured over time.
- **Drainage divide:** The boundary where flow splits between two basins. In
  code: the point where a request/data path could go to either of two
  subsystems. Natural place for an interface.

**Where it breaks:** Water flows downhill. Code execution doesn't have a
gravitational analog — calls go "uphill" in any architectural layering. Flow
finds paths; the architectural layering (from origami) judges whether those
paths go the right *direction*.

---

## Stratigraphy (Time)

Dates code layers by the patterns they contain, identifies where eras meet
incompatibly, and reveals temporal risks invisible to current-state analysis.

**Used in:** Wave 1 (infrastructure agent collects index fossils), Wave 2→3
gate (era compatibility check), Wave 3 (component agent runs full stratigraphy),
Wave 4 (evolution analysis integrates findings).

**Key concepts:**
- **Index fossils:** Code patterns that precisely date a stratum. `var` vs
  `let`/`const`, `$.ajax` vs `fetch` vs `axios`, class components vs hooks,
  `require` vs `import`, callback nesting vs Promise chains vs async/await.
  Faster and more reliable than git log clustering. Survives squashed history.
  **Fallback chain:** Codebases with consistent linting/autofix may have no
  surviving fossils. If fossils are absent or ambiguous, fall back to git log
  era clustering, then dependency vintages from the ecosystem agent. Record
  confidence as high/medium/low. If no method produces era data, say so —
  don't guess.
- **Fault:** A partial migration where the same logical layer appears at
  different "depths" in different regions. Module A migrated to async/await;
  Module B (which A depends on) still uses callbacks. The fault isn't where
  eras meet — it's where the *same era appears at different elevations.* Every
  partial migration is a fault. Faults are high-risk cut points because the
  strata don't align across them.
- **Diagenesis:** Temporary solutions that lithified into permanent
  infrastructure. A "temporary" caching layer becomes load-bearing. A "quick
  fix" adapter becomes the de facto API. Detect via TODO/hack/temporary
  comments in code that predates its current architectural role. The ground is
  softer than it looks — you might plan to cut along what appears solid, only
  to find it's compacted sand.
- **Metamorphism:** Code refactored so many times it looks modern (current
  syntax, current framework) but carries ancient assumptions in its data flow,
  error handling, or concurrency model. Passes superficial era checks but fails
  under load. Distinguish *superficial era* (syntax, framework) from *deep era*
  (data flow assumptions, concurrency model).
- **Inverted strata:** Newer code carrying older patterns — typically copied
  from old code. "Newer code" ≠ "newer assumptions." Code stratigraphy allows
  inversions that geological stratigraphy doesn't.
- **Unconformity:** A gap in the stratigraphic record — an era that should be
  present but isn't. Code that jumped from very old patterns directly to very
  new ones without the intermediate steps, often creating brittle bridges.

**Where it breaks:** Geological strata deposit in strict chronological order.
Code doesn't — modules can be inverted, copied, or partially migrated in any
direction. The skill must note that code stratigraphy allows inverted strata
and that temporal analysis is probabilistic, not deterministic.

---

## Knot Theory (Complexity)

Quantifies how tangled a dependency region is and determines the minimum number
of moves to simplify it.

**Used in:** Wave 3 (contract agent counts and classifies crossings), Wave 4
(synthesis computes knot complement for parallelism map).

**Key concepts:**
- **Crossing number:** Dependencies that cross a boundary. Weight by era
  distance: same-era crossings may be intentional design (two modules built
  together that genuinely need each other). Cross-era crossings are *more
  likely* accidental — but intentional cross-era coupling exists (e.g., plugin
  systems, stable APIs). Era weight is a *priority signal* for where to
  investigate, not a classification. Flag for review, don't auto-classify.
- **Unknotting number:** The minimum number of crossing changes needed to
  simplify a region. This is the *floor* for refactoring effort — you cannot
  do it in fewer moves regardless of approach.
- **Separability assessment:** Can this coupling be separated without
  redesigning both sides? If yes, it's accidental complexity — the joins are
  refactoring targets. If no, it's essential complexity — accept or redesign
  the boundary. This is a judgment call, not a formal decomposition — state
  reasoning. (The knot theory terms "prime" and "composite" are useful for
  communication but imply more rigor than code analysis delivers.)
- **Composite tangle:** Accidental complexity joining essential tangles. Knot
  theory proves every composite decomposes uniquely into primes. The accidental
  joins are always separable. Identifying which parts are separable vs essential
  tells you where to stop trying.
- **Knot complement:** The space *around* the knot — modules that don't depend
  on each other. Defines maximum available parallelism for refactoring. Two
  modules with no dependency path between them can be refactored simultaneously.
  The complement converts "6 serial moves = 6 sprints" into "6 moves, 3
  parallel pairs = 3 sprints."
- **Security pins:** Coupling that actively resists separation and gives false
  feedback: bidirectional serialization, shared mutable state with ordering
  constraints, load-bearing listener registration order. Named by analogy to
  lock picking — these aren't just hard crossings, they fight back. Require
  an explicit coordinator rather than direct decoupling.

**Where it breaks:** Mathematical knots have a fixed, known number of crossings.
Codebases have unknown numbers of constraints, and new ones can surface during
refactoring (latent bugs). The metaphor works for sequencing and quantification
but overpromises on determinism.

---

## Pruning (Readiness)

Assesses whether the system can absorb a specific cut and predicts what happens
afterward. A gate check, not a discovery step.

**Used in:** Phase 2 readiness protocol (before every drill), Phase 2 cut
classification.

**Key concepts:**
- **Collar:** The branch collar — where a branch meets the trunk. In code:
  tests and interfaces at the cut point that allow the system to absorb
  change. No collar = prep work first (write characterization tests, define
  an explicit interface). **Code does not self-heal.** Every cut requires
  *active* healing (writing adapters, updating callers) rather than passive
  recovery.
- **Response growth:** After a cut, the tree redirects energy — new growth
  appears near the wound. Code analog: callers that used to reach B through A
  find new paths after separation. Predict *before* cutting: will response
  growth be healthy (proper wound closure via explicit interface) or
  pathological (water sprouts — weak, vertical shoots that sap energy =
  workarounds, backdoor access)?
- **Deadwood removal:** Dead branches are the safest cuts — zero risk, improve
  visibility. Code analog: dead code, unused imports, orphaned modules,
  retired feature flags. **Always remove deadwood first**, before structural
  refactoring, because: (a) zero risk, (b) reduces noise in dependency graphs
  making real seams easier to see, (c) sometimes eliminates crossings entirely.
- **Crown reduction:** Removing outer growth to reduce overall size. Code:
  shrinking a module's public API surface. For modules with too-wide interfaces
  or feature creep.
- **Crown thinning:** Removing interior branches for better airflow. Code:
  cleaning internal coupling within a module without changing its external
  interface. For internal spaghetti behind a reasonable facade.

**Where it breaks:** Trees are living organisms that actively heal. Code only
gets worse without maintenance. The collar analogy (infrastructure that supports
the cut) holds, but the self-healing implication doesn't.

---

## Lock Picking (Constraint Order)

Determines the sequence in which to address seams. The order matters — resolving
the right constraint first can unlock many others.

**Used in:** Phase 2 drill sequencing (dynamic reordering after each drill),
Phase 2 integrity checks.

**Key concepts:**
- **Binding pin:** The pin under most tension — the highest-leverage constraint
  to resolve first. May not be in the highest-complexity region. A low-crossing
  region that happens to be the *precondition* for unknotting three high-crossing
  regions has more leverage than any of them individually.
- **Dynamic binding order:** Setting one pin changes tension on all others. Code:
  resolving one constraint changes leverage scores of all remaining seams.
  **Re-evaluate after each move**, don't commit to a fixed sequence.
- **False set:** A pin that feels set but springs back when you apply tension to
  the next. Code: a decoupling that appears complete (tests pass, interface
  looks clean) but breaks when you apply pressure elsewhere — a downstream
  module relied on a side effect. After each move, apply pressure to adjacent
  seams and verify the previous move holds.
- **Security pins:** Pins engineered to resist picking (spool, serrated) that
  give false feedback. Code: coupling that *actively resists* separation.
  Bidirectional serialization, shared mutable state with ordering constraints,
  event systems where listener registration order is load-bearing. They don't
  just resist — they give false "set" signals during decoupling. Require
  specialized techniques (explicit coordinator) rather than conventional picking.

**Where it breaks:** Locks have a fixed, known number of pins. Codebases have
unknown numbers of constraints, and new ones can appear mid-refactoring. The
metaphor works for sequencing but overpromises on determinism.

---

## Cross-Frame Interactions

These interactions produce insights no single frame contains. The orchestrator
checks for them during Wave 4 synthesis and Phase 2 drill.

| Interaction | What it reveals | When to check |
|-------------|----------------|---------------|
| **Stratigraphy × Knot theory** | Cross-era crossings are accidental coupling | Wave 3 contract agent weights crossings by era distance |
| **Watershed × Pruning** | Where flow redirects after a cut | Phase 2 readiness protocol step 3 |
| **Lock picking × Knot theory** | Low-crossing region may have highest downstream unknotting potential | Phase 2 drill sequencing |
| **Origami × Stratigraphy** | Whether target architecture is reachable given era constraints | Wave 4 cross-cutting synthesis check 4 |
| **Watershed × Stratigraphy** | Stream capture — responsibilities absorbed across eras | Wave 3 behavior agent |
| **Knot theory × Pruning** | Knot complement = parallelism map for refactoring | Wave 4 cross-cutting synthesis check 3 |
