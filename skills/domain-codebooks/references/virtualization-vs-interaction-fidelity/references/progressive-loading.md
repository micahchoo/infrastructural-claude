# Progressive Loading

## The Problem

Users expect immediate visual feedback when browsing media — photo grids, deep-zoom images, encrypted galleries. But full-resolution content is expensive: large file sizes, decryption overhead, network latency, and decode time. Progressive loading bridges this gap by showing low-fidelity content first and upgrading in place. The tradeoff seems simple (show placeholder, then real content) but the implementation creates spaghetti when multiple resolution tiers interact with caching, interaction state, and error handling.

The specific failure modes: a user clicks a thumbnail to select it while the full-resolution version is loading — does the click target change size when the real image arrives? A decrypt pipeline fails on step 2 of 3 — does the user see the thumbnail forever, an error state, or a retry button? A tile at zoom level 12 is loading while the user zooms to level 14 — do you abort the level-12 fetch or let it complete for the cache? Each resolution tier has different interaction capabilities, and transitions between tiers must not break the interaction contract.

## Competing Patterns

### Decrypt-Then-Load Pipeline (ente pattern)

**When to use**: End-to-end encrypted media galleries where content must be decrypted client-side before display. Thumbnail and full-resolution versions have separate encryption.

**When NOT to use**: Unencrypted media where standard `<img>` loading with `srcset` suffices, or server-side rendering where decryption is not a client concern.

**How it works**: A multi-stage pipeline progresses through resolution tiers, each requiring a separate fetch and decrypt cycle:

1. **Placeholder** — solid color or blurred micro-thumbnail (cached, instant)
2. **Encrypted thumbnail** — fetch from server, decrypt client-side, create blob URL
3. **Full-resolution original** — fetch on demand (detail view), decrypt, create blob URL

**ente implementation**: Progressive decrypt -> thumbnail -> original pipeline with blob caching. Each stage is independently cacheable. The blob URL cache prevents re-decryption when scrolling back to previously viewed items.

**Interaction per tier**:
- Placeholder: clickable (selection works), but no visual detail
- Thumbnail: all grid interactions (select, multi-select, drag), visual preview sufficient for identification
- Original: full-detail view, zoom, edit, share

**Tradeoff**: Each tier requires separate network round-trip + decryption. Pipeline must handle partial failure (thumbnail decrypts but original fails), cancellation (user navigates away mid-decrypt), and cache eviction (blob URLs consume memory).

### Bucket-Based Placeholder Heights (Immich pattern)

**When to use**: Virtualized grids where content height varies by group and actual dimensions aren't known until data loads.

**When NOT to use**: Fixed-height grids where all items have the same dimensions, or when the dataset is small enough to measure all heights upfront.

**How it works**: Before bucket data loads, each bucket occupies an estimated height in the scroll model. When actual content loads, the estimated height is replaced with the measured height, and scroll compensation prevents the viewport from jumping.

**Immich implementation** (`asset-store.svelte.ts`):
- Buckets have estimated heights before data loads, replaced with actual heights after
- `scrollCompensation: { heightDelta, scrollTop }` applied when heights change
- IntersectionObserver triggers bucket loading as placeholders scroll into the pre-fetch zone

**Tradeoff**: Scroll position accuracy improves progressively. Early scrollbar thumb position is approximate. `scrollToIndex` before all heights are known lands approximately, not exactly.

### Tile Pyramid with Coverage Tracking (OpenSeadragon pattern)

**When to use**: Deep-zoom viewers (medical imaging, maps, gigapixel art) where the image is pre-tiled into a resolution pyramid (e.g., DZI, IIIF, Zoomify).

**When NOT to use**: Single-resolution images, or when tiles are not pre-generated server-side.

**How it works**: The image exists as a pyramid of tiles at multiple resolution levels. At any zoom, the viewer determines which tiles at which level cover the viewport. Lower-resolution tiles display immediately while higher-resolution tiles load, providing continuous visual feedback.

**OpenSeadragon implementation**:
- **Dual coverage tracking**: "drawn" tiles (already painted) vs "loading" tiles (fetch in progress). The viewer shows the best available tile for each viewport region while loading better ones.
- **Recursive quad-coverage**: Each tile at level N covers four tiles at level N+1. The viewer recursively checks coverage from coarsest to finest, stopping when coverage is complete or the target level is reached.
- **Renderer fallback**: WebGLDrawer (best perf, compositing support) -> CanvasDrawer (wider support) -> HTMLDrawer (simplest, no compositing). Each has different capabilities for rotation, compositing, and smoothing.
- **Loading pipeline complexity**: `loadTilesWithAjax` chooses between `<img>` element loading (browser cache) and XMLHttpRequest (custom headers, auth). CORS policy affects whether the canvas is tainted (pixel-readable or not). Retry with `tileRetryMax` and `tileRetryDelay`.

**Tradeoff**: Seamless zoom experience at any depth, but the loading pipeline must handle CORS, authentication, caching, retry, abort, and renderer capability differences. The quad-coverage recursion is elegant but debugging tile loading issues requires understanding the full pyramid traversal.

**Key files**: `openseadragon/openseadragon.js` (lines 702-726, 1235-1238, 2362-2453, 8291-8386, 13611-13830)

### LOD with Explicit Degradation States (krita pattern)

**When to use**: Raster painting applications where continuous interaction (brush strokes) must remain responsive while working on gigapixel images.

**When NOT to use**: View-only applications (no continuous interaction pressure), or vector editors (LOD is per-shape, not per-image).

**How it works**: The rendering pipeline has explicit degradation states. During interaction, quality drops to maintain responsiveness. When interaction stops, quality is restored.

**krita implementation**:
- **State 1 — Full resolution**: Idle. All pixels at native resolution. Full visual fidelity.
- **State 2 — LOD active**: During brush strokes. `lodPreferredInImage` flag in `KisCanvas2`. Brushes render at reduced resolution for responsiveness, full resolution refines after stroke ends. User-controllable via `KisLodAvailabilityWidget`.
- **State 3 — Prescaled only**: During rapid pan/zoom. `KisPrescaledProjection` shows viewport-scale pre-rendered image without per-pixel accuracy.
- `KisCanvasUpdatesCompressor` batches update events — when the image pipeline produces updates faster than the display can consume, redundant repaints are dropped.

**Transition management**: The state machine is explicit — you always know which degradation state you're in. This prevents the ambiguous "partially loaded" state where some regions are high-res and others are low-res without clear indication of which.

**Tradeoff**: Three states to manage with two rendering backends (QPainter, OpenGL). Each state transition must correctly hand off between projection strategies. But the explicitness prevents the most common progressive-loading bug: unclear what quality level the user is seeing.

### Viewport-Aware Buffer Ratios (Allmaps pattern)

**When to use**: WebGL-rendered map/image viewers where tile fetching must balance between showing content quickly and not over-fetching.

**When NOT to use**: Non-tiled content, or when bandwidth is not a constraint.

**How it works**: Two buffer ratios control tile lifecycle around the viewport:
- `REQUEST_VIEWPORT_BUFFER_RATIO` — fetch tiles within this expanded viewport (pre-fetch for smooth panning)
- `PRUNE_VIEWPORT_BUFFER_RATIO` — discard tiles outside this larger boundary (keep recently-visible tiles in cache)

The gap between request and prune ratios creates a hysteresis zone that prevents tile thrashing during small viewport movements.

**Tradeoff**: Tuning the ratios is empirical. Too aggressive pre-fetch wastes bandwidth; too conservative causes visible tile pop-in during pans.

## Decision Guide

| Constraint | Approach |
|-----------|----------|
| E2E encrypted media | Decrypt pipeline with blob cache (ente) |
| Pre-tiled image pyramid | Quad-coverage with dual tracking (OpenSeadragon) |
| Continuous raster interaction | LOD with explicit degradation states (krita) |
| Virtualized grid, unknown heights | Placeholder heights + scroll compensation (Immich) |
| Tiled WebGL with panning | Buffer ratio hysteresis (Allmaps) |

## Anti-Patterns

### Ambiguous resolution state

**What happens**: The user sees an image but cannot tell if it's the thumbnail, a mid-resolution proxy, or the full original. They zoom in expecting detail and see pixelation, or they share what they think is the original but it's a thumbnail.

**Why it's tempting**: Resolution tiers are implementation details. Exposing them in UI feels like admitting the system is slow.

**What to do instead**: Explicit degradation states with optional visual indicators. Krita's LOD widget shows the current quality mode. At minimum, track state internally so programmatic queries ("is this full resolution?") return accurate answers.

### Aborting superseded fetches too aggressively

**What happens**: User zooms from level 10 to level 14. The system aborts all level-10 tile fetches. But level-14 tiles take seconds to load, and now there's nothing to show — the fallback coverage (level-10 tiles that were almost done loading) was destroyed.

**Why it's tempting**: Aborting obsolete fetches saves bandwidth and seems logical. Why finish loading tiles we no longer need at the target zoom?

**What to do instead**: OpenSeadragon's dual coverage tracking — let in-flight fetches for lower levels complete if they'll provide fallback coverage. Only abort fetches that are truly superseded (the target level's tiles are already drawn).

### Loading all resolution tiers sequentially

**What happens**: The pipeline always loads placeholder -> thumbnail -> medium -> full, even when the user has explicitly requested the full-resolution version (opened detail view). They wait through unnecessary intermediate stages.

**Why it's tempting**: A single pipeline path is simpler than conditional skipping. "It only adds a few hundred milliseconds."

**What to do instead**: Context-aware tier selection. Grid view: placeholder -> thumbnail is sufficient. Detail view: placeholder -> full (skip thumbnail if full is expected soon). The pipeline should accept a target tier and skip intermediates when appropriate.

### Unbounded blob URL accumulation

**What happens**: Each decrypted/loaded image creates a blob URL. As the user scrolls through thousands of items, blob URLs accumulate, consuming memory. Eventually the tab crashes or the OS starts swapping.

**Why it's tempting**: Revoking blob URLs requires tracking which images are visible and which are cached. The virtualizer already handles DOM lifecycle — adding blob lifecycle feels redundant.

**What to do instead**: Tie blob URL lifecycle to the virtualization window. When a bucket/item is unloaded from the virtualizer, revoke its blob URL. Re-create on next load (re-decrypt if necessary, but the decrypted data may be in a separate cache with its own eviction policy).
