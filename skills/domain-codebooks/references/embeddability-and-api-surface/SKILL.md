---
name: embeddability-and-api-surface
description: >-
  Force tension: making a complex system embeddable as a component while maintaining
  feature completeness, with a stable API surface that doesn't constrain internal evolution.
  Four forces pull against each other — embeddability demands a small surface, feature
  completeness demands a large one, API stability demands freezing the surface, and internal
  evolution demands changing everything behind it.

  Triggers: "npm package from working app", "imperative API vs props API",
  "plugin system architecture", "SDK packaging and splitting", "API surface tracking",
  "extension point registry design", "white-label product architecture",
  "React wrapper for stateful editor", "host app state ownership",
  "breaking change detection", "embed vs standalone chrome split".

  Brownfield triggers: "internal refactors keep breaking consumers",
  "React wrapper re-renders entire canvas on parent prop change",
  "plugins can access internal APIs and break document integrity",
  "standalone app vs embedded version need different UI chrome",
  "every SDK release breaks consumer code from renamed exports",
  "imperative API isn't memoized causing full re-renders",
  "can't strip down UI for embedded mode without forking",
  "public API accidentally exposes internal store methods",
  "config object shape keeps changing across versions".

  Symptom triggers: "packaging canvas editor as npm library for third-party embedding
  internal refactors keep breaking consumers public API accidentally exposes internal
  store methods how do tldraw Excalidraw manage boundary between library internals
  and public API surface",
  "editor SDK ships both React component and vanilla JS API React wrapper re-renders
  entire canvas when parent props change imperative API not memoized properly how
  should React integration layer work for embeddable editor",
  "third-party plugins register custom shape types but get access to internal APIs
  that let them break document integrity how do embeddable editors sandbox plugin
  capabilities while still allowing powerful extensions",
  "editor used both as standalone app and embedded in other products standalone
  needs full chrome menus toolbars panels embedded version needs minimal UI only
  features host app enables how do editors handle this split",
  "every major release of editor SDK breaks consumer code keep renaming exports
  changing shape of configuration objects how do editors maintain API stability
  across versions while still evolving internally".

triggers:
  - library-vs-app boundary design
  - imperative API design for editors or complex components
  - plugin system architecture
  - SDK packaging and package splitting
  - API surface tracking and breaking change detection
  - extension points and ShapeUtil-style registries
  - component embedding in host applications
  - white-label product architecture
  - npm package design for complex stateful editors
  - "how do we let the host app own X without forking?"
  - props-driven vs imperative API tradeoffs
  - "consumers break every release"
  - "plugin can't access needed state"
  - "can't extract the editor as a reusable component"
  - "existing API leaks internal implementation details"
  - "adding a feature requires a breaking API change"
  - "host app needs to override behavior we hardcoded"
  - "refactoring internals accidentally broke the public surface"
  - "the reference app uses internal imports that consumers can't"
cross_codebook_triggers:
  - "embedded editor's undo doesn't work (+ undo)"
  - "embedded editor's bindings break (+ constraint-graph)"

diffused_triggers:
  - constraint-graph-under-mutation (bindings must work across the API boundary)
  - distributed-state-sync (sync must be ownable by host app, not baked into the package)
  - "every internal refactor breaks downstream consumers"
  - "we need to split the package but don't know where the boundary is"
  - "the plugin system can't do what plugins actually need"
  - "consumers are forking because the API doesn't expose enough"
  - "our SDK versioning is a mess"
  - "can't white-label without forking the whole repo"
skip:
  - simple component libraries with no state ownership tension
  - REST API versioning (different domain — request/response, not embedded runtime)
  - npm package publishing mechanics (registry config, bundling — not architecture)
  - micro-frontend orchestration without shared mutable state
libraries:
  - "@excalidraw/excalidraw (React component package with ExcalidrawImperativeAPI)"
  - "tldraw SDK (@tldraw/editor, @tldraw/store, @tldraw/tlschema, @tldraw/sync-core)"
  - "Penpot plugin system (ClojureScript atom + JS interop sandbox)"
  - "Memories (Nextcloud OCP DI plugin with 9 host interfaces, reflection escape hatches)"
  - "fossflow (npm-published React component lib with props-only API, internal Zustand stores)"
  - "Ente (embed app for public albums + UniFFI/WASM Rust core boundary)"
production_examples:
  - "Excalidraw: npm package as embeddable React component, excalidraw-app as host"
  - "tldraw: SDK packages with .api.md tracked reports, dotcom as reference host"
  - "Penpot: plugin sandbox enforcing change-pipeline, no direct mutation"
  - "Memories: Nextcloud app with 9-interface OCP DI, reflection escape hatches, cross-app table reads"
  - "FossFLOW: npm-published lib with minimal props-only API (Isoflow + useIsoflow), internal Zustand stores hidden"
  - "Ente: purpose-built embed app (public album viewer) + UniFFI/WASM cross-language boundary for Rust core"
---

# Embeddability and API Surface

## Step 1 — Classify the Situation

Determine which sub-problem dominates:

| Situation | Dominant force | Go to |
|---|---|---|
| Building an npm package from a working app | Embeddability vs completeness | `boundary-architecture.md` |
| Consumers breaking on upgrades | API stability vs internal evolution | `api-surface-management.md` |
| Designing plugin/extension system | All four forces simultaneously | Both references, start with boundary |
| White-labeling an existing product | Embeddability + stability | `boundary-architecture.md` then `api-surface-management.md` |
| Choosing between props API and imperative API | Embeddability vs completeness | `boundary-architecture.md` §Competing Patterns |

## Step 2 — Load Reference

Read the relevant reference file(s) identified in Step 1. Each contains:
- The precise problem statement
- Competing architectural patterns with tradeoffs
- Production examples from Excalidraw, tldraw, and Penpot
- Decision guide for choosing between patterns
- Anti-patterns to avoid

## Step 3 — Advise

When advising, apply the principles below and cross-reference related codebooks.

### Cross-References

- **constraint-graph-under-mutation**: If the embedded component has a constraint system
  (e.g., shape bindings, layout constraints), those constraints must work correctly across
  the API boundary. The host app must not be able to put the constraint graph into an
  inconsistent state through the public API.

- **distributed-state-sync**: Collaboration and sync must be ownable by the host app.
  Baking sync into the package (rather than exposing it as a composable layer) is the
  single most common architectural mistake in editor embedding.

- **focus-management-across-boundaries**: When an editor is embedded in a host app, keyboard
  focus must cross the API boundary cleanly — the host's focus traps, tab order, and shortcut
  handlers must coexist with the editor's internal focus model without either side stealing input.

---

## Principles

### 1. The Host Owns the Hard Parts

Collaboration, persistence, encryption, and auth belong to the host application, not the
embeddable package. The package provides the hooks (callbacks, events, imperative methods)
but never the implementation. Excalidraw learned this: collab lives in excalidraw-app,
not @excalidraw/excalidraw.

### 2. Fewer Entry Points, More Capability per Entry Point

A stable API surface is small in area but deep in capability. Prefer one `onChange` callback
that carries a structured delta over twenty granular event handlers. Prefer one `ShapeUtil`
registration that lets consumers define everything about a shape over ten separate registration
calls for each concern.

### 3. The API Boundary Is a Compression Boundary

Everything crossing the API boundary should be serializable, inspectable, and versionable.
If you can't print it, you can't version it. If you can't version it, you can't keep it
stable. Penpot enforces this structurally: the plugin sandbox physically cannot hold a
reference to internal mutable state.

### 4. Track the Surface or It Will Drift

Without explicit surface tracking, every internal refactor risks becoming a breaking change.
tldraw's approach — generating .api.md reports from TypeScript declarations and tracking
them in version control — makes API drift a visible, reviewable diff. The mechanism matters
less than the discipline: the surface must be a diffable artifact.

### 5. Scope State Ownership Explicitly

When a complex system becomes embeddable, state ownership becomes ambiguous. Who owns
selection state? Undo history? Viewport position? Make ownership explicit at the architecture
level. Excalidraw uses scoped Jotai atoms (editor-jotai vs app-jotai). tldraw uses a
layered store with clear ownership boundaries. The pattern matters less than the explicitness.

### 6. The Reference App Is the First Consumer

The team's own application (excalidraw-app, tldraw dotcom) must consume the package through
the same public API that external consumers use. If the reference app needs escape hatches,
the API is incomplete. If the reference app uses internal imports, the boundary is a fiction.
