---
name: annotation-state-advisor
description: >
  Composite recipe for annotation state on spatial/visual/temporal media (maps, canvases,
  audio/video timelines). Combines force-cluster codebooks (distributed-state-sync,
  interactive-spatial-editing, undo-under-distributed-state, constraint-graph-under-mutation,
  schema-evolution-under-distributed-persistence, embeddability-and-api-surface,
  crdt-structural-integrity, hierarchical-resource-composition) with annotation-specific
  concerns (comment anchoring, type boundaries, templates).

  NOT generic state management, Canvas 2D API, text/document annotation,
  CSS/SVG drawing, Canvas LMS, Photoshop scripting, or chart/data visualization.

  Triggers: "map editor shape state", "canvas drawing tool architecture",
  "whiteboard undo system", "infinite canvas state management", "GeoJSON feature
  editing state", "marker/polygon/polyline editing UX", "collaborative whiteboard
  sync", "image annotation layer architecture", "timeline region editing",
  "pin/comment on map feature", "multiplayer canvas conflict resolution".

  Brownfield triggers: "existing annotation layer has stale rendering after
  mutations", "adding a new annotation type breaks the tool state machine",
  "comment anchoring drifts after editing the underlying geometry", "migrating
  annotation schema breaks existing saved documents", "undo doesn't work for
  the new annotation type I added", "the annotation store is spaghetti after
  multiple feature additions", "refactoring the map layer broke annotation
  hit-testing", "existing spatial index doesn't update when annotations are
  bulk-imported", "adding the 9th annotation type required changing 12 files",
  "video pins anchored to both time and space", "medical imaging annotation
  with offline support and W3C Web Annotation export", "GeoJSON editor works
  single-user but multiplayer conflicts on polygon vertices", "annotations
  flicker or show old state after adding new types", "hit-testing wrong for
  new annotation types but works for old ones".

  Diffused brownfield triggers: "the annotation system is getting unmaintainable",
  "after adding [feature] annotations render wrong", "why do comments detach
  from their anchors after editing", "our annotation persistence broke after
  the schema change", "the annotation layer is too coupled to the rendering
  engine".

  Symptom triggers: "building map annotation tool with Leaflet users draw
  polygons and comment with real-time sync where do I start", "whiteboard
  has 8 annotation types each implemented differently adding 9th requires
  changing 12 files", "video annotation tool pins at timestamps and spatial
  positions with real-time collaboration", "medical imaging annotation DICOM
  integration offline support W3C Web Annotation export", "GeoJSON feature
  editor adding multiplayer causes vertex edit conflicts and undo breaks",
  "after adding new annotation types rendering is stale hit-testing wrong
  and undo broken for new types but old types work fine".

  This is a COMPOSITE — it assembles advice from multiple force-cluster codebooks
  for the specific case of spatial/visual annotation systems. For the underlying
  force clusters in isolation, use the individual codebooks directly.

  Libraries: Terra Draw, MapLibre/Mapbox GL Draw, tldraw, Excalidraw, Annotorious,
  OpenLayers, Leaflet.draw, W3C Web Annotation, IIIF, GeoJSON, Yjs, @xyflow/react.
  Patterns from Felt, Figma, Penpot, Esri, OSM, Ideon.

  Skip: general React/Svelte/Redux state, raw Canvas 2D, SVG/chart libs, text
  editor undo, audio waveform without annotation, non-annotation state problems.
---

# Annotation State Advisor (Composite Recipe)

Assembles patterns from force-cluster codebooks for the specific case of building
annotation/editing systems on spatial, visual, or temporal media.

Production examples: Felt, Figma, tldraw, Excalidraw, Penpot, Mapbox, Esri, OSM editors.

## Step 1: Classify

1. **Media** — spatial (map/GeoJSON), visual (canvas/SVG), or temporal (audio/video)?
2. **Scale** — dozens or tens of thousands of annotations?
3. **Collaboration** — single-user, turn-taking, or real-time concurrent?
4. **Framework** — React, Svelte 5, Vue, vanilla?
5. **Which forces are active?** — identify which force clusters apply to this problem:

| Force | Active when... | Codebook |
|-------|---------------|----------|
| Distributed state sync | Multiple clients, real-time sync, persistence | **distributed-state-sync** |
| Interactive spatial editing | Mode-based tools, selection, hit-testing | **interactive-spatial-editing** |
| Undo under distributed state | Undo/redo on shared or batched state | **undo-under-distributed-state** |
| Constraint graph under mutation | Bindings between annotations (arrows, labels, containment) | **constraint-graph-under-mutation** |
| Schema evolution under distributed persistence | Versioned annotation schemas, cross-version sync | **schema-evolution-under-distributed-persistence** |
| Embeddability and API surface | Annotation editor embedded as library/SDK | **embeddability-and-api-surface** |
| CRDT structural integrity | CRDT-based storage with GC, compaction, snapshots | **crdt-structural-integrity** |
| Hierarchical resource composition | Layers, groups, frames, pages containing annotations | **hierarchical-resource-composition** |
| Gesture disambiguation | Touch/multi-touch annotation drawing, drag-to-pan vs drag-to-draw | **gesture-disambiguation** |
| Virtualization vs interaction fidelity | Large annotation counts with virtual scroll/viewport culling | **virtualization-vs-interaction-fidelity** |
| Focus management across boundaries | Embedded annotation editor negotiating focus with host | **focus-management-across-boundaries** |
| Text editing mode isolation | Text labels/comments within canvas annotations | **text-editing-mode-isolation** |
| Input device adaptation | Pen/touch/mouse annotation drawing with pressure | **input-device-adaptation** |
| Spec conformance | W3C Web Annotation, IIIF, GeoJSON export fidelity | **spec-conformance-under-creative-editing** |
| Optimistic UI vs data consistency | Showing annotation changes before sync confirms | **optimistic-ui-vs-data-consistency** |
| Rendering backend heterogeneity | Canvas/SVG/WebGL annotation rendering with export | **rendering-backend-heterogeneity** |
| State-to-render bridge | CRDT annotation state driving imperative render | **state-to-render-bridge** |

## Step 2: Load references

For each active force cluster from Step 1, query `get_docs("domain-codebooks", "<codebook> <concern>")` with 2-4 keywords. Examples:

| Concern | Query |
|---------|-------|
| Mutation-to-UI sync | `get_docs("domain-codebooks", "distributed-state-sync mutation sync")` |
| Collaboration & conflict | `get_docs("domain-codebooks", "distributed-state-sync collaboration conflict")` |
| Interaction modes / drawing FSM | `get_docs("domain-codebooks", "interactive-spatial-editing interaction modes")` |
| Selection / hit-testing | `get_docs("domain-codebooks", "interactive-spatial-editing selection hit-testing")` |
| Undo/redo / batch transactions | `get_docs("domain-codebooks", "undo-under-distributed-state undo redo")` |
| Binding propagation / constraints | `get_docs("domain-codebooks", "constraint-graph binding propagation")` |
| Schema migration strategies | `get_docs("domain-codebooks", "schema-evolution migration strategies")` |
| CRDT convergence / GC | `get_docs("domain-codebooks", "crdt-structural-integrity convergence gc")` |
| Gesture disambiguation | `get_docs("domain-codebooks", "gesture-disambiguation touch drawing")` |
| Spec conformance export | `get_docs("domain-codebooks", "spec-conformance round-trip fidelity")` |

For annotation-specific concerns, query `get_docs("domain-codebooks", "annotation-state-advisor <concern>")`:

| Concern | Query |
|---------|-------|
| Comment/discussion anchoring | `get_docs("domain-codebooks", "annotation comment anchoring")` |
| Type safety / coordinate bridging | `get_docs("domain-codebooks", "annotation type boundaries")` |
| Templates/symbols | `get_docs("domain-codebooks", "annotation templates symbols")` |
| Performance debugging | `get_docs("domain-codebooks", "annotation performance debugging")` |

Deep-dive case studies: `get_docs("domain-codebooks", "annotation sources developer-interviews")`

## Step 3: Advise and scaffold

Present 2-3 patterns with tradeoffs. On implementation:

- **Read the project first** — match existing conventions.
- **Framework-appropriate scaffolding:**
  - React: hooks + context, useReducer, useImperativeHandle
  - Svelte 5: `$state.raw()` for large collections, `untrack()` for circular deps,
    `$effect` cleanup, `createQuery` top-level only
  - Vue: composables + provide/inject, template refs
  - Vanilla: class stores + EventTarget
- **Type boundaries** — `// TYPE_DEBT:` comments over `any`. Preserve extension data.
- **Content security** — sanitize annotation HTML at render time, not just import.

## Principles

1. **Two-tier data model.** Portable tier (annotation content) vs workspace tier (viewport,
   selection, tool, filters). Governs: persistence scope, export scope, undo scope (portable
   only — Figma/Photoshop/VS Code consensus), collaboration sync, schema stability.

2. **Force clusters interact.** The hardest annotation bugs live at force-cluster intersections:
   undo + collaboration (multiplayer undo scope), selection + sync (selection invalidation on
   remote mutation), rendering + persistence (stale spatial index after schema migration),
   bindings + undo (constraint propagation not participating in undo transactions),
   hierarchy + sync (reparenting conflicts in CRDT), CRDT GC + undo (compacted items
   referenced by undo stack), schema migration + sync (cross-version document corruption).
   When advising, check for cross-cluster interactions.

3. **Spatial indexing is the #1 performance lever.** rbush dynamic, flatbush static,
   two-phase hit-testing always.

4. **Mode state machines are universal.** Lifecycle: onSetup -> onClick -> onDrag -> onStop ->
   toDisplayFeatures (Mapbox GL Draw / Terra Draw pattern).

5. **Schema migration is first-class.** Bidirectional (tldraw style) for multiplayer skew.
