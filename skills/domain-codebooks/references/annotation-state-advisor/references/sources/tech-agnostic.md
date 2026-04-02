# Tech-Agnostic Patterns: Cross-Cutting Insights

Patterns that transcend framework choice. The reference files in the parent directory
contain actionable guidance per axis — read this for the cross-cutting architectural
insights and convergence patterns across the industry.

---

## Collaboration convergence: CRDT-inspired but server-authoritative

Production systems uniformly reject pure CRDTs for annotation state, reserving complex
merge algorithms only for text editing.

### The Figma model (2019, Evan Wallace)

"Since Figma is centralized, we can simplify our system." Last-writer-wins registers
per property on a document tree modeled as `Map<ObjectID, Map<Property, Value>>`.
Each document gets its own process on the multiplayer service, holds state in memory,
broadcasts at ~30 FPS, checkpoints to storage every 30-60s. DynamoDB-backed write-ahead
log with sequence numbers prevents data loss during crashes.

### Eg-walker (2024-2025)

Figma's Code Layers feature adopted Event Graph Walker — a new algorithm by Joseph Gentle
and Martin Kleppmann combining CRDT merge performance with OT-like memory efficiency.
Represents edits as a directed acyclic causal graph (analogous to git rebase), temporarily
building CRDT structures only during conflict resolution and discarding after. Used only
for text, not for shapes/annotations.

### Excalidraw's version+nonce model

Each element carries `version` and random `versionNonce`. Higher version wins. Tied
versions → lower nonce wins deterministically. Soft-delete via tombstones. Acknowledged
trade-off: "For Excalidraw, we don't really care! We think this will be a pretty rare
situation, and that users will tolerate some jankiness."

### tldraw's TLSync + Durable Objects

Custom protocol with optimistic updates and automatic rollback on conflicts. One
Cloudflare Durable Object per file. Reactive state via Signia signals with global
logical clock. Supports 400,000+ users across 200,000+ shared projects, up to 50
concurrent collaborators per canvas.

### Linear's sync engine

In-memory MobX object graph persisted to IndexedDB. Centralized server provides total
ordering via monotonically incrementing `syncId` values. Each GraphQL mutation returns
`lastSyncId`; WebSocket push delivers `SyncAction` objects. LWW sufficient because
conflicts rare. CRDTs added only recently for rich-text issue descriptions.

Tuomas Artman: "I'm sure I won't ever go back to working any other way."

---

## Collaborative undo/redo: the unsolved hard problem

Martin Kleppmann's PaPoC 2024 paper "Undo and Redo Support for Replicated Registers":
counter-based approach where each operation gets an undo counter (even = visible,
odd = invisible).

Zed's editor: "each participant needs their own undo stack, capable of undoing operations
in arbitrary order."

Figma's invariant (Rasmus Andersson): "If you undo a lot, copy something, and redo back
to the present, the document should not change."

tldraw's `HistoryManager` uses `markHistoryStoppingPoint()` for atomic transaction
boundaries. `@tldraw/state` signals support transactions with rollback — clean undo
that doesn't interact with in-progress drawing.

---

## The local-first architecture

The shared pattern: `Client → Local DB → Instant UI Update ↓ (async) Sync Engine → Server`

First Local-First Conference: Berlin, May 2024. FOSDEM 2026: 22-talk devroom.

Practical benefit isn't ideological — it eliminates loading states, network error handling,
and cache invalidation from application code. Tradeoff: upfront investment in sync
infrastructure.

### Local-first sync engine landscape

- **Electric SQL**: Monitors Postgres via WAL, syncs "shapes" (filtered table subsets)
  over HTTP streams. Current version: read-path only; writes through your API.
- **PowerSync**: Replicates Postgres to in-app SQLite. Full SQL on client. Writes queue
  for upload. LWW default, custom conflict resolution in backend.
- **cr-sqlite**: SQLite extension upgrading tables to CRRs via `crsql_as_crr()`. Each
  column becomes independent CRDT. 2.5x slower inserts, 15% write overhead.
- **Triplit**: Full DB in browser and server, WebSocket sync. Outbox (pending) + cache
  (confirmed). Handles cache eviction on permission changes.

---

## Platform-specific CRUD paradigms

### Google Maps: observer/imperative

`MVCObject` base class with `get()`, `set()`, `bindTo()`. No centralized state store.
Data Layer accepts GeoJSON via `addGeoJson()`, fires events. DrawingManager deprecated
August 2025. Developers must build their own state management.

### Esri: batch command

`FeatureLayer.applyEdits()` takes `{ addFeatures, updateFeatures, deleteFeatures }` —
batch command pattern as transaction. Editor widget uses ViewModel separation. Supports
undo/redo during vertex editing, snapping, feature templates, attribute domains.

### CARTO: SQL mutation

No client-side feature store. CRUD = SQL against PostGIS/BigQuery/Snowflake/Redshift.
Visualization from server-side queries.

---

## Serialization beyond GeoJSON

GeoJSON limitations: no topology, no streaming, no schema, no spatial index, mandatory
WGS84, text parsing overhead. A 2.1GB Texas buildings file can exceed string buffer limits.

- **FlatGeobuf**: Binary, zero-copy deserialization, packed Hilbert R-tree for HTTP Range
  Request spatial filtering. 8x faster reads than Shapefile. Immutable after creation.
- **GeoParquet 2.0** (Feb 2025): Native GEOMETRY/GEOGRAPHY logical types in Parquet spec.
  20+ tools in 6+ languages. Columnar = cheap column-subset reads.
- **PMTiles**: Single-file archive for tiles, Hilbert curve ordering, HTTP Range Requests.
  Serverless tile hosting (S3/R2). Planet OSM ~107GB.
- **MVT**: Protocol Buffers, delta-encoded geometry, dictionary-encoded properties.
- **GeoArrow**: Apache Arrow columnar memory format for geometries. Zero-copy, contiguous
  buffers.

For annotation state specifically: Figma uses Kiwi (custom binary + zlib/Zstandard),
tldraw uses JSON snapshots with embedded schema versions, Excalidraw uses JSON with
per-element versioning (embeds in PNG metadata or SVG comments for roundtripping).

---

## Access control patterns

Per-feature permissions are rare. Most tools enforce at document/room/layer level.

- **ArcGIS**: Ownership-based access control (only creator can update/delete). Geographic
  restrictions via hosted feature layer views.
- **Figma**: Per-file (not per-element). Custom ACP system inspired by IAM policies.
  Evaluated OPA, Zanzibar, Oso before building their own.
- **Liveblocks**: Room-level. `room:write`, `room:read`, `room:presence:write` (follow-along).
- **PostGIS RLS**: Most powerful per-feature pattern. Policies with spatial predicates
  (`ST_Within(geometry, editor_region)`).
- **OSM**: Fully open edit access + community moderation + full history. Changeset model
  provides accountability without restricting access.

---

## Frame scheduling patterns

Three universal optimizations:
1. **Viewport culling**: Render only shapes intersecting visible area (highest impact)
2. **Draw call batching**: Group rendering operations to minimize CPU→GPU overhead
3. **rAF pacing**: `requestAnimationFrame` for display refresh rate

tldraw additions: skip hover hit-testing during panning, render shape indicators via
2D canvas instead of SVG (25x faster).
