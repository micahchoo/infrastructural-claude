# How Mapping Teams Manage Annotation Mutation State

Extended case studies from Felt, Figma, Excalidraw, tldraw, OSM editors, and others.
The reference files cover actionable patterns — read this for the team-specific
architectural decisions and the reasoning behind them.

---

## Real-time collaboration: why production tools reject CRDTs

Felt's CTO Can Duruk (2023 Browsertech Digest): "We're not using something like Yjs,
we're not using any of the CRDT or OT structures. We're just structuring the data as
deeply as possible, so that merge conflicts don't happen often." Follows "the Figma model"
— server-authoritative WebSocket on Elixir/Phoenix.

Key insight: concurrent edits to the same map element are vanishingly rare. The real
value of collaboration is establishing a single shared version.

### Geometry-aware CRDTs (academic frontier)

2025 ISPRS paper proposed Geometric Vector Clocks (GVCs) — extensions of vector clocks
incorporating spatial semantics and topological anomaly detection. Standard CRDTs applied
to vertex sequences produce geometrically invalid results (self-intersecting polygons,
broken topology). FOSS4G Europe 2025: CRDT-based co-editing of polygons with 100K-300K
vertices by 60 concurrent users is feasible, but GUI-CRDT integration is the bottleneck.

---

## Two schools of undo/redo: iD vs JOSM

### iD editor (immutable persistent data structures)

Entities (osmNode, osmWay, osmRelation) are immutable. Any edit produces new copy.
`coreGraph` = immutable map from entity IDs to entities. Adding/replacing/removing
produces new graph with structural sharing. `coreHistory` = stack of graph snapshots.
UI pipeline: Modes → Operations → Actions → new Graph → History stack.
At save time: diff between first and current graph → OsmChange document.

### JOSM (command pattern)

`Command` abstract base class: `executeCommand()`, `undoCommand()`. Before executing,
clones state of all affected primitives into `cloneMap`. Undo restores from map.
Concrete commands: `AddCommand`, `DeleteCommand`, `MoveCommand`,
`ChangePropertyCommand`, `SequenceCommand` (compound).

### Tom MacWright's evolution (2015-2021)

1. Immutable.js snapshots (Mapbox Studio, iD)
2. Hand-crafted immutability with ES6 spread
3. Immer for ergonomic mutable-looking code
4. JSON Patch (RFC 6902) for persistable diffs
5. OT/CRDTs as natural endpoint — same infrastructure for collaboration and undo/redo

Key observation: snapshots are trivially simple but cannot persist history or support
collaboration. Operations are complex but unlock both.

---

## Mode-based state machines

### Mapbox GL Draw hot/cold source pattern

`mapbox-gl-draw-hot` (frequently updated) vs `mapbox-gl-draw-cold` (rarely updated).
Features migrate based on interaction state. GitHub issue #994 proposes replacing with
Feature State API. Rich ecosystem of custom modes: freehand, rotation, circle, cut/split.

### nebula.gl (Uber/Vis.gl)

React-native "lift state up" pattern. App owns GeoJSON FeatureCollection, passes as
props, receives edit callbacks. Selection by feature index, not ID.

**Pitfall**: Passing new array instance for `selectedFeatureIndexes` clears in-progress
drawings. Requires careful reference stability.

---

## OSM's optimistic locking

API v0.6: per-element version numbers (CVS-like, not Git-like). Client must supply
current version to update; mismatch = HTTP 409. Changesets are NOT atomic — individual
changes can be independently rejected. No server-side merge or delta updating.

iD editor's optimistic save: attempt "fast save" first, enter conflict resolution only
on 409 (GitHub issue #3056 — optimization over pre-fetching all server versions).

### GeoGig (LocationTech)

Git's model for spatial data. Content-addressable storage, structural sharing, branching,
merging with feature-level conflict detection, push/pull to remotes. Event sourcing /
version control taken to logical conclusion for geospatial data.

### Proposed OSM API v0.7

Delta updating of element properties (e.g., append node to way without transmitting all
nodes). Relaxed locking (version match only for modified portion). Would bring OSM closer
to Figma/Felt's fine-grained property-level conflict resolution.
