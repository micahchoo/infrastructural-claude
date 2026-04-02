# Multi-Touch Arbitration

## The Problem

A single pointer stream is straightforward: track state, disambiguate click vs drag
via distance threshold. Multi-touch adds combinatorial ambiguity: is a second finger
starting a pinch-zoom, a two-finger pan, a two-finger draw, or an accidental palm
touch? The system must arbitrate between competing interpretations *while fingers are
still moving*, with no ability to ask the user "which did you mean?"

Temporal pressure: the decision must happen within ~100ms of the second touch or the
UI feels frozen. But waiting longer improves accuracy. Every system navigates this
tension differently.

## Competing Patterns

### 1. Slot-Based Touch Pipeline (drafft-ink)

**How it works:** Fixed number of touch "slots" (typically 2). `process_touch()`
assigns each touch point to a slot by ID. Disambiguation is structural:

- 1 slot occupied -> single-finger gesture (draw/select/pan depending on tool)
- 2 slots occupied -> compute pinch distance delta and center delta -> zoom/pan
- Slot freed -> revert to single-finger interpretation

**Key files:** `crates/drafftink-core/src/input.rs` (touch slots, pinch detection)

**Tradeoffs:**
- Simple, O(1) disambiguation — finger count IS the decision
- No temporal ambiguity: the moment a second finger touches, it's a pinch/pan
- Cannot distinguish 2-finger pan from 2-finger rotate without additional heuristics
- No cancel/rollback: if a 1-finger draw transitions to 2-finger pinch mid-stroke, the partial stroke is orphaned

**If removed:** Must fall back to distance/velocity heuristics to distinguish pinch from two independent touches. Much harder to get right.

**Detection signal:** Fixed-size touch point arrays, finger-count branching, no gesture recognizer abstraction.

### 2. Parallel Pinch State Machine (tldraw)

**How it works:** `useGestureEvents` hook (wrapping `@use-gesture/react`) maintains a
three-state pinch recognizer: `'zooming' | 'panning' | 'not sure'`. This runs
*outside* the main `StateNode` hierarchy — a parallel state machine.

**Key files:**
- `packages/editor/src/lib/hooks/useGestureEvents.ts` — pinch/pan recognition
- `packages/editor/src/lib/editor/managers/InputsManager/InputsManager.ts` — pointer velocity, origin tracking
- `packages/editor/src/lib/hooks/useDocumentEvents.ts` — bridges DOM events to dispatch

**Disambiguation flow:**
1. Two-finger gesture begins -> enter `'not sure'` state
2. Monitor scale delta vs translation delta
3. Scale delta exceeds threshold -> transition to `'zooming'`
4. Translation delta exceeds threshold without scale -> transition to `'panning'`
5. Once decided, the state locks for the remainder of the gesture

**Containment leak:** This pinch state machine does NOT participate in the `StateNode`
hierarchy. It's a parallel decision-maker that can override the active tool's state.
The statechart doesn't know about it until it receives a `pinch` or `pan` event.

**Tradeoffs:**
- Dedicated recognition logic, clean separation from tool states
- The `'not sure'` state handles the temporal ambiguity explicitly
- Parallel state machine creates a second source of truth for "what gesture is active"
- Tool states must handle being interrupted by pinch/pan at any point

**If removed:** Pinch recognition would need to live inside every tool's state machine,
duplicating the `'not sure'` -> `'zooming'` / `'panning'` logic across SelectTool,
DrawTool, EraseTool, etc.

**Detection signal:** Gesture library integration (`@use-gesture/react`, `hammer.js`),
separate pinch/pan state outside main tool FSM.

### 3. Per-Device Shortcut Registries (krita)

**How it works:** `KisShortcutMatcher` maintains entirely separate registries for
different input modalities:

- `strokeShortcuts` — pen/mouse button combinations
- `touchShortcuts` — finger count + gesture type (pinch/rotate/zoom/pan)
- `nativeGestureShortcuts` — OS-level gestures (macOS trackpad)

Touch arbitration happens within `KisTouchShortcut::matchDragType()`, which has its
own "not sure yet" state. The three-state stroke lifecycle (`Idle <-> Ready <-> Running`)
prevents cross-device interference: a pen stroke must fully transition before touch
can claim input.

**Key files:**
- `libs/ui/input/kis_shortcut_matcher.cpp` — parallel registries, priority
- `libs/ui/input/kis_touch_shortcut.cpp` — `matchDragType()` discriminator
- `libs/ui/input/kis_native_gesture_shortcut.cpp` — OS gesture path
- `libs/ui/input/kis_input_manager.cpp:267-291` — tablet event compression

**Tablet event compression:** `compressedMoveEvent` + `handleCompressedTabletEvent()`
coalesces high-frequency tablet moves (4000+ Hz on some tablets) to prevent event
flooding while preserving pressure/tilt fidelity for the final coalesced event.

**Palm rejection integration:** Pen proximity events suppress touch input. The
`CanvasSwitcher` event filter generates synthetic `FocusIn`/`FocusOut` on tablet
proximity changes, creating an implicit priority: pen > touch > mouse.

**Tradeoffs:**
- Device types never interfere — clean isolation
- Each modality can have custom matching logic (finger count, pressure, tilt)
- Separate codepaths mean separate bugs
- Adding a new input device type requires a new registry and matcher

**If removed:** All device types merge into a single event stream. Palm rejection
breaks immediately. Tablet pressure gets misinterpreted as touch force.

**Detection signal:** `QTabletEvent`/`QTouchEvent`/`QMouseEvent` switch, separate
shortcut lists per modality, `eventFilter()` overrides.

### 4. Module-Level Gesture Object (excalidraw)

**How it works:** A module-scoped `gesture` object tracks all active pointers:

```typescript
const gesture: {
  pointers: Map<number, { x: number; y: number }>;
  initialScale: number;
  lastCenter: { x: number; y: number } | null;
  initialDistance: number;
} = { ... };
```

Multi-touch arbitration is inline in `handleCanvasPointerMove`: check
`gesture.pointers.size`, compute distance between pointers, compare to
`initialDistance` for zoom, compute center delta for pan. Plus Safari-specific
`onGestureStart`/`onGestureChange`/`onGestureEnd` handlers (lines 5554-5613).

**Key files:**
- `packages/excalidraw/components/App.tsx` line 608 — gesture object
- Same file, `handleCanvasPointerMove` (line 6452) — inline arbitration
- Same file, `onTouchStart`/`onTouchEnd` (lines 3538/3595) — parallel touch path

**Tradeoffs:**
- Zero abstraction overhead — the logic is right where it's used
- Module-level mutable state is invisible to React's rendering model
- Parallel touch handlers (`onTouchStart`) and pointer handlers (`handleCanvasPointerMove`) both read/write the same `gesture` object
- Safari gesture API requires a completely separate codepath

**If removed:** Multi-touch stops working. No fallback — the `gesture` object is the only thing tracking multi-pointer state.

**Detection signal:** Module-level mutable object tracking pointer positions, inline distance/scale calculations in pointer-move handlers.

### 5. Per-Device GestureSettings (openseadragon)

**How it works:** Configuration object with separate settings per device type:

```javascript
gestureSettingsMouse: { clickToZoom, dblClickToZoom, dragToPan, ... }
gestureSettingsTouch: { clickToZoom, pinchToZoom, flickEnabled, ... }
gestureSettingsPen:   { clickToZoom, dblClickToZoom, dragToPan, ... }
```

Each device gets its own click-vs-drag distance threshold, double-click timeout, and gesture interpretation. The pointer event handler checks `event.pointerType` and routes to the appropriate settings.

**Tradeoffs:**
- Clean per-device configuration without code duplication
- Users can customize behavior per device type
- Settings multiply (3 device types x N settings each)
- Doesn't handle device type transitions (pen + touch simultaneously)

**Detection signal:** Separate configuration objects per `pointerType`, threshold parameters like `clickDistThreshold`, `dblClickDistThreshold`.

## Anti-Patterns

### 1. Competing Touch Interpreters

**What:** Multiple independent components each registering their own touch handlers
on the same element or overlapping elements.

**Evidence:** memories app has 3 competing touch interpreters on the timeline component.
Each independently processes touch events, leading to jittery behavior when two
interpreters disagree about gesture intent.

**Fix:** Single touch pipeline with explicit routing, not multiple independent listeners.

### 2. Blanket `preventDefault` Without Discrimination

**What:** Every touch/pointer handler calls `preventDefault()` to suppress browser
defaults (scroll, zoom, text selection), but this also suppresses legitimate
interactions on overlaid UI elements.

**Evidence:** neko `video.vue` uses `.stop.prevent` on every event type. Works for a
single-purpose overlay but makes it impossible to add interactive UI on top.

### 3. Ignoring Pointer Event Mismatches

**What:** Using `ignoreMismatchedPointerEvents: true` to paper over pointer ID
tracking bugs rather than fixing the root cause.

**Evidence:** allmaps TerraDraw overlays on MapLibre. The mismatch happens because
the overlay and the map both track pointers independently, and pointer IDs don't
always correspond between the two tracking systems.

## Decision Guide

**Choose Slot-Based Pipeline when:**
- Touch gestures are simple (1-finger draw, 2-finger pan/zoom)
- No need to distinguish rotate from pinch
- Native/Rust context where gesture libraries aren't available

**Choose Parallel State Machine when:**
- Already have a tool state machine (add pinch recognition alongside)
- Need `'not sure'` temporal disambiguation for multi-touch
- Willing to accept two sources of truth for active gesture

**Choose Per-Device Registries when:**
- Supporting pen + touch + mouse with fundamentally different semantics
- Desktop application with tablet driver integration
- Device isolation and palm rejection are critical

**Choose Per-Device Settings when:**
- Building a library/viewer consumed by others
- Users need to customize gesture behavior per device
- The gesture vocabulary is fixed (pan, zoom, click)

**Avoid Competing Interpreters always.**
