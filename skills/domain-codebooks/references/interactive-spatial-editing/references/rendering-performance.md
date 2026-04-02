# Rendering Performance & Spatial Indexing

## The Problem

Interactive annotation editors must render, hit-test, and cull potentially thousands of objects at 60fps. Without spatial indexing, every pointer event triggers an O(n) scan of all objects — a cost that compounds with viewport culling, hover detection, and area selection. Excalidraw visibly degrades past 8,000 objects with linear scans. The problem worsens in collaborative contexts where remote changes continuously invalidate render caches.

Beyond raw object count, reactive frameworks introduce a second performance cliff. Wrapping mutable data structures like R-trees in Svelte 5's `$state()` proxies causes up to 5,000x slowdowns because the proxy intercepts every internal tree operation. Developers must understand where reactivity helps (UI state) and where it destroys performance (spatial data structures, GPU state, physics engines). Getting this boundary wrong is invisible in small demos and catastrophic in production.

A third axis is batching: state mutations, render passes, and network sync each have different optimal batch sizes and timing. Failing to coalesce drag operations into single undo steps, or re-rendering on every intermediate `pointermove`, creates UX that feels sluggish despite fast individual operations.

## Competing Patterns

### Spatial Indexing

## Spatial indexing

Without spatial indexing, hit-testing and viewport culling are O(n) per frame; with it, O(log n). Excalidraw degrades at 8k+ objects with linear scans (#8136). tldraw added R-tree indexing in v4.4.0.

### RBush (dynamic data — interactive editing)

R*-tree with insert/remove/update. Only viable choice for editors where shapes change.

```typescript
const tree = new RBush();
tree.load(allAnnotations.map(toBBox)); // bulk load: 2-3x faster, 20-30% better queries
tree.insert({ minX, minY, maxX, maxY, id: anno.id });
tree.remove(item, (a, b) => a.id === b.id);
const visible = tree.search(viewportBBox);
```

**Rebuild vs incremental**: If bulk change touches >~30% of shapes, `clear()` + `load()` beats incremental. tldraw hides this decision internally.

### Flatbush (static data)

Packed Hilbert R-tree in single ArrayBuffer. Transferable via SharedArrayBuffer. Has k-nearest-neighbor. Immutable after `finish()`. Use for reference layers, cross-worker scenarios.

### KDBush (points only)

2x less memory than Flatbush. Best for scatter plots, marker clusters. No rectangle support.

### Wiring R-tree into Svelte 5 runes

**Critical**: `$state()` deep Proxies cause **up to 5,000x slowdowns** on RBush. Keep the tree outside the proxy system:

```javascript
export class SpatialIndex {
  #tree = new RBush();
  #version = $state(0);
  insert(item) { this.#tree.insert(item); this.#version++; }
  remove(item) { this.#tree.remove(item); this.#version++; }
  search(bbox) {
    const _ = this.#version;  // reactive dep without proxying tree
    return this.#tree.search(bbox);
  }
}
```

Use `$state.raw` for query results. **This generalizes**: any mutable side-effect data structure (spatial index, physics engine, WebGL state) should live outside reactivity, with a version counter bridging the two worlds.

### Viewport culling

tldraw: `notVisibleShapes` queries R-tree with viewport bounds, sets `display: none` on off-screen shapes. Skips hover hit-testing while camera is moving (`TLInstance.cameraState`). AntV demo: 60fps at 5k shapes with culling vs 35fps at 1k without.

## Two-phase hit testing

1. **Broad phase**: Spatial index query (tldraw) or linear reverse-z scan (Excalidraw) returns candidates
2. **Narrow phase**: Precise geometry test per candidate

### tldraw's narrow phase

`ShapeUtil.getGeometry()` returns `Geometry2d` with `hitTestPoint(point, margin, hitInside)` and `hitTestLineSegment(A, B, distance)`. Hierarchy: `Rectangle2d`, `Polygon2d`, `Polyline2d`, `Circle2d`, `Ellipse2d`, `CubicBezier2d`, `CubicSpline2d`, `Group2d`. Boolean `isFilled` determines boundary-only vs area hits. Ruiz: "five hundred of the most confusing lines of code in tldraw."

### Excalidraw's pipeline

`getElementAtPosition` -> `hitElement` -> `getElementShape`. Reverse z-order, O(n). No spatial index — fast enough for typical scale (tens to hundreds).

### Ray casting edge cases (real bugs)

- **Vertex intersections**: Count only if other vertex lies below ray
- **Horizontal edges**: "Slightly above" convention
- **Float precision**: Epsilon offset `P.y += 0.0001`
- Self-intersecting polygons defeat even-odd. Ruiz: "Got to take your losses somewhere."

### Distance-to-path for stroked shapes

- Canvas 2D: `ctx.isPointInStroke(path, x, y)` with temporary wider `lineWidth`
- Bezier.js: Two-pass LUT (100 samples -> subdivide)
- Line segments: point-to-segment with endpoint clamping

### GPU color picking (Konva.js / deck.gl)

Unique RGB per object, off-screen render, read pixel -> O(1). Handles arbitrary shapes. Costs memory + one GPU round-trip. Konva's `hitStrokeWidth` independently controls hit vs visible stroke.

## Hot/cold rendering split

**Mapbox GL Draw**: `hot` source (selected/active, frequent updates) vs `cold` source (inactive, rare updates). Features migrate on interaction.

**Felt Lightning**: Pre-generated base tiles (Tippecanoe) + edit database. Dynamic tiling merges edits in real-time; background process re-incorporates into base tiles.

## Batching

**State**: tldraw `editor.run()` / `transact()` with rollback. Svelte 5 batches within synchronous blocks.

**Render**: Excalidraw throttles `pointermove` to rAF (#4727), caps scene render to rAF (#5422). tldraw uses 2D canvas for shape indicators instead of SVG DOM — **25x faster**. Skips hover hit-testing during panning.

**Network**: Excalidraw 30ms debounce. Yjs `Y.mergeUpdates()`. Liveblocks 100ms throttle + `room.batch()`. tldraw `FpsScheduler` throttles to 1 FPS with no collaborators.

**Undo coalescing**: Mark at drag start -> entire drag = one undo step. Excalidraw's `CaptureUpdateAction`: `IMMEDIATELY`, `EVENTUALLY`, `NEVER`.

## Computed caches with automatic cleanup

Annotations produce many derived values (bounds, labels, bindings). Manual cleanup on deletion causes memory leaks and stale-state bugs.

```typescript
// tldraw: derive per-record, auto-cleanup on deletion
const boundsCache = store.createComputedCache<Box2d, TLShape>('bounds', (shape) => {
  return shapeUtil.getGeometry(shape).bounds;
});
const shapeBounds = boundsCache.get(shapeId); // undefined when deleted
```

**Implementation approaches**:
- **Store-integrated** (tldraw): `createComputedCache()` — deletion triggers eviction via change propagation
- **WeakRef-based**: Periodic sweep of GC'd referents. Simpler, less deterministic.
- **Subscription-based**: Listen to deletions, manually evict. Works with any store.

When built on reactive signals, the cache auto-recomputes on change AND auto-cleans on deletion — same mechanism. tldraw's entire derivation layer (bindings, parent-child trees, visibility) works this way.

## Freehand drawing

`perfect-freehand` (tldraw, Canva, draw.io, Excalidraw) avoids Douglas-Peucker during draw (curves jump visibly). Uses `streamline` (0-1) lerping previous/current points. Apply simplification after drawing completes.

## Zoom-aware rendering cache

```typescript
function zoomBucket(zoom: number, baseZoom: number): number {
  return Math.round(Math.log2(zoom / baseZoom));
}
// Cache key: (shapeId, contentHash, zoomBucket)
```

**Invalidation**: Pan = reuse. Zoom within bucket = reuse. Zoom to new bucket = re-render. Shape mutation = invalidate always.

Evidence: drafft-ink caches roughr paths by zoom bucket. tldraw caches shape rendering, invalidates on zoom. Mapbox/MapLibre use discrete zoom levels for tile caching (same principle).

## Worker-offloaded spatial queries

At >500-1000 shapes, spatial queries during area selection block main thread 5-20ms/frame.

**Architecture**: Main thread posts selection rect + filters to worker -> worker queries index -> returns matching IDs -> main thread updates selection.

**Incremental updates**: Diff old/new object maps, patch index. Penpot's worker diffs and patches quadtree incrementally.

**Domain-aware worker filtering**:
- Skip hidden/invisible and locked shapes
- Group vs children selection semantics
- Clip parent intersection checks
- Stroke-width-expanded bounds for unfilled shapes

**Scale thresholds**:
- <500: Main thread fine
- 500-5000: Worker for area selection; point queries on main thread
- \>5000: Worker essential for both. Consider SharedArrayBuffer + Flatbush for zero-copy.

## Decision guide

| Scale | Approach |
|-------|----------|
| < 100 | No spatial index |
| 100 - 10k | RBush (editing) + Flatbush (reference) |
| 10k - 100k | RBush + viewport culling + hot/cold split |
| 100k+ | Vector tiles (cold) + GeoJSON overlay (hot) |

## GPU context loss recovery

WebGL annotation renderers (Mapbox GL overlays, deck.gl, Penpot WASM) must handle `webglcontextlost`/`webglcontextrestored`. Occurs on tab backgrounding (especially mobile), GPU memory pressure, driver crashes. All GPU resources invalidated. Recovery: listen for restored event -> re-create context -> re-upload resources -> re-render from document store. Annotation state must live outside GPU; only render pipeline rebuilds. Penpot uses `context-lost`/`context-restored` state machine.

---

## Z-index layer token system

**Three-tier stacking model** (tldraw pattern):

1. **Canvas** — container stacking context: base media, grid, annotations, active/selected, overlays
2. **Overlay** — sub-context for interaction chrome: marquee, handles, snap lines, cursors
3. **App UI** — separate stacking context: panels, menus, tooltips, modals

```css
:root {
  /* Tier 1: Canvas */
  --z-canvas-background: 100;  --z-canvas-grid: 150;
  --z-canvas-annotations: 200; --z-canvas-active: 250;
  --z-canvas-overlays: 300;
  /* Tier 2: Overlay */
  --z-overlay-guides: 10;      --z-overlay-selection-bg: 20;
  --z-overlay-selection-fg: 50; --z-overlay-handles: 60;
  --z-overlay-indicator: 70;    --z-overlay-custom: 80;
  --z-overlay-cursor: 100;
  /* Tier 3: App UI */
  --z-ui-panels: 300;    --z-ui-dropdowns: 400;
  --z-ui-tooltips: 500;  --z-ui-command-palette: 600;
  --z-ui-toasts: 700;    --z-ui-modal-backdrop: 900;
  --z-ui-modal: 950;
}
```

**Rules**:
- Each tier's container creates its own stacking context (`isolation: isolate`)
- 100-unit gaps between canvas tokens for future insertion
- Selected annotations promoted from `--z-canvas-annotations` to `--z-canvas-active` (Felt/Figma pattern)
- `--z-overlay-custom` extension slot for plugins
- No raw z-index integers — always reference tokens
- Modals portal-render to app root for Tier 3 stacking

Evidence: tldraw 30+ named CSS properties across three tiers. Excalidraw ~15 `:root` tokens. WebGL editors (Figma, MapLibre) use GPU draw order for canvas but CSS tokens for HTML overlay UI.

---

## Async resource lifecycle

**The race condition**: Renderer starts before annotation dependencies (images, fonts, videos) load. Renders incorrect geometry or caches wrong measurements.

**Worse race**: Event-driven resource discovery creates timing gap between state load and scan. WeaveJS hit this; fixed by switching to explicit call-site initialization.

**Critical ordering** (from WeaveJS):
1. Load annotation state
2. **Scan state for async dependencies — register all as NOT_LOADED**
3. **Then** set up renderer
4. Load resources in parallel; renderer shows placeholders
5. Mark LOADED on resolution, re-render affected annotations
6. All loaded -> enable export, hide loading indicators

Step 2 before step 3 is non-negotiable. If renderer starts first, it caches wrong measurements requiring forced re-layout.

**Checkpoint rule**: Before rendering any annotation layer, traverse state tree for async dependencies and gate render on resolution. Never let the renderer discover missing resources reactively.

Evidence: tldraw's AssetStore resolves blob URLs before rendering. Excalidraw's `loadImages()` loads from Firebase/IndexedDB/share-links by `fileId`. WeaveJS's `WeaveAsyncManager` tracks NOT_LOADED->LOADING->LOADED with `watchMap`. Annotorious tracks async IIIF tile loading.

## Anti-Patterns

- **Wrapping spatial data structures in reactive proxies.** Svelte 5 `$state()` or Vue `reactive()` on RBush/Flatbush causes 1,000-5,000x slowdowns. Keep mutable performance-critical structures outside the proxy system; bridge with a version counter.
- **Linear scan hit-testing past 100 objects.** Works for demos, fails in production. Profile with real data counts early.
- **Caching display coordinates as annotation positions.** Display coords change on zoom/pan; storage coords don't. Leads to "annotations drift" bugs.
- **Re-rendering on every `pointermove`.** Throttle to rAF. Excalidraw learned this (#4727, #5422).
- **Event-driven resource discovery.** Letting the renderer discover missing images/fonts reactively creates timing gaps and wrong cached measurements. Scan state for async dependencies before initializing the renderer.
- **Raw z-index integers.** Magic numbers across components lead to stacking bugs. Use CSS custom property tokens organized by tier (canvas/overlay/UI).
- **Incremental R-tree updates when >30% of shapes change.** `clear()` + `load()` is faster than thousands of individual insert/remove calls during bulk operations.
