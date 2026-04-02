# Advanced Characterization Techniques

Techniques for characterizing code that standard input→output assertions can't reach. Adapted from patterns observed across 7 major OSS ecosystems (source: `get_docs("how-they-test@main", "<topic>")`).

## Type-Level Probing

Characterize what types a function actually returns — not what the docs say, what the compiler sees. Runtime tests can't catch `any` leaking through generics.

Use this in **architectural probe** mode to discover: does this API actually return the type the caller expects, or is `any` hiding a mismatch?

```typescript
// Vitest (native) or Jest/bun:test (install 'expect-type')
import { expectTypeOf } from 'vitest' // or from 'expect-type'

it('actually returns User, not any', () => {
  const result = parseApiResponse<User>(rawData)
  expectTypeOf(result).toEqualTypeOf<User>()
  expectTypeOf(result).not.toBeAny()
})

it('infers generic from argument', () => {
  const store = createStore({ count: 0 })
  expectTypeOf(store.getState().count).toBeNumber()
})
```

**When to use**: characterizing generic functions, builder patterns, API response parsers, utility types. Especially valuable before refactoring — if the code currently returns `any` and callers depend on that looseness, your refactoring to strict types will break them.

## Assertion Counting

Ensure all expected callbacks/events actually fire during characterization. Without this, a test can pass silently when the callback was never invoked.

Critical for event-driven and callback code where the characterization question is "how many times does this fire, and in what order?"

```typescript
// Jest / Vitest / bun:test
it('fires all lifecycle hooks', async () => {
  expect.assertions(3)  // test FAILS if fewer than 3 assertions run
  plugin.onInit(() => expect(true).toBe(true))
  plugin.onReady(() => expect(true).toBe(true))
  plugin.onClose(() => expect(true).toBe(true))
  await plugin.start()
  await plugin.stop()
})

// node:test
test('fires all lifecycle hooks', (t) => {
  t.plan(3)  // same concept
})
```

**When to use**: characterizing event emitters, plugin systems, middleware chains, Observable pipelines — any code where "did all the callbacks fire?" is the characterization question.

## Fixture-Based Characterization

For code generators, CLI tools, config parsers, compilers — anything with file→file transformation. Capture what the code produces *now* as golden fixtures, then any future change that alters output breaks the fixture.

```
test/fixtures/
  basic-config/
    input.json
    expected-output.ts    ← captured from actual output
  nested-config/
    input.json
    expected-output.ts
```

```typescript
import { readdirSync, readFileSync } from 'fs'

const fixtures = readdirSync('test/fixtures')

for (const fixture of fixtures) {
  it(`produces current output for ${fixture}`, () => {
    const input = JSON.parse(readFileSync(`test/fixtures/${fixture}/input.json`, 'utf8'))
    const expected = readFileSync(`test/fixtures/${fixture}/expected-output.ts`, 'utf8')
    expect(generate(input)).toBe(expected)
  })
}
```

**Creating fixtures**: Run the code, capture the output as `expected-output.*`. You're not asserting correctness — you're locking down current behavior. If the output looks wrong, note it and assert it anyway. That's characterization.

**When to use**: before modifying code generators, template engines, serializers, CLI tools, or any input→output transformer. The fixtures become your safety net — any behavioral change shows up as a diff.

**Relationship to snapshots**: Fixture-based testing is the manual, curated version of snapshot testing. Prefer fixtures when you need to review and understand each captured output. Use snapshots (`toMatchSnapshot`) when you have many cases and want automated capture — but be aware that snapshot updates can silently accept regressions.
