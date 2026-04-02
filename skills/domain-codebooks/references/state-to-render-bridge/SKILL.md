---
name: state-to-render-bridge
description: >-
  Force tension: authoritative collaborative state (CRDT/OT/action-log) must be
  projected into an imperative render system (Canvas, WebGL, DOM tree, scene graph)
  with fundamentally different update granularity, ordering semantics, and lifecycle.

  The three-way tension: state fidelity vs render performance vs bridge complexity.

  Triggers: "CRDT to render reconciliation", "collaborative state to canvas",
  "reactive state to imperative renderer", "virtual DOM for canvas scene graph",
  "decoration overlay merging", "normalized state to spatial index bridge",
  "fractional index sort order for rendering", "document coordinates to screen
  coordinates transform", "computed derived properties in render pipeline",
  "transient UI state vs persistent document state compositing",
  "async remote state integration into render loop",
  "Svelte effect cascade from map events", "bidirectional prop binding to
  imperative API", "effect_update_depth_exceeded with map library",
  "reactive framework wrapping imperative map/canvas/WebGL API",
  "MapLibre move events triggering infinite reactive updates".

  Brownfield triggers: "full scene rebuild on every CRDT update is slow",
  "reactive state to flat GPU buffers is expensive on every change",
  "multiple decoration sources conflict in render pass",
  "expensive render nodes lose state during canvas reconciler diffs",
  "maintaining spatial index incrementally when shapes move is complex",
  "transient 60fps state and infrequent document state need unified pipeline",
  "fractional index re-sort on remote insert is inefficient",
  "annotation overlay recomputes all positions on every viewport change",
  "computed properties with cross-entity dependencies are hard to invalidate",
  "async remote updates arrive mid-frame and cause tearing",
  "Svelte $effect fires on every map move event and hits depth limit",
  "removing map props to avoid cycles made things worse",
  "map library's bidirectional binding creates effect cascades during tile load".

  Symptom triggers: "CRDT updates cause full scene teardown and rebuild
  which is slow for large documents", "transforming hierarchical reactive
  state into flat GPU vertex buffers on every change is expensive",
  "text decoration overlays from multiple sources like selections search
  results and collaborator cursors conflict", "virtual DOM canvas
  reconciler loses expensive render nodes with textures and shaders during
  diffs", "normalized entity map needs spatial tree quadtree but maintaining
  it incrementally when shapes move is complex", "persistent document state
  and transient 60fps UI state like selection hover drag need unified render
  pipeline", "fractional index re-sort on remote insert for draw order is
  inefficient", "annotation HTML overlay recomputes all positions on every
  zoom and pan", "computed visible bounds depend on geometry plus parent
  clip path plus zoom and are hard to invalidate", "async remote updates
  arrive during render frame and cause visual tearing".

triggers:
  - CRDT to render reconciliation
  - collaborative state to canvas
  - Yjs to scene graph
  - Automerge to ProseMirror
  - ShareDB to renderer
  - OT state to DOM
  - state bridge layer
  - reconciler for collaborative state
  - CRDT diffs to imperative updates
  - "remote changes don't render until refresh"
  - "render thrash when many ops arrive at once"
  - "full rebuild on every state change kills performance"
  - "position mapping between CRDT and editor is wrong"
  - "remote edits cause flicker or layout jump"
  - "undo renders intermediate states before settling"

cross_codebook_triggers:
  - "CRDT updates cause render glitches (+ distributed-state-sync)"
  - "optimistic update shows then disappears (+ optimistic-ui-vs-data-consistency)"
  - "remote changes break selection state (+ interactive-spatial-editing)"

diffused_triggers:
  - "how do I connect Yjs to my canvas library"
  - "Automerge changes need to update ProseMirror"
  - "ShareDB ops should reflect in the UI"
  - "CRDT state changed but nothing re-rendered"
  - "too many re-renders when collaborative edits arrive"
  - "bridge layer between state and view is getting unmaintainable"
  - "decoration-based approach vs transaction-based approach"
  - "should I rebuild the scene graph or patch it incrementally"

skip:
  - Single-user state management (Redux → React, Vuex → Vue)
  - Server-side rendering without collaborative state
  - Static data visualization (no live mutations)

libraries:
  - weavejs (Yjs → SyncedStore → React Reconciler → Konva)
  - allmaps (ShareDB → Svelte runes → WebGL2)
  - upwelling (Automerge → PositionMapper → ProseMirror)
  - iiif-manifest-editor (Vault action replay → Redux → React)
  - svelte-maplibre-gl (MapLibre GL JS ↔ Svelte 5 runes via compare-guard bidirectional sync)
  - penpot (potok/beicon streams → ClojureScript atoms → SVG/WASM canvas via event-source discrimination)

production_examples:
  - "weavejs reconciler.ts — custom React Reconciler targeting Konva scene graph from CRDT state"
  - "allmaps warpedmaplayer.svelte.ts — Svelte reactive bridge between ShareDB and WebGL2 renderer"
  - "upwelling PositionMapper.ts + AutomergeToProsemirrorTransaction.ts — bidirectional CRDT↔rich-text mapping"
  - "iiif-manifest-editor server-vault.ts — action replay over WebSocket with causal ordering"
  - "svelte-maplibre-gl MapLibre.svelte — compare-guard bidirectional sync between MapLibre GL move events and Svelte 5 $bindable() camera props"
  - "penpot viewport.cljs — event-source discrimination + rAF batching for high-frequency pan/zoom via potok/beicon streams"
---

# State-to-Render Bridge

When collaborative state (CRDT, OT, or action-log) is the source of truth,
every remote mutation must be projected into a rendering system with different
update semantics. This codebook covers how to design, optimize, and maintain
that bridge layer.

---

## Step 1: Classify

Answer these questions to determine which patterns apply:

1. **What is the collaborative state model?** CRDT (Yjs, Automerge), OT
   (ShareDB, Firepad), action-log (custom replay), or hybrid?

2. **What is the render target?** Imperative scene graph (Konva, Three.js),
   Canvas2D/WebGL direct, DOM tree (ProseMirror, Slate), or reactive framework
   (React, Svelte, Vue)?

3. **How many intermediate layers exist?** Direct (CRDT → renderer), one
   intermediate (CRDT → reactive store → renderer), or multi-layer (CRDT →
   proxy → reconciler → scene graph)?

4. **What is the mutation frequency?** Bursty (paste, remote batch sync) vs
   continuous (collaborative typing, drag operations)?

5. **Is position mapping required?** Flat index (CRDT chars) → tree positions
   (ProseMirror/Slate nodes)? Or flat-to-flat (CRDT → canvas objects)?

6. **Must the bridge preserve local state?** Selection, scroll position, cursor
   decorations, animation state that should survive remote updates?

---

## Step 2: Load Reference

| Scenario | Reference | Key Pattern |
|---|---|---|
| Full-rebuild vs incremental patching, reconciler design | `get_docs("domain-codebooks", "state-to-render reconciliation strategies")` | Custom reconciler, remove+add, diff-and-patch |
| Rich-text CRDT↔editor mapping, decoration overlays | `get_docs("domain-codebooks", "state-to-render decoration bridge")` | Position mapping, transaction translation, decoration layers |
| Remote updates cause render thrash or flicker | `get_docs("domain-codebooks", "state-to-render reconciliation strategies")` | Transaction batching, coalescing |
| Bridge must preserve selection/scroll across updates | **cross-ref:** interactive-spatial-editing | Selection state isolation |
| Optimistic local state vs confirmed remote state | **cross-ref:** optimistic-ui-vs-data-consistency | Dual truth reconciliation |
| CRDT internals (tombstones, compaction) affect bridge | **cross-ref:** crdt-structural-integrity | GC impact on rendering |

---

## Step 3: Advise

### When the render target is an imperative scene graph (Konva, Three.js):

Use a reconciler pattern. Map CRDT document nodes to scene graph nodes via a
stable ID. On CRDT change, diff the CRDT state against current scene graph and
emit create/update/remove instructions. Weavejs does this with a custom React
Reconciler targeting Konva — `createInstance`/`commitUpdate`/`removeChild`
mirror React's reconciliation protocol but output Konva mutations.

### When the render target is a reactive framework (Svelte, React, Vue):

Let the framework's reactivity handle reconciliation. Bridge CRDT state into
the framework's reactive primitives (Svelte runes, React state, Vue refs). The
framework then diffs and updates the DOM. Allmaps does this: ShareDB ops flow
through `json1-operations.ts` into Svelte reactive state, which triggers
component re-renders that drive WebGL updates.

### When the render target is a rich-text editor (ProseMirror, Slate):

Build bidirectional transaction translators. CRDT changes must be expressed as
editor transactions; editor transactions must be expressed as CRDT operations.
Position mapping between flat CRDT indices and tree-structured editor positions
is the critical complexity. Upwelling's `PositionMapper.ts` handles this with
per-block-element offset arithmetic — and explicitly defers complex block types
(lists, blockquotes) because they break the position math.

### When mutation frequency is bursty (remote sync, paste):

Batch CRDT changes into a single render update. Coalesce multiple ops that arrive
in the same frame into one reconciliation pass. Without batching, N remote ops
trigger N re-renders — producing visible flicker as intermediate states display
briefly. Weavejs uses `observeDeep` to collect all changes, then dispatches a
single reconciler update.

### When the bridge must preserve local state:

Isolate ephemeral local state (selection, cursor, scroll, animation) from the
bridge layer. Remote updates flow through the bridge; local state is restored
after each reconciliation pass. ProseMirror's decoration system is designed for
this — decorations overlay the document without being part of it, surviving
remote transaction application.

---

## Cross-References

- **distributed-state-sync** — Provides the collaborative state that this
  codebook bridges to rendering. The sync layer's batching semantics directly
  affect bridge design (single-op vs batch delivery).
- **optimistic-ui-vs-data-consistency** — The bridge must handle the gap between
  optimistic local display and confirmed remote state. Rollback strategies
  interact with bridge reconciliation.
- **interactive-spatial-editing** — Selection, hit-testing, and drag state must
  survive bridge reconciliation of remote changes.
- **crdt-structural-integrity** — Tombstone growth, compaction events, and
  snapshot loading all trigger non-incremental bridge updates.
- **rendering-backend-heterogeneity** — Different render backends (Canvas2D,
  WebGL, SVG) require different bridge output formats.

---

## Principles

1. **The bridge is a one-way projection, not a sync protocol.** CRDT state is
   authoritative. The bridge reads CRDT state and writes render state. Never
   store render-derived state back into the CRDT — that creates feedback loops.

2. **Batch before bridging.** Coalesce multiple CRDT changes into one
   reconciliation pass. The bridge should operate on "what changed since last
   render frame," not "process each op individually."

3. **Stable identity enables incremental updates.** If CRDT objects have stable
   IDs that map to render objects, the bridge can diff and patch. Without stable
   IDs, every change requires full rebuild — which is correct but expensive.

4. **Position mapping is the hardest part of text bridges.** Flat CRDT indices
   and tree-structured editor positions use different coordinate systems. Every
   structural element (paragraph, heading, list item) introduces offset
   divergence. Restrict schema complexity until the mapping is proven correct.

5. **Local ephemeral state must survive remote updates.** Selection, scroll
   position, cursor decorations, and in-progress drag operations must be
   preserved across bridge reconciliation. Design the bridge to be
   non-destructive to ephemeral state.

6. **The bridge layer is where complexity concentrates.** When you compose
   rather than build (delegating CRDT to Yjs, rendering to Konva, etc.),
   the integration seams — not the algorithms — become the spaghetti risk.
   Budget complexity management effort for the bridge.
