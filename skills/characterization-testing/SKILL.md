---
name: characterization-testing
description: >-
  Write tests that document what existing code actually does — the inverse of TDD.
  Two uses: safety net before modifying code, and architectural probe to map
  unknown territory. Triggers: "what does this code do", "test before I change
  it", "capture current behavior", "safety net tests", "probe this architecture",
  "map this module's behavior", pattern-extraction-pipeline Stage 2, or
  seam-identification when you need to verify what happens at a seam.
  Distinguishing test: do you know what the test should assert? Yes = use TDD.
  No = use this.
---

# Characterization Testing

The inverse of TDD. You don't know what the code should do — you discover what it actually does and lock it down as a safety net.

Michael Feathers defined it: "A characterization test captures what the code does now." You are not asserting correctness — you're documenting reality. The code might do something "wrong." You assert it anyway. When you later modify the code and a characterization test breaks, you've found coupling — the most valuable signal in your workflow.

In TDD, you write the assertion first and make the code match. Here, you run the code first and make the assertion match. The inversion is total. This is not lesser testing — it's testing for a different purpose. TDD specifies intent. Characterization testing maps territory.

## Two Modes

**Safety net**: Lock down behavior before modifying code. Capture what IS so you know what your changes break.

**Architectural probe**: Use tests as instruments to map unknown territory. You're not preparing to modify — you're investigating how the system works. Tests at seams and boundaries reveal coupling topology, hidden invariants, and what's structural vs incidental. For seam taxonomy (object/link/extension seams) to guide boundary test placement, load `pattern-extraction-pipeline/references/seam-types.md`. Probing pairs naturally with seam-identification — write characterization tests at identified seams to verify what actually happens at each joint.

The protocol below serves both modes. Safety nets focus on code you're about to change; probes focus on code you're trying to understand.

Before writing tests, run `search_patterns("<behavior-area>")` to surface known patterns for the behavior area — reveals what's intentional vs accidental and surfaces edge cases others have documented.

## The Protocol

### 1. Call the code

Pick the function, method, module, or API you're about to modify. Call it with representative inputs. Don't predict the output. Run it and observe.

### 2. Assert the actual output

Whatever came back — assert it. Even if it looks wrong. Even if it contradicts documentation. The test says "this is what the code does today."

If the actual output is nothing — null, empty, constant regardless of input, no state change — you've found a behavioral stub. Assert it anyway (`expect(result).toBeNull()`), but recognize this changes your modification scope: what looked like "modify existing behavior" is actually "implement missing behavior." Flag for plan revision.

```
// You expected a sorted array. It doesn't sort. Assert reality.
expect(processItems(input)).toEqual(unsortedResult);

// You expected state changes. It's a no-op. Document and flag.
expect(stateAfter).toEqual(stateBefore);
```

### 3. Widen coverage

Write 3-5 characterization tests covering distinct behaviors:
- **Happy path**: typical inputs, expected usage
- **Edge cases**: empty inputs, nulls, boundary values
- **State-dependent behavior**: how does output change based on setup/context?
- **Error paths**: what happens with invalid inputs? Does it throw, return null, silently fail? Watch for Silent Swallow — try/catch that absorbs errors with generic logging but no rethrow.
- **Behavioral presence**: does the function actually *do* something? A function that accepts arguments but ignores them, returns a constant regardless of input, or delegates but discards the result is a behavioral stub — structurally present but functionally absent. Only calling it and observing reveals the gap.
- **Adversarial inputs**: injection strings, oversized payloads, deeply nested structures. You're documenting what the code actually does with attacks, not asserting correctness.
- **Scale boundaries**: what happens at 0, 1, N, 10N, 100N items? Discover where behavior changes — silent truncation, performance cliffs, OOM.

Choose what to characterize based on proximity to your planned change — start with code you're about to modify, then widen to callers and callees.

`[eval: assert-reality]` Every assertion reflects observed output, not assumed or documented behavior.
`[eval: depth]` 3+ characterization tests covering distinct behaviors, all passing.
`[eval: modification-boundary]` Safety-net tests cover code at and adjacent to the planned modification boundary.

### 4. Run them all

Every characterization test must pass — by definition, they describe what IS. If a test fails, your assertion doesn't match reality. Fix the assertion, not the code.

### 5. You now have a safety net

Modify the code. Run the characterization tests. Anything that breaks reveals coupling you need to understand. If characterization revealed stubs in the flow path, reassess scope — your plan assumed working code at those nodes. Check callers of stubs: functions that delegate to a stub are transitively incomplete.

After the safety net is established, switch to TDD for new behavior you're adding. Characterization tests remain as regression guards.

`bias:substitution` — After probing, check: are you testing what's easy to test, or what actually matters?

### When Characterization Tests Break After Modification

A broken characterization test is the most valuable signal — but you must decide correctly:

1. **Preserve original intent.** The test documents what the code *did*. If the behavior change was intentional, update the assertion. If unintentional, your modification has a side effect — investigate.
2. **Update expectations only when the change is deliberate.** "I changed the sort order on purpose" → update. "I didn't expect this function to return differently" → your change broke something.
3. **Never delete a broken characterization test.** It found coupling. If behavior legitimately changed, update and add a comment: `// Changed from X to Y in <context>`. If the old behavior was wrong, convert to a TDD-style assertion (assert correct behavior).
4. **Run updated tests multiple times** — flakiness after modification indicates non-determinism your change introduced or exposed.

`[eval: characterization-integrity]` Broken tests were investigated and updated with rationale, not deleted or weakened.

### Scaling to modification scope

| Scope | Tests needed | Focus |
|---|---|---|
| Single function, clear I/O | 3 tests (happy, edge, error) | Just the function |
| Cross-module change | 5-8 tests, include adversarial | Function + callers + callees |
| Architectural change | 10+ tests, include property-based + scale | All touched modules + integration points |
| Security-sensitive change | Add adversarial at every scope | Document what hostile inputs do *now* |

---

## Property-Based Characterization

Beyond specific-input tests, discover structural invariants — properties that hold regardless of inputs:

- **Roundtrip**: `deserialize(serialize(x)) === x`
- **Algebraic**: commutative operations commute, associative operations associate
- **Invariant preservation**: sorted collections stay sorted after operations
- **Idempotence**: `f(f(x)) === f(x)` — applying twice equals applying once
- **Non-constancy**: `f(a) !== f(b)` for distinct `a`, `b` — output varies with input. Failure means hardcoded return regardless of input.
- **Non-identity**: `f(x) !== x` — the function transforms its input. Failure means passthrough.
- **Effectfulness**: `state_after(f(x)) !== state_before(f(x))` — calling changes observable state. Failure means no-op.
- **Parameter influence**: `f(x, y) !== f(x, z)` for distinct `y`, `z` — all declared parameters matter. Dead parameters indicate partial implementation.

A function that fails non-constancy, non-identity, and effectfulness is almost certainly a stub.

Property-based tests are especially powerful because they survive refactoring — they test structural properties, not implementation details. When you change how serialization works, the roundtrip property still holds — or its failure reveals a broken structural contract.

Intermittent failures: mark `[FLAKY: conditions]` and run N times before concluding.

See `references/property-based-characterization.md` for framework-specific APIs and patterns. Use `get_docs` for your test framework's property testing support.

---

## Advanced Techniques

For code that standard input→output assertions can't fully characterize:

- **Type-level probing**: Use `expectTypeOf` to characterize actual return types — catches `any` leaking through generics
- **Assertion counting**: Use `expect.assertions(n)` to ensure all callbacks/events fire — critical for event-driven and plugin code
- **Fixture-based characterization**: Capture file→file transformer output as golden fixtures — the curated alternative to snapshot testing

See `references/advanced-characterization-techniques.md` for the full reference. Use `get_docs("how-they-test@main", "<topic>")` for testing patterns (mocking, async, runner APIs, DI).

If probe results reveal unexpected coupling boundaries, invoke seam-identification to map the full seam topology — a broken characterization test at a boundary is a stronger seam signal than static analysis alone.

If `.mulch/assessments/qa-assessment.md` exists, read `## For characterization-testing` for priority targets — areas with high churn but weak coverage, fragile tests to replace, and force cluster boundaries to probe. For reading QA artifacts as team-intent signals (suppressions, CI gates, snapshots), load `quality-linter/references/contract-signals.md`.
