---
name: gesture-disambiguation
description: >-
  Pointer intent ambiguity when multiple handlers compete for the same input
  event (drag vs scroll vs select vs pan vs resize vs draw). Tool state machines,
  multi-touch arbitration, event delegation vs direct binding, capture/bubble
  phase conflicts, temporal/spatial click-vs-drag thresholds.

  Triggers: "pointer events fighting", "drag conflicts with scroll", "touch
  gesture conflicts", "tool state machine", "click vs drag threshold",
  "multi-touch pinch vs two-finger pan", "overlapping event handlers",
  "pointer coalescing", "canvas event handling architecture", "gesture
  recognizer conflicts", "layered hit-testing with gesture priority",
  "right-click vs right-drag dead-zone", "long-press detection cancels on move",
  "capture-phase event arbitration for overlays".

  Brownfield triggers: "clicking a button inside a draggable area doesn't work",
  "drag starts when I try to select text", "pinch zoom conflicts with drawing",
  "my tool state machine is getting unwieldy", "pointer events leak through
  overlays", "touch and mouse behave differently", "stopPropagation everywhere",
  "can't tell click from drag on pointerdown", "two-finger pinch conflicts with
  two-finger pan", "resize handle hit area overlaps shape body drag",
  "switching tools mid-gesture corrupts state", "right-click context menu
  dismisses immediately when drag starts", "long-press conflicts with drag-to-move
  on mobile", "rubber-band select triggers near shape boundaries",
  "drag-and-drop between panels fights with canvas pan".

  Symptom triggers: "how do editors disambiguate click vs drag intent on
  pointerdown", "how to arbitrate competing gesture handlers by pointer count
  and movement direction", "priority system for resize handle vs shape body
  drag within pixel radius", "canvas tool modes as state machines with clean
  transitions", "right-click context menu vs right-click-drag panning conflict",
  "normalize stylus barrel button into logical gesture intents",
  "capture/bubble conflict between canvas and embedded scrollable panel",
  "scrollable panel inside canvas loses scroll because canvas captures pointer",
  "how to handle event delegation between overlay UI and canvas layer".
---

# Gesture Disambiguation

The tension between multiple input handlers that all want to interpret the same
pointer/touch event. Produces spaghetti when unresolved because disambiguation
logic infiltrates every interactive component — each handler needs to know about
every other handler's claims on the event.

Evidence: 12/18 repos STRONG. The most universal UX force cluster observed.

## Evidence repos
- **tldraw** — SelectTool with 18 child states, `Idle.onPointerDown` ~500 lines of nested switches
- **excalidraw** — App.tsx god object (12.5K lines), 50+ private handlers, no formal state machine
- **penpot** — 12+ boolean params in pointer-down handler
- **krita** — `KisShortcutMatcher` with parallel stroke/touch/native-gesture registries
- **openseadragon** — Per-device GestureSettings (mouse/touch/pen), temporal/spatial thresholds
- **drafft-ink** — Custom 2-finger touch pipeline, ToolKind/ToolState enum routing
- **allmaps** — TerraDraw overlays on MapLibre with `ignoreMismatchedPointerEvents: true`
- **FossFLOW** — 10+ interaction modes with no centralized arbitration
- **recogito2** — 130-line `onMouseup`, forwardEvents boolean toggle
- **weavejs** — Pointer/touch/pen disambiguation, multi-pointer pinch guards
- **neko** — Blanket .stop.prevent on overlay, Guacamole keyboard gating
- **memories** — 3 competing touch interpreters on timeline

## Classify

1. **Input modalities** — mouse-only, touch+mouse, pen+touch+mouse?
2. **Handler count** — how many independent handlers compete for events?
3. **Spatial overlap** — do handler regions physically overlap (canvas + overlay)?
4. **Temporal ambiguity** — click vs drag vs long-press distinguished by timing?
5. **Modal tools** — are tools mutually exclusive (FSM) or concurrent?

## Patterns

### Hierarchical State Machine (tldraw pattern)
Tool hierarchy: Root → Tool → Child State. Each level can claim/pass events.
StateNode base class with `onPointerDown`, `onPointerMove`, `onPointerUp`.

**Tradeoff**: Clean separation but state count explodes (tldraw SelectTool: 18 children).
Best for: complex editors with many mutually exclusive tools.

### Per-Device Settings (openseadragon pattern)
Separate GestureSettings per input device (mouse/touch/pen). Each device gets its
own click-vs-drag thresholds and gesture interpretation.

**Tradeoff**: Clean device separation but settings multiply. Best for: viewers/libraries
that must handle all input devices uniformly.

### Capture-Phase Arbitration
A single top-level handler in capture phase decides which component gets the event.
Uses spatial position + current mode + device type to route.

**Tradeoff**: Centralized control but coupling to all handlers. Best for: overlay-heavy UIs.

### Boolean Mode Flags (anti-pattern)
`isDragging && !isResizing && !isPanning && event.button === 0 && !event.ctrlKey`
— the spaghetti this codebook exists to prevent.

**Detection signal**: 3+ boolean checks in a pointer handler, `stopPropagation` calls
scattered across components, `pointerEvents: 'none'` toggled at runtime.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| interactive-spatial-editing | Gesture layer IS the spatial editing entry point; they share tool state machines |
| input-device-adaptation | Same gesture means different things on different devices |
| focus-management-across-boundaries | Drag operations that cross focus boundaries |
| virtualization-vs-interaction-fidelity | Hit-testing across viewport boundaries during gesture |
| optimistic-ui-vs-data-consistency | Gesture in-progress state must be displayed before sync confirms |
| **userinterface-wiki** | `spring-for-gestures` (gesture motion must use springs), `spring-for-interruptible` (interruptible motion needs springs), `none-high-frequency` (no animation on rapid interactions), `physics-active-state` (:active scale on interactive elements) |

## References

Load as needed:
- `get_docs("domain-codebooks", "gesture-disambiguation state machine patterns")` — 4 competing patterns (hierarchical FSM, god object + closures, parallel registries, boolean flags) with tldraw/excalidraw/krita/penpot evidence, file paths, detection signals, de-factoring, decision guide
- `get_docs("domain-codebooks", "gesture-disambiguation multi-touch arbitration")` — 5 competing patterns (slot-based, parallel pinch FSM, per-device registries, module-level gesture object, per-device settings) with drafft-ink/tldraw/krita/excalidraw/openseadragon evidence, 3 anti-patterns
- `get_docs("domain-codebooks", "gesture-disambiguation overlay event interception")` — 5 competing patterns (blanket capture, DOM bridge, closure-scoped window listeners, event filter chain, pointer-events toggle) with neko/tldraw/excalidraw/krita/recogito evidence, 4 anti-patterns
