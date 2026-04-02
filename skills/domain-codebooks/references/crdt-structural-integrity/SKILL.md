---
name: crdt-structural-integrity
description: >-
  Force tension: convergence guarantees vs resource economy vs historical
  introspection. All peers must reach the same state, but operations and
  tombstones consume unbounded resources, and users need attribution,
  snapshots, and time-travel. This operates one layer BELOW application-level
  distributed-state-sync — it concerns CRDT document internals: operation
  storage, tombstone lifecycle, type composition, encoding, and sync protocols.

  NOT application-level state sync (use distributed-state-sync), generic
  distributed consensus (Raft/Paxos), database replication, file sync
  (Dropbox/rsync), or application-level undo UX (use undo-under-distributed-state).

  Triggers: "CRDT tombstone accumulation", "garbage collection breaks references",
  "snapshot consistency across peers", "attribution tracking through GC",
  "CRDT document forking and merging", "awareness presence protocol",
  "CRDT encoding performance columnar binary", "operation log compaction",
  "CRDT type composition nested maps arrays", "conflict resolution at CRDT layer",
  "CRDT sync protocol state-based op-based", "fractional indexing within CRDT".

  Brownfield triggers: "Yjs document is 18MB but visible content is only 2MB",
  "GC enabled but tombstones not reclaimed", "orphaned child items after GC on
  parent Y.Map", "snapshot references items that GC compacted away",
  "attribution lost after tombstone is collected", "nested Automerge maps have
  wrong structural merge", "custom sync protocol diverges with 3+ clients",
  "compaction broke undo because UndoManager references compacted items",
  "migrating from Yjs to Automerge with different document models",
  "tombstones grow unbounded after months of editing", "awareness state goes
  stale after disconnect".

  Symptom triggers: "initial sync payload is huge but visible content is small",
  "Yjs GC enabled but nothing reclaimed", "orphaned child items after parent
  Y.Map is garbage collected", "snapshot references items that no longer exist
  after GC", "who deleted a paragraph is lost after tombstone collection",
  "nested Automerge maps have wrong structural merge on concurrent edits",
  "custom sync protocol works for 2 clients but diverges with 3+",
  "undo broke after running compaction on CRDT store", "migrating from Yjs
  to Automerge document format conversion", "state vector comparison seems
  wrong in sync protocol", "UndoManager references compacted items".

  Libraries: Yjs (YATA), Automerge (columnar), Loro (hybrid list+map),
  cr-sqlite, Diamond Types.

  Production examples: weavejs/Yjs, ideon/Yjs, upwelling-code/Automerge,
  drafft-ink/Loro.

cross_codebook_triggers:
  - "undo fights the CRDT after migrating to Yjs (+ undo-under-distributed-state)"
  - "compaction broke undo because UndoManager references compacted items (+ undo-under-distributed-state)"
  - "sync provider diverges with 3+ clients (+ distributed-state-sync)"
---

# CRDT Structural Integrity

## Force Tension

**Convergence guarantees** vs **resource economy** vs **historical introspection**.

All peers must eventually reach the same state (convergence), but the operations and tombstones that guarantee convergence consume unbounded resources (economy), and users need to attribute, snapshot, and time-travel through history (introspection). Optimizing any one axis degrades the other two.

This operates one abstraction layer BELOW application-level distributed-state-sync. It concerns the internal mechanics of CRDT documents: operation storage, tombstone lifecycle, type composition, encoding, and sync protocols.

---

## Skip

Do NOT use this codebook for:

- **Application-level state sync** -- use `distributed-state-sync` instead. That codebook handles provider patterns, connection lifecycle, room management, offline-first sync strategies.
- **Generic distributed consensus** -- Raft, Paxos, total-order broadcast. Those are consensus protocols, not CRDTs.
- **Database replication** -- PostgreSQL logical replication, MySQL binlog, CockroachDB ranges. Different problem domain.
- **File sync** -- Dropbox-style sync, rsync, IPFS. File-level, not operation-level.
- **Application-level undo UX** -- use `undo-under-distributed-state` for the user-facing undo/redo design. This codebook covers the CRDT-native undo primitives that codebook builds on.

---

## Cross-References

| Codebook | Relationship |
|---|---|
| `distributed-state-sync` | This codebook is the layer BELOW it. Sync providers consume the primitives described here. |
| `undo-under-distributed-state` | CRDT-native undo patterns (UndoManager, origin filtering, tombstone interaction) originate here. |

---

## Evidence Base

Patterns in this codebook are grounded in analysis of:

| Source | CRDT Library | Algorithm | Key Observations |
|---|---|---|---|
| weavejs (Yjs) | Yjs | YATA | Transaction lifecycle, StructStore, deferred cleanup, Awareness protocol, Snapshot/attribution |
| ideon (Yjs) | Yjs | YATA | Canvas workspace context, Y.Map for document state, third confirmation of Yjs patterns |
| upwelling-code | Automerge | Operation-based, columnar | Branching/drafts model, Change objects, sync protocol, document forking/merging |
| drafft-ink | Loro | Hybrid list+map CRDT | Container-based architecture, fractional indexing within CRDT, different GC strategy |

---

## Reference Documents

- `get_docs("domain-codebooks", "crdt-structural-integrity convergence GC")` -- Tombstone lifecycle, GC strategies, compaction trade-offs
- `get_docs("domain-codebooks", "crdt-structural-integrity type composition")` -- Composing CRDT types, nested conflict resolution semantics
