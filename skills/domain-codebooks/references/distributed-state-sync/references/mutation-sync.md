# Mutation → UI Sync Patterns

## The Problem

When a user creates, edits, or deletes an annotation, every part of the UI that displays that annotation must update — the map layer, the sidebar list, the detail panel, the undo stack. Without a deliberate sync strategy, each component fetches or caches its own copy. One component shows the new annotation while another still shows stale data, or worse, a deleted annotation persists as a ghost in the sidebar because nobody told it to re-query. Optimistic updates compound this: you show the change instantly for responsiveness, but if the server rejects it, rolling back one component while leaving another stale produces split-brain UI.

The problem intensifies with spatial data. Vector tile layers are pre-rendered — they can't reflect a mutation until tiles regenerate, which may take seconds or minutes. Meanwhile the user expects to see their edit immediately. And at high frequency (dragging shapes at 60fps), pushing every intermediate position through a reactive store triggers cascading re-renders across the entire component tree, turning a smooth interaction into a stuttering mess.

These failures are subtle because they don't throw errors. The UI just looks "slightly wrong" — a shape that should be gone is still there, a list that should update doesn't, a drag that should be smooth hitches. Debugging requires understanding the full mutation-to-render pipeline, which is exactly what these patterns address.

## Competing Patterns

## Pattern 1: Query cache with automatic invalidation (server-backed apps)

**When to use**: App fetches annotations from an API and multiple components need consistent state after mutations.

**When NOT to use**: Client-only apps with no server, or when you need sub-frame latency (60fps dragging) — cache invalidation round-trips are too slow.

**How it works**: Wrap API calls in a cache layer (TanStack Query, SWR). After mutations, invalidate the relevant cache keys so all subscribed components refetch. For creates, invalidate in `onSettled` (need server-assigned IDs). For deletes, use optimistic updates with rollback on error.

```typescript
const queryKeys = {
  annotations: {
    all: ['annotations'] as const,
    list: (mapId: string) => ['annotations', 'list', mapId] as const,
    detail: (id: string) => ['annotations', 'detail', id] as const,
  },
};

// After mutation:
await queryClient.invalidateQueries({ queryKey: queryKeys.annotations.list(mapId) });
```

**Svelte 5 pitfall**: `createQuery` MUST be at component top-level. Never inside `$effect`, `$derived`, or conditionally — causes infinite loops.

**Optimistic deletes** (rollback on error):
```typescript
const deleteMutation = createMutation({
  mutationFn: (id: string) => trpc.annotations.delete.mutate({ id }),
  onMutate: async (id) => {
    await queryClient.cancelQueries({ queryKey: queryKeys.annotations.list(mapId) });
    const previous = queryClient.getQueryData(queryKeys.annotations.list(mapId));
    queryClient.setQueryData(queryKeys.annotations.list(mapId), (old) =>
      old?.filter((a) => a.id !== id)
    );
    return { previous };
  },
  onError: (_err, _id, context) => {
    queryClient.setQueryData(queryKeys.annotations.list(mapId), context?.previous);
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.annotations.list(mapId) });
  },
});
```

**Production example**: Felt uses TanStack Query for annotation CRUD with per-map-id cache keys. Invalidation after mutations keeps sidebar lists, map overlays, and detail panels in sync without manual coordination.

**Tradeoffs**:
- Cache key design determines invalidation granularity — too broad refetches everything, too narrow misses dependents
- Optimistic updates add complexity (rollback logic, snapshot caching) but are essential for responsive UX
- `staleTime` (30s for annotation lists) and `refetchOnWindowFocus: false` prevent surprise refetches mid-editing

**Creates**: Just invalidate in `onSettled` (need server-assigned IDs).

**Svelte 5 pitfall**: `createQuery` MUST be at component top-level. Never inside `$effect`, `$derived`, or conditionally — causes infinite loops.

## Pattern 2: Hot/cold overlay (large vector tile layers)

**When to use**: Annotations served as vector tiles (Martin, Tippecanoe) but recent edits must appear before tile regeneration.

**When NOT to use**: Small datasets that don't need vector tiles, or apps where tile regeneration is fast enough (<1s) to skip the overlay.

**How it works**: Maintain two sources — a cold source (pre-generated vector tiles for stable data) and a hot source (small GeoJSON overlay for recent edits). Features migrate hot-to-cold after tile cache refreshes. The hot overlay is typically a simple GeoJSON source that the map renderer composites on top of the tile layer.

**Production example**: Felt runs a background process that continuously merges hot edits into base tiles, keeping the delta small. Simpler alternative: cache-bust tile URL after mutations.

**Tradeoffs**:
- Adds a second data source to maintain and render
- Hot-to-cold migration timing affects how long the overlay grows
- Imperative `setTiles()` cache-busting conflicts with declarative map wrappers (svelte-maplibre-gl, react-map-gl) — use the hot overlay instead

## Pattern 3: Event-driven store (client-only apps)

**When to use**: Client-only apps with IndexedDB persistence, no server round-trips. Need event hooks for plugins, undo, or cross-component notifications.

**When NOT to use**: Server-backed apps where cache invalidation (Pattern 1) provides consistency for free, or apps needing CRDT sync (use Pattern 6 instead).

**How it works**: A single store class owns the annotation collection and emits typed events on mutation. Subscribers (UI components, persistence layer, undo manager) react to events rather than polling or re-deriving. Use `$state.raw()` + a version counter in Svelte 5 to avoid deep proxy overhead on large Maps.

```typescript
class AnnotationGraphStore {
  #annotations = $state.raw(new Map<string, Annotation>());
  #version = $state(0);
  #listeners = new Set<EventHandler>();

  add(anno: Annotation): void {
    const map = new Map(this.#annotations);
    map.set(anno.id, anno);
    this.#annotations = map;
    this.#version++;
    this.#emit({ type: 'add', annotation: anno });
  }
}
```

**Why `$state.raw` + version counter**: `$state` deep-proxies objects — expensive for large Maps. `$state.raw` opts out; `#version` counter triggers reactivity on collection changes.

## Pattern 4: Manual array spreading (anti-pattern)

`annotations = [...annotations, created]` — no cache invalidation across components, no optimistic updates, no error rollback, every component manages its own copy. Migrate to Pattern 1 or 3.

## Error handling

- Surface errors via toast/inline — never silently swallow
- Retry transient network errors once; never retry validation errors (`BAD_REQUEST`)
- For optimistic rollback: toast "Delete failed — annotation restored." Don't silently restore.

## Svelte 5 effect pitfalls

**Circular dependency** — effect reads and writes same reactive graph:
```typescript
// BROKEN:
$effect(() => {
  const selected = selectionStore.selectedIds;
  mapStore.highlightFeatures(selected); // writes → retriggers
});

// FIX: untrack() breaks the cycle
$effect(() => {
  const selected = selectionStore.selectedIds;
  untrack(() => { mapStore.highlightFeatures(selected); });
});
```

**Effect cleanup**: Always return cleanup for map event listeners in `$effect`.

## Ephemeral modifier/preview layer

Interactive transforms (drag, resize, rotate) need visual feedback every frame but must not flood the undo stack, trigger persistence, or emit collaboration events.

### Four-phase lifecycle

1. **Create**: Build modifier tree mapping shape IDs to pending transforms
2. **Set (preview)**: High frequency (60fps), ephemeral state only — renderer reads this
3. **Apply (commit)**: Once on mouse-up, mutates document, creates single undo entry
4. **Clear**: Reset ephemeral state

Phase 2 runs 60+ times/sec. Phase 3 runs once. Undo sees one entry, not 60.

### Production examples

- **Penpot**: `workspace-modifiers` holds transient transforms. `set-modifiers` updates preview; `apply-modifiers` commits through changes-builder. WASM renderer has parallel path (`workspace-wasm-modifiers`).
- **tldraw**: `editor.run()` with `transact()` collects operations. Shapes render from `getCurrentPageShapesSorted()` including pending transforms.
- **Excalidraw**: Pending elements shown visually before committing to element array.
- **Mapbox GL Draw**: `toDisplayFeatures()` renders ephemeral features not yet in GeoJSON source.

### Implementation rules

- **Keep modifiers outside reactive system.** 60fps updates must not trigger deep proxy traversal. Use `$state.raw()` or plain objects in Svelte 5; refs or external stores in React.
- **Only the commit step creates undo entries.** Preview updates must never touch undo, persistence, or collaboration events.
- **Multi-shape batch transforms need parent-child propagation.** Penpot uses `geometry-parent`/`geometry-child` modifier lists to separate inherited from direct transforms.
- **WASM/WebGL renderers** may need parallel modifier paths (Penpot maintains both `workspace-modifiers` and `workspace-wasm-modifiers`).

## Structure vs geometry modifier channels

When annotations have hierarchy (groups, frames), mutations split into two categories needing separate pipelines:

- **Structure**: Reparenting, add/remove children, reorder siblings → tree traversal propagation
- **Geometry**: Position, scale, rotation, skew → transform matrix composition

**Why separate channels:**
1. **Different propagation.** Reparenting requires updating parent pointer AND rebasing local coordinates. Shared pipeline risks wrong ordering.
2. **Different undo granularity.** "Move into group" vs "resize group" are distinct undo entries.
3. **Different collaboration semantics.** Concurrent reparent + resize should merge cleanly.

**Production examples:**
- **Penpot**: `set-structure-modifiers` (tree ops) vs `set-wasm-modifiers` (spatial ops), merged at `apply-modifiers`
- **Figma**: Auto-layout separates "reorder children" (structure) from "resize frame" (geometry) as two phases
- **tldraw**: Binding system separates structural bindings (`onAfterCreate`/`onAfterDelete`) from positional updates (`onAfterChange`)

**Process structure first, then geometry** — parent transforms must be correct before coordinate rebasing.

**When needed:** Only with nested containers (groups, frames). Flat annotation editors (simple GeoJSON) don't need this.

## Pattern 5: Per-record reactive atoms (high-frequency updates)

**When to use**: >50 annotations with high-frequency individual updates (dragging, real-time collab) where single-store re-notification is a measurable bottleneck.

**When NOT to use**: Small collections (<50 items) or low-frequency updates where the overhead of per-record signals exceeds the re-render savings.

**How it works**: Instead of a single reactive collection that notifies all subscribers on any change, each annotation gets its own reactive signal. Updating one annotation only notifies components subscribed to that specific record. The collection itself is a non-reactive Map; individual entries are wrapped in framework-specific atoms.

**Production example**: tldraw's `AtomMap` gives each shape its own `@tldraw/state` signal. Dragging one shape at 60fps only re-renders that shape's subscribers, not the entire canvas component tree.

**Tradeoffs**:
- More memory overhead (one signal per record) — negligible past ~50 records where the benefit kicks in
- Collection-level queries (filter, sort) still need a top-level subscription or derived signal
- **Framework mappings**: `@tldraw/state` AtomMap | Svelte 5 `$state.raw()` collection + per-record signals | Jotai `atomFamily` | MobX `observable.map()`

## Pattern 6: Mutation reducer for live editing + temporal replay

**When to use**: Apps needing both real-time collaborative editing and temporal history replay (version browsing, audit trails) with guaranteed behavior parity between live and replayed state.

**When NOT to use**: Simple CRUD apps without history features, or apps where server-side state reconstruction is sufficient (no client-side replay).

**How it works**: A pure function `(state, mutation) → state` handles all graph/annotation mutations. The same reducer powers both live editing and historical state reconstruction, guaranteeing behavior parity between "what you see now" and "what you'd see if you replayed history."

```typescript
type Mutation =
  | { type: 'blockMove'; payload: { id: string; position: Position } }
  | { type: 'blockResize'; payload: { id: string; dimensions: Dimensions; position?: Position } }
  | { type: 'blockDelete'; payload: { id: string } }
  | { type: 'edgeCreate'; payload: Edge }
  | { type: 'edgeDelete'; payload: { id: string } }
  | { type: 'graphSnapshot'; payload: { blocks: Block[]; links: Edge[] } };

function applyMutation(state: GraphState, mutation: Mutation): GraphState {
  switch (mutation.type) {
    case 'blockMove':
      return {
        ...state,
        blocks: state.blocks.map(b =>
          b.id === mutation.payload.id
            ? { ...b, position: mutation.payload.position }
            : b
        ),
      };
    case 'blockDelete':
      return {
        ...state,
        blocks: state.blocks.filter(b => b.id !== mutation.payload.id),
        links: state.links.filter(l =>
          l.source !== mutation.payload.id && l.target !== mutation.payload.id
        ),
      };
    case 'graphSnapshot':
      return { blocks: mutation.payload.blocks, links: mutation.payload.links };
    // ... other cases
  }
}
```

**Why a shared reducer matters:**
- **Live editing**: CRDT observers call `applyMutation()` to update React/Svelte state from incoming Yjs changes
- **Temporal replay**: Loading a historical snapshot replays a sequence of mutations through the same function, guaranteeing the reconstructed state matches what users originally saw
- **Testing**: Pure function — unit-test every mutation type without mounting UI or CRDT infrastructure

**Cascading deletes**: Block deletion must also remove edges referencing that block. The reducer handles this atomically — no separate "cleanup orphaned edges" pass needed.

**Spatial constraints**: Some blocks may have fixed positions (anchor blocks, core nodes). The reducer enforces these constraints inline — if the block is immovable, the position field is ignored regardless of what the mutation payload says.

**Production example**: Ideon's `applyGraphMutation()` is used for both real-time Yjs observer updates and temporal history reconstruction via the same code path. Excalidraw's `storeIncrement` captures deltas with built-in inverses. Figma's operation log replays through a similar reducer for version history.

**Tradeoffs**:
- Pure function is easily unit-testable without UI or CRDT infrastructure
- Cascading deletes (block deletion removes referencing edges) handled atomically in one reducer case
- Spatial constraints (immovable blocks) enforced inline — reducer ignores invalid position payloads
- Adding new mutation types requires touching the reducer — central choke point is both a strength (auditability) and weakness (merge conflicts in large teams)

## Decision guide

| Constraint | Pattern |
|-----------|---------|
| Server-backed, multiple components | Query cache (1) |
| Server-backed, large geo datasets | Query cache + hot/cold (1+2) |
| Client-only, IndexedDB persistence | Event-driven store (3) |
| CRDT/real-time sync | Store with sync adapter |
| Live editing + temporal replay needed | Mutation reducer (6) |

## Silent mutation failures

Spatial libraries commonly return original state silently on validation failure (missing ID, absent parent). UI never re-renders, no error thrown — looks identical to a rendering bug.

**Pervasive in**: Mapbox GL Draw (ignores invalid feature IDs), Terra Draw (`changeIds()` silent on missing features), OpenLayers Modify (silently skips filtered features).

**Why**: Spatial libraries prioritize "don't crash during map interaction." But this leaks into app-level mutation functions where crashes aren't a concern.

**Fix**: App-level mutations should use `Result<T, E>` or throw. Reserve silent returns only for gesture-level code.

## Content sanitization at render boundaries

Annotation content (W3C `TextualBody` with HTML, IIIF bodies, GeoJSON `properties`) carries user-supplied HTML. Import-time sanitization is insufficient — post-import mutations (edits, merges, bulk updates) bypass it.

**Fix**: Sanitize at render time, unconditionally. The renderer treats all annotation body content as untrusted. Single sanitization point that can't be bypassed; negligible performance cost for typical annotation sizes.

## Anti-Patterns

### Manual array spreading for state sync

**What happens**: `annotations = [...annotations, created]` — no cache invalidation across components, no optimistic updates, no error rollback. Every component manages its own copy, leading to stale data in some views.

**Why it's tempting**: Zero setup, works in a single component prototype. Feels like "just JavaScript."

**What to do instead**: Use Pattern 1 (query cache) for server-backed apps or Pattern 3 (event-driven store) for client-only apps.

### Imperative tile cache-busting in declarative wrappers

**What happens**: Calling `setTiles()` or mutating tile URLs directly conflicts with declarative map wrappers (svelte-maplibre-gl, react-map-gl). The wrapper re-renders from its own state, overwriting or fighting the imperative mutation.

**Why it's tempting**: Cache-busting a URL is the obvious way to force a tile refresh. Works in vanilla Mapbox GL.

**What to do instead**: Use Pattern 2's hot/cold overlay — a separate GeoJSON source for recent edits composited on top of tiles.

### Pushing 60fps preview updates through reactive stores

**What happens**: Dragging a shape at 60fps through `$state` or Zustand triggers deep proxy traversal and cascading re-renders across the entire component tree. Interaction stutters visibly.

**Why it's tempting**: The reactive store is already wired up, and it's natural to update the same state that rendering reads.

**What to do instead**: Use the ephemeral modifier/preview layer pattern — keep preview transforms outside the reactive system (`$state.raw()` or plain objects), commit to the store only on mouse-up.

### Silent mutation failures

**What happens**: Spatial libraries return original state silently on validation failure (missing ID, absent parent). UI never re-renders, no error thrown — looks identical to a rendering bug.

**Why it's tempting**: Spatial libraries are designed this way to avoid crashes during map interaction. App-level code inherits the pattern by convention.

**What to do instead**: App-level mutations should use `Result<T, E>` or throw. Reserve silent returns only for gesture-level code where crashing mid-interaction would be worse.

### Import-only content sanitization

**What happens**: Annotation HTML content is sanitized at import time but not at render time. Post-import mutations (edits, merges, bulk updates) bypass the sanitization, allowing XSS through unsanitized body content.

**Why it's tempting**: Sanitizing once at import feels sufficient and avoids per-render overhead.

**What to do instead**: Sanitize at render time unconditionally. The renderer treats all annotation body content as untrusted. Negligible performance cost for typical annotation sizes.
