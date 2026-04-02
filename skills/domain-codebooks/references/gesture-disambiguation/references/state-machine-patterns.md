# State Machine Patterns for Gesture Disambiguation

## The Problem

Every interactive canvas must decide what a pointer event *means*. The same
`pointerdown` could start a drag, a selection, a pan, a draw, or a resize.
How the codebase organizes the decision tree determines whether gesture logic
stays contained or metastasizes across files.

## Competing Patterns

### 1. Hierarchical State Machine (tldraw)

**How it works:** A tree of `StateNode` objects. Each node can have children;
the active child handles events. Events bubble up if unhandled. Tool switching
replaces the active subtree.

```
Root
 ├── SelectTool (18 child states)
 │    ├── Idle           ← entry point, 500+ line onPointerDown
 │    ├── PointingCanvas ← temporal disambiguation: click or drag?
 │    ├── PointingShape  ← temporal disambiguation: click or drag on shape?
 │    ├── Brushing       ← rubber-band selection (entered from PointingCanvas)
 │    ├── Translating    ← move shapes (entered from PointingShape)
 │    ├── Resizing       ← resize shapes (entered from PointingResizeHandle)
 │    ├── Rotating       ← rotate shapes
 │    ├── DraggingHandle ← arrow/line handle
 │    ├── EditingShape   ← text editing mode
 │    ├── Crop/          ← nested sub-statechart
 │    └── ...6 more Pointing* states
 ├── DrawTool
 ├── EraseTool
 ├── HandTool
 └── ZoomTool
```

**Key files:**
- `packages/editor/src/lib/editor/tools/StateNode.ts` — base class, `handleEvent()` maps event names via `EVENT_NAME_MAP`, bubbles unhandled to parent
- `packages/tldraw/src/lib/tools/SelectTool/childStates/Idle.ts` — the disambiguation epicenter
- `packages/editor/src/lib/editor/managers/ClickManager/ClickManager.ts` — click count, double/triple/quad detection, coarse-pointer distance thresholds
- `packages/editor/src/lib/editor/managers/InputsManager/InputsManager.ts` — modifier keys, pointer velocity, pen detection as reactive atoms
- `packages/editor/src/lib/hooks/useDocumentEvents.ts` — DOM event -> `TLPointerEventInfo` -> `editor.dispatch()`

**Temporal disambiguation via `Pointing*` states:** When `pointerdown` fires, the
system enters a `Pointing*` state (e.g., `PointingShape`). This state waits for
sufficient movement to disambiguate click vs drag. If movement exceeds threshold,
transition to action state (`Translating`). If `pointerup` fires first, treat as
click and transition back to `Idle`.

**Typed event system:** `TLEventInfo` union with discriminated `target` field
(`'canvas' | 'shape' | 'selection' | 'handle'`) prevents handler confusion.

**Tradeoffs:**
- Clean separation: each state only handles events relevant to its context
- Testable: each state is an independent class
- State count explodes (SelectTool alone: 18+ children)
- Complexity concentrates at `Idle.onPointerDown` (~500 lines of nested switches)
- `getHitShapeOnCanvasPointerDown` duplicates hit-testing logic — re-targets `info.target` from `'canvas'` to `'shape'` by recursively calling `this.onPointerDown()` with modified info

**If removed:** All 18 child states collapse into a single handler with boolean flags tracking "am I dragging?", "am I resizing?", "what did I click on?" — the excalidraw pattern.

**Detection signal:** Look for `extends StateNode`, `onPointerDown`/`onPointerMove`/`onPointerUp` methods, `parent.transition()` calls.

### 2. God Object with Closure-Based Sub-States (excalidraw)

**How it works:** A single class (`App.tsx`, 12,535 lines) contains 50+ private
handler methods. Per-gesture state is created via closures: each `pointerdown`
creates a `pointerDownState` object threaded through `pointermove`/`pointerup`
handlers registered as window-level event listeners.

**Key handlers:**
- `handleCanvasPointerDown` (line 7232) -> dispatches to `handleSelectionOnPointerDown`, `handleTextOnPointerDown`, `handleFreeDrawElementOnPointerDown`, `handleLinearElementOnPointerDown`, `handleDraggingScrollBar`
- `handleCanvasPointerMove` (line 6452) -> multi-touch pinch, drag, hover, eraser
- `onPointerMoveFromPointerDownHandler` (line 9205) / `onPointerUpFromPointerDownHandler` (line 10110) — closure-based sub-state machines
- Module-level `gesture` object (line 608) tracking `pointers: Map<id, coords>`, `initialScale`, `lastCenter`, `initialDistance`

**Cross-file coupling:**
- `packages/element/src/linearElementEditor.ts` (2490 lines)
- `packages/element/src/binding.ts` (2940 lines)
- `packages/element/src/resizeElements.ts` (1500 lines)
- Each contains pointer-interaction-adjacent logic that App.tsx calls into bidirectionally.

**Containment attempt:** `withBatchedUpdates` wrapper on most event handlers batches React state updates. `pointerDownState` closure provides per-gesture isolation within the monolith.

**Tradeoffs:**
- No indirection: every handler is visible in one file (if you can find it in 12.5K lines)
- No state-class boilerplate
- Disambiguation is inline conditionals checking `activeTool.type`, `gesture.pointers.size`, modifier keys, drag thresholds — all in the same methods
- Implicit state machines via closures registered on `window` — invisible to tooling
- Adding a new tool means adding branches to every handler

**If removed:** The closure-per-gesture pattern is load-bearing. Without it, you'd need
explicit state objects (moving toward tldraw's pattern) or boolean flags (moving toward
penpot's anti-pattern).

**Detection signal:** Look for `pointerDownState`, handler methods > 200 lines with
tool-type conditionals, window-level event listener registration inside pointer-down handlers.

### 3. Parallel Shortcut Registries (krita)

**How it works:** `KisInputManager` acts as a central `QObject::eventFilter`,
dispatching `QTabletEvent`, `QTouchEvent`, `QMouseEvent`, and `QNativeGestureEvent`
through entirely separate codepaths. `KisShortcutMatcher` maintains three parallel
registries with independent matching and priority resolution:

- `QList<KisStrokeShortcut*> strokeShortcuts` — pen/mouse strokes
- `QList<KisTouchShortcut*> touchShortcuts` — finger count + gesture type
- `QList<KisNativeGestureShortcut*> nativeGestureShortcuts` — OS-level (macOS trackpad)

**Key files:**
- `libs/ui/input/kis_shortcut_matcher.cpp` — parallel registries, priority resolution
- `libs/ui/input/kis_touch_shortcut.cpp` — `matchDragType()` with "not sure yet" state
- `libs/ui/input/kis_native_gesture_shortcut.cpp` — OS gesture path
- `libs/ui/input/kis_input_manager.cpp:267-291` — tablet event compression
- `libs/ui/input/kis_input_manager_p.cpp:253-373` — `CanvasSwitcher` event filter

**Three-state stroke lifecycle:** `Idle <-> Ready <-> Running`. A stroke must fully
transition before a competing device can claim input. Prevents accidental cross-device
gesture triggering.

**Tradeoffs:**
- Device-type isolation: pen, touch, and native gestures never interfere
- Tablet event compression preserves pressure/tilt while preventing flooding
- Separate codepaths mean separate bugs — touch and pen can diverge in behavior
- Adding a new input device type requires a new registry
- `suppressAllKeyboardActions()` is a blunt instrument (all-on or all-off)

**If removed:** All device types merge into a single event stream. Palm rejection
breaks immediately — touch events during pen proximity would trigger tools.

**Detection signal:** Look for `eventFilter()` overrides, device-type switches on
`QEvent::type()`, separate shortcut lists per input modality.

### 4. Boolean Mode Flags (anti-pattern)

**How it works:** Disambiguation via boolean flags: `isDragging`, `isPanning`,
`isResizing`, `isDrawing`, etc. Checked in every handler.

**Evidence:** Penpot uses 12+ boolean params in pointer-down handler. FossFLOW has
10+ interaction modes with no centralized arbitration.

**Why it fails:** Flags interact combinatorially. With N flags, there are 2^N possible
states, most of which are invalid but not prevented. Adding a new mode means auditing
every handler for flag interactions.

**Detection signal:** Multiple `is*` booleans checked in event handlers, no state
machine or explicit mode enum.

## Decision Guide

**Choose Hierarchical State Machine when:**
- Many mutually exclusive tools with distinct gesture semantics
- Complex temporal disambiguation (click vs drag vs long-press)
- Team is large enough that isolated state classes aid parallel development
- You need testable, independent gesture handlers

**Choose God Object with Closures when:**
- Prototyping or small team that can hold the whole file in mind
- Tools share most gesture logic with minor variations
- You accept the cost of a single growing file

**Choose Parallel Registries when:**
- Multiple input device types with fundamentally different semantics (pen pressure, touch finger count, trackpad native gestures)
- Desktop application with tablet support
- Device isolation is more important than unified gesture model

**Avoid Boolean Flags unless:**
- You have <= 3 modes and no plans to add more (spoiler: you will)
