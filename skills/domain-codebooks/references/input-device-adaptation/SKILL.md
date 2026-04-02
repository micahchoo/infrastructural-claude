---
name: input-device-adaptation
description: >-
  Pen vs touch vs mouse modality switching — same gesture means different things
  on different devices. Pressure/tilt mapping, coarse vs fine pointer detection,
  per-device gesture settings, tablet event compression, hover availability.

  Triggers: "pen pressure mapping", "touch vs mouse behavior", "tablet input",
  "coarse pointer", "pointer type detection", "device-specific gestures",
  "stylus tilt", "palm rejection", "hover state on touch devices",
  "PointerEvent pressure tilt", "multi-touch with stylus", "per-device
  scroll zoom gestures", "Apple Pencil double-tap", "Wacom tablet calibration",
  "digitizer vs browser pointer events".

  Brownfield triggers: "pen pressure doesn't work", "touch and mouse behave
  differently", "hover states break on touch", "tablet events are laggy",
  "palm triggers unwanted drawing", "fine controls unusable on touch",
  "pressure curve feels linear and unnatural", "spurious touch events while
  drawing with stylus", "hundreds of pointer events cause frame drops",
  "touch targets don't adapt when switching input device", "hover-dependent
  UI breaks on tablet", "tilt angle not mapped for calligraphy brush",
  "scroll and zoom gestures conflict between touch and mouse".

  Symptom triggers: "palm resting on screen while drawing with stylus creates
  unwanted strokes", "raw pressure values feel linear need curve mapping and
  per-device calibration", "show larger touch targets for fingers vs precise
  targets for mouse", "fast pen strokes have visible straight-line segments
  between sparse input points", "device-adaptive layout compact for mouse
  spacious for touch but user switches mid-session", "Apple Pencil double-tap
  vs Wacom express keys vs barrel button need unified tool-switching API",
  "mouse right-click vs touch long-press need parallel gesture mappings per
  input modality", "stylus hover preview vs touch which has no hover at all",
  "tilt values from Apple Pencil vs Wacom vs Samsung S Pen have different
  ranges need normalization", "convertible laptop switches between mouse and
  touchscreen mid-session".

  Loaded via domain-codebooks router. Also consulted by pattern-advisor
  for multi-device input architecture decisions.
---

# Input Device Adaptation

The tension between supporting multiple input devices (pen, touch, mouse) that
have fundamentally different capabilities and interaction semantics. Produces
spaghetti when device-specific logic spreads across every interaction handler.

Evidence: 5 repos with distinct evidence (tldraw, drafft-ink, weavejs, krita, openseadragon).

## Patterns

- **Per-Device GestureSettings** (openseadragon) — separate threshold configs per device type
- **Pointer Type Routing** (weavejs) — pen/touch/mouse discrimination at event entry
- **Pressure Pipeline** (drafft-ink) — dedicated pressure-to-visual mapping with device calibration
- **Tablet Event Compression** (krita) — coalescing high-frequency tablet events

### Code evidence: krita tablet event compression

**File:** `libs/ui/input/kis_input_manager.cpp:267-291`

`compressedMoveEvent` + `handleCompressedTabletEvent()` coalesces high-frequency tablet
move events to prevent event flooding while preserving pressure/tilt fidelity. Tablet
digitizers report at 200+ Hz; without compression, every intermediate point generates a
full paint-engine stroke segment.

Krita also maintains parallel shortcut registries per device type in `KisShortcutMatcher`:
`strokeShortcuts`, `touchShortcuts`, `nativeGestureShortcuts` — each with independent
matching and priority resolution (`libs/ui/input/kis_shortcut_matcher.cpp`).

- **If removed:** Paint strokes at high tablet report rates generate 200+ redundant
  paint-engine updates per second. CPU-bound rendering stalls while the event queue
  backs up, producing visible lag.
- **Detection signal:** `compressedMoveEvent` accumulator pattern; `QTabletEvent` handlers
  that batch before dispatching to the paint tool.

### Code evidence: drafft-ink pressure-to-visual pipeline

**Files:** `crates/drafftink-render/src/vello_impl.rs`, `crates/drafftink-core/src/shapes/mod.rs`

The freehand rendering pipeline applies pressure-dependent stroke width with sin-easing:
```rust
width = base_size * (1.0 - thinning * (1.0 - (pressure * PI / 2.0).sin()))
```
Points store per-sample pressure values (`Freehand { pressures: Vec<f64> }`). Mouse
defaults to pressure 1.0; stylus provides real values. Left/right contour generation
in `vello_impl.rs` uses this width to produce variable-width Bezier paths.

- **If removed:** All strokes render at uniform width regardless of pressure. The
  `thinning` parameter becomes dead code. Stylus input loses its primary expressive
  dimension.
- **Detection signal:** Per-point `pressures` vector on freehand shapes; sin-eased
  width calculation in the render pipeline.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| gesture-disambiguation | Device type affects which gesture interpretation is correct |
| interactive-spatial-editing | Device capabilities constrain available interaction modes |
| **userinterface-wiki** | `prefetch-touch-fallback` (no cursor = no trajectory prediction), `prefetch-hit-slop` (larger activation zones for coarse pointers), `ux-fitts-hit-area` (expand targets for touch), `none-high-frequency` (suppress animation on high-frequency tablet input) |
