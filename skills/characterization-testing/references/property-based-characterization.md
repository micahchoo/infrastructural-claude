# Property-Based Characterization Testing

Property-based tests generate many random inputs and verify that a property holds for all of them. For characterization testing, this discovers structural invariants you didn't know existed.

## Invariant Types

### Roundtrip (encode/decode symmetry)

The most common structural property. If a system serializes and deserializes, the roundtrip should be identity.

**fast-check (TypeScript):**
```typescript
fc.assert(
  fc.property(fc.jsonValue(), (value) => {
    expect(deserialize(serialize(value))).toEqual(value);
  })
);
```

**Hypothesis (Python):**
```python
@given(st.from_type(MyModel))
def test_roundtrip(instance):
    assert deserialize(serialize(instance)) == instance
```

Applies to: JSON/protobuf serialization, coordinate transforms (screen↔world), codec pairs, import/export, AST parse/unparse.

### Algebraic (commutativity, associativity)

Operations on the same type often have algebraic properties.

**fast-check:**
```typescript
fc.assert(
  fc.property(fc.integer(), fc.integer(), (a, b) => {
    expect(merge(stateA, stateB)).toEqual(merge(stateB, stateA)); // commutativity
  })
);
```

Applies to: CRDT merge operations, set operations, configuration merging, event ordering (if claimed commutative).

### Invariant Preservation

An operation should preserve structural invariants of its input.

**Hypothesis:**
```python
@given(sorted_list=st.lists(st.integers()).map(sorted))
def test_insert_preserves_sort(sorted_list):
    result = sorted_insert(sorted_list, 42)
    assert result == sorted(result)
```

Applies to: sorted collections, balanced trees, valid HTML/DOM structure, schema-conforming data, spatial index consistency.

### Idempotence

Applying an operation twice produces the same result as applying it once.

**fast-check:**
```typescript
fc.assert(
  fc.property(fc.anything(), (input) => {
    const once = normalize(input);
    const twice = normalize(normalize(input));
    expect(twice).toEqual(once);
  })
);
```

Applies to: normalization, formatting, deduplication, cache population, migration scripts, UI re-renders.

## Deriving Properties from Signatures

Type signatures hint at which properties to test:

| Signature shape | Likely property |
|---|---|
| `A → B` paired with `B → A` | Roundtrip |
| `(A, A) → A` (binary, same type) | Commutativity, associativity |
| `A → A` (endomorphism) | Idempotence, invariant preservation |
| `[A] → [A]` (list transform) | Length preservation, element preservation, ordering |
| `A → Bool` (predicate) | Consistency with related predicates |

## When Property-Based Beats Example-Based

- **Structural analysis**: You don't know specific expected outputs, but you know structural relationships should hold
- **Refactoring safety**: Implementation changes but structure shouldn't — properties catch structural regressions that example tests miss
- **Discovering edge cases**: Generators find inputs you wouldn't think to test (empty strings, negative numbers, Unicode, deeply nested structures)
- **Characterizing APIs you didn't write**: Properties let you test contracts without knowing implementation details
