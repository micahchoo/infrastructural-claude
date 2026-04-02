# Snapping & Alignment

## The Problem

Without snapping, users manually align annotations by eye — producing visually inconsistent layouts where shapes are "almost" aligned but off by 1-3 pixels. This is especially painful in collaborative contexts where multiple users place annotations independently, resulting in a canvas that looks sloppy despite careful individual effort. Users waste time zooming in to pixel level, nudging with arrow keys, and still producing imperfect alignment.

The engineering challenge is that snapping must run at 60fps during drag operations, comparing the dragged object against all potential snap targets. Naive O(n) implementations become frame-budget killers past a few hundred annotations. Worse, snapping interacts with nearly every other system: undo (snapped position is what gets committed), collaboration (snap targets include remote users' shapes), and multi-selection (group bounding box vs individual shapes). A snap system that doesn't account for these interactions produces flickering guides, incorrect undo states, or snapping to stale positions from concurrent edits.

## Competing Patterns

## Snap geometry model

Convergent pattern (tldraw, Excalidraw, Figma, WeaveJS, OpenLayers): **three snap points
per axis** from each annotation's bounding box — start (left/top edge), center, end
(right/bottom edge). Each stores offset from annotation's absolute position for container
nesting. tldraw: `ShapeUtil.getBoundsSnapGeometry()` + `getHandleSnapGeometry()`.

## Snap types

**Edge alignment (most common):** Compare dragged annotation's snap points against guide
stops from siblings (3 points/axis each) and container edges. If distance < threshold
(~5px screen), apply position correction.

**Distance/spacing:** Snap to create equal gaps between 3+ aligned annotations. Find
overlapping annotations on movement axis, sort by position, if gap matches existing peer
gap → snap to equidistant position. Figma "smart guides" effect.

**Grid:** Snap to nearest grid intersection. Usually toggled by preference. Often mutually
exclusive with object snapping (Excalidraw offers one or other).

**Handle/vertex:** Snap vertices to geometry on nearby annotations during editing. tldraw
`HandleSnapGeometry` supports points, segments, custom geometry. OpenLayers `ol/interaction/Snap`.

**Rotation:** Constrain to 15°/45° increments (Shift key). Fine: snap to nearby shape
rotation. Just `Math.round(angle / increment) * increment`.

## Hysteresis

Without it, annotation near threshold boundary oscillates (snap/unsnap flicker).
Fix: different enter/exit thresholds (5px enter, 7px exit). Once snapped, must move 7px
away to unsnap. WeaveJS tracks per-axis independently.

## Self-snap filtering

Exclude dragged shape's own points from snap candidates. For multi-shape drag, exclude
all selected shapes from candidate pool.

## Performance: candidate culling

Smart alignment is O(n) per drag event at 60fps. Pipeline (apply in order):
1. Viewport filter: skip non-visible shapes
2. Proximity filter: expand dragged bbox by snap radius; skip outside
3. Candidate cap: hard limit 200 (Inkscape, drafft-ink)
4. Spatial index: rbush range query → O(log n + k)

Budget: <2ms per drag event. Profile early.

## Multi-shape drag

Snap the group's bounding box, not individual shapes. Apply offset equally to all,
preserving relative positions. Use tighter snap radius (drafft-ink: 400 vs 800 for single).

## Snap priority

When multiple types fire simultaneously:
1. Nearest wins per axis (smallest distance)
2. Type priority if tied: point-to-point > alignment > spacing > grid
3. Never combine two snaps on same axis (contradictory position)

## Undo interaction

Snapping is display-time constraint, not state mutation. Snapped position is what gets
committed to store/undo. Undo restores snapped position (matches user intent).

## Collaboration interaction

Snap candidates include shapes from other users. Stale candidates possible if collaborator
moves shape between drag start and drop — recompute snap on drop using latest state.
CRDT/LWW resolves final position; snapping needs no own conflict resolution.

## Integration with drag pipeline

1. Drag start: collect guide stops from non-dragged siblings
2. Drag move (~16ms): compute snaps, apply correction, render guide lines on overlay
3. Drag end: clear guides, finalize position
4. Transform (resize/rotate): same but with anchor-specific snap points

## Persistent user-placed guides

Design editors (Figma, Penpot, Sketch) support ruler guides — user-dragged persistent
lines distinct from dynamic snap guides. Store at page level with axis, position, optional
frame association. Frame-relative: guide moves with frame (delta vector). Highest snap
priority (guides > objects > grid). Primarily for canvas editors, not map/timeline.

## Decision guide

| Context | Snap types |
|---------|-----------|
| Whiteboard/canvas | Edge + distance + grid |
| Map annotations | Grid + optional vertex snap |
| Image annotations | Edge alignment |
| Timeline annotations | Grid to time markers |
| <100 annotations | No perf concern |
| 1000+ | Spatial-index stops or viewport limit |

## Anti-Patterns

- **Snapping to the dragged shape's own geometry.** Produces snap-to-self where the shape locks to its original position. Always exclude dragged shapes (and all selected shapes in multi-drag) from the candidate pool.
- **No hysteresis on snap threshold.** Using the same pixel distance for enter and exit causes visible flicker as the shape oscillates between snapped and unsnapped states near the threshold boundary. Use asymmetric thresholds (e.g., 5px enter, 7px exit).
- **Combining two snaps on the same axis.** If both an alignment snap and a spacing snap fire on the X axis, they produce contradictory positions. Only the nearest snap per axis should apply.
- **O(n) candidate scanning at 60fps past a few hundred shapes.** Apply the culling pipeline (viewport filter, proximity filter, candidate cap, spatial index) before snap calculation. Budget: <2ms per drag event.
- **Snapping individual shapes during multi-selection drag.** Snap the group's bounding box, not each shape independently. Otherwise shapes within the selection shift relative to each other.
- **Storing snap offsets as state.** Snapping is a display-time constraint, not a state mutation. The snapped position is what gets committed; there's no "snap offset" to persist or undo.
