# Pressure/Tilt Pipeline and Tablet API Abstraction

## The Problem

Raw tablet sensor data (pressure 0.0-1.0, x/y tilt in degrees, barrel rotation, tangential pressure, cursor speed) arrives from heterogeneous hardware — Wacom tablets, Apple Pencil, Samsung S Pen, Surface Pen — each with different value ranges, sampling rates, and supported axes. Without a dedicated pipeline, pressure feels "wrong" (linear mapping feels unresponsive at low pressure and saturates too quickly), tilt-dependent brush effects break across devices, and mouse input lacks sensible defaults for pressure-dependent tools.

Symptoms: pressure curve feels linear and unnatural, tilt angle not mapped for calligraphy brushes, mouse strokes render at zero width in pressure-dependent tools, per-device calibration impossible, brush response inconsistent across tablets from different vendors.

## Competing Patterns

### Pattern A: Configurable Curve-Based Pressure Mapping

**When to use:** Drawing/painting applications where pressure is a primary expressive dimension and users expect subjective tuning of pressure response.

**When NOT to use:** Applications that only use pressure as a binary signal (pressed/not-pressed) or don't support pen input.

**How it works:** Raw pressure values pass through a user-configurable transfer curve before reaching the rendering pipeline. The curve is sampled into a lookup table at initialization for O(1) interpolation at stroke time. The curve shape is persisted in user preferences and can be edited via a curve widget.

**Production example:** Krita `KisPaintingInformationBuilder` (`libs/ui/tool/kis_painting_information_builder.cpp`) samples a `KisCubicCurve` from user preferences into `m_pressureSamples` at `LEVEL_OF_PRESSURE_RESOLUTION = 1024` discrete points. The `pressureToCurve()` method performs linear interpolation:

```cpp
// kis_painting_information_builder.cpp
const int KisPaintingInformationBuilder::LEVEL_OF_PRESSURE_RESOLUTION = 1024;

void KisPaintingInformationBuilder::updateSettings()
{
    KisConfig cfg(true);
    const KisCubicCurve curve(cfg.pressureTabletCurve());
    m_pressureSamples = curve.floatTransfer(LEVEL_OF_PRESSURE_RESOLUTION + 1);
}

qreal KisPaintingInformationBuilder::pressureToCurve(qreal pressure)
{
    return KisCubicCurve::interpolateLinear(pressure, m_pressureSamples);
}
```

The mapped pressure feeds into `KisPaintInformation`, which bundles pressure with tilt, rotation, tangential pressure, perspective, speed, and canvas orientation — a complete sensor data object passed to every paint operation.

**Tradeoffs:** Requires a curve editor UI. The 1024-sample table trades memory (4KB) for zero-cost interpolation. Users may misconfigure curves and blame the application. Curve presets per device type add configuration surface area.

### Pattern B: Per-Point Pressure Storage with Render-Time Mapping

**When to use:** Applications that need to replay, export, or re-render strokes with different pressure mappings after the fact. Lighter-weight than Pattern A.

**When NOT to use:** Applications where strokes are rasterized immediately and never re-rendered. Storage-constrained environments where per-point overhead matters.

**How it works:** Store raw (or minimally processed) pressure values per sample point on the stroke data structure. Apply the visual mapping (pressure-to-width, pressure-to-opacity) at render time, not at input time. This separates data capture from visual interpretation.

**Production example:** drafft-ink stores per-sample pressure in the shape model: `Freehand { pressures: Vec<f64> }` (`crates/drafftink-core/src/shapes/mod.rs`). The render pipeline in `vello_impl.rs` applies sin-eased width mapping at draw time:

```rust
// crates/drafftink-render/src/vello_impl.rs
width = base_size * (1.0 - thinning * (1.0 - (pressure * PI / 2.0).sin()))
```

Mouse input defaults to pressure 1.0 so all tools produce visible output regardless of input device. Left/right contour generation uses the computed width to produce variable-width Bezier paths.

**Tradeoffs:** Storage cost scales with stroke complexity (one f64 per sample point). Changing the mapping function re-renders all visible strokes. The sin-easing is a specific artistic choice — different applications need different curves. Export must preserve the raw pressure data or bake in a specific mapping.

### Pattern C: Multi-Axis Sensor Data Object

**When to use:** Professional painting/illustration applications that use tilt, rotation, and tangential pressure for brush dynamics beyond simple width variation.

**When NOT to use:** Applications that only use pressure for width. Web applications targeting PointerEvent (which exposes limited axes).

**How it works:** Bundle all sensor axes into a single data object created at event processing time. This object flows through the entire paint pipeline — smoothing, Bezier fitting, brush engine — without requiring each stage to know which axes exist. The constructor handles device-specific normalization (e.g., tilt direction offset, canvas rotation/mirror correction).

**Production example:** Krita `KisPaintInformation` aggregates 10+ sensor axes in its constructor (`libs/ui/tool/kis_painting_information_builder.cpp`):

```cpp
KisPaintInformation pi(
    imagePoint,
    !m_pressureDisabled ? 1.0 : pressureToCurve(event->pressure()),
    event->xTilt(), event->yTilt(),
    event->rotation(),
    event->tangentialPressure(),
    perspective,
    timeElapsed,
    qMin(1.0, speed / qreal(m_maxAllowedSpeedValue))
);
pi.setCanvasRotation(canvasRotation());
pi.setCanvasMirroredH(canvasMirroredX());
pi.setCanvasMirroredV(canvasMirroredY());
pi.setTiltDirectionOffset(m_tiltDirectionOffset);
```

Key design choices:
- **Pressure disabled flag**: When `m_pressureDisabled` is true, all pressure reads return 1.0 (mouse fallback)
- **Tilt direction offset**: User-configurable in [-180, 180] degrees, compensating for physical tablet orientation
- **Speed normalization**: Raw speed clamped to `m_maxAllowedSpeedValue` (default 30), normalized to [0, 1]
- **Canvas transform compensation**: Canvas rotation and mirror state stored per-point so brush engines can compensate for view transforms

Krita also provides `createHoveringModeInfo()` for hover events that still carry tilt/rotation data (used for brush outline preview).

**Tradeoffs:** Object size grows with axis count. Not all paint engines use all axes — unused data is carried through the pipeline. Adding a new axis requires touching the data object, its constructors, and serialization. The `KisSpeedSmoother` used for speed calculation adds latency.

## Decision Guide

- "Need user-tunable pressure response?" -> Pattern A (curve-based mapping). Pre-sample the curve for O(1) lookup.
- "Need to re-render or export strokes with different pressure mappings?" -> Pattern B (per-point storage with render-time mapping). Store raw values, map late.
- "Need tilt, rotation, tangential pressure, or speed dynamics?" -> Pattern C (multi-axis sensor object). Bundle axes early, flow through pipeline.
- "Drawing app with full tablet support?" -> Combine A + C: curve-mapped pressure feeds into multi-axis data object.
- "Lightweight sketching app?" -> Pattern B alone may suffice, with a fixed sin/ease curve.

## Anti-Patterns

### Don't: Map Pressure at Input Time and Discard Raw Values
**What happens:** Once the curve is baked into the stroke data, changing the pressure curve requires re-drawing everything. Export to formats that support pressure (SVG, PSD) loses the original sensor data.
**Instead:** Store raw pressure per-point (Pattern B) and apply mapping at render time, or store both raw and mapped values.

### Don't: Assume All Devices Report All Axes
**What happens:** Code that reads `event.tiltX` without checking device capability gets 0 for mice and some basic tablets. Brush effects that depend on tilt produce flat/incorrect output.
**Instead:** Provide sensible defaults per axis (pressure=1.0 for mouse, tilt=0, rotation=0) and gate advanced features on axis availability. Krita's `m_pressureDisabled` flag is this pattern.

### Don't: Apply a Linear Pressure Curve
**What happens:** Human perception of pressure is non-linear. A linear mapping feels sluggish at low pressure (where fine control matters) and saturates too quickly at high pressure. Users describe this as "pressure doesn't work" or "feels dead."
**Instead:** Use at minimum a sin/ease curve (like drafft-ink's `(pressure * PI / 2.0).sin()`) or a user-configurable curve (like Krita's cubic curve). Both are dramatically better than linear.
