# Overlay Event Interception

## The Problem

Interactive applications layer UI on top of a primary interaction surface (canvas,
map, video, remote desktop). Every event must be routed to exactly one handler:
the overlay panel or the underlying surface. Get it wrong and buttons don't click
(events swallowed by canvas), drawings start when clicking menus (events leak
through overlays), or scroll/zoom affects the wrong layer.

The DOM's capture/bubble model provides two interception points, but neither solves
the routing problem alone. `stopPropagation` is a blunt instrument — it stops
events from reaching *all* other handlers, not just the ones you want to exclude.
`pointer-events: none` disables interaction entirely, with no middle ground.

## Competing Patterns

### 1. Blanket Capture with Hosting Gate (neko)

**How it works:** The overlay element registers handlers for every event type with
`.stop.prevent` modifiers, preventing ALL default behavior and propagation.
Interaction is toggled by a single boolean gate.

```vue
<textarea
  @wheel.stop.prevent="onWheel"
  @mousemove.stop.prevent="onMouseMove"
  @mousedown.stop.prevent="onMouseDown"
  @mouseup.stop.prevent="onMouseUp"
  @contextmenu.stop.prevent
  :style="{ pointerEvents: hosting ? 'auto' : 'none' }"
/>
```

Non-hosts get `pointer-events: none` — zero event capture. Hosts get total capture.
Guacamole keyboard attached via `keyboard.listenTo(this._overlay)` with `onkeydown`
returning `false` to suppress browser handling. Gate: `if (!this.hosting || this.locked) return true` (pass-through).

**Key evidence:**
- Touch events explicitly simulated as mouse events (`onTouchHandler` creates `MouseEvent` from `TouchEvent`)
- Scroll forwarding: `onWheel` converts deltas with `WHEEL_LINE_HEIGHT` normalization, scroll inversion, sensitivity clamping, 100ms throttle — forwarded via binary DataChannel
- `lockKeyboard`/`unlockKeyboard` for fullscreen keyboard lock API

**Tradeoffs:**
- Simple binary model: either the overlay captures everything or nothing
- Works perfectly for remote desktop (the overlay IS the interaction surface)
- Cannot have interactive UI elements (buttons, inputs) on top of the overlay
- Touch-to-mouse simulation loses multi-touch semantics

**If removed:** Raw browser events would fire on the underlying video element, causing
text selection, context menus, and unintended browser navigation.

**Detection signal:** `.stop.prevent` on every handler, `pointer-events` toggled by
boolean, single gate function controlling all event forwarding.

### 2. DOM Event Bridge with Typed Dispatch (tldraw)

**How it works:** `useDocumentEvents` hook registers handlers at the `document` level.
Raw DOM events are converted to typed `TLPointerEventInfo` objects with a discriminated
`target` field, then dispatched to the editor's state machine. The state machine
decides routing — not the DOM.

**Flow:**
1. `pointerdown` on `document` -> `useDocumentEvents` handler
2. Hit-test determines target: `'canvas' | 'shape' | 'selection' | 'handle'`
3. Create `TLPointerEventInfo` with target, point, modifiers
4. Call `editor.dispatch(info)`
5. StateNode hierarchy routes based on target + current state

**Overlay handling:** tldraw UI panels (toolbars, menus, dialogs) are React components
rendered *outside* the canvas element. They use standard React event handling. The
`document`-level handler checks if the event target is inside the canvas container
before dispatching to the editor.

**Key files:**
- `packages/editor/src/lib/hooks/useDocumentEvents.ts` — DOM bridge
- `packages/editor/src/lib/editor/types/event-types.ts` — typed events
- `packages/editor/src/lib/editor/tools/StateNode.ts` — routing

**Tradeoffs:**
- Clean separation: DOM events become typed domain events before routing
- UI panels and canvas have independent event systems
- Document-level registration means the handler fires for ALL events, even
  those clearly destined for UI panels — must check containment every time
- Hit-testing on every pointer event has performance cost

**If removed:** Each canvas element would need its own event handlers. Overlapping
elements would need explicit `stopPropagation` coordination. Hit-testing would
move into individual handlers, duplicating logic.

**Detection signal:** Document-level event registration, event-to-domain-object
conversion, containment checks before dispatch.

### 3. Closure-Scoped Window Listeners (excalidraw)

**How it works:** `handleCanvasPointerDown` creates a `pointerDownState` closure and
registers `pointermove`/`pointerup` handlers directly on `window`. These window-level
handlers capture all subsequent pointer events regardless of which element they target.

```typescript
// Inside handleCanvasPointerDown:
const pointerDownState = { origin, hit, ... };

const onPointerMove = withBatchedUpdates((event) => {
  // Uses pointerDownState from closure
  this.onPointerMoveFromPointerDownHandler(pointerDownState, event);
});

window.addEventListener("pointermove", onPointerMove);
window.addEventListener("pointerup", onPointerUp); // cleans up both
```

**Overlay interaction:** Excalidraw renders its toolbar and panels as React components
within the same container. The `withBatchedUpdates` wrapper ensures React state updates
from gesture handlers don't cause intermediate renders. Panel clicks don't conflict
because the `pointerdown` on a panel button doesn't trigger `handleCanvasPointerDown`
(the canvas element's handler).

**Cross-file coupling:**
- `packages/element/src/linearElementEditor.ts` (2490 lines) — handles pointer events
  for arrow editing, called from App.tsx gesture handlers
- `packages/element/src/binding.ts` (2940 lines) — binding updates during drag
- `packages/element/src/resizeElements.ts` (1500 lines) — resize during drag
- These files contain pointer-interaction-adjacent logic coupled bidirectionally to App.tsx

**Tradeoffs:**
- Window-level capture guarantees no events are missed during a drag
- Closure provides per-gesture isolation without explicit state objects
- Window listeners are invisible to React DevTools and component hierarchy
- If `pointerup` handler fails to clean up, listeners leak permanently
- Cannot easily cancel or redirect a gesture mid-stream

**If removed:** Pointer events would only fire while over the canvas element. Dragging
outside the canvas boundary would lose the gesture. This is why every canvas
application uses window/document-level listeners for drag operations.

**Detection signal:** `window.addEventListener` inside pointer-down handlers, closure
variables captured across event phases, cleanup in pointer-up.

### 4. Event Filter Chain (krita / Qt)

**How it works:** Qt's `QObject::eventFilter()` provides capture-phase interception.
`KisInputManager` installs itself as an event filter on the canvas widget. Events
pass through the filter before reaching the widget's own event handlers.

**Chain structure:**
1. `KisInputManager::eventFilter()` — first pass, classifies event type
2. Route to appropriate handler: `tabletEvent()`, `touchEvent()`, `mousePressEvent()`
3. Handler consults `KisShortcutMatcher` for action mapping
4. If matched, consume event (return `true` from filter)
5. If unmatched, pass through to widget's default handling

**Focus boundary handling:** `CanvasSwitcher` is a separate event filter that
intercepts `FocusIn`/`FocusOut` events with a debounce threshold
(`setupFocusThreshold()`), preventing spurious focus transitions when clicking
between canvas and docker panels.

**Keyboard gating:** `suppressAllKeyboardActions()` disables all keyboard shortcuts
when tools enter text-editing mode. `suppressConflictingKeyActions(QVector<QKeySequence>)`
selectively disables specific shortcuts. `KisInputActionGroupsMask` callback
dynamically filters action groups based on UI state.

**Key files:**
- `libs/ui/input/kis_input_manager.cpp` — primary event filter
- `libs/ui/input/kis_input_manager_p.cpp:253-373` — `CanvasSwitcher`
- `libs/ui/input/kis_shortcut_matcher.cpp` — action matching

**Tradeoffs:**
- Qt's event filter is a first-class pattern with clear semantics
- Chain of responsibility: multiple filters can be stacked
- Filter return value explicitly controls propagation (true = consumed)
- Filters see ALL events for the filtered object — must be fast
- Focus debouncing is a workaround for Qt's eager focus model

**If removed:** Events would reach canvas widget handlers directly. No centralized
input classification. Each tool would need its own event type checking.

**Detection signal:** `eventFilter()` override, `installEventFilter()` calls,
boolean return value controlling propagation.

### 5. `pointer-events: none` Toggle with `forwardEvents` (recogito / annotation overlays)

**How it works:** Annotation overlay layers sit on top of the content being annotated.
By default, `pointer-events: none` passes all events through to the content below.
When annotation mode is active, `pointer-events: auto` is set and a `forwardEvents`
boolean controls whether events that don't hit an annotation are forwarded to the
underlying content.

**Evidence:** recogito2 uses a `forwardEvents` boolean toggle and a 130-line
`onMouseup` handler that decides post-hoc whether the event was an annotation
gesture or should be forwarded.

**Tradeoffs:**
- Simple toggle model for annotation-on-content pattern
- Content below remains interactive when annotations are passive
- Post-hoc forwarding is fragile — events have already been captured
- `forwardEvents` boolean doesn't handle partial forwarding (forward scroll but capture click)

**If removed:** Annotation overlay would either block all content interaction or
miss all pointer events — no middle ground.

**Detection signal:** `pointer-events` CSS toggled by mode, `forwardEvents` flag,
manual event re-dispatch to underlying elements.

## Anti-Patterns

### 1. `stopPropagation` Everywhere

**What:** Every component calls `stopPropagation()` to prevent events from reaching
other handlers. Creates a fragile web where removing one `stopPropagation` breaks
unrelated components.

**Why it fails:** `stopPropagation` is non-composable. It prevents ALL handlers on
parent elements, not just the one you're trying to avoid. Components become
implicitly coupled through propagation prevention.

**Fix:** Use a single event router (pattern 2 or 4) that makes explicit routing
decisions, rather than distributed `stopPropagation` calls.

### 2. `ignoreMismatchedPointerEvents`

**What:** Suppressing pointer ID tracking errors rather than fixing the root cause.

**Evidence:** allmaps TerraDraw overlays on MapLibre. The overlay and map track
pointers independently. When pointer IDs don't match between tracking systems,
events are silently dropped rather than reconciled.

**Fix:** Single pointer tracking system shared between overlay and underlying surface,
or explicit pointer ID mapping between the two.

### 3. Z-Index Wars

**What:** Overlay panels fighting for event precedence via z-index stacking rather
than explicit event routing. Adding a new panel requires auditing all existing
z-index values.

**Fix:** Event routing should be based on explicit containment/delegation, not
paint order. Z-index controls rendering, not interaction semantics.

### 4. Synthetic Event Re-Dispatch

**What:** Capturing an event, calling `preventDefault()`, then creating a new
synthetic event and dispatching it to a different target.

**Evidence:** neko converts `TouchEvent` to synthetic `MouseEvent` for forwarding.

**Why it's risky:** Synthetic events may lack properties of the original (pressure,
tilt, coalesced events). Browser security restrictions may prevent some synthetic
events. Re-dispatch can cause infinite loops if the new event triggers the same handler.

**When it's acceptable:** Cross-device translation (touch -> mouse for remote desktop)
where the target system only understands one input type.

## Decision Guide

**Choose Blanket Capture when:**
- The overlay IS the primary interaction surface (remote desktop, game)
- No interactive UI elements needed on top of the overlay
- Binary active/inactive model is sufficient

**Choose DOM Bridge with Typed Dispatch when:**
- Building a web canvas application with standard UI panels
- Want clean separation between DOM events and domain events
- Willing to pay hit-testing cost on every pointer event

**Choose Closure-Scoped Window Listeners when:**
- Need guaranteed drag tracking outside element boundaries
- Per-gesture state isolation without explicit state objects
- Willing to manage listener cleanup carefully

**Choose Event Filter Chain when:**
- Qt or similar framework with first-class event filter support
- Multiple interception points needed (input classification + focus management)
- Want explicit propagation control (consume vs pass-through)

**Choose `pointer-events` Toggle when:**
- Annotation or overlay layer that's usually passive
- Underlying content must remain interactive by default
- Simple mode toggle is sufficient
