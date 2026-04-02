# Collaboration & Sync Patterns

## The Problem

When two users edit the same annotation simultaneously, something has to give. Without a deliberate conflict resolution strategy, you get last-write-wins at the TCP level — one user's changes silently vanish, and neither user knows until they refresh and notice their work is gone. The failure mode is insidious: it only manifests under concurrent editing, which is rare enough during development that you ship without seeing it, then common enough in production to erode trust.

Beyond data conflicts, presence creates its own problems. Users need to see where collaborators are working and what they're editing, but presence data (cursor positions, active selections) arrives at 30-60Hz per user. Pushing these high-frequency updates through the same channel as document edits pollutes undo history with transient data, bloats persistence, and turns the reactive store into a firehose that re-renders the entire UI every frame. And if you mix presence with document state, disconnecting a user can accidentally delete their cursor position from the CRDT, creating a "ghost edit" that permanently alters the document.

Branching compounds the problem further. When annotations live in version branches (like Figma branches or GeoGig repos), merge introduces a new class of conflicts: what happens to a comment anchored to an annotation that was modified in one branch and deleted in another? Without explicit merge policies, you get orphaned comments, duplicated annotations, or silent data loss at merge time.

## Competing Patterns

## LWW beats CRDTs for most annotation apps

Every major collaborative canvas (Felt, Figma, Excalidraw, Linear) uses LWW variants with server ordering. Concurrent edits to the same annotation are vanishingly rare — the real value is shared state, not simultaneous vertex editing.

### Felt/Figma model (server-authoritative LWW)

**When to use**: Real-time collaboration with a server available. Concurrent edits to the same annotation are rare; the real value is shared state, not simultaneous vertex editing.

**When NOT to use**: Offline-first apps where users edit without connectivity, or rich text within annotations where character-level merging matters.

**How it works**: Server holds authority. WebSocket broadcasts. LWW resolved at (ObjectID, Property) level. Server process per document, state in memory, checkpoints every 30-60s.

**Felt's CTO**: "We're not using Yjs, we're not using any CRDT or OT structures. We're just structuring the data as deeply as possible, so that merge conflicts don't happen often."

**Figma's co-founder**: "CRDTs are designed for decentralized systems where there is no single central authority. Since Figma is centralized, we can simplify our system."

### Excalidraw model (peer-to-peer LWW)

**When to use**: Real-time collaboration without a dedicated server. Acceptable to have occasional janky merges on rare concurrent edits.

**When NOT to use**: Apps requiring strong consistency guarantees or server-side access control on every mutation.

**How it works**: Each element carries version + random versionNonce. Higher version wins. Tied versions -> lower nonce wins deterministically. Soft-delete via tombstones. Acknowledged jankiness in rare concurrent edits, but massively simpler.

### tldraw model (CRDT-like with Durable Objects)

**When to use**: High-concurrency (50+ users) real-time editing with optimistic updates and automatic conflict rollback. Willing to invest in custom sync infrastructure.

**When NOT to use**: Simple annotation apps where LWW is sufficient. The complexity cost is significant.

**How it works**: Custom TLSync protocol with optimistic updates and automatic rollback. One Cloudflare Durable Object per file. Reactive state via Signia signals. Supports 50 concurrent users. Most sophisticated among canvas tools, also most complex.

## When CRDTs ARE worth it

1. **Offline-first with multi-device sync**
2. **Rich text within annotations** — Figma added Eg-walker for code layers
3. **Geometric topology preservation** — concurrent vertex editing on complex polygons (academic, not production-ready)

### Yjs patterns for annotation apps

- Awareness protocol handles presence — NOT part of the document CRDT
- Debounce persistence writes (2000ms default)
- UndoManager for per-client undo within CRDT context

### cr-sqlite

`crsql_as_crr('annotations')` — each column becomes an independent LWW register. 2.5x slower inserts, 15% write overhead. Good for local-first with SQL.

### Electric SQL / PowerSync

Read-path sync from Postgres to client. Writes through your API. LWW default, custom conflict resolution available. Good for PostGIS annotation data.

## Presence vs document state separation

**Non-optional.** Every production collaborative tool separates these:

| | Presence | Document |
|---|---------|----------|
| Lifetime | Resets on disconnect | Survives disconnects |
| Consistency | Best-effort | Eventually consistent |
| Frequency | 10-60 Hz (cursors) | Event-driven (edits) |
| Persistence | Never | Always |

**Anti-pattern**: Storing cursor positions in the CRDT document pollutes history with transient data.

**tldraw's approach**: `instance_presence` records live in the same reactive store as shapes/bindings but are excluded from persistence and undo. Unified queries without polluting history. Figma does the same — one query system, one reactive graph.

Contrast: Yjs awareness and Liveblocks use separate APIs requiring manual bridging. Fine for cursor dots, but adds complexity when presence must interact with annotations ("show which annotation each collaborator is editing").

**Cursor rendering optimization**: Store remote cursor positions in a ref (not reactive state) and render via `requestAnimationFrame` loop. At 30-60Hz cursor updates, pushing positions through React/Svelte reactivity re-renders the entire component tree per frame. A ref + RAF loop bypasses the framework entirely — only the cursor DOM elements update. Ideon, tldraw, and Figma all use this pattern.

## Client-side rebase for optimistic collaboration

**When to use**: Middle ground when you need better consistency than LWW but don't want full CRDT infrastructure. You already have command-pattern undo with pre-computed inverses.

**When NOT to use**: If you don't have bidirectional changes (forward + inverse ops) already — the prerequisite is non-trivial to add retroactively.

**How it works**: Middle ground between LWW and CRDTs. Used by Penpot and similar non-CRDT collaborative editors.

1. Apply changes locally immediately
2. Queue commit with unique ID
3. Send queued commits to server one at a time
4. On remote change: unwind pending locals (reverse undo-changes) -> apply remote -> replay locals (forward redo-changes)
5. On server ACK: remove from pending queue

**Prerequisite**: Bidirectional changes — every mutation needs forward + inverse ops. If you have command-pattern undo with pre-computed inverses, rebase comes free.

**Source discriminator pattern**: Route ALL mutations through one commit function. `source: 'local' | 'remote'` controls side effects — only local commits are undoable and persisted.

## Adaptive sync throttling

Presence-driven throttle switching (tldraw, production-proven at 50 concurrent users):
- **Solo (1 FPS)**: Coalesce mutations into 1 sync/second. Sufficient for persistence.
- **Collaborative (30 FPS)**: Smooth cursors and near-instant mutation visibility.
- Switch when first collaborator joins / last leaves.

Works with any presence system (Liveblocks `others.length`, Yjs awareness, WebSocket room count). Presence info you already need for cursors doubles as throttle signal.

## Annotation lifecycle in branching workflows

Production examples: Figma branches, GeoGig (Git for geospatial), tldraw snapshots.

### Merge policies

- **Union merge**: All annotations from both branches appear. Duplicates by ID. GeoGig default.
- **LWW per-annotation**: Newer version wins per-annotation. Figma branches use this.
- **Field-level LWW**: Merge at property level — different properties on same annotation don't conflict. CRDT approach (Automerge, Yjs), best results but most infrastructure.

### Anchored comments across branches

When a comment is anchored to an annotation modified in one branch, deleted in another:
- **Delete wins**: Comment becomes orphaned (see comment-anchoring reference)
- **Preserve wins**: Deletion requires manual resolution. Safer for review workflows.
- **Branch-scoped**: Comments belong to the branch. On merge, only "resolved" comments carry forward. Upwelling uses this.

### Version history

- Store annotation state as part of version snapshots
- Comment threads typically span versions — not reverted even when annotations are

## Fractional indexing for conflict-free ordering

String-based fractional indices (`fractional-indexing` by rocicorp, `@tldraw/indices`) — insert between elements without renumbering.

**Annotation-specific integration**:
- **Undo/redo**: Indices survive history replay. Only moved elements get new indices. Version fields excluded during history application so redos act as fresh actions for collaboration.
- **Reconciliation**: Sort by index, validate (predecessor < index < successor), repair idempotently.
- **Incremental repair**: `syncMovedIndices()` regenerates only between boundary elements of moved groups, including interleaved deletes.

**Production**: Excalidraw uses `fractional-indexing@3.2.0` with `FractionalIndex` brand type. tldraw uses `@tldraw/indices`. Both chose it specifically for multiplayer safety.

## Hybrid incremental + periodic full sync

**Incremental** (default): Track `broadcastedVersions: Map<id, version>`, send only changed elements.

**Full sync** (periodic fallback): Every 20-30s, broadcast all syncable elements. Recovers from dropped messages, server restarts, network partitions without ACK tracking. Also triggered on: new user joins, reconnection after network drop.

**Version gating**: Scene-level version hash prevents echo-back and infinite sync loops.

**Sync filtering** — exclude: deleted elements past TTL, invisibly small elements (accidental micro-clicks), elements actively being created (wait for mouseup).

## Pessimistic locking via awareness channels

**When to use**: Concurrent edits produce semantically invalid results — complex geometry (boolean union, topology editing), destructive operations (vertex deletion, polygon split/merge), or regulated/audit workflows where authorship must be unambiguous.

**When NOT to use**: Normal property edits where LWW produces acceptable results. Locking adds latency and UX friction for the common case.

**How it works**: Prevent conflicts instead of resolving them. Reuse presence/awareness infrastructure as lock distributor — no separate lock server needed.

**When locking beats LWW/CRDTs:**
- Complex geometry (boolean union, topology editing) — LWW merge produces shapes neither user intended
- Destructive operations (vertex deletion, polygon split/merge) — merge is undefined
- Regulated/audit workflows — LWW makes authorship ambiguous
- Long-running path edits spanning minutes

**Architecture**: Reuse presence/awareness infrastructure as lock distributor. No separate lock server.

**Lock granularity:**

| Granularity | Use when |
|-------------|----------|
| Per-annotation | Most cases — editing geometry, properties |
| Per-region | Spatial partitioning for large datasets |
| Per-operation | Short-lived locks during destructive ops |
| Per-layer | Layer-based workflows |

**Deadlock prevention**: Rarely an issue (users work on spatially disjoint features), but: TTL expiration (30-60s inactivity, matches awareness offline timeout) + disconnect cleanup (awareness removes state, releasing locks).

**UI feedback is non-negotiable.** Silent "click does nothing" is the worst UX. Show who holds the lock and what they're doing.

**Production**: WeaveJS uses mutex locks via Yjs awareness. Esri uses pessimistic locks at feature class level. JOSM uses optimistic locking (detect rather than prevent).

**Hybrid LWW + advisory locks** (pragmatic default): LWW for normal edits (95%), short-lived advisory locks for destructive operations (5%).

## Decision guide

| Constraint | Approach |
|-----------|---------|
| Real-time, server available | Server-authoritative LWW (Felt/Figma) |
| Real-time, no server | Version+nonce LWW (Excalidraw) |
| Offline-first, multi-device | CRDT (Yjs or cr-sqlite) |
| Rich text in annotations | Yjs YText or Automerge |
| Simple turn-taking | Optimistic locking (OSM version numbers) |
| Destructive geometry ops | Pessimistic locking via awareness (or hybrid) |
| Regulated/audit workflows | Pessimistic locking with per-edit attribution |

Deep dives: `sources/tech-agnostic.md` (Eg-walker, collaborative undo, local-first, sync engines) and `sources/mutation-state.md` (geometry-aware CRDTs, OSM optimistic locking).

## Anti-Patterns

### Storing cursor positions in the CRDT document

**What happens**: Presence data (cursors, active selections) written to the CRDT pollutes document history with transient data. Every cursor movement becomes a permanent operation in the CRDT log, bloating storage and making version history meaningless.

**Why it's tempting**: The CRDT is already there and reactive. Using a separate presence channel feels like extra infrastructure.

**What to do instead**: Use a separate presence/awareness channel (Yjs awareness, Liveblocks presence, or custom WebSocket room). tldraw keeps `instance_presence` records in the same reactive store but excludes them from persistence and undo.

### Pushing cursor updates through framework reactivity

**What happens**: At 30-60Hz cursor updates per collaborator, pushing positions through React/Svelte reactivity re-renders the entire component tree per frame. Visible jank and wasted CPU.

**Why it's tempting**: The reactive store pattern works for everything else — natural to use it for cursors too.

**What to do instead**: Store remote cursor positions in a ref (not reactive state) and render via `requestAnimationFrame` loop. Only the cursor DOM elements update. Ideon, tldraw, and Figma all use this pattern.

### CRDT-first without evaluating LWW

**What happens**: Teams adopt Yjs/Automerge for annotation collaboration before evaluating whether LWW would suffice. CRDTs add significant complexity (schema migration difficulties, debugging opacity, tombstone management) for a problem that rarely manifests — concurrent edits to the same annotation are vanishingly rare.

**Why it's tempting**: CRDTs are technically elegant and solve the "hardest" version of the problem. Feels like future-proofing.

**What to do instead**: Start with server-authoritative LWW (Felt/Figma model). Add CRDTs only for specific sub-problems that need them: rich text (Yjs YText), offline-first sync (cr-sqlite), or geometric topology preservation.

### Silent lock failures (click does nothing)

**What happens**: When pessimistic locking prevents an edit, the UI gives no feedback. The user clicks repeatedly, thinks the tool is broken, and files a bug report about "unresponsive UI."

**Why it's tempting**: Easier to just `return` from the handler than build lock-awareness UI.

**What to do instead**: Show who holds the lock and what they're doing. UI feedback for lock contention is non-negotiable.

### Unbounded sync frequency

**What happens**: Sync runs at maximum frequency regardless of whether anyone else is in the document. Solo users pay the cost of 30fps sync when 1fps persistence would suffice.

**Why it's tempting**: One sync frequency is simpler to implement and reason about.

**What to do instead**: Adaptive sync throttling — solo mode at 1fps, collaborative mode at 30fps, switching when the first collaborator joins or the last leaves. Presence info you already need for cursors doubles as the throttle signal.
