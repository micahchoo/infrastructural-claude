# API Surface Management

## The Problem

A complex embeddable system must evolve its internals — refactoring state representations,
changing rendering strategies, improving algorithms — without breaking consumers who depend
on its public API. But without deliberate tracking, the API surface is implicit: it's
whatever consumers happen to import. Every export is potentially load-bearing. Every
internal refactor is potentially breaking.

The challenge is making the API surface explicit, trackable, and reviewable so that
stability is an engineering discipline rather than an accident.

## Competing Patterns

### 1. Tracked API Reports (tldraw Pattern)

**Structure:** TypeScript API Extractor generates `.api.md` files for each package.
These files are checked into version control and reviewed in PRs.

**How it works:**
- Microsoft's API Extractor (`@microsoft/api-extractor`) processes TypeScript declarations
- For each public package, a `.api.md` report is generated listing every exported type, function, class, and their signatures
- Reports are committed to the repo (tldraw tracks ~11.6K lines across packages)
- CI fails if the generated report doesn't match the committed report
- Any API change appears as a diff in the PR, forcing explicit review
- `@public`, `@beta`, `@internal` TSDoc tags control visibility tiers

**Tradeoffs:**
- (+) API changes are visible diffs — reviewers see exactly what changed
- (+) Accidental exports are caught immediately
- (+) The report is the contract — no ambiguity about what's public
- (+) Works with existing TypeScript tooling
- (-) Report files are noisy in PRs (thousands of lines)
- (-) Requires build step to generate — not instant feedback
- (-) Only tracks TypeScript type-level surface, not runtime behavior contracts

**When to use:** You ship TypeScript packages. You have multiple packages with distinct
API surfaces. You want API changes to be first-class review artifacts.

### 2. Semver-Only Discipline (Excalidraw Pattern)

**Structure:** API surface is defined by what's exported from the package entry point.
Breaking changes are communicated through semver major bumps and changelogs.

**How it works:**
- Package has a single entry point that re-exports the public API
- Breaking changes are documented in CHANGELOG.md
- No automated surface tracking — the team manually identifies breaking changes
- Consumers rely on semver to know when to expect breakage
- TypeScript types provide some compile-time detection of breakage

**Tradeoffs:**
- (+) No tooling overhead — just discipline
- (+) Consumers understand semver
- (+) Flexible — doesn't constrain the release process
- (-) Breaking changes can slip through without anyone noticing
- (-) No diff-level visibility into what changed in the API
- (-) Relies on human judgment to identify what's "breaking"
- (-) Consumers discover breakage at upgrade time, not at review time

**When to use:** Small API surface. Single package. Team is small enough that everyone
knows the public API. Fast iteration is more valuable than stability guarantees.

### 3. Language-Boundary Enforcement (Penpot Pattern)

**Structure:** The plugin API is defined in a different language than the core, creating
a physical boundary that forces explicit API definition.

**How it works:**
- Core is ClojureScript; plugin API is JavaScript
- Every function exposed to plugins must be explicitly written as a JS-callable interop function
- Internal ClojureScript functions are invisible to plugins by default
- The interop boundary is the API surface — it cannot drift accidentally
- Changes to the plugin API require writing new interop code, making them always intentional

**Tradeoffs:**
- (+) Structural enforcement — impossible to accidentally expose internals
- (+) API surface is exactly the set of interop functions, nothing more
- (+) Internal refactoring has zero risk of breaking the plugin API
- (-) Language boundary adds development overhead for every new API method
- (-) Debugging across the boundary is harder
- (-) Not applicable to single-language stacks

**When to use:** You already have a multi-language architecture. Security isolation
matters (plugins from untrusted sources). You want the strongest possible guarantee
against accidental API surface changes.

### 4. TypeScript Declaration Extraction

**Structure:** Generate `.d.ts` files from the public API and diff them between versions.

**How it works:**
- Package build produces declaration files
- CI compares declarations against a baseline
- Tools like `@arethetypeswrong/cli` validate that declarations match runtime behavior
- Declaration diffing catches type-level breaking changes

**Tradeoffs:**
- (+) Leverages existing TypeScript build output
- (+) Catches type-level breakage automatically
- (-) Declarations can be complex and hard to diff meaningfully
- (-) Doesn't catch runtime behavior changes
- (-) Less human-readable than API Extractor reports

**When to use:** You want lightweight automated checking without adopting API Extractor.
You already generate declarations as part of your build.

### 5. Consumer Contract Tests

**Structure:** Maintain a suite of tests that exercise the public API from the consumer's
perspective. These tests import only from the public entry point.

**How it works:**
- Separate test suite that imports the package the same way a consumer would
- Tests cover the documented API surface: component rendering, imperative methods, callbacks, type compatibility
- Tests break when the API breaks, regardless of internal changes
- Can be run against multiple versions to verify backward compatibility

**Tradeoffs:**
- (+) Tests actual consumer experience, not just type signatures
- (+) Catches runtime behavior regressions, not just type changes
- (+) Doubles as documentation — tests show how the API is used
- (-) Only covers tested scenarios — gaps in test coverage are gaps in the contract
- (-) Slower feedback than static analysis
- (-) Must be maintained alongside the API

**When to use:** As a complement to any of the above patterns. Especially valuable when
runtime behavior is part of the contract (not just types).

## Decision Guide

```
How many packages do you ship?
├── Multiple packages with distinct surfaces
│   → Tracked API Reports (tldraw pattern) + Consumer Contract Tests
├── Single package, large API surface
│   → TypeScript Declaration Extraction + Consumer Contract Tests
├── Single package, small API surface
│   → Semver-Only Discipline (if team is small)
│   → TypeScript Declaration Extraction (if team is growing)
└── Multi-language boundary exists?
    → Language-Boundary Enforcement + whatever fits the consumer-facing language
```

```
What's your stability requirement?
├── "Must never break without explicit decision"
│   → Tracked API Reports (make breakage visible in every PR)
├── "Should rarely break, acceptable with semver major"
│   → Semver-Only + Declaration Extraction
└── "Must be structurally impossible to break accidentally"
    → Language-Boundary Enforcement or Plugin Sandbox
```

## Anti-Patterns

### The Invisible Surface

No explicit definition of what's public. Everything exported from any module is
potentially part of the API. Consumers import from deep paths
(`@pkg/internal/utils/helpers`). The team discovers the "public API" by seeing what
breaks when they refactor.

**Why it happens:** The package grew organically from an internal module. Nobody drew
the boundary because there was no external consumer initially.

**Fix:** Define an explicit entry point. Re-export only the public API from it. Use
TypeScript `paths` or package.json `exports` to prevent deep imports. If consumers
already depend on deep paths, deprecate them over a migration period.

### The Changelog Lie

The changelog says "no breaking changes" but consumers' builds break after upgrading.
The team didn't consider a change breaking because it was "just a type refinement" or
"just removing an unused export."

**Why it happens:** Human judgment about what's "breaking" is unreliable. The team's
mental model of the API surface doesn't match consumers' actual usage.

**Fix:** Automated surface tracking removes human judgment from breaking-change detection.
If the API report changes, someone must explicitly acknowledge the change. Whether it's
"breaking" depends on the diff, not on the author's opinion.

### Surface Tracking Without Review Discipline

API reports are generated but nobody reads them. The CI check passes because the report
was regenerated, but no human evaluated whether the API change was intentional or desirable.

**Why it happens:** The report files are long and boring. Reviewers skip them.

**Fix:** API report changes should block merge until a designated API owner approves.
Use CODEOWNERS to route API report changes to the right reviewer. Keep report files
per-package so the diff is scoped.

### Version Pinning as a Stability Strategy

Instead of managing the API surface, consumers pin to exact versions and never upgrade.
The package team ships breaking changes freely because "consumers can just pin."

**Why it happens:** It's easier to break things than to maintain backward compatibility.
Pinning shifts the cost to consumers.

**Fix:** This is a cultural problem masquerading as a technical one. If your package has
consumers, you have a stability obligation. Version pinning is a consumer workaround for
a producer failure. Adopt one of the patterns above and treat API stability as a feature.

### Over-Stabilization

Every internal type is marked `@public`. The API surface is so large that any internal
change requires a major version bump. The team is paralyzed — they can't refactor without
"breaking" the API.

**Why it happens:** Marking things public is the path of least resistance when a consumer
asks for access to something.

**Fix:** Use visibility tiers (`@public`, `@beta`, `@internal`). Make `@beta` the default
for new exports — it signals that the API is available but not yet stable. Promote to
`@public` only after the API has proven stable through real usage. Ruthlessly keep
internals internal.

## Additional Production Evidence

### 6. Props-Driven Embedding Contract (FossFLOW/Isoflow Pattern)

**Structure:** `fossflow-lib` is published to npm as `fossflow`. The public API is two
exports: `Isoflow` (React component) and `useIsoflow` (hook). The embedding contract is
defined by `IsoflowProps` — a typed props interface with callbacks (`onModelUpdated`,
`onItemClick`), initial data, `editorMode` toggle, and `disableInteraction` flag.

**How it works:**
- The lib package exposes only `export { Isoflow, useIsoflow }` from its entry point
- `IsoflowProps` is the entire API surface — consumers configure behavior through props, not imperative methods
- Internal state lives in Zustand stores (`modelStore`, `sceneStore`, `uiStateStore`) that are never exposed to consumers
- The app package (`fossflow-app`) consumes the lib through the same public API — it is the first consumer
- Callback-based communication (`onModelUpdated`) is the only channel for host-to-lib state flow
- Mode configuration (`editorMode`, `disableInteraction`) controls capability without exposing internals

**Tradeoffs:**
- (+) Minimal API surface: two exports, one props type, a few callbacks
- (+) Internal Zustand stores can be freely refactored without breaking consumers
- (+) Props-only contract is familiar to React developers — no imperative API to learn
- (+) The app package dogfoods the same API external consumers use
- (-) No imperative escape hatch — if the callback model can't express a use case, consumer is stuck
- (-) Callback-based communication can have timing issues with rapid state updates
- (-) No extension system (no ShapeUtil equivalent) — consumers can't add new entity types

**When to use:** Your embeddable is a React component with a well-scoped feature set.
Consumers need configuration and event notification, not deep customization. You prefer
API surface minimalism over extensibility.

**Key files:** `packages/fossflow-lib/src/index.ts`, `packages/fossflow-lib/src/types/isoflowProps.ts`,
`packages/fossflow-lib/src/Isoflow.tsx`
