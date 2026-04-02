# Persistence & Schema Migration

## The Problem

Annotation data represents irreplaceable work — field observations, design decisions, review comments anchored to specific spatial or temporal positions. Losing it is not a "sync again" situation; it's gone. Yet the default path in every framework is optimistic: write to IndexedDB and hope the browser doesn't evict it, trust that multi-tab writes won't corrupt each other, assume the schema you deployed last week matches the data format stored on the client three months ago.

The failure modes are specific and painful. Browser disk pressure silently evicts IndexedDB data — Excalidraw learned this the hard way and now dual-writes to localStorage as a fallback. Multiple tabs writing to OPFS concurrently cause silent data corruption — Notion observed this and built an entire SharedWorker architecture to enforce single-writer access. Schema migrations on client-stored data are particularly treacherous: two CRDT-connected clients running different app versions may independently migrate the same document, producing conflicting schemas that neither client can read.

And the problem compounds with collaboration. When a CRDT handles real-time sync but a relational database is the canonical store, you need three persistence tiers (client cache, CRDT WAL, canonical DB) with explicit translation boundaries between them. Miss one tier and you either lose CRDT updates on server restart or can't query annotation data with SQL. The infrastructure cost is real, but the alternative — silent data loss or schema corruption — is worse.

## Competing Patterns

## Client-side storage

### IndexedDB (pragmatic default)

**When to use**: Simple to moderate annotation apps with few concurrent writes and datasets under 100MB.

**When NOT to use**: Complex client queries needing SQL, multi-tab concurrent writes, or datasets exceeding 100MB where IDB performance degrades.

**How it works**: Most annotation tools use IndexedDB. Caveats: browsers can evict under disk pressure
(Excalidraw dual-writes localStorage + IDB for critical data). Safari incognito lacks OPFS.

**Linear's approach:** IDB + MobX in-memory. Full bootstrap on first load, IDB hydration on
subsequent loads, WebSocket delta sync. BroadcastChannel for cross-tab. LWW except rich text.

### SQLite/WASM + OPFS

**When to use**: Complex client-side queries, large datasets, or apps that benefit from relational schema on the client (joins, indexes, aggregations).

**When NOT to use**: Simple key-value storage needs where IDB suffices, or when you can't afford the architectural complexity (SharedWorker, single-writer enforcement).

**How it works**: Notion achieved 20% faster navigation (33% in India). But architecture is non-trivial.

**Core problem:** OPFS has poor concurrency — Notion observed data corruption with multi-tab
writes. Only safe approach is single-writer.

**Notion's architecture:** SharedWorker manages which tab is active writer. Each tab has
dedicated Worker running SQLite. Web Locks detect tab closures. All queries route: Main
Thread → SharedWorker → Active Tab's Worker → SQLite/OPFS.

**VFS selection** (PowerSync Nov 2025):
| VFS | Best for | Note |
|-----|----------|------|
| AccessHandlePoolVFS | Best raw perf, no Asyncify | Single connection, Worker required. Notion's choice |
| OPFSCoopSyncVFS | General-purpose | PowerSync's 2025 recommendation |
| IDBBatchAtomicVFS | Widest context support | Degrades >100MB |
| OPFSPermutedVFS | Concurrent read+write | Chrome only |

Notion chose AccessHandlePoolVFS — no COOP/COEP headers needed (third-party scripts break COEP).

### Cross-tab coordination (BroadcastChannel)

Uncoordinated multi-tab writes to IDB/OPFS cause silent data loss. Pattern (tldraw, Linear):
broadcast diffs (not full state), treat cross-tab updates as "remote" (exclude from local
undo, don't re-persist), debounce persistence but broadcast immediately.

**Tab lifecycle:** New tab loads from IDB — may see stale data within debounce window.
tldraw broadcasts current in-memory state when new tab announces. Linear uses Web Locks
for presence.

### tldraw auto-persistence

`<Tldraw persistenceKey="my-document" />`. IDB + BroadcastChannel cross-tab. Snapshot API
separates `document` (shapes → server) from `session` (camera → local).

### Mapping SDKs

No mapping SDK provides annotation persistence. Tile caches exist, but user annotations
are always developer's responsibility.

## Schema migration

**tldraw bidirectional (gold standard):** Named sequences with up/down functions. Enables
multiplayer version skew — newer clients down-migrate for older. Every snapshot embeds
schema versions.

**Excalidraw pragmatic:** `restoreElements()` with graceful defaults. No formal system.
Unknown properties preserved. Good enough for simple apps, breaks on property renames.

**CRDT schema evolution:** Two users may independently perform same migration → conflicts.
Automerge recommends hard-coded deterministic actorId. Yjs has no built-in migration.

## Seed-based determinism

Procedural rendering (sketch effects, noise patterns, randomized hatching) must store
random seed per shape. Without it: visual jitter on undo/redo, different output on reload,
collaborator sees different visual, cache rebuild changes appearance. Generate unique seed
at creation, never regenerate. Evidence: Excalidraw `seed` for roughjs, drafft-ink `seed`
in ShapeStyle, tldraw caches rendered output instead.

## Tombstones and deletion

- **Yjs:** Deleted items keep lightweight GC objects. Disabling GC awful for performance.
- **Excalidraw:** `isDeleted` flag, strip when saving to persistent storage.
- **Spatial problem:** Deleted shapes in 2D don't compress into runs. R-tree must include
  tombstones, maintain secondary index, or rebuild after compaction.

**Soft delete with TTL-gated lifecycle:** Deleted elements stay for undo (isDeleted hides
from render), broadcast within TTL window (Excalidraw: 24h), eventually GC'd after TTL.

## Save confirmation integrity

Never update save-status UI optimistically. Annotation data often represents irreplaceable
field work. `.catch(() => {})` on persistence writes = silent data loss. Update save
indicators only in success callback. Surface failures in UI.

## Three-tier persistence (CRDT apps with server authority)

When a CRDT (Yjs) handles real-time sync but a relational DB is the canonical store, you need three persistence tiers working together. Each tier serves a different consistency/latency tradeoff.

| Tier | Technology | Purpose | Consistency |
|------|-----------|---------|-------------|
| **Client cache** | y-indexeddb, IndexedDB | Instant load, offline resilience | Eventual (local) |
| **CRDT WAL** | LevelDB, Redis, Durable Objects | Persist raw CRDT updates server-side | Eventual (distributed) |
| **Canonical store** | PostgreSQL, SQLite | Queryable source of truth, relations, access control | Strong (server) |

**Why three tiers, not two:** The CRDT WAL (write-ahead log) bridges the gap between real-time collaboration and relational queries. Without it, you either lose CRDT updates on server restart (no WAL) or can't query/join annotation data with relational models (no canonical DB).

**Data flow:**
1. User mutation → Yjs doc (in-memory) → broadcast to peers via WebSocket
2. Yjs update → LevelDB/WAL (debounced, 2000ms) — survives server restart
3. Yjs doc callback → extract structured data → write to PostgreSQL — queryable, joinable

**Production examples:**
- **Ideon**: y-indexeddb (client) + y-leveldb (server WAL) + PostgreSQL via Kysely (canonical). Server's `WSSharedDoc` persists Yjs updates to LevelDB on every change, while a callback system extracts block/link data to PostgreSQL for API queries and access control.
- **tldraw**: localStorage (client) + Cloudflare Durable Objects (CRDT WAL) + R2 (canonical snapshots)
- **Liveblocks**: IndexedDB (client) + Liveblocks servers (CRDT WAL) + webhook-driven DB sync (canonical)

**Key decisions:**
- **WAL debounce interval**: 500-2000ms. Too short wastes I/O on rapid edits; too long risks data loss on crash. Yjs's `y-leveldb` defaults to immediate writes but batches internally.
- **Canonical sync trigger**: On every Yjs update callback (Ideon), on periodic snapshot (tldraw), or via webhook (Liveblocks). Event-driven is freshest but couples persistence to edit frequency.
- **Schema divergence**: The CRDT schema (Y.Maps, Y.Arrays) and relational schema (tables, columns) will diverge. The callback/sync layer is a translation boundary — keep it explicit and tested.

## Named snapshots with hash-based dedup

Distinct from undo/redo (linear stack) — named snapshots let users save, browse, and restore labeled points in time. Common in spatial editors where users want "save this layout" before experimenting.

**Architecture:**
```typescript
// Save: hash current state, skip if identical to last snapshot
const hash = await generateStateHash(blocks, links);
if (hash === lastSnapshotHash) return; // dedup
await saveSnapshot({ name, blocks, links, hash, timestamp });

// Preview: load snapshot into read-only mode without modifying live state
const snapshot = await loadSnapshot(stateId);
enterPreviewMode(snapshot.blocks, snapshot.links);

// Apply: replace live state with snapshot, creating single undo entry
await applySnapshot(stateId); // wraps in CRDT transaction
```

**Hash-based dedup** prevents storing identical snapshots when nothing changed — users often "save" defensively. Hash the serialized state (blocks + links + positions) and compare before writing.

**Preview before apply** is essential — users need to see the snapshot before committing to restore it. Preview mode reuses the same canvas renderer but disables mutations, undo, and collaboration (see interaction-modes.md "Preview/read-only mode").

**Production**: Ideon uses `generateStateHash()` to compare present state against snapshot before applying, with toast feedback when states are identical. tldraw snapshots separate `document` from `session`. Figma version history is server-managed with thumbnail previews.

## Decision guide

| Constraint | Approach |
|-----------|----------|
| Simple, few annotations | IndexedDB via `idb` |
| Complex client queries | SQLite/WASM + OPFS |
| Multi-tab | SharedWorker + single-writer |
| Schema changes expected | tldraw-style bidirectional migrations |
| CRDT-synced, no server DB | Yjs with debounced server persistence |
| CRDT-synced, server DB needed | Three-tier (client cache + CRDT WAL + canonical DB) |
| Branching / save points | Named snapshots with hash dedup |

## Anti-Patterns

### Optimistic save-status UI

**What happens**: Save indicator shows "saved" before the persistence write completes. If the write fails (network error, disk full, quota exceeded), the user believes their work is safe when it isn't. Annotation data often represents irreplaceable field work.

**Why it's tempting**: Immediate "saved" feedback feels responsive. The write "almost always" succeeds.

**What to do instead**: Update save indicators only in the success callback. Surface failures in UI with actionable recovery (retry, export to file).

### Uncoordinated multi-tab writes

**What happens**: Multiple tabs write to IDB or OPFS independently. Writes interleave, producing silent data corruption. One tab's changes overwrite another's without conflict detection.

**Why it's tempting**: Each tab works fine in isolation during development. Multi-tab testing is rare.

**What to do instead**: BroadcastChannel for IDB (broadcast diffs, not full state; treat cross-tab updates as "remote"). SharedWorker + single-writer for OPFS (Notion's architecture).

### Relying solely on browser storage without server backup

**What happens**: Browsers can evict IndexedDB under disk pressure without warning. Safari incognito has no OPFS. User clears browser data and loses everything.

**Why it's tempting**: Client-only persistence is simpler than server infrastructure. "We'll add server sync later."

**What to do instead**: For critical data, dual-write to localStorage + IDB (Excalidraw pattern) as minimum. For production apps, implement at least two-tier persistence (client cache + server backup).

### Disabling CRDT garbage collection

**What happens**: Yjs with GC disabled retains every tombstone forever. Performance degrades progressively — spatial data is especially bad because deleted shapes in 2D don't compress into runs.

**Why it's tempting**: GC seems risky ("what if we need the history?"). Disabling it avoids reasoning about tombstone lifecycles.

**What to do instead**: Soft delete with TTL-gated lifecycle — deleted elements stay for undo window (`isDeleted` hides from render), broadcast within TTL (24h), eventually GC'd after TTL.

### Schema migration without bidirectional support

**What happens**: In multiplayer, a user on the newer app version migrates their local data forward. Users on older versions can't read the migrated format. The document becomes unreadable for anyone who hasn't updated.

**Why it's tempting**: Forward-only migrations are simpler and match server-side migration patterns.

**What to do instead**: tldraw-style bidirectional migrations with up/down functions. Every snapshot embeds schema versions. Newer clients down-migrate when sending to older peers.
