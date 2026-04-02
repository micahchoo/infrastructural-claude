# Boundary Architecture

## The Problem

A monolithic editor application works well as a standalone product but cannot be embedded
into other applications. Extracting it into an embeddable component creates a tension:
the embedded version must be simple enough to drop into a host app (small API surface,
few dependencies, props-driven configuration) while retaining enough capability that
consumers don't immediately need to fork it or reimplement features.

The boundary you draw determines what the host app can own, what the package must own,
and what falls into the gap between them.

## Competing Patterns

### 1. Imperative API + Callbacks (Excalidraw Pattern)

**Structure:** Single React component (`<Excalidraw />`) with props for configuration and
an imperative API handle (`ExcalidrawImperativeAPI`) for programmatic control.

**How it works:**
- The component accepts props: `initialData`, `onChange`, `onPointerUpdate`, `UIOptions`, theme
- The imperative API exposes methods: `updateScene()`, `getSceneElements()`, `getAppState()`, `exportToBlob()`
- Host app receives state changes via `onChange` callback and pushes changes via imperative methods
- Collaboration is not in the package — excalidraw-app implements collab using `onChange` + `updateScene` as the seam
- State scoping: editor-internal state (Jotai atoms scoped to editor) vs app-level state (host-owned)

**Tradeoffs:**
- (+) Single package, simple to install and render
- (+) onChange/updateScene is a universal seam — works for collab, persistence, undo bridging
- (+) Host app has full control over everything outside the canvas
- (-) Imperative API surface grows over time as consumers need more control
- (-) No type-level enforcement of what the host can/cannot do
- (-) State synchronization between host and editor can have subtle timing issues

**When to use:** You have one primary component that hosts embed directly. The component
has clear visual boundaries. State ownership is mostly binary (editor owns or host owns).

### 2. SDK Package Split (tldraw Pattern)

**Structure:** Multiple npm packages with explicit dependency relationships:
`@tldraw/editor` (core), `@tldraw/store` (state), `@tldraw/tlschema` (data model),
`@tldraw/sync-core` (CRDT sync), `tldraw` (batteries-included).

**How it works:**
- Consumers who want the full experience import `tldraw` (includes default UI, tools, shapes)
- Consumers who want deep customization import `@tldraw/editor` and compose their own UI
- `ShapeUtil` is the extension surface: register custom shapes with full control over rendering, hit testing, binding, migration
- Each package has a tracked API surface (.api.md files generated from TypeScript declarations)
- Store layer is independent — consumers can use the built-in sync or bring their own

**Tradeoffs:**
- (+) Consumers choose their depth of integration: full package or core-only
- (+) Extension system (ShapeUtil) allows new capabilities without API surface growth
- (+) Package boundaries enforce layering — you can't accidentally depend on UI internals from the store layer
- (+) API surface tracking catches unintentional breaking changes in CI
- (-) More packages to version, publish, and keep compatible
- (-) Consumers must understand the package topology to make good choices
- (-) ShapeUtil API itself becomes a critical stability surface

**When to use:** Your system has natural layers (data model, state management, rendering, UI)
and different consumers need different layers. You expect a plugin/extension ecosystem.

### 3. Plugin Sandbox (Penpot Pattern)

**Structure:** Core application in ClojureScript with immutable atom-based state.
Plugin system exposes a JavaScript API that communicates through a controlled interop boundary.

**How it works:**
- Core state is a ClojureScript atom — structurally immutable, only mutated through the change pipeline
- Plugins run in a sandboxed JS context with no direct access to the atom
- Plugin API exposes query methods (read projections of state) and mutation methods (submit changes through the pipeline)
- The language boundary (ClojureScript/JS) physically prevents plugins from holding references to internal state
- All plugin mutations go through the same validation/pipeline as user actions

**Tradeoffs:**
- (+) Structural enforcement — plugins literally cannot break invariants
- (+) Internal refactoring is invisible to plugins as long as the projection/mutation API is stable
- (+) Same mutation pipeline means plugins get undo, validation, and persistence for free
- (-) Plugin capability is limited to what the API exposes — no escape hatch
- (-) Language boundary adds serialization overhead
- (-) Plugin developers must learn a custom API rather than using familiar framework patterns

**When to use:** You need strong isolation guarantees. Internal state representation is
complex and must remain consistent. You can afford to be opinionated about what plugins can do.

### 4. Headless Core + UI Shell

**Structure:** State management and business logic in a framework-agnostic core.
UI is a thin shell that renders from core state and dispatches core commands.

**How it works:**
- Core exposes a command/query interface: `dispatch(command)` and `subscribe(query, callback)`
- Core knows nothing about rendering — it manages the document model, selection, history
- UI shell (React, Svelte, etc.) subscribes to state projections and renders
- Different shells can wrap the same core for different contexts (full app, embedded widget, headless testing)

**Tradeoffs:**
- (+) Maximum embedding flexibility — any framework, any context
- (+) Clean testability — core is pure state machine
- (+) UI can be completely replaced without touching business logic
- (-) The command/query interface must be comprehensive enough to build a full UI
- (-) Performance-sensitive rendering (canvas, WebGL) may need tighter coupling than command/query allows
- (-) Two mental models: core state transitions and UI rendering

**When to use:** You need to support multiple UI frameworks. Your business logic is
complex enough to justify the indirection. Rendering is not the bottleneck.

## Decision Guide

```
Is the system a single visual component with clear boundaries?
├── Yes → Is the rendering performance-critical (canvas/WebGL)?
│   ├── Yes → Imperative API + Callbacks (Excalidraw pattern)
│   └── No  → Headless Core + UI Shell
└── No  → Does the system have natural layers that different consumers need?
    ├── Yes → SDK Package Split (tldraw pattern)
    └── No  → Do you need strong isolation guarantees for third-party code?
        ├── Yes → Plugin Sandbox (Penpot pattern)
        └── No  → Imperative API + Callbacks (simplest starting point)
```

## Anti-Patterns

### The God Component

A single component with 50+ props that tries to be both embeddable and feature-complete.
Every new feature adds more props. Every consumer uses a different subset. The props
interact in undocumented ways. Testing the combinatorial space is impossible.

**Why it happens:** Starting with "just add a prop" is easy. The cost is deferred.

**Fix:** Identify which props represent host-owned concerns (persistence, auth, collab)
vs editor-owned concerns (tool state, selection). Host-owned concerns should be callbacks
or injected dependencies, not configuration props.

### The Leaky Abstraction Boundary

The package exposes internal types, internal state shapes, or internal event systems
through its public API. Consumers depend on these internals. Every internal refactor
becomes a breaking change.

**Why it happens:** Convenience. It's faster to export an existing internal type than to
design a public-facing projection of it.

**Fix:** Every public type should be deliberately designed for external consumption.
Internal types can be richer, more mutable, more coupled. The projection from internal
to public is where the stability contract lives.

### Sync Baked Into the Package

The embeddable package includes collaboration/sync as a built-in feature rather than
an ownable concern. Every consumer gets the package's sync solution whether they want
it or not. Consumers who need different sync (their own backend, their own conflict
resolution) must fight the package.

**Why it happens:** The team builds sync for their own app and ships it as part of the
package because "everyone needs sync."

**Fix:** Sync is a layer, not a feature. Expose the seams (onChange, state snapshots,
incremental updates) that let the host app implement or choose their own sync. Ship
your sync as a separate composable package (like @tldraw/sync-core).

### The Internal Import Escape Hatch

The reference app (built by the same team) imports from internal package paths rather
than the public API. The public API appears stable because the team never uses it for
anything hard.

**Why it happens:** The team has access to internals and deadlines to meet.

**Fix:** The reference app must be the first and most demanding consumer of the public API.
If the reference app needs an escape hatch, that's a signal the public API is missing
something. Add it to the public API.

## Additional Production Evidence

### 5. Deep Host DI with Reflection Escape Hatches (Memories/Nextcloud Pattern)

**Structure:** Nextcloud app (Memories) deeply embedded in a host platform via OCP
dependency injection. Every controller inherits `GenericApiController` which injects 9
OCP interfaces (`IConfig`, `IUserSession`, `IDBConnection`, `IRootFolder`, `IAppManager`,
etc.). The app cannot function outside Nextcloud.

**How it works:**
- `FsManager` wraps Nextcloud's `IRootFolder` to build `TimelineRoot` objects, handling share tokens, public album tokens, user folders, and external mounts — each with different permission models
- When the host API is insufficient, the plugin breaks encapsulation: `FoldersController` uses PHP `ReflectionProperty` to access `\OC\Files\Node\Node::$view` (a private property) because no public API exists for MIME-filtered directory listing
- Cross-app table coupling: Albums are stored in `photos_albums` and `photos_albums_files` — tables owned by the Nextcloud Photos app. Memories queries them directly with version-conditional table names (`collaboratorsTable()` checks app version to pick `photos_albums_collabs` vs `photos_collaborators`)
- Multi-surface API: the same backend serves Nextcloud web UI, public share links, public album shares, NativeX mobile app (localhost HTTP), and admin CLI — each with different auth, data scopes, and lifecycle
- `ClustersBackend` implements plugin-within-a-plugin: face recognition, places, tags, and albums all share a common cluster interface, with swappable AI providers (`recognize` vs `facerecognition`)

**Tradeoffs:**
- (+) Full access to host platform capabilities (filesystem, users, sharing, DB)
- (+) DI-based coupling is at least explicit about what's needed
- (-) 9 injected interfaces = massive coupling surface; the app is unportable
- (-) Reflection escape hatches create invisible breakage risk on host upgrades
- (-) Cross-app table reads without formal contracts create silent breaking changes
- (-) Multi-surface auth patching (`tok()` in `API.ts`) shows the boundary leaking into every layer

**When to use:** You are building a plugin for an opinionated host platform that owns
auth, storage, and lifecycle. The host's public API covers 80% of your needs but the
remaining 20% requires escape hatches. Be aware that each escape hatch is a ticking
time bomb — document and isolate them.

**Key files:** `lib/Controller/GenericApiController.php`, `lib/Controller/FoldersController.php`,
`lib/Db/FsManager.php`, `lib/Db/AlbumsQuery.php`, `src/services/API.ts`

### 6. Embed App + UniFFI Cross-Language Boundary (Ente Pattern)

**Structure:** Multi-product platform (Photos, Auth, Locker) with a dedicated embed app
(`web/apps/embed/`) for public album viewing, plus a Rust core crate (`ente-core`)
exposed to mobile/desktop via UniFFI and to web via WASM.

**How it works:**
- The embed app is a narrow, purpose-built embeddable: a public album viewer that can be iframe'd, with password protection and client-side decryption
- `ente-core` in Rust reimplements libsodium in pure Rust, then exposes crypto primitives via UniFFI to Flutter/Dart (mobile) and via WASM to web
- The UniFFI boundary forces explicit API definition: every function exposed to mobile must be declared in the UniFFI IDL, creating structural enforcement similar to Penpot's language boundary
- The embed surface is intentionally narrow — no general-purpose SDK, no plugin API, just the minimum needed for public album display with E2EE

**Tradeoffs:**
- (+) UniFFI boundary prevents accidental exposure of Rust internals to mobile code
- (+) Purpose-built embed app avoids god-component bloat — it does one thing
- (+) Cross-language boundary (Rust/Dart, Rust/WASM) structurally enforces API surface discipline
- (-) Narrow embed surface means no extensibility — consumers get exactly what's offered
- (-) UniFFI/WASM dual compilation adds build complexity
- (-) No SDK story — third parties can embed the viewer but cannot build on the platform

**When to use:** You need a narrow embeddable artifact (viewer, widget) from a larger
platform, and you have a cross-language core that already enforces boundary discipline.
The UniFFI/WASM pattern is particularly relevant when the same core logic must serve
mobile, desktop, and web with identical semantics.

**Key files:** `web/apps/embed/`, `rust/core/src/crypto/`, UniFFI definitions in `ente-core`
