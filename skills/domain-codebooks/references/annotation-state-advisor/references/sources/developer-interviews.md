# Developer Interviews & Deep Dives

Extended case studies, interview quotes, and source code pointers. The reference files
in the parent directory contain the actionable patterns — read this for deeper context
when you need to understand *why* a pattern was chosen or trace it to source code.

---

## §1. Spatial Indexing: Source Code & Interviews

### tldraw's SpatialIndexManager internals

tldraw v4.4.0 (January 2026): PR #7676 added R-tree, PR #7699 immediately made it
internal API. `editor.spatialIndex` was explicitly removed from public API — consumers
use `editor.getShapesAtPoint()` and `editor.getShapeAtPoint()` instead.

The `SpatialIndexManager` sits alongside `SnapManager` under the `Editor` class (also
manages `HistoryManager` and `InputsManager`). Performance companion changes: optimized
Set comparisons, reduced memory allocations, cached string hashes, `FpsScheduler` that
throttles network to 1 FPS when no collaborators present.

### Steve Ruiz interviews

Across Latent Space podcast, Code with Jason #273, devtools.fm, Scaling DevTools, and
ShopTalk Show #690, consistent themes:

- tldraw uses DOM and React for rendering (not canvas) — enables composability (any React
  component on the canvas). Significant SDK advantage over canvas-based competitors.
- The Editor class is a hierarchical state machine for tools. Managing complexity through
  abstractions and state machines was the recurring theme across multiple full rewrites.
- JSNation 2026: "Agents on the Canvas With tldraw" — spatial agents, agent-on-canvas.

### Excalidraw's viewport culling gap

GitHub issue #8136: community reports degradation at 8,000+ objects, advocating for
quadtrees or R-trees. Excalidraw still uses `isElementInViewport()` O(n) scan. AntV
Infinite Canvas Tutorial: 60fps with 5,000 shapes vs 35fps at 1,000 without culling.

### RBush custom indexing

`toBBox`, `compareMinX`, `compareMinY` methods let you index non-standard formats.
Default node size is 9. JSON serialization supported for server-to-client index transfer.

---

## §2. Mode Architectures: Extended API Details

### Terra Draw extended details

v1.25.1, OSGeo Community Project. Three mode categories documented in guides
(GETTING_STARTED, MODES, STYLING). Store exposed via `draw.getSnapshot()`.
`draw.on('change', callback)` for any mutation.

James Milner at FOSS4G 2023, FOSS4G Europe 2024, FOSDEM 2025. Referenced in Google
Maps JavaScript API documentation.

### Mapbox GL Draw extended bug documentation

- **Issue #582**: `changeMode()` during `draw_polygon` → infinite `modeChanged` event
  loop → Chrome freeze. Root cause: in-progress polygon not cleaned up before mode switch.
- **Issue #1103**: Keyboard shortcuts break across mapbox-gl-js v2.7.1 / maplibre-gl v2.1.7.
- **Issue #1028**: Framework's event handler consumes Delete/Backspace when `control.trash`
  is false, preventing custom modes from receiving them via `onKeyUp`.

### tldraw's StateNode hierarchy

Tools extend `StateNode` with static `id`, `initial` child state, `children()` returning
child state classes. Events bubble up through hierarchy. State transitions:
`this.parent.transition('pointing', { shape })`. Mirrors UML statecharts / XState.

David Khourshid has presented on how statecharts prevent impossible state combinations.

---

## §3. TypeScript Boundaries: Specific Conflicts

### MapLibre #4855 (the most common failure)

`@types/css-font-loading-module` declares `FontFaceSet.onloadingdone` with
`FontFaceSetLoadEvent`. TypeScript's built-in `lib.dom.d.ts` declares it with `Event`.
Produces `TS2717`. MapLibre's transitive dependency introduces ambient declarations
clashing with TypeScript's DOM lib (which absorbed those types with different signatures).
Earlier versions had syntax errors in `.d.ts` under `strict` mode (issue #790).

### Terra Draw #350 (type isolation)

Before monorepo split, bundling all adapter type declarations forced users to install
`@types/google.maps`, `@arcgis/core`, and OpenLayers types even for MapLibre-only use.
Fix: separate packages (`terra-draw-maplibre-gl-adapter`).

### Annotorious coordinate translation

`W3CImageAdapter` parses/serializes between Annotorious native pixel coords and W3C
string selectors. For IIIF geographic contexts: W3C `#xywh` Fragment Selectors for
pixel regions + annotation bodies with GeoJSON-LD for geographic coords. Nested
GeoJSON coordinate arrays incompatible with JSON-LD 1.0 processing.

### GeoJSON Geometry union (discussion #6323)

`event.features[0].geometry.coordinates` fails because `GeometryCollection` has no
`coordinates`. Type narrowing on `geometry.type` required.

---

## §4. SQLite/WASM: Notion's Full Story

### The corruption incident

During testing of `sqlite3_vfs` with SharedArrayBuffer, Notion observed severe data
corruption: wrong data on pages, comments attributed to wrong coworkers, multiple rows
with same ID containing different content. Root cause: OPFS concurrency handling
insufficient for simultaneous multi-tab writes.

### Why they chose AccessHandlePoolVFS

Needed no COOP/COEP headers. They depend on many third-party scripts that would break
under COEP restrictions. Performance: WASM SQLite loaded asynchronously to avoid
blocking initial page load. "Race" between disk cache read and network request handles
slow devices (some Android phones read OPFS slower than fetching from API).

### wa-sqlite discussions (#81, #84, #138)

Roy Hashimoto on multi-tab coordination: `MessageChannel`-based approach achieves
single-hop communication vs Notion's two-hop SharedWorker pattern. Direct channels
between tabs via `BroadcastChannel` signaling — more efficient but more complex.

**Critical caveat**: When a write transaction is submitted and an exception occurs during
service migration, you can't know if the transaction committed. Simply resubmitting may
produce incorrect results. Applications need idempotent write patterns.

### OPFS Async-Sync Bridge: JSPI

JavaScript Promise Integration (JSPI), available in Chrome 137+ (May 2025) without
flags. Suspends WASM natively on promises — no compile-time transforms. But no Safari
support. The SQLite team refuses to use Emscripten Asyncify (~2x file size, 2-5x perf hit).

---

## §5. Hit Testing: Extended Analysis

### Steve Ruiz, React Advanced 2025

"What's Under the Pointer?" — "five hundred of the most confusing lines of code in tldraw."
The complexity isn't in the spatial query — it's in precise geometry tests, overlapping
shape resolution, and self-intersecting polygon edge cases.

Self-intersecting polygons: "Unless you do a lot of extra complicated things to build
essentially multiple polygons out of the self-intersecting polygon... Got to take your
losses somewhere."

### tldraw's Geometry2d hierarchy

`ShapeUtil.getGeometry()` returns abstract `Geometry2d` with:
- `hitTestPoint(point, margin, hitInside)`
- `hitTestLineSegment(A, B, distance)`
- `nearestPoint(point)` — closest point on geometry edge

Subclasses: `Rectangle2d`, `Polygon2d`, `Polyline2d`, `Circle2d`, `Ellipse2d`,
`CubicBezier2d`, `CubicSpline2d`, `Group2d`.

Shape indicators now render via 2D canvas (not SVG) — 25x faster rendering.

### Excalidraw refactoring

PR #8539 by Mark Tolmacs: refactored distance and hit testing into dedicated math package.
Reorganized collision detection, bounds calculation, intersection logic. Distinguishes
`hitElement` from `hitElementBoundingBoxOnly` (must account for bound text).

### Konva.js hit canvas

Hidden canvas where shapes drawn with unique colors. `hitStrokeWidth` property independently
controls width of strokes on hit canvas vs visible canvas — clean separation of visual
and interactive concerns.

### Bezier distance calculation

Bezier.js uses two-pass LUT: generate 100 sample points along curve, find closest, then
refine by subdivision. For line segments: point-to-segment distance with endpoint clamping.

---

## Sources Index

### Podcasts & Talks
- Latent Space — "The Accidental AI Canvas" (Jan 2024)
- Code with Jason #273 — managing complexity through abstractions
- devtools.fm (Feb 2022) — open source canvas graphics
- ShopTalk Show #690
- Scaling DevTools — creativity, taste, marketing (June 2025)
- React Advanced 2025 — "What's Under the Pointer?"
- JSNation 2026 — "Agents on the Canvas With tldraw"
- FOSS4G 2023, FOSS4G Europe 2024, FOSDEM 2025 — Terra Draw (James Milner)

### Engineering Blogs
- Notion — "How we sped up Notion in the browser with WASM SQLite" (July 2024)
- PowerSync — "The Current State of SQLite Persistence on the Web" (Nov 2025)
- MapLibre — "Developing Plugins for MapLibre Interoperability" (Jan 2023)

### Source Code Pointers
- `tldraw/tldraw` — `packages/editor/src/lib/editor/Editor.ts` (SpatialIndexManager)
- `excalidraw/excalidraw` — `App.tsx` (hitElement, getElementAtPosition, getElementShape)
- `JamesLMilner/terra-draw` — `TerraDrawBaseMode` extension, adapter interface
- `rhashimoto/wa-sqlite` — VFS implementations
- `mapbox/mapbox-gl-draw` — `docs/MODES.md` (custom mode interface)
