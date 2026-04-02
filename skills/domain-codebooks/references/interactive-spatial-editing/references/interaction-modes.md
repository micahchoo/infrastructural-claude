# Interaction mode state machines

## The Problem

A spatial editor has many mutually exclusive interaction modes — select, draw point, draw polygon, pan, measure, direct-select vertices. Without a state machine enforcing exclusivity, these modes are represented as boolean flags (`isDrawing`, `isSelecting`, `isPanning`) that can all be true simultaneously. The user clicks to place a polygon vertex and simultaneously selects an existing shape, or starts drawing while the pan tool is still active. The result is corrupted geometry, phantom shapes, and an undo stack full of half-completed operations.

The problem deepens with multi-step drawing tools. A polygon requires accumulating vertices across multiple clicks, detecting close conditions, rendering preview edges, and batching everything into a single undo entry on completion. Cancellation mid-draw must discard all accumulated state without leaving artifacts. If the drawing tool's internal state machine leaks into the document (vertices added to undo before the shape is complete), Escape produces a broken undo entry instead of a clean discard.

Touch and mobile interaction add a third dimension of complexity. Touch has no hover, larger hit targets, and multitouch gestures (pinch-zoom) that must coexist with single-finger drawing. Long-press conflicts with OS-level context menus. Timing-based disambiguation (tap vs drag) needs both distance and time thresholds that vary by input device. Every production drawing tool has learned these lessons independently — the patterns below consolidate them.

## Competing Patterns

## Universal mode interface

```typescript
interface AnnotationMode {
  onSetup(opts): ModeState;
  onClick(state, event): void;
  onMouseMove(state, event): void;
  onDrag(state, event): void;
  onKeyDown(state, event): void;
  onKeyUp(state, event): void;
  onStop(state): void;
  toDisplayFeatures(state, features): Feature[];
}
```

## Terra Draw: adapter + mode architecture

Decouples drawing from mapping libraries via thin adapters (MapLibre, Mapbox, Leaflet, Google Maps, OpenLayers). "Any mode can work with any adapter and vice versa" — James Milner, FOSS4G 2023.

Modes extend `TerraDrawBaseMode`. Each declares typed cancel/finish keys:
```typescript
cancel: KeyboardEvent["key"] | null  // defaults to Escape
finish: KeyboardEvent["key"] | null  // defaults to Enter
```

**Select mode feature flags** — granular per geometry type: `draggable`, `coordinates.midpoints`, `coordinates.draggable`, `coordinates.deletable`, `coordinates.snappable`, resize from `center` or `opposite`.

**Mid-draw cancellation**: `draw.setMode('select')` transitions out. Store exposed via `draw.getSnapshot()`. In-progress state cleaned up automatically on mode exit.

## Mapbox GL Draw: lifecycle methods with known pitfalls

Custom modes: object with `onSetup`, `onClick`, `onKeyUp`, `toDisplayFeatures`, `onStop`, `onTrash`. Access to `this.newFeature()`, `this.addFeature()`, `this.deleteFeature()`, `this.changeMode()`.

**Known bugs**:
- **#582**: `changeMode()` during `draw_polygon` causes infinite `modeChanged` event loops. In-progress polygon must be cleaned up first.
- **#1103**: Keyboard shortcuts break across mapbox-gl-js v2.7.1 / maplibre-gl v2.1.7.
- **#1028**: Framework consumes Delete/Backspace when `control.trash` is false, blocking custom modes.

| Concern | Mapbox GL Draw | Terra Draw |
|---|---|---|
| Cancel key | Manual `onKeyUp` handler | Typed `cancel` property per mode |
| In-progress cleanup | Manual in `onStop` | Automatic |
| Custom modes | Object with lifecycle methods | Class extending `TerraDrawBaseMode` |
| Adapter model | Coupled to Mapbox GL | Library-agnostic adapters |
| Feature data | Hot/cold source split | Single store, GeoJSON snapshots |

## tldraw: hierarchical state machine (statechart)

Tools extend `StateNode` with static `id`, `initial` child state, `children()`. Events bubble up from child to parent. Transitions: `this.parent.transition('pointing', { shape })`. Mirrors UML statecharts — prevents impossible state combinations.

## Discriminated union for mode state

**Anti-pattern**: boolean flags (`isDrawing`, `isSelecting`) — can both be true.

**Pattern**: discriminated union makes impossible states unrepresentable:
```typescript
type InteractionMode =
  | { kind: 'default' }
  | { kind: 'draw'; tool: 'point' | 'line' | 'polygon' }
  | { kind: 'select'; featureIds: Set<string> }
  | { kind: 'direct-select'; featureId: string; vertexIndex: number }
  | { kind: 'pan' }
  | { kind: 'measure' };
```

## Cancellation pattern

Three techniques combined:
1. **Transaction wrapping** — tldraw's `transact()` supports atomic batch + rollback. On Escape, roll back without touching undo stack.
2. **Entry/exit actions** — Terra Draw's `start()`/`stop()`/`cleanUp()`, Mapbox GL Draw's `onStop()`.
3. **Separate in-progress from committed geometry** — hot/cold source or temporary feature flags ensure uncommitted geometry never enters undo history.

## Atomic mode transitions

**Bug class**: split writes — mode changes to `drawRegion` but tool stays on `select`. Single `transitionTo()` atomically sets mode AND implied tool:

```typescript
function transitionTo(next: InteractionState) {
  interactionState = next;
  switch (next.type) {
    case 'drawRegion': selectionStore.setActiveTool('polygon'); break;
    case 'pickFeature': selectionStore.setActiveTool('select'); break;
    case 'idle': selectionStore.setActiveTool('select'); break;
  }
}
```

No direct assignment to `interactionState` outside `transitionTo()`. Mapbox GL Draw's `changeMode()` and tldraw's `transition()` serve the same purpose. **Mode transitions are atomic operations, not sequential flag assignments.**

## Async drawing tool initialization

Dynamic imports (`import('terra-draw')`) create race conditions when the trigger fires multiple times (map style reloads, reactive re-runs, HMR). Two async inits run concurrently, second crashes with "Source already exists."

**Generation counter pattern**:
```typescript
let generation = 0;
async function initDrawingTool(map: MapLibreMap) {
  const gen = ++generation;
  const { TerraDraw } = await import('terra-draw');
  if (gen !== generation) return null;  // stale — abort
  const draw = new TerraDraw({ ... });
  draw.start();
  return draw;
}
```

**When to extract to a store**: when lifecycle (init/ready/stopped) is referenced from multiple components, use a discriminated union state:
```typescript
type DrawingState =
  | { status: 'idle' }
  | { status: 'importing'; generation: number }
  | { status: 'ready'; instance: TerraDraw; generation: number }
  | { status: 'stopped' };
```

Keep event handlers in the component (they depend on props). Only lifecycle moves to the store.

## Mode / selection interaction

- Enter draw mode -> clear selection
- Enter select mode -> enable click-to-select
- Escape from draw -> cancel current drawing, return to default
- Escape from select -> deselect all

## Touch and mobile interaction

No production drawing tool uses long-press for annotation. Universal approach: mode-switching buttons + movement threshold for tap/drag disambiguation.

**Terra Draw**: Pointer Events only, ignores multitouch (`!event.isPrimary`). Three-state drag machine (`not-dragging` / `pre-dragging` / `dragging`), 1px default threshold, **8px while drawing** (fat-finger buffer). Map pan disabled via `setDraggability(false)` during drags.

**Mapbox GL Draw**: `touchBuffer: 25` vs `clickBuffer: 2` (12.5x larger hit radius). Tap: < 25px movement AND < 250ms. Disables `touchZoomRotate` during drawing.

**Excalidraw**: `gesture.ts` tracks all pointers in `Map<id, coords>`, computing `getCenter()` / `getDistance()` for pinch-to-zoom. Handles multitouch in application code.

**tldraw**: Detects coarse pointer via `(pointer: coarse)` media query. Adapts UI but uses same Pointer Events pipeline.

### Map-specific touch strategy

1. Ignore non-primary pointers — let map handle pinch-zoom natively
2. Larger hit buffers for touch — 25px vs 2px (Mapbox GL Draw values)
3. Disable map pan on drag start — re-enable on mode exit
4. Mode buttons, not gestures — no long-press

### Multi-pointer disambiguation

Maintain `Map<pointerId, coords>`, check count on each `pointerdown`:
- **1 pointer**: draw/select
- **2+ pointers**: navigation — cancel in-progress drawing, let map handle gesture

Tap vs drag on touch needs distance AND time thresholds. Production values: 8-25px movement, 200-400ms time. Tune per input device.

### Touch anti-patterns

- Long-press for anything — conflicts with OS gestures (context menu, text selection, accessibility)
- One-finger-draw vs one-finger-pan by timing — use mode buttons
- Assuming hover events exist — touch fires no `mousemove` before `mousedown`

## Accessibility

### Industry-wide gap

No production tool has ARIA on canvas shapes, `aria-live` announcements, or tab navigation between shapes.

### What IS implemented: keyboard shortcuts

- **tldraw**: Single-key tools (R=rectangle, A=arrow, V=select, H=hand). `,` key simulates pointer_down/up at cursor. `isRequiredA11yAction` flag keeps critical actions working when shortcuts suppressed.
- **Excalidraw**: Single-key tools + standard modifier combos.
- **Mapbox GL Draw / Terra Draw**: Minimal — Escape/Enter only.

### Patterns to implement (none ship yet)

**`aria-live` announcements**:
```svelte
<div aria-live="polite" class="sr-only">{announceText}</div>
```
Wire to store change events. Clear then set via `requestAnimationFrame` to force re-announcement.

**Keyboard tool switching**: single-key bindings (v=select, p=point, l=line, g=polygon, Escape=default). Guard with `if (e.target !== document.body) return` to avoid capturing from inputs.

**Focus management**: draw mode -> focus canvas; exit draw -> focus toolbar; open detail -> trap focus in panel.

## Freehand input processing

**Variable-width stroke**: store `points: Point[]` + `pressures: number[]` (0-1). Both arrays must stay paired through simplification, serialization, undo, and CRDT sync.

**Pressure simulation** (mouse/non-Apple-Pencil touch): `pressure = exp(-normalizedVelocity)`, clamped [0.2, 1.0], smoothed with exponential moving average. tldraw's `perfect-freehand` implements this.

**Path simplification**: Ramer-Douglas-Peucker after drawing completes, not during — simplification during draw causes visible jumps. Interpolate pressure at retained points.

---

## Drawing tool internal state machine

Within a drawing tool, a second FSM manages multi-step shape construction — accumulating vertices, setting Bezier handles, detecting close conditions, batching to a single undo entry.

```
IDLE ──click──> DRAWING ──click──> DRAWING (accumulate vertex)
                   │                    │
                   │                    ├──drag──> SET_HANDLE (Bezier control point)
                   │                    │              └──mouseup──> DRAWING
                   │                    ├──click near start──> CLOSING
                   │                    └──double-click/Enter──> FINISHING
                   └──Escape──> CANCELLED (discard)

CLOSING / FINISHING ──> COMMITTED ──> IDLE (single undo entry)
```

### Key concerns

**Point accumulation**: vertices are draft state in tool-local storage, not in the document. Only on COMMITTED does the shape enter the document.

**Close detection**: 8-12px in screen space (not document space — must account for zoom). Mapbox GL Draw, Terra Draw, OpenLayers all use screen-space proximity.

**Bezier handles**: click-drag places vertex AND sets control handles. Penpot and Figma implement this; Mapbox GL Draw and Terra Draw support straight segments only.

**Batch to single undo entry**: all vertex additions collapse to one undo entry. No intermediate entries per vertex. On CANCELLED, discard everything — no undo entry.

**Visual feedback during construction**: solid edges between placed vertices, dashed preview edge to cursor, close indicator near start vertex, handle indicators. Renders from tool-local state, not document (ephemeral modifier pattern — see mutation-sync.md).

### Production examples

- **Mapbox GL Draw**: `draw_polygon` — `onClick` adds vertex, `onStop` finalizes, `toDisplayFeatures()` renders preview.
- **Terra Draw**: `TerraDrawPolygonMode` — tracks `clickCount`, closes on start-vertex click.
- **OpenLayers**: `ol/interaction/Draw` with `type: 'Polygon'` — supports freehand mode toggle.
- **Penpot**: `path/drawing.cljs` — click adds point, drag sets handles, ESC closes. Batches via `start-undo-transaction`.
- **tldraw**: `DrawShapeUtil` — `onPointerDown` starts, `onPointerUp`/`onComplete` finalizes.

---

## Preview / read-only mode

Spatial editors need a view-only mode that reuses the same canvas renderer but disables all mutation paths. Distinct from "locked annotations" (per-element) — this is a global mode toggle that makes the entire canvas non-interactive for editing.

**What preview mode disables:**
- Undo/redo manager (destroy or disconnect — don't just hide the buttons)
- All mutation handlers (drag, resize, delete, create)
- Collaboration broadcasting (stop sending presence/awareness updates)
- Context menus and editing UI

**What preview mode preserves:**
- Pan and zoom (viewport navigation)
- Click-to-inspect (read-only detail panels)
- Canvas rendering (same component, same layout)

**Implementation pattern:**
```typescript
// Single boolean gates all mutation paths
const isPreviewMode = $state(false);

// Undo manager: destroy in preview, recreate on exit
$effect(() => {
  if (isPreviewMode) {
    undoManager?.destroy();
    return;
  }
  undoManager = new Y.UndoManager([yBlocks, yLinks], { ... });
});

// Mutation handlers return early
function onBlockDrag(event: DragEvent) {
  if (isPreviewMode) return;
  // ... normal drag logic
}

// Expose no-op versions for consistent API
if (isPreviewMode) {
  return { undo: () => {}, redo: () => {}, canUndo: false, canRedo: false };
}
```

**Use cases:**
- **Snapshot preview**: Viewing a historical state before deciding to restore it (see persistence.md "Named snapshots")
- **Shared view links**: Read-only URLs for stakeholders who shouldn't edit
- **Presentation mode**: Showing work without risk of accidental edits
- **Embedded views**: Canvas embedded in a dashboard or report

**Production**: Ideon uses `isPreviewMode` to gate undo manager lifecycle, mutation handlers, and collaboration. tldraw has `editor.updateInstanceState({ isReadonly: true })`. Excalidraw has `viewModeEnabled` prop. Figma has view-only mode for non-editors.

## Annotation draft lifecycle

**Dominant pattern: centralize draft state in a shared store, not components.** tldraw and Excalidraw have no component-owned drafts — all state in central `Editor`/scene store. Tool transitions call `editor.complete()` or `editor.cancel()`.

**Three-tier guidance:**

1. **Default: shared draft store.** Interface: `save()`, `clear()`, `canSave`. Mode transitions call `store.save()`. Works across Svelte 5 (reactive class), React (Zustand/Jotai), Vue 3 (composable).
2. **Fallback: framework imperative escape hatch.** For opaque children (third-party editors, iframes): React `useImperativeHandle`, Vue `defineExpose()`, Svelte `bind:this` with exported functions. Expose `{ save(), clear() }`.
3. **Anti-pattern: callback registration.** `registerSave(fn)` / `registerClear(fn)` reinvents the shared store with extra indirection.

**Draft resolution triggers**: mode transition (auto-save or prompt), panel close (prompt if `canSave`), explicit save, undo while draft active (discard draft), Escape (discard + return to previous mode).

## Anti-Patterns

### Boolean flags for mode state

**What happens**: `isDrawing`, `isSelecting`, `isPanning` can all be true simultaneously, producing impossible state combinations — user draws while selecting while panning. Each new mode doubles the number of flag combinations to test.

**Why it's tempting**: Booleans are the simplest possible state representation. Work fine with 1-2 modes.

**What to do instead**: Discriminated union (`type InteractionMode = { kind: 'default' } | { kind: 'draw'; tool: ... } | ...`) makes impossible states unrepresentable at the type level.

### Sequential flag assignments for mode transitions

**What happens**: Mode changes to `drawRegion` in one statement, tool stays on `select` until a second statement. Between the two assignments, the system is in an inconsistent state — mode and tool disagree. Events processed in this window produce bugs.

**Why it's tempting**: Setting two variables sequentially looks correct and passes manual testing.

**What to do instead**: Single `transitionTo()` function that atomically sets mode AND all implied state (active tool, cursor, event handlers). No direct assignment to mode state outside this function.

### Long-press for mobile annotation

**What happens**: Long-press conflicts with OS-level gestures (context menu, text selection, accessibility actions). Users trigger the wrong action or nothing at all.

**Why it's tempting**: Long-press feels like a natural "secondary action" on touch, analogous to right-click.

**What to do instead**: Mode-switching buttons for tool selection. Movement threshold for tap/drag disambiguation. No production drawing tool uses long-press for annotation.

### Timing-only tap vs drag disambiguation on touch

**What happens**: One-finger-draw vs one-finger-pan distinguished by hold duration alone. Users with different interaction speeds get inconsistent behavior. Fast users accidentally pan when trying to draw.

**Why it's tempting**: Time threshold is a single parameter to tune.

**What to do instead**: Use mode buttons to disambiguate intent (explicit tool selection), then use distance AND time thresholds together (8-25px movement, 200-400ms) for tap vs drag within a mode.

### Per-vertex undo entries during polygon construction

**What happens**: Each vertex click during polygon drawing creates a separate undo entry. Pressing Ctrl+Z removes one vertex instead of discarding the entire in-progress shape. The undo stack fills with intermediate construction state.

**Why it's tempting**: Using the standard mutation path for vertex additions is consistent with other edits.

**What to do instead**: Keep vertices as draft state in tool-local storage (not in the document). Only on completion does the shape enter the document as a single undo entry. On cancellation, discard everything — no undo entry created.

### Callback registration for draft lifecycle

**What happens**: `registerSave(fn)` / `registerClear(fn)` creates a manual pub/sub system that reinvents the shared store with extra indirection. Registration ordering, cleanup on unmount, and multiple registrations become bugs.

**Why it's tempting**: Avoids introducing a shared store when "just one callback" seems sufficient.

**What to do instead**: Centralize draft state in a shared store with `save()`, `clear()`, `canSave` interface. Mode transitions call `store.save()`. Works across Svelte 5 (reactive class), React (Zustand/Jotai), Vue 3 (composable).

### Assuming hover events exist on touch devices

**What happens**: Touch fires no `mousemove` before `mousedown`. Preview features that depend on hover (snap indicators, close-detection highlights, cursor-following preview lines) never appear on touch devices.

**Why it's tempting**: Hover-dependent previews work perfectly on desktop and look great in demos.

**What to do instead**: Design preview feedback that works without hover — show indicators on the last placed point, use the finger position from `touchmove` only after the first touch starts.
