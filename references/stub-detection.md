# Stub Detection Reference

A stub is a promise of behavior with no delivery. That's the invariant across every stack. Stubs are distinct from dead code: dead code is unreachable, stubs are reachable but empty or trivial. No mainstream tool specifically targets this category.

**Critical assumption: lexical markers are unreliable.** Research confirms TODO/FIXME markers capture only 25-35% of actual incompleteness (Zampetti et al. 2020). Detection must work without markers.

## Detection Layers

Four layers, each with different cost and coverage. Higher layers catch what lower layers miss. Layer 1 alone is never sufficient.

### Layer 1: Lexical (grep-able tokens) — cheap, unreliable

Text matching for author-placed markers. First pass only.

- **Markers:** TODO, FIXME, STUB, HACK, XXX, PLACEHOLDER, WIP
- **Phrases:** "not implemented", "coming soon", "not yet", "skeleton only"
- **Throws:** `throw new Error("not implemented")`, Kotlin's `TODO()`
- **Empty bodies:** `{}` after function/method signature
- **Noop returns:** `return []`, `return {}`, `return null`, `return undefined`
- **Log-as-stub:** `console.warn("X not yet implemented")`

Never conclude "no stubs" based on Layer 1 alone.

### Layer 2: Structural (AST-level patterns) — medium cost, catches silent stubs

Code that has the shape of behavior but no substance.

| Pattern | What it looks like |
|---------|-------------------|
| Empty handlers | Event binding → function with empty or single-return body |
| Dead parameters | Function accepts args but never reads them |
| Identity functions | Input → same output unchanged (passthrough) |
| Constant returns | Function always returns the same literal regardless of input |
| Config with noops | Object literal where values are `() => {}` or `null` |
| Disabled elements | UI attribute permanently set to `disabled`/`hidden`/`false` |
| Effect-type contradiction | Function signature implies I/O or mutation but body has none — takes mutable args but never writes, has async signature but no await, accepts callback but never calls it |

**Key discriminator:** Is it a type annotation or a value? `() => void` as a type vs as a value. Position determines intent — ~40% of false positives come from confusing the two.

**Tooling:** Semgrep custom rules, CodeQL queries, SonarQube code smells. CodeQL is strongest — can query whether parameters influence output.

### Layer 3: Behavioral (runtime observation) — high cost, catches invisible stubs

Code that runs but produces no observable effect. This is where characterization testing becomes stub detection.

| Pattern | How to detect |
|---------|--------------|
| No side effects | Function called, nothing written/emitted/mutated |
| No network | Handler bound but no fetch/request made |
| No DOM change | UI handler fires, DOM unchanged after |
| No state mutation | Store action dispatched, state identical before/after |
| Silent Swallow | try/catch that absorbs errors with generic logging, no rethrow |

**Three detection methods:**

1. **Characterization testing** — Call the code, observe what happens. If the answer is "nothing," it's a behavioral stub. The characterization test itself becomes the evidence.

2. **Mutation testing as stubness scoring** — Mutate the function's logic (replace operators, remove statements, change returns). If no test fails (all mutants survive), the function's behavior doesn't matter to any consumer. A function where every mutant survives is behaviorally equivalent to a stub. The survived/killed ratio per function is a continuous "stubness score." Tools: Stryker (JS/TS/C#), PIT (Java), Infection (PHP).

3. **Metamorphic properties** — Property-based tests that detect stubs without knowing expected behavior:
   - "Different inputs produce different outputs" (non-constant function)
   - "Calling this function changes observable state" (effectful function)
   - "This function is not the identity function" (non-passthrough)
   - "Output depends on all declared parameters" (non-dead-parameter)
   
   These are language-agnostic, implementable in any PBT framework (Hypothesis, QuickCheck, fast-check).

### Layer 4: Relational (graph-level absence) — medium cost, catches missing connections

Expected connections that don't exist. Requires understanding the system's intended topology.

| Pattern | What's missing |
|---------|---------------|
| Declared but unused | Export exists, no importer |
| Wired but empty | Config slot filled, target is noop |
| Interface partial | Interface has N methods, implementation has M real + (N-M) throws |
| Route with no handler | URL mapped, handler returns static/empty |
| Menu item → nowhere | UI entry point with no downstream action |
| Feature flag off | Toggle exists, always evaluates false, no mechanism to enable |
| **Cross-function propagation** | Function A is a stub. Function B delegates to A. B is transitively incomplete. Trace the delegation chain. |

**Detection method:** Trace the graph — import graph, call graph, UI navigation graph, config wiring. Look for edges that exist structurally but carry no information. Fan-in/fan-out asymmetry: high fan-in + low internal complexity = likely facade over stubs.

**Tooling:** Dependency-Cruiser (JS/TS), madge, CodeQL call graphs, Go's `callgraph`. ArchUnit/fitness functions for rule-based detection.

## Deduplication

The same stub often appears across multiple layers. When reporting:
- Keep the highest-confidence detection (behavioral > structural > lexical)
- Merge evidence from all layers that found it
- One finding per stub, all evidence attached

## Classification

| Verdict | Criteria |
|---------|---------|
| **CONFIRMED** | Multiple layers agree, or behavioral evidence is clear |
| **LIKELY** | Single layer, high-confidence pattern |
| **NEEDS_VERIFICATION** | Single layer, ambiguous pattern |
| **FALSE_POSITIVE** | Known-good pattern that resembles a stub |

### Common false positives (suppress)

- Defensive no-ops: `unregister() {}` on an empty registry — intentional
- Guard clauses: early returns are not stubs
- Intentional passthrough adapters: middleware that forwards by design
- Test doubles: noops in test code are intentional
- Type annotations: `() => void` as a type, not a value
- Optional callback defaults: empty implementations for optional hooks
- Abstract base methods with empty default: designed for optional override

## Diagnostic Gaps in Current Tooling

These are unsolved — no tool addresses them. Awareness shapes what to look for manually:

| Gap | Description |
|-----|------------|
| **Semantic dead code** | Code that runs, is covered, produces output, but output is meaningless (always same hardcoded value) |
| **Intent-implementation gap** | Distance between what a function name/docstring promises and what it does |
| **Temporal incompleteness** | Code complete for v1 requirements but incomplete for current requirements |
| **Reverse BDD** | Extracting what code actually does → diff against intended specs. Characterization testing does the extraction; the diff step is manual |

## Integration Points for Brownfield Workflows

**Flow mapping:** Stub nodes in a flow path change implementation scope — what looks like "modify existing behavior" becomes "implement missing behavior." A flow map should distinguish live nodes from stub nodes.

**Characterization testing:** A characterization test that discovers a function does nothing is simultaneous stub detection + documentation. Metamorphic properties ("not identity," "not constant," "changes state") systematize this.

**Seam identification:** An incomplete seam (interface declared, implementation stubbed) is both an architectural joint AND an implementation gap. Seam maps should distinguish complete from stub seams. Cross-function stub propagation follows seam boundaries.

**Contract verification:** A contract that exists in types but not in behavior is a stub contract. The signature promises something the body doesn't deliver. Consumer-driven contract testing (Pact, Spring Cloud Contract) is the closest tooling.

**Mutation testing:** Use diagnostically, not just for test quality. "Survived mutant in called code" = the function's behavior doesn't matter to any consumer. Run against flow path nodes before modifying them.
