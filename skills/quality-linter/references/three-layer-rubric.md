# Three-Layer Rubric: QA Architecture Quality

A scannable reference for evaluating QA infrastructure across three layers. Load this when running the quality-linter skill.

---

## Layer 1: AI-Specific Failure Modes

Use when the codebase has AI-generated or AI-assisted code. These failure modes are systematic, not random.

### Failure Mode Catalog

| Failure Mode | Static Signal | Linter Rule Pattern |
|---|---|---|
| **Over-abstraction** | Abstract classes / interfaces in files < 100 lines; test setup > 20 lines before first assertion | Flag `abstract_class_count > 0 AND file_line_count < 100`; flag test setup blocks exceeding 20 lines |
| **Phantom API** | Import not in `package.json` / `Cargo.toml`; method not in indexed lib docs | Cross-reference all imports against manifest; flag any package not declared as dependency |
| **Silent error handling** | `catch {}` or `catch (e) { console.log(e) }` in test code; test body with zero `expect`/`assert` calls | Flag empty catch blocks in tests; flag test functions with no assertion |
| **Dependency gap** | Package API call using version newer than lockfile pin | Cross-reference API calls against *installed* version docs, not latest |

### What to Look for in Model-Generated Tests

- Test file longer than the implementation it tests — over-engineering secondary effect
- Mocking an interface that has 8 methods when only 1 is used — phantom interface
- `expect(service).toBeDefined()` on a freshly constructed object — trivially true assertion
- `vi.mock()` / `jest.mock()` at file level on non-adapter code — link-seam fragility
- Try/catch around the entire test body with no assertion in catch — silent pass

### Domain Pattern → Testable Property Mapping

| Domain Pattern | Core Invariant | Required Test Type |
|---|---|---|
| CRDT merge | `merge(A,B) == merge(B,A)` (commutativity) | Property-based |
| CRDT merge | `merge(A,A) == A` (idempotence) | Property-based |
| Undo/redo stack | `undo(apply(op, state)) == state` | Round-trip |
| Undo + collaboration | Remote edits preserved after undo | Integration (multi-actor) |
| LWW sync | Higher timestamp always wins | Property-based |
| Schema migration | `down(up(schema)) == schema` | Round-trip |
| Normalization | `normalize(normalize(x)) == normalize(x)` | Property-based |
| Serialization | `deserialize(serialize(x)) == x` | Round-trip |
| Mutation annotation (NEVER) | `NEVER` actions never modify undo stack length | Integration |
| Spatial transform | `invert(transform(point)) == point` | Round-trip |

**Most commonly missing:** Integration tests combining undo + concurrent remote edits. Single-player undo tests pass while collaborative undo is broken.

---

## Layer 2: Code-Specific Patterns

Use when assessing architectural quality of the test suite itself.

### Seam Type → Test Pattern

| Seam Type | Enabling Point | Correct Test Pattern | Anti-pattern |
|---|---|---|---|
| **Object (DI)** | Constructor / DI container | Inject test double at construction; one real object per test | Module mocking when DI seam exists |
| **Link (module)** | Import/require path | `vi.mock()` only for adapter boundaries, not internal logic | Using link seams as default mocking strategy |
| **HTTP** | Framework inject (`fastify.inject`, `supertest`) | Call inject method; assert status + body without network | Spinning up a real server for unit-scope tests |
| **Functional core** | Function signature | Call directly with constructed inputs; assert output | Mocking DOM when function has no DOM dependency |
| **Pipeline stage** | Compiler/build boundary | Fixture-based: known input → assert output contract | Testing internal IR instead of stage boundary output |
| **Preprocessing** | Build config / env flag | Conditional test execution (`describe.skipIf`) | Testing all modes in single test with runtime branching |

**Seam quality signal:** If you cannot name the seam a test file exercises, the seam does not exist yet in the production code.

### Test Topology Patterns

| Topology | What it signals | When appropriate |
|---|---|---|
| Mirror-directory (`test/` mirrors `src/`) | Tests are separate documentation artifact | Library code, public API packages |
| Co-located (`*.test.ts` next to source) | Tests are implementation guards | Application code, feature modules |
| Centralized by pipeline stage | Tests map 1:1 to compiler/build stages | Compiler, build tool, pipeline code |
| Fixture-based (`samples/` + runner) | Tests are data; runner is infrastructure | Compiler output contracts, formatter rules |
| Test helper library mirrors domain | Pure functional core; helpers build state | Domain-rich FP codebases (Clojure, Haskell, Elm) |

**Smell:** Tests that straddle multiple modules with no clear boundary indicate seam confusion in production code.

### Architectural Linter Rules (not style)

These enforce what-may-depend-on-what. Violations are architecture bugs.

| Rule / Tool | Invariant Enforced | Priority |
|---|---|---|
| `eslint-plugin-boundaries` | Dependency direction (UI → domain, domain ↛ UI) | High |
| `eslint no-restricted-imports` + patterns | No cross-feature imports; features import only from shared/core | High |
| `import/no-cycle` | Acyclic module graph | High |
| Path restrictions (no barrel bypass) | Imports go through index file; internals are encapsulated | Medium |
| `c8 --100` / `vitest --coverage --100` | 100% coverage gate per package (library code only) | Medium |
| Go `internal/` / Rust `pub(crate)` | Language-level boundary enforcement | Use when available |

**Rule:** Language-level enforcement (Rust visibility, Go `internal/`) is stronger than lint. Prefer it when the language supports it.

---

## Layer 3: Contributor-Agnostic Style

Use when assessing whether the codebase eliminates style discretion systematically.

### Formatter Completeness Checklist

#### Fully eliminated by Prettier / Biome (zero contributor discretion)
- [ ] Indentation (tabs vs spaces, indent size)
- [ ] Quote style (single/double)
- [ ] Trailing commas
- [ ] Semicolons
- [ ] Line length (hard wrap)
- [ ] Bracket spacing
- [ ] Arrow function parens
- [ ] JSX attribute line breaks

#### Requires additional plugin (not covered by base formatter)
- [ ] Import ordering — requires `eslint-plugin-import/order` or `@trivago/prettier-plugin-sort-imports`
- [ ] Object property order — requires custom lint rule

**Key gap:** Projects using Prettier without an import-sort plugin still have discretionary import ordering, producing noisy diffs.

### Naming Convention Enforcement

These require lint rules, not just docs:

| Convention | Enforcement Tool |
|---|---|
| `camelCase` vs `snake_case` identifiers | ESLint `camelcase` / `@typescript-eslint/naming-convention` |
| `is`/`has` prefix for booleans | `@typescript-eslint/naming-convention` (custom selector) |
| `PascalCase.tsx` vs `kebab-case.tsx` file names | `eslint-plugin-filenames` or custom rule |
| `*.test.ts` vs `*.spec.ts` | ESLint `no-restricted-glob-patterns` or custom rule |
| Named exports vs `export default` | `import/no-default-export` |

### Import Direction Rules

1. Dependencies flow inward: UI → domain → infrastructure (not reversed)
2. Feature modules import only from shared/core, not from each other
3. Imports use barrel/index files, not internal paths
4. Import order: external > internal > relative (enforced by plugin)

### Contributor-Agnostic Assessment Checklist

Quick pass for brownfield codebase:

- [ ] Formatter configured and enforced in CI (Prettier, Biome, gofmt, rustfmt)
- [ ] Import ordering covered (plugin or separate lint rule)
- [ ] Naming conventions in lint rules, not just README
- [ ] Dependency direction enforced by `eslint-plugin-boundaries` or equivalent
- [ ] No-circular-imports rule active
- [ ] Coverage enforced as a gate (not just reported)
- [ ] Test file naming convention enforced (not just documented)
