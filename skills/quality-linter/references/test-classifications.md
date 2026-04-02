# Test Classifications Reference

## 5-Category Rubric

| Category | Definition | Mutation Signal | Machine-Detectable Signal |
|----------|-----------|-----------------|--------------------------|
| **Purposeful** | Asserts a specific value or behavior; would fail if implementation made a behavioral change | Kills mutants | Assertion on exact/computed value from SUT |
| **Trivial** | Asserts something always true, or derives expected from the same operation as the SUT | Mutants survive (no assertion gap) | `toBeDefined()` on new object; `expected = x + y` when testing `Sum(x, y)` |
| **Fragile** | Correct behavior, but coupled to internal structure; breaks on refactoring without behavior change | Breaks before mutant can survive | `vi.mock()`/`jest.mock()` at file level; snapshot of internal state |
| **Orphaned** | Was purposeful; target behavior was removed or changed, test now tests nothing real | No coverage (code path gone) | Import points to deleted symbol; test subject no longer exists |
| **Missing-the-point** | Covers the right code but wrong behavioral layer; misses the domain invariant that matters | Survives because tested scenario is too narrow | No multi-actor or cross-concern tests for patterns that require them |

---

## Real Examples by Category

### Purposeful

**SvelteKit cookie domain matching** (`src/runtime/server/cookie.spec.js`)
```javascript
test('subdomain match', () => {
  assert.ok(domain_matches('sub.example.com', '.example.com'));
});
```
Discrete behavioral contract. Mutation to subdomain logic caught; exact-match mutation also caught independently.

**Graphite opacity node** (`gcore/` Rust crate)
```rust
assert_eq!(opacity_node.eval(Color::WHITE), Color::from_rgbaf32_unchecked(1., 1., 1., 0.1));
```
Exact numeric output for specific input. Any mutation to the opacity formula fails this assertion.

**Lifecycle assertion counting** (event-driven code pattern)
```typescript
it('fires all lifecycle hooks', async () => {
  expect.assertions(3)
  plugin.onInit(() => expect(true).toBe(true))
  plugin.onReady(() => expect(true).toBe(true))
  plugin.onClose(() => expect(true).toBe(true))
  await plugin.start(); await plugin.stop()
})
```
`expect.assertions(3)` fails if any callback never fires — catches "test passes because nothing ran."

---

### Trivial

**Tautological expected value** (`cheatsheets@master`, golang testing)
```go
expected := 2 + 4  // same operation as Sum — not a fixed oracle
if !reflect.DeepEqual(Sum(x, y), expected) { ... }
```
`Sum(x, y+1)` returns 7, `expected` is 6... actually this would catch it. But `expected := x + y` in general mirrors the SUT. The signal: expected computed from the *same formula* being tested, not an independent oracle.

**Identity assertion**
```typescript
test('service is initialized', () => {
  const service = new UserService();
  expect(service).toBeDefined();  // always true
});
```
`toBeDefined()` on a freshly constructed object — no behavioral mutation can break this.

---

### Fragile

**Import mock coupling** (from `how-they-test@main`, `no-import-mocks`)
```typescript
vi.mock('../../services/auth', () => ({
  validateToken: vi.fn().mockReturnValue(true)
}));
```
Couples test to import path and export shape. Refactoring the auth module's location or interface breaks the test even if behavior is identical.

**Internal state snapshot**
```typescript
test('undo stack state', () => {
  expect(historyState).toMatchSnapshot();
  // includes internal IDs, timestamps, implementation details
});
```
Every internal restructuring regenerates the snapshot. Tests nothing about observable undo behavior.

---

### Orphaned

Detected from `excalidraw@0.18.0` undo-defactor analysis: tests that covered the single-player undo path that was correct before collaboration was added. After the behavior changed, the tests continued to pass because the single-player path still worked — but they were now disconnected from the invariant that mattered.

Detection signal: test subject behavior was redefined by a feature addition; existing tests passed through the change without updating.

---

### Missing-the-Point

**Undo without collaboration** (`excalidraw@0.18.0`, undo-defactor)
```typescript
test('undo restores element', () => {
  addElement(el); undo();
  expect(scene).not.toContain(el);  // passes in single-player
  // misses: concurrent remote edits must survive undo
});
```
Tests correct behavior in isolation; misses the domain invariant that undo in a collaborative context must not clobber concurrent edits from other users.

**Annotation without stack validation** (`mutation-annotation-patterns` codebook)
```typescript
store.scheduleAction(mutation, CaptureUpdateAction.NEVER);
// Existing test: assert no error thrown
// Missing test: assert undoStack.length unchanged
```
Tests that the action completes; does not verify the annotation caused correct undo-stack behavior.

---

## Classification Decision Tree

```
Is there at least one assertion?
├─ NO  → TRIVIAL (vacuous pass) or ORPHANED (if test subject is gone)
└─ YES
    Does the assertion depend on a value only the SUT can produce?
    ├─ NO  → TRIVIAL (toBeDefined, tautological expected)
    └─ YES
        Does the test break on refactoring without behavior change?
        ├─ YES → FRAGILE (import mock, internal snapshot)
        └─ NO
            Does the test's behavioral scope cover the domain invariant?
            ├─ NO  → MISSING-THE-POINT (wrong layer, missing multi-actor)
            └─ YES
                Is the test subject still the current implementation?
                ├─ NO  → ORPHANED
                └─ YES → PURPOSEFUL
```

---

## Mutation Testing Connection

| Stryker/cargo-mutants State | Quality Signal | Maps To |
|-----------------------------|---------------|---------|
| **Killed** | Test asserts behavior | Purposeful |
| **Survived** | No test depends on this code path's result | Trivial or Missing-the-point |
| **No coverage** | Code never reached | Orphaned (if test claimed to cover it) or plain gap |
| **Timeout** | Missing termination test | Specific gap (Missing-the-point for termination invariant) |
| **Runtime error** | Incidental kill — not a real assertion | Can mask Trivial tests |

**Equivalent mutants:** Not every surviving mutant is a test gap. If replacing `return x` with `return x + 0` survives, it may be equivalent (same observable behavior). cargo-mutants surfaces what each mutant does — review "surprising" survivors first (e.g., replacing an important function body with `Ok(())` and nothing fails).

**Mutation score baselines:** No universal threshold exists (Stryker and cargo-mutants both defer to the developer). Domain matters: pure transform functions should approach 90%+; UI rendering code legitimately lower.

---

## Property-Based Testing Patterns

Property tests generate hundreds of inputs against invariants — structurally harder for mutations to survive.

| Pattern | Invariant | Domain Examples | Expression |
|---------|-----------|-----------------|------------|
| **Roundtrip** | `decode(encode(x)) == x` | JSON, coordinates, AST parse/unparse, schema migration | `fc.property(arb, x => decode(encode(x)) === x)` |
| **Commutativity** | `f(a, b) == f(b, a)` | CRDT merge, set union, config merging | `fc.property(state, state, (a, b) => merge(a, b) === merge(b, a))` |
| **Idempotence** | `f(f(x)) == f(x)` | Normalization, formatting, deduplication, re-renders | `fc.property(arb, x => normalize(normalize(x)) === normalize(x))` |
| **Invertibility** | `invert(apply(op, s)) == s` | Undo/redo, spatial transforms | Apply op, invert, assert original state |
| **Invariant preservation** | `invariant(f(x))` holds if `invariant(x)` holds | Sorted collections, balanced trees, schema-conforming state | `fc.property(valid, x => isValid(transform(x)))` |
| **LWW conflict resolution** | Higher timestamp always wins | Distributed sync (ente, any LWW store) | `fc.property(ts1, ts2, ...) => ts2 > ts1 implies remote wins` |

**Collaboration test gap (highest-priority missing tests):** Any project using an undo pattern should have an integration test combining undo + concurrent remote edit. This is documented as absent in excalidraw's own defactoring analysis (`undo-defactor`). The specific property: `remoteEdit(); undo(); expect(remoteEdit).toStillExist()`.

**Note on prevalence:** Indexed projects with CRDT/undo domains (excalidraw, penpot, graphite) do not use property-based testing despite having directly applicable invariants. These recommendations are aspirational — absence of PBT in a codebase is itself a finding, not evidence that PBT doesn't apply.
