# Pointer Event Normalization and Pen Mode Gating

## The Problem

Applications receive input from heterogeneous sources — mouse events, tablet events (QTabletEvent), touch events (QTouchEvent), native gesture events (QNativeGestureEvent), and browser PointerEvents — each with different coordinate systems, capabilities, and delivery semantics. Without normalization, every interaction handler must understand every event type. Without modality gating, pen users are plagued by spurious touch events (palm rejection), and touch users trigger pen-only behaviors.

Symptoms: palm resting on screen creates unwanted strokes, touch events fight pen events during stylus use, pointer position tracked in wrong coordinate space, drag thresholds too small for touch / too large for mouse, the same gesture triggers different code paths depending on which event type fires first.

## Competing Patterns

### Pattern A: Reactive Input State Model

**When to use:** Web/TypeScript applications using PointerEvent where all input arrives through a single event type with `pointerType` discrimination.

**When NOT to use:** Native applications that receive fundamentally different event types (QTabletEvent vs QMouseEvent vs QTouchEvent) requiring type-level dispatch.

**How it works:** Maintain a single reactive state object that normalizes all pointer, pinch, and wheel events into unified coordinate spaces (screen space and page/canvas space). The state object exposes atoms/signals for current position, velocity, modifier keys, and device type. All downstream code reads from this state rather than raw events.

**Production example:** tldraw `InputsManager` (`packages/editor/src/lib/editor/managers/InputsManager/InputsManager.ts`) maintains reactive atoms for position in both screen and page coordinates:

```typescript
// InputsManager.ts
private _currentScreenPoint = atom<Vec>('currentScreenPoint', new Vec())
private _currentPagePoint = atom<Vec>('currentPagePoint', new Vec())
private _isPen = atom<boolean>('isPen', false)

updateFromEvent(info: TLPointerEventInfo | TLPinchEventInfo | TLWheelEventInfo): void {
    const sx = info.point.x - screenBounds.x
    const sy = info.point.y - screenBounds.y
    const sz = info.point.z ?? 0.5  // z = pressure, default 0.5

    this._currentScreenPoint.set(new Vec(sx, sy))
    const nx = sx / cz - cx  // Transform through camera
    const ny = sy / cz - cy
    this._currentPagePoint.set(new Vec(nx, ny, sz))

    this._isPen.set(info.type === 'pointer' && info.isPen)
}
```

Key design decisions:
- **Pressure as Z coordinate**: `info.point.z ?? 0.5` normalizes pressure into the Vec's z component, defaulting to 0.5 for non-pressure devices
- **Previous/current tracking**: Stores `_previousScreenPoint` and `_previousPagePoint` for velocity and delta calculation
- **Pointer velocity smoothing**: Lerps velocity with previous value (`pointerVelocity.clone().lrp(direction.mul(length / elapsed), 0.5)`) to dampen jitter
- **Origin tracking**: Captures position at `pointer_down` for drag distance calculation

**Tradeoffs:** All event types must be pre-normalized into `TLPointerEventInfo` before reaching the manager. The reactive atom system adds overhead for high-frequency events. The single-point-of-truth model means no handler sees raw events.

### Pattern B: Priority Event Filter Chain

**When to use:** Native applications receiving heterogeneous Qt/platform event types that can't be pre-normalized into a single type. Applications needing layered event processing (popup dismissal, shortcut matching, tool dispatch).

**When NOT to use:** Web applications where PointerEvent already provides a unified type. Simple applications with one event processing layer.

**How it works:** Install the input manager as an event filter on the canvas widget. Process events through a priority-ordered filter chain before the main handler. Each filter can consume events, transform them, or pass them through. The main handler then dispatches by event type to specialized subsystems.

**Production example:** Krita `KisInputManager` (`libs/ui/input/kis_input_manager.cpp`) implements `QObject::eventFilter()` with a priority filter chain:

```cpp
// kis_input_manager.cpp
bool KisInputManager::eventFilter(QObject* object, QEvent* event)
{
    if (object != d->eventsReceiver) return false;
    if (d->eventEater.eventFilter(object, event)) return false;

    if (!d->matcher.hasRunningShortcut()) {
        for (auto it = d->priorityEventFilter.begin();
             it != d->priorityEventFilter.end(); /*noop*/) {
            const QPointer<QObject> &filter = it->second;
            if (filter.isNull()) {
                it = d->priorityEventFilter.erase(it);
                continue;
            }
            if (filter->eventFilter(object, event)) return true;
            // If filter modified the list, exit loop
            if (d->priorityEventFilterSeqNo != savedPriorityEventFilterSeqNo) {
                return true;
            }
            ++it;
        }
    }
    // ... dispatch to type-specific handlers
}
```

The filter chain handles:
1. **Event eating**: `d->eventEater` suppresses synthetic mouse events generated by touch
2. **Priority filters**: Plugins and overlays insert themselves at specific priority levels
3. **Popup dismissal**: If a popup is visible, press events close it and are consumed
4. **Running shortcut bypass**: When a stroke shortcut is running, priority filters are skipped for latency

After the filter chain, `eventFilterImpl()` dispatches by `QEvent::Type`:
- `QEvent::TabletPress/Move/Release` -> shortcut matcher + compressed move
- `QEvent::MouseButtonPress/Move/Release` -> shortcut matcher (if not from tablet)
- `QEvent::TouchBegin/Update/End/Cancel` -> touch shortcut subsystem
- `QEvent::NativeGesture` -> native gesture shortcut subsystem

**Tradeoffs:** Complex event type dispatch with platform-specific branches (`#ifdef Q_OS_MACOS`, `#ifdef Q_OS_ANDROID`). Filter modification during iteration requires sequence number tracking. Touch-to-mouse synthesis by Qt must be explicitly suppressed.

### Pattern C: Pen Mode Gating with Auto-Detection

**When to use:** Applications that support both pen and touch on the same device and need to prevent touch interference during pen use.

**When NOT to use:** Desktop-only applications where pen/touch conflict doesn't occur. Applications where touch should always be active alongside pen.

**How it works:** Track whether the current session is in "pen mode" based on the most recent input device. When pen mode is active, reject touch/mouse events at the event dispatch entry point. Auto-detect pen mode on first pen event; optionally allow manual override.

**Production example:** tldraw implements pen mode gating in `Editor.ts` (`packages/editor/src/lib/editor/Editor.ts:10570-10642`):

```typescript
// Editor.ts — pointer event dispatch
case 'pointer': {
    const { isPen } = info
    const { isPenMode } = instanceState

    switch (info.name) {
        case 'pointer_down': {
            // If we're in pen mode and the input is not a pen, stop here
            if (isPenMode && !isPen) return

            // If pen mode is off but we got a pen event, turn pen mode on
            if (!isPenMode && isPen) this.updateInstanceState({ isPenMode: true })

            // Surface Pen / Wacom eraser button detection
            if (info.button === STYLUS_ERASER_BUTTON) {
                this._restoreToolId = this.getCurrentToolId()
                this.complete()
                this.setCurrentTool('eraser')
            }
            break
        }
        case 'pointer_move': {
            // If the user is in pen mode, but the pointer is not a pen, stop here.
            if (!isPen && isPenMode) return
            // ...
        }
    }
}
```

Key design decisions:
- **Auto-activation**: Pen mode activates on first pen event, no user action needed
- **Touch rejection**: Once in pen mode, non-pen `pointer_down` and `pointer_move` are silently dropped
- **Eraser detection**: `STYLUS_ERASER_BUTTON` (button 5) triggers automatic tool switching, with `_restoreToolId` for recovery
- **Persistent state**: `isPenMode` is stored in instance state, surviving page navigation

Krita takes a different approach — it uses a configuration flag (`KisConfig::disableTouchOnCanvas()`) rather than auto-detection, and synthesizes mouse events from single-finger touch when touch painting is enabled:

```cpp
// kis_input_manager.cpp — TouchEnd handler
if (!d->touchStrokeBlocked
    && !KisConfig(true).disableTouchOnCanvas()
    && !d->touchHasBlockedPressEvents
    && touchEvent->touchPoints().count() == 1) {
    // Single finger tap with no drag — synthesize press+release
    d->matcher.buttonPressed(Qt::LeftButton, d->originatingTouchBeginEvent.data());
    d->matcher.buttonReleased(Qt::LeftButton, touchEvent);
}
```

**Tradeoffs:** Auto-detection can't distinguish "user wants to use finger" from "palm touched screen." Manual override (Krita's approach) gives control but requires UI. The "reject all non-pen in pen mode" rule breaks multi-modal workflows (e.g., pinch-zoom while drawing with pen).

## Decision Guide

- "Web app with PointerEvent support?" -> Pattern A (reactive state model). Normalize once, read everywhere.
- "Native app with heterogeneous event types?" -> Pattern B (priority filter chain). Dispatch by type after filtering.
- "Device supports both pen and touch?" -> Pattern C (pen mode gating). Reject touch during pen use.
- "All three?" -> Layer them: filter chain (B) at the OS event level, normalize into state model (A) for downstream code, gate on modality (C) at dispatch.

## Anti-Patterns

### Don't: Let Each Handler Parse Raw Events Independently
**What happens:** Every tool, gesture recognizer, and UI handler duplicates coordinate transformation, device detection, and modifier key tracking. Bugs in one handler don't match behavior in another. Screen-to-canvas transforms drift when the camera changes.
**Instead:** Normalize events once into a shared state model (Pattern A) or dispatch through a single filter chain (Pattern B). Handlers read normalized state, never raw events.

### Don't: Use Fixed Drag Distance Thresholds for All Input Devices
**What happens:** A 4px drag threshold designed for mouse is too small for touch (causing accidental drags) and too large for pen (preventing fine adjustments).
**Instead:** tldraw uses `isCoarsePointer` to select between `dragDistanceSquared` and `coarseDragDistanceSquared`, and uses `coarsePointerWidth` to expand edge scroll activation zones. The discrimination happens once in the state model; handlers just read the threshold.

```typescript
// Editor.ts — drag detection with device-adaptive thresholds
(instanceState.isCoarsePointer
    ? this.options.coarseDragDistanceSquared
    : this.options.dragDistanceSquared) / cz
```

### Don't: Suppress Touch Events Globally When a Tablet Is Connected
**What happens:** Users with convertible laptops lose all touch functionality even when the pen is holstered. Capability detection (navigator.maxTouchPoints > 0) stays true permanently — it doesn't indicate current use.
**Instead:** Gate on the current event's `pointerType` (Pattern C), not on device capability. Activate pen mode on pen event, not on tablet detection. Provide a way to exit pen mode.
