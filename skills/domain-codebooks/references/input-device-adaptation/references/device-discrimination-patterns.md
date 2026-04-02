# Device Discrimination and Adaptation Patterns

## The Problem

Pen, touch, and mouse have fundamentally different capabilities (pressure, tilt, hover, precision) and interaction semantics (a finger drag means pan, a pen drag means draw, a mouse drag means select). Without explicit device discrimination, the same gesture triggers wrong behavior on different devices, pressure is ignored, tablet events flood the render pipeline, and hover-dependent UI breaks on touch.

Symptoms: pen pressure doesn't work, touch triggers unwanted drawing, hover states break on tablet, hundreds of pointer events cause frame drops, fine controls unusable with finger.

## Competing Patterns

### Pattern A: Per-Device Gesture Settings

**When to use:** Applications that need device-specific behavior for the same gesture type (e.g., different scroll/zoom sensitivity for mouse wheel vs pinch-zoom).

**When NOT to use:** Simple apps with only mouse input. Apps where all devices should behave identically.

**How it works:** Maintain separate configuration objects per device type (mouse, touch, pen, unknown). Each config specifies gesture thresholds, sensitivity multipliers, and enabled/disabled gestures. On pointer event, look up the config by `pointerType` and apply device-specific parameters.

**Production example:** OpenSeadragon maintains separate `GestureSettings` objects per device type with independent scroll/zoom/click thresholds. When a pointer event arrives, the appropriate settings are selected by device type, so pinch-zoom sensitivity differs from mouse wheel sensitivity.

**Tradeoffs:** Configuration surface area multiplies by device count. Testing requires exercising each device type independently.

### Pattern B: Pointer Type Routing at Event Entry

**When to use:** Applications where the same gesture has fundamentally different meanings on different devices (pen = draw, touch = pan, mouse = select).

**When NOT to use:** Applications where all devices should trigger the same action. Single-device applications.

**How it works:** At the event entry point (before gesture interpretation), check `PointerEvent.pointerType` and route to different handlers. This happens before the gesture disambiguation layer, so the correct intent is established early.

**Production example:** weavejs discriminates pen/touch/mouse at the event entry point, routing pen events to drawing handlers and touch events to navigation handlers. tldraw uses `pointerType` to adjust hit-testing sensitivity (larger targets for touch) and to determine whether pressure data is available.

**Tradeoffs:** Requires clear device→intent mapping upfront. Users who want to draw with finger (not pen) need an override mechanism. Device switching mid-session must update routing.

### Pattern C: Pressure Pipeline with Device Calibration

**When to use:** Drawing/painting applications where pen pressure is a primary expressive dimension.

**When NOT to use:** Applications that don't use pressure data. Text-focused applications.

**How it works:** A dedicated pipeline maps raw pressure values (0.0-1.0) through calibration curves to visual output. The pipeline handles: device detection (mouse defaults to pressure=1.0), pressure curve shaping (linear, ease-in, custom), and per-point pressure storage for replay/undo. The visual mapping (e.g., stroke width) applies the curve at render time.

**Production example:** drafft-ink stores per-sample pressure values (`Freehand { pressures: Vec<f64> }`). The render pipeline applies sin-eased width: `width = base_size * (1.0 - thinning * (1.0 - (pressure * PI / 2.0).sin()))`. Mouse defaults to pressure 1.0; stylus provides real values. Left/right contour generation produces variable-width Bezier paths.

**Tradeoffs:** Pressure curves are subjective — users expect customization. Storage cost increases (per-point pressure vs per-stroke). Replay/export must preserve pressure data.

### Pattern D: Tablet Event Compression

**When to use:** Applications receiving high-frequency input from tablet digitizers (200+ Hz) that feed expensive operations (paint strokes, path calculation).

**When NOT to use:** Applications where every input sample matters (handwriting recognition). Low-frequency input sources.

**How it works:** Coalesce consecutive move events from tablet devices, preserving the latest pressure/tilt values while discarding intermediate position samples. Process the compressed event batch once per frame instead of once per raw event.

**Production example:** krita `kis_input_manager.cpp` — `compressedMoveEvent` + `handleCompressedTabletEvent()` coalesces high-frequency tablet move events. Without compression, 200+ Hz tablet reports generate redundant paint-engine stroke segments, causing CPU-bound rendering stalls. Krita also maintains parallel shortcut registries per device type (`strokeShortcuts`, `touchShortcuts`, `nativeGestureShortcuts`).

**Tradeoffs:** Compression loses intermediate samples — bad for precise handwriting but acceptable for paint strokes. Compression ratio needs tuning per device. Some applications need the full event stream for smoothing algorithms.

## Decision Guide

- "Same gesture, different meaning per device?" → Pattern B (pointer type routing)
- "Same gesture, different sensitivity per device?" → Pattern A (per-device settings)
- "Pen pressure is a core feature?" → Pattern C (pressure pipeline)
- "Tablet input causes performance issues?" → Pattern D (event compression)
- "All of the above?" → Layer them: routing at entry (B), settings per device (A), pressure pipeline for pen (C), compression for tablet (D)

## Anti-Patterns

### Don't: Ignore `pointerType` and Treat All Input as Mouse
**What happens:** Touch triggers hover states, pen pressure is ignored, tablet event flood causes lag, touch targets are too small for fingers.
**Instead:** Check `pointerType` at event entry and adapt behavior. Use `@media (pointer: coarse)` for CSS-level adaptation.

### Don't: Couple Device Detection to Feature Detection
**What happens:** "If touch is available, disable hover" — but many laptops have both touchscreen and trackpad. Device presence doesn't mean current use.
**Instead:** Detect the *current* input device from the event's `pointerType`, not from device capability queries.

### Don't: Apply Mouse Interaction Patterns to Touch
**What happens:** Tiny buttons, hover-dependent menus, right-click context menus, precise drag handles — all unusable on touch.
**Instead:** Adapt hit areas, provide alternative gesture paths, and ensure core functionality works without hover.
