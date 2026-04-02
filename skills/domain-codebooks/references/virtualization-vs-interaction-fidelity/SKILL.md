---
name: virtualization-vs-interaction-fidelity
description: >-
  Virtual scroll/viewport culling vs full interaction fidelity (selection,
  keyboard nav, drag targets, search highlighting). DOM recycling breaks focus.
  Tile loading creates responsiveness gaps. Progressive resolution trades
  quality for speed.

  Triggers: "virtual scroll selection", "viewport culling breaks keyboard nav",
  "tile loading performance", "progressive image loading", "windowed list
  interaction", "recycled DOM focus", "deep zoom viewer", "canvas culling vs
  selection", "large list performance with selection", "R-tree spatial index
  for render vs interaction", "marker clustering at zoom levels", "sticky
  headers in virtual list", "tree view virtualization with expand collapse",
  "shift-click multi-select across virtual boundaries".

  Brownfield triggers: "keyboard nav skips items in virtual list", "selection
  state lost when scrolling", "search highlighting doesn't work on offscreen
  items", "drag target disappears on scroll", "focus jumps when list recycles",
  "tile pop-in during zoom", "selected shape disappears at certain zoom levels",
  "Tab cycles through shapes but skips culled ones", "Ctrl+F can't find items
  not in the DOM", "tiles show gaps during fast panning", "recycled DOM nodes
  flash old content before updating", "select-all-in-region misses offscreen
  shapes", "tree view with 100k nodes freezes on expand", "photo timeline
  sticky dates disappear during scroll".

  Symptom triggers: "Tab to cycle through shapes skips culled off-screen ones",
  "Ctrl+F browser search can't find items not in the DOM in virtual list",
  "low-res placeholder tiles replaced with full-res during pan",
  "drag-and-drop targets for off-screen virtualized elements don't exist",
  "select all in region needs to include shapes not currently rendered",
  "recycled DOM nodes flash old content and focus state gets lost",
  "shapes too small to interact with individually need zoom-dependent clustering",
  "expanding tree node with 5000 children causes scroll position jump",
  "rubber-band selection needs spatial overlap check against all shapes
  including culled ones", "minimap sync with virtualized main canvas is expensive",
  "R-tree spatial index query for interaction vs render purposes".
---

# Virtualization vs Interaction Fidelity

The tension between rendering performance (only render what's visible) and
interaction completeness (selection, keyboard, drag, search must work across
ALL items, not just visible ones). Produces spaghetti when virtualization
assumptions conflict with interaction requirements — two systems fighting over
DOM ownership.

Evidence: 6/18 repos STRONG + 6 MODERATE. Third most universal UX cluster.

## Evidence repos
- **penpot** — Active SVG-to-WASM renderer transition, async worker hit-test via vbox
- **krita** — Multi-tier projection (KisPrescaledProjection + LOD with 3 degradation states)
- **openseadragon** — Recursive quad-coverage, dual coverage tracking (drawn vs loading)
- **ente** — Progressive decrypt→thumbnail→original pipeline with blob caching
- **memories** — virtualSticky flag overrides recycling for day headers, dual-scroll sync
- **Immich** — Bucket-based custom virtualizer, shift-range selection across all buckets

## Classify

1. **Virtualization type** — list windowing, canvas culling, tile loading, or LOD?
2. **Interaction requirements** — selection, keyboard nav, drag, search, focus?
3. **Data size** — hundreds, thousands, or millions of items?
4. **Progressive loading** — thumbnail→full, low-res→high-res, placeholder→content?
5. **Framework** — using library (react-virtuoso, TanStack Virtual) or custom?

## Patterns

### Selection-Aware Windowing (Immich pattern)
Virtualize rendering but maintain full selection state across all items (including
offscreen). Shift-range selection traverses all buckets, not just rendered ones.

**Tradeoff**: Selection state memory for entire dataset, but interaction is complete.

### Culling with Exemptions (tldraw pattern)
Cull shapes outside viewport EXCEPT selected shapes. Selected shapes always render
regardless of viewport position.

**Tradeoff**: Simple but exemption list grows with selection size.

### Multi-Tier Progressive Loading (krita/ente pattern)
Multiple resolution tiers: placeholder → low-res → full-res. Each tier has different
interaction capabilities. LOD system with explicit degradation states.

**Tradeoff**: Complex tier management but smooth user experience.

### Sticky Headers in Virtual Lists (memories pattern)
Override virtualization for structural elements (day headers, section dividers) that
must remain visible during scroll for spatial context.

**Tradeoff**: Breaks pure virtualization but preserves navigation context.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| gesture-disambiguation | Hit-testing across viewport boundaries during gesture |
| focus-management-across-boundaries | Keyboard nav across virtual items not in DOM |
| hierarchical-resource-composition | Virtual rendering of tree structures (layers, groups) |
| optimistic-ui-vs-data-consistency | Virtual items may be stale during optimistic mutation |
| **userinterface-wiki** | `container-two-div-pattern` + `container-use-resize-observer` (measurement patterns for recycled DOM), `mode-pop-layout-for-lists` (popLayout for animated list reordering), `container-overflow-hidden` (overflow hidden during layout transitions) |

## References

Load as needed:
- `get_docs("domain-codebooks", "virtualization list windowing patterns")` — bucket-based windowing, fixed-size windowed, infinite scroll, sticky headers, scroll compensation, selection across virtual boundaries
- `get_docs("domain-codebooks", "virtualization canvas culling patterns")` — R-tree culling with exemptions, async worker hit-testing, multi-tier LOD projection, recursive quad-coverage, spatial index patterns
- `get_docs("domain-codebooks", "virtualization progressive loading")` — decrypt pipelines, tile pyramids with dual coverage tracking, LOD degradation states, placeholder heights, buffer ratio hysteresis
