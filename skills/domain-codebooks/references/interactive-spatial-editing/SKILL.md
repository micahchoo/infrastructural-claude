---
name: interactive-spatial-editing
description: >-
  Architectural advisor for interactive editing on spatial/visual media — canvas
  editors, map editors, CAD tools, image annotators, whiteboard tools. The force
  tension: discoverability vs power-user speed vs state complexity when users
  manipulate objects in 2D/3D space through mode-based tools.

  NOT text editors, form builders, spreadsheets, terminal UIs, or non-spatial
  state management. NOT rendering engines or game engines (those are the
  substrate, not the editing interaction layer).

  Triggers: drawing tool state machines, mode switching (draw/select/edit/pan),
  spatial hit-testing, two-phase hit-test (broad + narrow), selection models
  (ID-set, renderer-owned, crossfilter), handle systems (resize/rotate/control
  points), spatial indexing (rbush/flatbush), viewport culling, zoom-aware
  rendering, snapping and alignment constraints, z-index layer stacking,
  freehand input processing, touch/multi-pointer disambiguation, lasso
  selection, group/ungroup transforms, frame/artboard containment.

  Brownfield triggers: "adding a new tool type breaks the state machine",
  "selection breaks when I add grouped shapes", "hit-testing is wrong after
  refactoring the renderer", "snapping no longer works after zoom changes",
  "existing handle system doesn't support rotation", "drag pipeline drops
  events after adding touch support", "spatial index gets stale after bulk
  mutations", "adding a new element type doesn't integrate with selection",
  "viewport culling misses elements after coordinate system change",
  "tool state machine is spaghetti adding a tool touches 6 files",
  "hit-testing iterates all shapes on every mouse move visibly laggy",
  "selection uses object references breaks after undo replaces objects",
  "snap threshold feels inconsistent across zoom levels",
  "nested groups broke selection handles clicking inside selects wrong thing",
  "DOM shapes sluggish at 200 elements switching to Canvas 2D rendering".

  Symptom triggers: "vector editor has 12 drawing tools and the tool state machine is
  becoming spaghetti adding a new polygon tool required changes in 6 files",
  "hit-testing iterates through all 5000 shapes on every mouse move visibly laggy
  need spatial indexing but shapes move frequently during drag",
  "selection model uses direct object references after implementing undo selection
  breaks because undo replaces the shape object invalidating the reference",
  "snapping guides shapes snap to other shapes edges during drag at different zoom
  levels snap threshold feels inconsistent calculated in document coordinates
  zoom-aware snapping with screen-pixel thresholds",
  "nested groups broke selection handles select a group resize handles appear
  clicking inside group should enter group and select individual shapes",
  "whiteboard uses DOM elements for shapes 200 plus shapes pan zoom sluggish
  switch to Canvas 2D rendering keep existing interaction model hit-testing
  without DOM events",
  "how do canvas editors structure their tool state machines to be extensible
  without coupling",
  "how do canvas editors handle dynamic spatial indexing with frequent updates",
  "how should selection be stored to survive undo and sync operations".

  Diffused triggers: "canvas drawing tool architecture", "shape tool mode
  switching", "map feature selection model", "infinite canvas state management",
  "spatial editor tool palette state", "how does tldraw handle hit-testing",
  "vector editor state machine", "snapping feels wrong", "selection handles
  don't follow zoom", "drag pipeline architecture", "the tool state machine is
  spaghetti", "adding a new shape type breaks everything", "our selection model
  can't handle nested groups", "hit-testing is slow with thousands of elements",
  "the handle system is getting unmaintainable".

  Libraries: tldraw, Excalidraw, Konva, Fabric.js, Paper.js, PixiJS, Three.js,
  MapLibre/Mapbox GL Draw, Terra Draw, OpenLayers, Leaflet.draw, rbush,
  flatbush, @xyflow/react.

  Production examples: tldraw, Excalidraw, Figma, Penpot, Felt, Krita,
  Inkscape, iD editor, QGIS.

  Skip: text cursor/caret management, spreadsheet cell selection, terminal UI
  focus management, audio waveform editing without spatial annotation,
  3D game character control, pure rendering optimization without editing
  interaction.
---

# Interactive Spatial Editing

**Force tension:** Discoverability vs power-user speed vs state complexity
when users manipulate objects in 2D/3D space through mode-based tools.

This force cluster covers the editing interaction layer on spatial media. It's
where mode state machines, selection models, hit-testing, and spatial constraints
interact to create (or prevent) spaghetti.

## Step 1: Classify the editing problem

1. **Media type**: Vector canvas, raster image, geographic map, 3D scene, timeline?
2. **Tool complexity**: Simple (select/draw/delete) or full palette (20+ tools)?
3. **Selection model**: Single-select, multi-select, crossfilter, or nested groups?
4. **Rendering substrate**: DOM/SVG, Canvas 2D, WebGL, or hybrid?
5. **Object count**: Dozens (whiteboard), thousands (map features), millions (point clouds)?
6. **Precision requirements**: Pixel-perfect (vector), approximate (whiteboard), geographic (map)?

## Step 2: Load reference

| Axis | File |
|------|------|
| Interaction modes / drawing FSM / touch / freehand / a11y / preview mode | `get_docs("domain-codebooks", "interactive-spatial-editing interaction modes")` |
| Selection / hit-testing / handles / grouping / crossfilter | `get_docs("domain-codebooks", "interactive-spatial-editing selection hit-testing")` |
| Rendering / spatial indexing / layer stacking / culling | `get_docs("domain-codebooks", "interactive-spatial-editing rendering spatial-index")` |
| Snapping & alignment / constraints / guides | `get_docs("domain-codebooks", "interactive-spatial-editing snapping alignment")` |

## Step 3: Advise and scaffold

Present 2-3 competing patterns with tradeoffs. Match existing framework conventions.

### Cross-References (force interactions)

- When spatial state needs real-time sync → see **distributed-state-sync**
- When spatial editing needs undo/redo → see **undo-under-distributed-state**
- When building annotation tools specifically → see **annotation-state-advisor** (composite recipe)
- When pointer/touch/pen inputs need intent classification before the tool state machine sees them → see **gesture-disambiguation**
- When the same editing interaction must adapt across mouse, touch, stylus, and trackpad with different affordances → see **input-device-adaptation**

## Principles

1. **Mode state machines are universal.** Lifecycle: onSetup -> onClick -> onDrag -> onStop -> toDisplayFeatures (Mapbox GL Draw / Terra Draw pattern).
2. **Spatial indexing is the #1 performance lever.** rbush dynamic, flatbush static, two-phase hit-testing always.
3. **Preview before commit.** Ephemeral modifier layer for transforms; commit on mouse-up.
4. **Two-tier data model.** Portable tier (annotation content) vs workspace tier (viewport, selection, tool, filters). Governs persistence scope, undo scope, collaboration sync.
5. **Store selection by ID, not by object reference.** Object references break on undo, paste, and sync.
