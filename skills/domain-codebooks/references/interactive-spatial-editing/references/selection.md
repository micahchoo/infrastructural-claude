# Selection State Management

## The Problem

Selection looks simple — store a set of IDs, highlight the matching shapes. But selection sits at the intersection of three independent concerns: presence (per-user, ephemeral), history (undo stack), and spatial queries (hit-testing). Each concern pulls the architecture in a different direction, and getting any one wrong produces bugs that are invisible during single-user desktop testing but surface immediately in production.

The first failure mode is stale selection. Undo deletes a shape, but the selection set still contains its ID. Now you have ghost handles floating over empty canvas, undefined lookups in the detail panel, and silent rendering breaks that look like framework bugs. The fix is a single line of code (filter selected IDs to existing shapes after undo), but it must be wired explicitly — and most implementations miss it until a user reports "phantom selection boxes."

The second failure mode emerges in multi-view apps. A map + timeline editor needs spatial selection (lasso on map) and entity selection (click in list) to coexist. A flat global `Set<string>` forces these views to fight: clicking a list item replaces the spatial selection entirely, destroying context. And the third failure mode is collaboration: if selection lives in the undo stack, User B's undo changes User A's selection. If selection lives in the renderer (Konva Transformer, Fabric.js), it can't participate in collaboration presence at all. These competing forces demand an explicit architecture choice, not a default.

## Competing Patterns

## Pattern 1: ID-set selection (store-owned)

**When to use**: Default choice for most editors. Required when you have multi-view UI (sidebar highlights selection), collaboration (presence reads from stores), undo integration, framework rendering, or persistence.

**When NOT to use**: Single-view canvas editors with canvas-native interactions (Konva, Fabric.js) where renderer-owned selection is simpler and sufficient.

**How it works**: Selection state lives in a reactive store as a Set or array of annotation IDs. All UI reads from the same source — map highlights, sidebar selections, detail panels, and collaboration presence all derive from one `selectedIds` set. Hit-testing maps click/tap coordinates to IDs via spatial index queries, and the store exposes imperative (`select(ids)`) and declarative (derived from mode state) interfaces.

Store selection by ID, not by object reference:
- **tldraw**: `editor.selectedShapeIds` — array of IDs in `TLInstance` record
- **Excalidraw**: `appState.selectedElementIds` — `Record<string, boolean>`
- **Mapbox GL Draw**: `active` property on features; selected = hot source, unselected = cold
- **felt-like-it**: `selectionStore.selectedFeatureIds` — `Set<string>`

**Svelte 5**: Must assign new Set for reactivity (`$state` tracks assignments, not mutations):
```typescript
let _selectedIds = $state<Set<string>>(new Set());
function toggleId(id: string) {
  const next = new Set(_selectedIds);
  next.has(id) ? next.delete(id) : next.add(id);
  _selectedIds = next;
}
```

**Production example**: tldraw and Excalidraw both use store-owned ID sets. tldraw's store subscriptions auto-remove deleted shapes from selection. Excalidraw re-derives from element existence each render.

**Tradeoffs**:
- All views read from one source — no sync bugs between sidebar and canvas
- Undo integration is straightforward (include or exclude selection changes per policy)
- Requires explicit invalidation after undo/redo (filter `selectedIds` to IDs that still exist)
- Shallow equality checks needed to avoid unnecessary re-renders (`getSelectedElements()` checks equality before returning)

### Selection and undo

| Tool | Selection in undo? | Rationale |
|------|-------------------|-----------|
| Figma | Yes | Undo navigates between pages, restoring previous selection |
| Excalidraw | No | Selection is `server: false, export: false` — purely ephemeral |
| tldraw | Configurable | `editor.run(() => {...}, { history: 'ignore' })` |

**Collaborative apps**: Selection is presence (ephemeral, per-user) — keep out of undo stack. User B's undo must never change User A's selection.
**Single-user apps**: Including selection in undo feels more natural.

### Selection invalidation on undo/redo

Undo can delete currently-selected annotations. Without re-validation: ghost handles, undefined lookups, silent rendering breaks.

**Fix**: After every undo/redo, filter `selectedIds` to IDs that still exist. Single-line operation but must be wired explicitly — unless selection is derived state (tldraw's store subscriptions auto-remove deleted shapes). WeaveJS's `syncSelection()` re-validates on undo/redo. Excalidraw re-derives from element existence each render.

### Selection and rendering

Shallow equality avoids unnecessary re-renders. Excalidraw's `getSelectedElements()` checks shallow equality before returning.

```typescript
const selectedAnnotations = $derived.by(() => {
  void version;
  return Array.from(_selectedIds).map(id => store.get(id)).filter(Boolean);
});
```

### Multi-select patterns

- **Click**: select (deselect others). **Shift+click**: toggle. **Click empty**: deselect all.

### Programmatic selection

**Mapbox GL Draw gotcha**: No `select()` API. Must change modes: `draw.changeMode('simple_select', { featureIds: [...] })`.
**tldraw**: `editor.select(...shapes)`, `editor.selectNone()`.

Expose both imperative (`select(ids)`) and declarative (reactive derived from mode state) interfaces.

## Pattern 2: Renderer-owned selection

**When to use**: Single-view editors with canvas-native interactions (Konva Transformer, Fabric.js `getActiveObjects()`). No collaboration, undo, or multi-view needs.

**When NOT to use**: Any app with multi-view UI, collaboration presence, undo integration, or framework rendering. Renderer-owned selection can't participate in these systems without mirroring to a store (which makes it a hybrid).

**How it works**: Selection lives entirely in the rendering library — Konva's Transformer manages which nodes are selected and renders handles natively. No store representation exists. The renderer handles visual feedback (selection boxes, handles, transforms) as part of its built-in selection system.

**Hybrid variant**: Renderer handles visual feedback; mirror to store for external consumers. Cost is two sources of truth — acceptable for single-view, fragile for multi-view.

```typescript
// Konva hybrid: renderer owns visuals, store serves sidebar/collab/undo
transformer.on('transformend', () => {
  selectionStore.set(transformer.nodes().map(n => n.id()));
});
```

**Production example**: WeaveJS uses Konva Transformer with mutex locks for multi-user — selection in renderer, lock state in awareness. tldraw/Excalidraw use store-owned due to multi-view needs.

**Tradeoffs**:
- Zero setup for single-view canvas editors — handles, transforms, and visual feedback come free
- Cannot participate in collaboration presence, undo, or multi-view sync without mirroring
- Hybrid (mirror to store) creates two sources of truth — acceptable for single-view, fragile for multi-view
- Framework-agnostic — works with any canvas library that has built-in selection

## Pattern 3: Crossfilter / multi-view selection

**When to use**: Editor has multiple synchronized views (map + timeline, canvas + list panel) where different views have different selection semantics.

**When NOT to use**: Single-view editors where a flat `Set<string>` is sufficient.

**How it works**: When an editor has multiple synchronized views, a flat global `Set<string>` breaks down. User selects spatially on map, then clicks list item — list click replaces map selection entirely. Spatial context lost. Spatial semantics (intersects-viewport) and list semantics (exact-click) are fundamentally different.

**Two-layer crossfilter model:**

**Layer 1**: Each view emits typed selections in its own domain:
```typescript
type ViewSelection =
  | { type: 'entity'; ids: Set<string> }
  | { type: 'spatial'; bounds: BBox; ids: Set<string> }
  | { type: 'temporal'; range: [Date, Date]; ids: Set<string> }
  | { type: 'query'; query: string; ids: Set<string> };
```

**Layer 2**: Central resolver computes AND intersection of all active view selections.

**Key decisions:**
1. Each view owns its selection independently — clearing map doesn't affect list.
2. Resolver is derived state, never stored as primary.
3. View selections carry metadata (bbox, time range) needed for UI feedback.
4. Empty selection = "no filter from this view", not "nothing selected."

**Production example**: dc.js and Crossfilter pioneered this pattern for linked dashboards. Kepler.gl uses a similar approach for map + filter panel coordination.

**Tradeoffs**:
- Views are independent — clearing one doesn't destroy context in others
- Resolver is derived state, keeping the source of truth clear
- More complex than a flat set — overkill for single-view editors
- AND intersection is the common default but OR/custom logic may be needed for some domains

### Filtering and derived views

Keep filter state separate from annotation store — derive filtered views reactively. For indexed filtering, maintain secondary indexes (`Map<motivation, Set<id>>`) for O(1) lookup.

## Pattern 4: Spatial-query selection (lasso/marquee)

**When to use**: Any editor where users need to select by drawing a region — lasso, marquee, or freehand polygon. Works in conjunction with Pattern 1 (store-owned IDs) or Pattern 3 (crossfilter) for the selection result storage.

**When NOT to use**: Click-only selection where spatial querying adds unnecessary complexity.

**How it works**: Two-phase pipeline. Broad phase: spatial index query (R-tree, grid) finds candidates whose bounding boxes intersect the selection region. Narrow phase: precise geometry test (point-in-polygon, polygon intersection) filters to actual hits. Two modes: containment (fully within) vs intersection (any overlap).

**Lasso/marquee**: Broad phase (spatial index bbox query) then narrow phase (precise geometry test).

### Freehand lasso: even-odd ray casting

```typescript
function pointInPolygon(px: number, py: number, polygon: [number, number][]): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}
```

Edge cases: vertex intersections (count only if other vertex is below ray), horizontal edges ("slightly above" convention), floating-point precision (epsilon offset). See rendering-performance.md.

### Hit-testing for click selection

Two-phase pipeline: spatial index query at click point (+ margin: 2px click, 25px touch per Mapbox GL Draw) then precise geometry test, return topmost z-order hit.

- **tldraw**: `editor.getShapeAtPoint(point)` — R-tree broad phase + `ShapeUtil.getGeometry()` narrow phase
- **Excalidraw**: `getElementAtPosition(x, y)` — reverse z-order iteration, `hitElement` per element, `hitElementBoundingBoxOnly` for fast pre-check
- **Mapbox GL Draw**: `map.queryRenderedFeatures(point, { layers })` — MapLibre grid-based spatial index

**Production example**: Mapbox GL Draw uses `queryRenderedFeatures` with layer filters for broad phase and `touchBuffer: 25` vs `clickBuffer: 2` for touch-aware hit margins. tldraw uses R-tree spatial indexing for sub-millisecond hit tests on thousands of shapes.

**Tradeoffs**:
- Spatial index (R-tree, grid) is essential for performance past ~100 shapes
- Touch hit margins (25px) must be much larger than click margins (2px)
- Containment vs intersection mode is a UX decision that should be user-selectable
- Edge cases in ray casting (vertex intersections, horizontal edges, floating-point) require careful handling

## Supporting Concerns

## Handle system architecture

### Handle type taxonomy — discriminated union per mutation type

```typescript
type HandleType =
  | { kind: 'corner'; corner: 'topLeft' | 'topRight' | 'bottomLeft' | 'bottomRight' }
  | { kind: 'edge'; edge: 'top' | 'right' | 'bottom' | 'left' }
  | { kind: 'endpoint'; index: number }
  | { kind: 'intermediate'; index: number }
  | { kind: 'segment-midpoint'; index: number }
  | { kind: 'rotate' };
```

Handles by shape: rect/ellipse = corner+edge+rotate. Line/arrow = endpoint+intermediate+segment-midpoint. Freehand = endpoint only or none (path editing mode). Groups = corner+edge+rotate on group bbox.

### Zoom-aware handle sizing

Screen-space radius: `handleWorldRadius = BASE_HANDLE_RADIUS / camera.zoom`. Without this, handles vanish at high zoom and overlap at low zoom. tldraw, Excalidraw, Figma all do this.

### Hit-test priority

1. Handles of selected shape(s)
2. Shape boundary (edge/stroke)
3. Shape fill (interior)
4. Empty canvas (deselect)

Handles only hit-testable for selected shapes — prevents collisions between overlapping shapes.

### Rotation handle

Place above bbox with thin stem line. Fixed screen-space offset (20-30px). Stem increases hit target.

## Grouping and nesting

### Group selection model

Single click on member selects group. Double-click enters group (selects individual member). Universal pattern: tldraw, Excalidraw, Figma, Inkscape.

### Transform propagation

- **Move**: delta to each child position.
- **Resize**: scale child position relative to anchor + scale dimensions. Non-uniform scaling needs per-shape-type aspect ratio decisions.
- **Rotate**: rotate child position around group center, THEN add rotation delta to child's own rotation. Order matters.

### Derived bounding box

Group bbox derived from children — no intrinsic geometry. Cache and invalidate on child changes. Nested groups: invalidation bubbles up.

### Group undo semantics

Group/ungroup = single undo entry. Transform on group = single entry reverting all children. Edit within group (after enter) = normal per-shape entries.

### Nested groups

- **Depth limit**: Figma unlimited; tldraw 1 level. Deeper = more transform propagation complexity.
- **CRDT sync**: Store `parentId` per shape (tldraw pattern), not `children[]` on group — avoids array ordering conflicts in CRDTs.

## Clipboard operations

- **ID regeneration**: New UUIDs for pasted shapes. Build old-to-new ID map, rewire all internal references (group parent, arrow connections).
- **Position offset**: Paste at cursor or +10,+10 per successive paste. Never exact same position (invisible duplicates).
- **Cross-document**: Negotiate format (native JSON, SVG, PNG fallback). Excalidraw copies both native + SVG for cross-app paste.
- **Undo**: Paste batch = single undo entry.

## Locked and grouped elements

- **Excalidraw**: Locked elements can't be box-selected. Bound text auto-selects with container.
- **tldraw**: Groups select as unit; double-click enters group.

### Container/frame targeting

Canvas editors with frame nesting (tldraw, Excalidraw, Figma, WeaveJS) need drop-target resolution during drag: identify deepest intersecting container. Key decisions: `lockToContainer` flag, whether dragging out re-parents to root, deepest-first nested resolution. Primarily relevant to canvas/whiteboard editors — map/timeline editors use flat models.

## Z-index and ordering

**Explicit z-index** (tldraw): Fractional string indices via `@tldraw/indices` — always allows inserting between two values without renumbering.

**Insertion order + fractional indexing** (Excalidraw): Array position is authoritative cache; `FractionalIndex` strings (rocicorp) enable conflict-free reordering in collaboration. Z-operations use array manipulation for speed; reconciliation sorts by fractional index.

**Map annotations**: Z-index controlled by layer order, not per-annotation. `queryRenderedFeatures` returns top-to-bottom visual order.

## Element containment hierarchy (frames/artboards)

Frames (Excalidraw), artboards (Figma), containers (Penpot) define spatial scopes with four cascading behaviors:

1. **Selection mutual exclusion**: Frame and children never selected simultaneously. Selecting frame hides child handles; clicking inside selected frame enters it.
2. **Canvas clipping**: Children beyond frame boundary are clipped. `save()` then clip path then render children then `restore()`. Togglable via `clipContent` flag.
3. **Atomic duplication**: Duplicating frame duplicates all children with ID remapping table (`origId` to `newId`). Orphaned children reset `frameId` to null.
4. **Cross-frame group prohibition**: Groups cannot span frames. Excalidraw's `omitGroupsContainingFrameLikes()` enforces at selection time.

**Data model**: Single `frameId: string | null` per element. One parent max. Frame nesting via frame elements having a `frameId` pointing to another frame.

**Selection bounds clipping**: Clip to frame interior: `Math.max(frameX1, elementX1)`.

## Testing annotation state

```typescript
test('undo after add removes the annotation', () => {
  const store = new AnnotationGraphStore();
  store.add(makeAnnotation({ id: 'a1' }));
  store.undo();
  expect(store.size).toBe(0);
});

test('concurrent selection and deletion', () => {
  const store = new AnnotationGraphStore();
  store.add(makeAnnotation({ id: 'a1' }));
  selectionStore.select('a1');
  store.remove('a1');
  expect(selectionStore.selectedIds.has('a1')).toBe(true);  // ID persists
  expect(store.get('a1')).toBeUndefined();  // But annotation is gone
});
```

## Decision Guide

| Constraint | Pattern |
|-----------|---------|
| Multi-view UI, collaboration, undo | ID-set selection, store-owned (1) |
| Single-view canvas with native interactions | Renderer-owned selection (2) |
| Multiple synchronized views (map + timeline) | Crossfilter / multi-view selection (3) |
| Region-based selection (lasso, marquee) | Spatial-query selection (4) + store (1 or 3) |
| Single-view, Konva/Fabric, need sidebar | Hybrid renderer + store mirror (2 variant) |
| Collaborative app | Store-owned (1) + exclude selection from undo |
| Single-user app | Store-owned (1) + include selection in undo |

## Anti-Patterns

### Flat global Set for multi-view selection

**What happens**: A single `Set<string>` serves map, timeline, and list views. Clicking a list item replaces the spatial selection entirely — spatial context is lost. Views fight over the same selection state with fundamentally different semantics.

**Why it's tempting**: One set is simple. Works fine in demos with one view. "We'll add multi-view later."

**What to do instead**: Crossfilter pattern (Pattern 3) — each view owns its selection independently, central resolver computes intersection.

### Selection in the CRDT document for collaborative apps

**What happens**: User B's undo changes User A's selection. Selection changes flood the CRDT log with per-user ephemeral state that has no business being in the document.

**Why it's tempting**: The CRDT is already reactive and synced. Putting selection there means "everything just works."

**What to do instead**: Selection is presence — keep it in the awareness/presence channel, not the document. tldraw's `instance_presence` is excluded from persistence and undo despite living in the same reactive store.

### Missing selection invalidation after undo

**What happens**: Undo deletes a shape, but `selectedIds` still contains its ID. Ghost handles render over empty canvas. Detail panel does `store.get(id)` on a deleted shape and gets `undefined`, producing silent rendering breaks.

**Why it's tempting**: Undo "just works" for the document state. Selection feels like a separate concern that should be unaffected.

**What to do instead**: After every undo/redo, filter `selectedIds` to IDs that still exist. Or use derived selection (tldraw's store subscriptions auto-remove deleted shapes).

### Object-reference selection instead of ID-based

**What happens**: Storing selected objects by reference instead of by ID. After undo/redo or CRDT sync, the object reference points to a stale copy. Equality checks fail, selection appears empty even though the "same" shape exists under a new reference.

**Why it's tempting**: Object references give direct access without a lookup step. Feels more efficient.

**What to do instead**: Always store selection as a set of string IDs. Look up the current object from the store when needed.

### Fixed-size handles across zoom levels

**What happens**: Handles are rendered at a fixed world-space size. At high zoom they vanish (too small to see or click). At low zoom they overlap each other and obscure the shape.

**Why it's tempting**: Fixed-size handles are simpler — no zoom-dependent calculations needed.

**What to do instead**: Screen-space sizing: `handleWorldRadius = BASE_HANDLE_RADIUS / camera.zoom`. tldraw, Excalidraw, and Figma all do this.
