# Twelve Architectural Patterns: Extended Details

Production details and edge cases beyond what the reference files cover.
Read these sections when you need deeper context on a specific pattern.

---

## Presence state: implementation details

### Figma presence

Cursor updates throttled on sending side, interpolated on receiving side via rAF.
Custom styling: name label, assigned color, shadows. "Cursor chat" (press `/`) attaches
ephemeral text. "Spotlight" draws attention. Click avatar → follow viewport.

### tldraw presence

`TLInstancePresence` records: cursor (x, y, type, rotation), chat message, activity
timestamp, current page, user identity, selection state, viewport bounds. `perfect-cursors`
library handles interpolation. 12-color palette. Follow-mode for guided editing.

### Yjs awareness protocol

Defined in `y-protocols`, NOT core `yjs` — explicitly not part of document CRDT.
Each client maintains local awareness state (arbitrary JSON) with increasing clock.
Receivers overwrite only if received clock is newer. 30-second timeout → offline.
Exchanges complete state per client (no state vectors needed — payloads are small).

### Liveblocks presence API

`useMyPresence()` returns `[presence, updateMyPresence]`. `useOthers()` returns array.
Default throttle 100ms (10 updates/sec), configurable to 16ms (60fps). Resets on
every disconnect.

---

## Schema migration details

### tldraw's SDK extension model

SDK users add parallel migration sequences for custom shapes:

```typescript
const migrations = createShapePropsMigrationSequence({
  sequenceId: 'com.tldraw.shape.myshape',
  sequence: [{
    id: versions.AddColor,
    up(props) { props.color = 'black' },
    down(props) { delete props.color },
  }],
})
```

Dependency graph orders migrations. Every snapshot embeds `schema` with versions per
sequence. On load, store compares versions and applies missing migrations.

### OSM tagging evolution

100,000+ unique tag combinations, no formal schema. Deprecated tags persist in legacy
data with no migration. `id-tagging-schema` codifies common tags into presets for
editors like iD and StreetComplete.

### Cambria paper

Safe schema migrations for CRDT apps — explored but not production-ready.

---

## Tombstone specifics

### Yjs three strategies (Kevin Jahns)

1. **Struct merging**: Sequential inserts from same user → single struct
2. **Content deletion**: `doc.gc = true` (default) → deleted items lose content, keep
   lightweight GC objects
3. **Orphan GC**: Parent deleted → children safely become GC objects

"Tombstone garbage collection is not even necessary for CRDTs to work in practice."
But disabling GC for version history (`doc.gc = false`) is "pretty awful for performance,
disk space, and network throughput."

### Automerge 2.0/3.0

Retains full document history by design. Binary columnar format: <1 additional byte per
character. 3.0: 10x+ memory reduction — Moby Dick doc: 700MB → 1.3MB in memory, load
time: 17 hours → 9 seconds. Storage layer: clever concurrency-safe compaction where each
process tracks own "live keyset" and only deletes keys it loaded.

### tldraw ephemeral shapes

Issue #7869: separating "ephemeral shapes" from document shapes avoids polluting the
shape system with non-document concerns (presence indicators, temporary guides).

---

## Reactive derived state: Signia details

### tldraw's `@tldraw/state` (Signia)

Global logical clock — single integer incremented on any root state change. Comparing
clock values enables "always-on caching" regardless of whether computed values are
being observed. Solved tldraw's problem: computed values used only during pointer-move
were discarded and recomputed every frame in other frameworks.

Key innovation: **incremental derivations with diffs**. Signals emit change descriptions
alongside current values, enabling list filtering to apply predicates only to new/updated
items. Transactions (`transact()`) batch updates and trigger reactions once; errors roll
back all updates.

### Figma's parameter runtime

C++/WASM document representation with custom reactive system. Variable changes trigger
invalidation → resolution → re-rendering via usage tracking. Hot paths use time-slicing
to avoid frame drops.

### Mapbox GL JS label placement

Most computationally sophisticated derived-state system in mapping. Collision detection
runs synchronously every frame using global viewport approach. For line labels: collision
circles (not rectangles) approximate curved text path. Variable anchor placement
(`text-variable-anchor`) tries multiple positions. `CrossTileSymbolIndex` tracks symbols
across tile boundaries.

---

## Batching specifics

### perfect-freehand

Used by tldraw, Canva, draw.io, Excalidraw. Avoids Douglas-Peucker/RDP during drawing
("curves will noticeably jump around"). `streamline` parameter (0-1) lerps between
previous and current points, recalculating entire stroke every frame. Post-hoc
simplification only after drawing completes.

### Excalidraw sync optimization

30ms debounce on sync reduced bandwidth from lag-inducing levels (8-15 second delays
during rotations) to imperceptible. `onChange` callback fires on every minimal change;
implementations should cache `getSceneVersion()` and only persist when it increments.
Recommend 500ms debounce on save.

---

## Validation tools

### turf.js

`@turf/kinks` — detect self-intersections. `@turf/unkink-polygon` — decompose
self-intersecting into simple polygons. `buffer(0)` trick repairs invalid topology.

### JSTS (JavaScript Topology Suite)

Full port of Java JTS. `isValid()` per OGC Simple Features: shells CCW, holes CW,
no self-intersections, MultiPolygon elements touch only at finite points.

### Snapping implementations

Mapbox GL Draw snap plugins: 15px default, vertex-over-midpoint priority,
`nearestPointOnLine` for edge snapping. Alt/Option disables.

tldraw SnapManager: `BoundsSnaps` (align edges/centers during translate/resize) and
`HandleSnaps` (snap handles to geometry points). Custom shapes define targets via
`ShapeUtil.getHandleSnapGeometry()`.

### iD editor validators

`modules/validations/`: crossing ways, almost-junctions, disconnected routing islands,
close nodes, non-square buildings, outdated tags, missing essential tags. Runs instantly
while editing. Errors block changeset upload; warnings advisory. Quick-fix buttons for
common issues.
