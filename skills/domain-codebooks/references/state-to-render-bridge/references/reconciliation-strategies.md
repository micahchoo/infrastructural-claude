# Reconciliation Strategies

## The Problem

Collaborative state (CRDT/OT) and imperative render systems have fundamentally
different update models. CRDTs produce fine-grained operations (insert char,
update property, delete node); render systems expect coarse-grained mutations
(add scene node, update props, remove subtree). The bridge must translate between
these granularities without:
- Causing render thrash (too many updates)
- Losing intermediate state (too few updates)
- Breaking render-local state (selection, animation)
- Scaling poorly with document size

---

## Competing Patterns

### 1. Custom Reconciler (weavejs)

**How it works:** A React-like reconciler protocol targeting a non-DOM render
system. CRDT state changes flow through a reactive proxy, triggering reconciler
operations that map to scene graph mutations.

**Example — weavejs Yjs→SyncedStore→Reconciler→Konva:**

The pipeline has four layers:
1. **Yjs Y.Doc** — authoritative CRDT state (Y.Map, Y.Array)
2. **SyncedStore proxy** — reactive JavaScript proxy over Yjs types
3. **Custom React Reconciler** — implements `createInstance`, `appendChildToContainer`,
   `removeChild`, `commitUpdate` targeting Konva
4. **Konva scene graph** — imperative canvas rendering

Key file: `packages/renderer-konva-base/src/reconciler.ts`

The reconciler implements:
- `createInstance(type, props)` — creates Konva node from CRDT-derived props
- `commitUpdate(instance, updatePayload, type, oldProps, newProps)` — patches
  existing Konva node with changed props
- `removeChild(parentInstance, child)` — removes Konva node and cleans up
- `isAncestorOf` guards prevent cross-subtree mutations
- Container resolution via `parentAttrs.containerId` → `findOne()` lookup
- Z-index post-correction (`initialZIndex`, `setZIndex(index)`)

Instruction processing in `renderer.ts`:
- `buildSubtree` / `createSubtree` — initial tree construction
- `updateProps` — incremental property updates
- `removeSubtree` — cleanup with descendant traversal

**Tradeoffs:**
- Leverages React's proven reconciliation model
- Incremental — only changed nodes are updated
- Complex — four layers of indirection
- Z-index management competes with Konva's native ordering
- `observeDeep` on SyncedStore can fire excessively

**De-Factoring Evidence:**
- **If the SyncedStore proxy layer were removed:** CRDT changes would need manual
  diffing against last-known Konva state. Every `Y.observe` callback would need
  to compute the delta and dispatch Konva mutations directly. The proxy absorbs
  the semantic gap between Yjs's event format and React's props model.
  **Detection signal:** Manual `Y.observe` handlers with hand-written diff logic
  that duplicates React's reconciliation.

- **If the custom reconciler were removed:** React's default DOM reconciler would
  produce DOM nodes, requiring a second DOM→Konva translation layer. Or, bypass
  React and write imperative Konva updates — losing batching and diffing.
  **Detection signal:** `useEffect` hooks that manually create/destroy Konva
  nodes, fighting React's lifecycle instead of leveraging it.

---

### 2. Remove-and-Add (allmaps)

**How it works:** On state change, destroy the existing render representation
and rebuild from scratch. Simple and correct, but expensive.

**Example — allmaps ShareDB→Svelte→WebGL:**

Three state layers:
1. **ShareDB document** — server-authoritative JSON via JSON1 OT
2. **Svelte reactive state** — `*.svelte.ts` files with Svelte 5 runes
3. **WebGL render state** — WarpedMapList, TileCache, RTree

Change flow: ShareDB op → parsed via `json1-operations.ts` → update Svelte rune
state → `warpedmaplayer.svelte.ts` bridges to imperative WebGL renderer.

Key file: `packages/render/src/renderers/WebGL2Renderer.ts`

The WebGL renderer maintains its own state (shader programs, texture arrays,
uniform caches) that cannot be incrementally patched from ShareDB ops. When a
map's control points change, the entire warped map is re-triangulated and
re-uploaded as textures — the GPU doesn't support incremental mesh updates for
this use case.

**Tradeoffs:**
- Correct by construction — no stale render state possible
- Simple bridge — no diff/patch logic needed
- Expensive — full rebuild on any change
- Acceptable when changes are infrequent (editing GCPs is discrete, not continuous)
- Unacceptable for high-frequency updates (typing, dragging)

**De-Factoring Evidence:**
- **If the Svelte reactive layer were removed:** ShareDB ops would need to drive
  WebGL state directly. The reactive layer absorbs the mismatch between JSON1 op
  semantics (path-based patches) and WebGL state (typed arrays, shader uniforms).
  **Detection signal:** ShareDB `on('op')` handlers with WebGL API calls.

---

### 3. Reactive Framework as Bridge (general pattern)

**How it works:** Feed CRDT state into a reactive framework's state primitives
(React state, Svelte stores, Vue refs). Let the framework's built-in
reconciliation handle DOM updates.

This is the simplest bridge but only works when the render target is the
framework's native output (DOM for React/Svelte/Vue). For non-DOM targets
(Canvas, WebGL, scene graphs), you need pattern 1 or 2.

**Key design decision:** Granularity of reactive binding.
- **Document-level:** One reactive atom for the whole CRDT doc. Framework diffs
  the entire component tree on any change. Simple but O(n) re-render.
- **Node-level:** One reactive atom per CRDT object. Framework only re-renders
  changed subtrees. More complex setup but O(1) per-change re-render.
- **Field-level:** One reactive atom per CRDT field. Finest granularity,
  minimal re-renders, but high memory/subscription overhead.

SyncedStore (used by weavejs) provides field-level reactivity via JavaScript
Proxy, but the `observeDeep` aggregation can collapse it back to document-level
if not carefully bounded.

#### 3a. Compare-Guard Bidirectional Sync (svelte-maplibre-gl)

When the render target is itself an imperative API with its own event model
(MapLibre GL, OpenLayers, Three.js), the bridge must be **bidirectional**: user
gestures on the imperative side write to reactive state, and reactive state
changes write back to the imperative API. The cycle-prevention mechanism is
deep equality comparison.

**Example — svelte-maplibre-gl MapLibre↔Svelte 5 runes:**

Key file: `src/lib/MapLibre.svelte`

Two bridge directions:
1. **Imperative → Reactive** (moveend handler):
```javascript
map.on('moveend', (ev) => {
  center = ev.target.getCenter();
  zoom = ev.target.getZoom();
  pitch = ev.target.getPitch();
  bearing = ev.target.getBearing();
});
```

2. **Reactive → Imperative** (camera $effect with compare guard):
```javascript
$effect(() => {
  if (map) {
    let options = {};
    if (center != null && !compare(center, map.getCenter())) {
      options.center = center;
    }
    if (zoom != null && !compare(zoom, map.getZoom())) {
      options.zoom = zoom;
    }
    // ... bearing, pitch same pattern
    if (Object.keys(options).length) {
      map.easeTo(options);
    }
  }
});
```

The `compare()` function (from `just-compare`) does deep equality. After a
gesture triggers `moveend`, the handler writes `center = map.getCenter()`.
This triggers the `$effect`, which compares the new `center` against
`map.getCenter()` — they're equal, so `easeTo()` is never called. Cycle broken.

Props are declared `center = $bindable(undefined)`, `zoom = $bindable(undefined)`.
Parents use `bind:center bind:zoom` for bidirectional flow.

**Tradeoffs:**
- Elegant — no flags, no debouncing, no event interception
- Relies entirely on value equality to break cycles
- No explicit throttling — rapid gestures produce rapid effect runs (fine because
  Svelte 5's `effect_update_depth_exceeded` only counts effects that **write** to
  state, not effects that run and no-op via the compare guard)
- Fragile to `undefined` — if a prop isn't passed, `moveend` transitions it from
  `undefined` to a value, which IS a change even though the map hasn't moved

**De-Factoring Evidence:**
- **If the compare guard were removed:** Every `moveend` would trigger `easeTo()`,
  which would trigger another `moveend`, creating an infinite loop. The compare
  function is the entire cycle-prevention mechanism — there are no backup guards.
  **Detection signal:** Infinite `moveend` → `easeTo()` → `moveend` loop when
  any map interaction occurs.
- **If `$bindable()` were removed and props made read-only:** Parents could set
  camera state but never read it back from map gestures. The bridge becomes
  one-directional, losing the "map as input device" capability.
  **Detection signal:** Parent component needs separate `onmoveend` callback to
  track map position, duplicating state management.

**Production example:** svelte-maplibre-gl — Svelte 5 runes + MapLibre GL JS.
Also used by allmaps editor (`apps/editor/src/lib/shared/maplibre.ts`), which
adopts the identical compare-guard pattern for its MapLibre integration.

#### 3b. Event-Source Discrimination with Stream Flow Control (penpot)

When the imperative API produces high-frequency events (pointer moves, scroll,
wheel zoom) that could overwhelm the reactive system, use stream operators to
classify, filter, and batch events before they enter reactive state.

**Example — penpot viewport sync (ClojureScript + potok/beicon):**

Key file: `frontend/src/app/main/data/workspace/viewport.cljs`

The bridge uses three mechanisms layered together:

1. **Event-source tags** distinguish event origins:
```clojure
;; Pointer events tagged by source — prevents cross-contamination
(rx/filter #(= :delta (:source %)))   ;; Only process drag deltas
(rx/filter #(= :viewport (:source %))) ;; Only process viewport events
```

2. **Guard flags** prevent re-entrant processing:
```clojure
(when-not (get-in state [:workspace-local :panning])
  ;; Only start panning if not already panning
  (rx/of #(-> % (assoc-in [:workspace-local :panning] true)))
  ...)
```

3. **Animation-frame batching** coalesces high-frequency events:
```clojure
(->> pointer-events
     (rx/observe-on :af)       ;; Schedule to requestAnimationFrame
     (rx/take-until stopper))  ;; Cancel on finish-panning event
```

**Tradeoffs:**
- Handles extreme event rates (hundreds of pointer events per second)
- Event-source tags prevent the reactive system from confusing programmatic
  moves with user gestures — a problem the compare-guard pattern doesn't address
- More complex — requires stream infrastructure (RxJS/beicon)
- Guard flags are explicit mutable state that must be correctly managed
- Stream lifecycle (subscription, teardown) adds operational complexity

**De-Factoring Evidence:**
- **If event-source discrimination were removed:** Programmatic viewport updates
  (e.g., "zoom to fit") would be indistinguishable from user gestures. The system
  would either suppress programmatic moves (breaking "zoom to fit") or process
  them as gestures (creating phantom pan events).
  **Detection signal:** `zoom-to-fit` triggers phantom pan-end handlers; viewport
  state oscillates between programmatic target and user's last gesture position.
- **If rAF batching were removed:** Each pointer-move event (potentially 60+ per
  second during drag) would trigger a synchronous state update and re-render.
  Multiple events per frame cause multiple renders per frame — visible jank.
  **Detection signal:** Frame drops during pan/zoom; profiler shows multiple
  layout recalculations per animation frame.

**Production example:** penpot — ClojureScript + potok event system + beicon
reactive streams. The viewport sync handles pan, zoom, and scroll with separate
stream pipelines per interaction type, all batched to animation frames.

---

### 4. Action Replay (iiif-manifest-editor)

**How it works:** Instead of diffing CRDT state, replay high-level actions
(Redux-like action objects) that produce both state changes and render effects.

**Example — iiif-manifest-editor Vault→React:**

Key file: `packages/server-vault/src/server-vault.ts`

The server-vault relays Vault actions (Redux-like) over WebSocket:
- `_lastActionId` for causal ordering
- Rebroadcast to all clients except sender
- Sender gets confirmation via `RemoteActionConfirmation`
- Rejection mechanism exists (`RemoteActionRejection`) but handlers are stubs

Client applies received actions to local Vault store, which triggers React
re-renders through normal Redux→React flow.

**Tradeoffs:**
- No bridge layer needed — actions already describe render-meaningful changes
- Causal ordering via action IDs is simpler than CRDT merge
- No conflict resolution — arrival-order wins
- Doesn't handle concurrent edits to same data (divergence possible)
- Works for "one editor at a time" collaboration, not concurrent editing

**De-Factoring Evidence:**
- **If action replay were replaced with CRDT sync:** The simple relay becomes
  a CRDT merge layer. Actions lose their identity (merged into CRDT state).
  The benefit of "human-readable actions" is lost.
  **Detection signal:** Need for conflict resolution suggests outgrowing this
  pattern.

---

## Decision Guide

**Choose Custom Reconciler when:**
- Render target is a non-DOM scene graph (Konva, Three.js, Pixi)
- Update frequency is high (real-time collaboration)
- You need fine-grained incremental updates
- You're already using React and can leverage its reconciler model

**Choose Remove-and-Add when:**
- Changes are infrequent (discrete edits, not continuous)
- Render state is hard to patch incrementally (GPU textures, compiled shaders)
- Correctness matters more than performance
- Bridge simplicity is a priority

**Choose Reactive Framework Bridge when:**
- Render target is DOM (the framework's native output)
- You want the framework to handle reconciliation
- CRDT objects have stable reactive bindings available

**Choose Compare-Guard Bidirectional Sync when:**
- Render target is an imperative API with its own event model (map library,
  3D engine, audio graph)
- The imperative API fires events on user interaction that must flow back to
  reactive state (bidirectional, not one-way projection)
- Value equality is cheap to compute for the synced properties
- The wrapper library already implements the binding contract (e.g.,
  svelte-maplibre-gl's `$bindable()` props)

**Choose Event-Source Discrimination when:**
- The imperative API produces high-frequency events (>30/sec) during normal use
- You need to distinguish user gestures from programmatic updates
- Multiple interaction types (pan, zoom, rotate) can overlap temporally
- You have stream infrastructure (RxJS, beicon) available

**Choose Action Replay when:**
- Collaboration is turn-based, not concurrent
- Actions are semantically meaningful for both state and UI
- You don't need conflict resolution (or have external locking)

---

## Anti-Patterns

### 1. Bridging Derived State Instead of Source State
Syncing render-derived values (computed positions, cached layout) through the
CRDT creates feedback loops. Bridge from authoritative CRDT state; let each
client derive render state locally.
**Detection signal:** CRDT document contains fields like `renderX`, `cachedBounds`,
or `displayPosition` alongside semantic data.

### 2. Per-Op Reconciliation Without Batching
Processing each CRDT operation as a separate render update causes N re-renders
for N ops in a sync batch. Coalesce to one update per animation frame.
**Detection signal:** Visible flicker during remote sync; render callbacks inside
`Y.observe` or `doc.on('op')` without debouncing.

### 3. Monolithic Bridge Function
A single function that reads entire CRDT state and writes entire render state.
Grows linearly with document complexity. No way to optimize for common cases.
**Detection signal:** Bridge function exceeds 500 LOC; all changes take the
same code path regardless of what changed.

### 4. Two-Way Bridge Mutations
Bridge writes render changes back into CRDT state (e.g., updating a "lastRendered"
field). Creates circular dependency between state and rendering layers.
**Detection signal:** CRDT writes inside render callbacks; "infinite loop" bugs
when remote changes arrive.

### 5. Undefined Props in Bidirectional Sync
When a reactive wrapper declares props as `$bindable(undefined)` and the parent
doesn't pass them, the imperative API's events create `undefined → value`
transitions that look like changes to the reactive system. The effect runs,
compares against the API's current state, and no-ops — but the transition itself
may trigger downstream effects or (in frameworks that count effect runs) contribute
to flush depth pressure.
**Detection signal:** `effect_update_depth_exceeded` or excessive effect runs
during tile loading or animation, even though no actual state cycle exists. The
fix is to pass the props (with initial values or via binding), not to remove them.
**Consequence:** Removing props to "avoid cycles" actually makes things worse —
the `undefined → value` transition on every event is a bigger problem than the
bidirectional sync the props enable.

### 6. Fighting the Library's Sync Contract
When a reactive wrapper library (svelte-maplibre-gl, react-map-gl, vue-mapbox)
is designed for bidirectional prop binding, working around it — removing props,
intercepting events, adding manual `onmove` handlers — creates a parallel state
management system that competes with the library's built-in bridge.
**Detection signal:** Custom event handlers that duplicate what the library
already does; wrapper components with `on:moveend` callbacks that manually
update local state instead of using `bind:center`; guard flags (`isMoving`,
`skipNextUpdate`) that wouldn't be needed if props were bound normally.
**Consequence:** Two competing state management paths — the library's bidirectional
sync AND custom event handlers — that interfere with each other, creating the
exact cascades the workaround was meant to prevent.

### 7. Store Method Tracking Leak
When an `$effect` (or `useEffect` with fine-grained signals, or Vue `watchEffect`)
calls a store method that internally **reads** reactive state — even for a guard
check like `if (state.status === 'ready')` — the effect tracks that state as a
dependency. If the method also **writes** to the same state (e.g.,
`state = { status: 'idle' }`), the new object reference triggers the effect
again, creating an invisible cycle.

The danger is that the effect author sees a write-only call (`store.reset()`)
but the reactive system sees a read-then-write through the method's internals.

**Detection signal:** Two effects ping-ponging indefinitely with the same
dependency values on every run. The effect body appears to only write, not read,
the store — but a method it calls contains a conditional read.

**Fix hierarchy** (cheapest first):
1. **No-op guard in the store method** — `if (state.status === 'idle') return;`
   prevents writing a new object when the value is semantically unchanged.
2. **`untrack()` around the call** — wrapping `untrack(() => store.reset())`
   in the effect body prevents the method's internal reads from becoming
   tracked dependencies.
3. **Separate the guard from the mutation** — split `reset()` into a pure
   status check and an untracked write, so the conditional read never enters
   the tracking scope.

**Applies to:** Svelte 5 `$state`/`$effect`, SolidJS signals/effects,
Vue 3 `ref`/`watchEffect`, any fine-grained reactivity system where function
calls inside effects inherit the tracking scope.

**Production example:** felt-like-it — `drawingStore.reset()` called inside a
Terra Draw initialization `$effect` read `_state.status` (tracked), then wrote
`_state = { status: 'idle' }` (new ref). This triggered a tool-sync effect that
read `_state` via `drawingStore.instance`/`isReady` getters, which re-triggered
the init effect → infinite loop. 10 prior fix commits targeted other components
because the cycle was invisible without effect-level instrumentation.

---

## Cycle Elimination Process

When `effect_update_depth_exceeded` (Svelte 5), infinite `useEffect` loops
(React), or signal cycle warnings (SolidJS/Vue) occur, follow this process
instead of guessing at fixes.

### Step 1: Instrument — make the cascade visible

Add labeled entry/exit logging to every effect and mutation logging to every
store write. Each log entry needs:
- **Effect name** (component prefix + semantic label)
- **Tick count** within the current flush cycle
- **Dependency snapshot** (values the effect read)
- **Caller** (which effect triggered this mutation)

This turns an opaque "depth exceeded" error into a readable chain like:
```
EFFECT A (reads X=1) → MUTATION store.Y ← from A → EFFECT B (reads Y) → MUTATION store.X ← from B → EFFECT A ...
```

### Step 2: Identify the cycle participants

From the instrumented chain, find **repeated effect names**. The cycle is the
shortest path between two occurrences of the same effect. Effects that appear
once are bystanders — they ran but didn't contribute to the loop.

### Step 3: For each edge in the cycle, apply the cheapest structural fix

| Symptom | Fix | Cost |
|---------|-----|------|
| Effect reads state it doesn't need | `untrack()` the read | Trivial |
| Store method has internal guard that reads state | No-op guard + `untrack()` at call site | Trivial |
| Write creates new reference for same semantic value | Equality guard before write | Low |
| Two effects that could be one | Merge into single effect | Low |
| Effect exists only to sync two stores | Replace with `$derived` | Medium |
| Bidirectional sync with imperative API | Compare-guard pattern (§3a above) | Medium |
| Fundamental architecture mismatch | Redesign state ownership | High |

### Step 4: Verify — run with instrumentation still active

After fixing, the flush cycle tick count should be **stable and low** (typically
< 30 for a complex component tree). If it's still climbing, repeat from Step 2
with the new chain — multiple independent cycles can mask each other.

### Step 5: Remove instrumentation or gate behind a flag

Leave the infrastructure in place behind a runtime flag
(`window.__EFFECT_DEBUG = false`) for the next occurrence. Effect cycles are
recurrent — they reappear when new effects or store methods are added.
