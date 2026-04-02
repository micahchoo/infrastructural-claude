# Canvas Culling Patterns

## The Problem

Canvas applications (design tools, map viewers, paint programs) contain potentially unbounded spatial content — thousands of shapes, millions of pixels, or deep-zoom tile pyramids. Rendering everything every frame is impossible, so the renderer must cull: determine what is visible in the current viewport and skip the rest. But culling creates a fundamental conflict with interaction. Culled shapes still need to be selectable, searchable, and navigable. A user who selects a shape, pans away, and pans back expects it to still be selected and visible. Hit-testing must work against the full spatial model, not just what's drawn.

The spaghetti emerges when the culling system, the selection system, and the hit-testing system each maintain their own spatial models. Changes to one (viewport pan invalidates culling) must propagate to the others (but selected shapes are exempt from culling, and hit-testing uses a different spatial index than rendering).

## Competing Patterns

### Culling with Exemptions (tldraw pattern)

**When to use**: Vector canvas editors where users frequently select shapes, pan away, then interact with selection (move, delete, copy). Shape count is moderate (hundreds to low thousands).

**When NOT to use**: Raster painting (no discrete shapes to exempt) or extremely high shape counts where the exemption list itself becomes expensive.

**How it works**: Cull all shapes outside the viewport EXCEPT shapes that are selected or being edited. Selected shapes always render regardless of viewport position.

**tldraw implementation**:
- `notVisibleShapes` derivation (in `packages/editor/src/lib/editor/derivations/`) queries the spatial R-tree index against viewport bounds
- `Editor.getCulledShapes()` wraps `notVisibleShapes` but **exempts selected and editing shapes** from culling
- `ShapeCullingProvider` (React context) centralizes DOM mutations: a single reactor calls `setStyleProperty(container, 'display', 'none')` for culled shapes instead of each shape subscribing individually
- `Shape.tsx` component registers with `ShapeCullingProvider` on mount, providing its container refs
- Hit-testing in `getHitShapeOnCanvasPointerDown` works against the spatial index, not the rendered DOM — culled shapes are still clickable if the user clicks at their spatial location

**Spatial index**: R-tree is the single source of truth for shape bounds. Both culling and hit-testing query it. This prevents divergence between "what's visible" and "what's clickable."

**Camera-aware optimization**: `TLInstance.cameraState` tracks `'idle' | 'moving'`. Hover hit-testing is **skipped while camera is moving** to avoid expensive queries during pan/zoom. Only pointer-down hit-testing runs during motion.

**Tradeoff**: Simple and effective. Exemption list grows with selection size, but selections are typically small. The real complexity is in maintaining the R-tree — every shape mutation (move, resize, create, delete) must update the spatial index.

### Async Worker Hit-Testing (penpot pattern)

**When to use**: Complex vector editors transitioning between rendering backends (SVG to WASM/WebGL) where hit-testing cannot rely on DOM-based hit regions.

**When NOT to use**: Simple canvas apps where synchronous hit-testing is fast enough, or when the latency of worker round-trips would make interaction feel sluggish.

**How it works**: Hit-testing is delegated to a Web Worker that maintains its own spatial model. The main thread sends pointer coordinates; the worker returns which shapes are under the cursor.

**penpot implementation**:
- Dual renderer: `viewport-classic*` (SVG) and `viewport.wasm/viewport*` conditionally switched by `"render-wasm/v1"` feature flag
- Both renderers must support identical interaction semantics
- `setup-hover-shapes` sends queries to a web worker (`mw/ask!`) to determine shapes under cursor
- `vbox` (visible viewport rect in design coordinates) + `vport` (physical viewport size) + `zoom` define the coordinate mapping
- WASM render API: chunked shape processing (`SHAPES_CHUNK_SIZE = 100`, `ASYNC_THRESHOLD = 100`) with throttling (`THROTTLE_DELAY_MS = 10`)

**Tradeoff**: Decouples hit-testing from rendering backend, enabling renderer transitions. But introduces async latency for hover feedback — the worker round-trip means hover highlights lag behind cursor movement. Penpot mitigates by batching queries and caching recent results.

### Multi-Tier Projection with LOD (krita pattern)

**When to use**: Raster painting applications where the canvas is a single massive image (potentially gigapixels) that must render at interactive framerates during brushstrokes.

**When NOT to use**: Vector editors (shapes are individually cullable) or tile-based viewers (use tile pyramid instead).

**How it works**: Pre-render the image at viewport scale, with explicit degradation states during interaction. Full resolution renders only when idle.

**krita implementation**:
- `KisPrescaledProjection` — pre-renders image data at viewport scale via `fillInUpdateInformation(viewportRect, info)` and `updateScaledImage()` (`libs/ui/canvas/kis_prescaled_projection.h`)
- `KisProjectionBackend` — abstract interface separating projection strategy from canvas widget, enabling QPainter and OpenGL backends (`libs/ui/canvas/kis_projection_backend.h`)
- `KisCanvasUpdatesCompressor` — mutex-protected queue batching `KisUpdateInfo` objects, preventing redundant repaint when the image pipeline produces updates faster than display can consume (`libs/ui/canvas/kis_canvas_updates_compressor.h`)
- `KisCoordinatesConverter` — full transform chain: image pixels -> document coordinates -> viewport widget coordinates, including rotation and mirroring (`libs/ui/canvas/kis_coordinates_converter.h`)
- LOD system: `lodPreferredInImage` flag in `KisCanvas2`, with `KisLodAvailabilityWidget` exposing user control. LOD renders brushes at reduced resolution during strokes, then refines to full resolution when idle (`libs/ui/canvas/kis_canvas2.cpp:355`)

**Three degradation states**: (1) Full resolution — idle, all detail visible. (2) LOD active — during brush strokes, reduced resolution for responsiveness. (3) Prescaled only — during rapid pan/zoom, viewport-scale projection without per-pixel accuracy.

**Tradeoff**: Complex tier management (three degradation states, two rendering backends, update compression) but enables interactive painting on images that would otherwise be unusable. The explicit state machine prevents ambiguous "partially loaded" states.

### Recursive Quad-Coverage (OpenSeadragon pattern)

**When to use**: Deep-zoom tile viewers (medical imaging, maps, gigapixel photography) where the image is a tile pyramid with multiple resolution levels.

**When NOT to use**: Discrete-shape canvases (use R-tree culling) or single-resolution images (use simple viewport clipping).

**How it works**: Tiles are organized in a quad-tree pyramid. The viewer recursively determines which tiles at which resolution levels cover the current viewport, tracking both "drawn" (already rendered) and "loading" (in-flight) coverage separately.

**OpenSeadragon implementation**:
- Three renderer implementations (WebGLDrawer, CanvasDrawer, HTMLDrawer) with different capability sets — `canRotate()`, `canComposite()`, image smoothing differ per renderer
- Dual coverage tracking: "drawn" tiles (already painted to canvas) vs "loading" tiles (fetch in progress) — prevents showing gaps while waiting for higher-resolution tiles
- Tile loading pipeline with CORS/auth complexity: `loadTilesWithAjax` toggles between `<img>` element loading (browser-cached) vs `XMLHttpRequest` (header/auth support, different cache behavior)
- `crossOriginPolicy: false` default means canvas taint by default — cannot read pixels for compositing without explicit CORS
- Retry support: `tileRetryMax`, `tileRetryDelay`, `timeout: 30000` with dual abort paths for img vs XHR (`downloadTileStart`/`downloadTileAbort`)

**Key files**: `openseadragon/openseadragon.js` (lines 702-726, 1235-1238, 2362-2453, 8291-8386, 13611-13830)

**Tradeoff**: Handles arbitrary zoom depths with consistent performance, but the tile loading pipeline is complex (CORS, auth, caching, retry, abort) and the renderer fallback chain (WebGL -> Canvas2D -> HTML) adds combinatorial surface area.

## Decision Guide

| Constraint | Approach |
|-----------|----------|
| Vector shapes, selection must survive pan | Culling with exemptions (tldraw) |
| Renderer backend in transition | Async worker hit-testing (penpot) |
| Gigapixel raster, interactive painting | Multi-tier projection + LOD (krita) |
| Deep-zoom tile pyramid | Recursive quad-coverage (OpenSeadragon) |
| Mixed (shapes on tiled background) | Tile pyramid for background + R-tree culling for shapes |

## Anti-Patterns

### Separate spatial models for culling and hit-testing

**What happens**: The renderer maintains a "visible set" for drawing, while hit-testing walks a different data structure (or worse, the DOM). After a pan, the visible set updates but the hit-test model lags. Users click on a shape they can see but the hit-test says nothing is there, or click on empty space and hit a shape that scrolled away.

**Why it's tempting**: Culling and hit-testing have different performance profiles. Culling runs every frame; hit-testing runs on pointer events. Optimizing them separately seems logical.

**What to do instead**: Single spatial index (R-tree) queried by both systems. tldraw's approach — one R-tree, two query modes (viewport intersection for culling, point query for hit-testing).

### Culling selected shapes

**What happens**: A user selects a shape, pans away, then tries to delete/copy/move it. The shape was culled because it left the viewport, so the operation either fails silently or operates on stale cached state.

**Why it's tempting**: The culling system doesn't know about selection. It only knows viewport bounds.

**What to do instead**: Exemption list for selected and editing shapes. The selection system registers shapes that must survive culling. tldraw's `getCulledShapes()` exempts `selectedShapeIds` and `editingShapeId`.

### Synchronous hit-testing during camera motion

**What happens**: Every pointer-move event during pan/zoom triggers a full spatial query to update hover state. With thousands of shapes, this creates frame drops during navigation.

**Why it's tempting**: Hover feedback should be immediate. Skipping it feels like a compromise.

**What to do instead**: Track camera state (`idle` vs `moving`). Skip hover hit-testing during motion; only run pointer-down hit-testing. Resume hover queries when camera settles. tldraw's `cameraState` pattern.
