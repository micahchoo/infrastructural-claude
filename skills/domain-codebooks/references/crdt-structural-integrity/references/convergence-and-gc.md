# Convergence and Garbage Collection

## The Problem

Every delete in a CRDT produces a tombstone -- a marker that says "this item existed but was removed." Tombstones are necessary for convergence: a late-arriving peer must distinguish "item was deleted" from "item was never seen." Without tombstones, a peer receiving an insert after missing the delete would resurrect the item.

The cost is unbounded growth. A document edited daily for months accumulates thousands of tombstones that serve no purpose for active peers -- but cannot be safely removed without breaking convergence guarantees for peers that haven't synced recently.

This is the central tension: **convergence requires remembering deletions, but resource economy requires forgetting them.**

**De-Factoring Evidence (binary tombstones only):**
- **If removed:** Without graduated reclamation, the system is forced into all-or-nothing: keep full Items forever (unbounded growth) or destroy them entirely (breaking late arrivals, undo, and positional references). Mobile browser tabs crash on documents edited daily for months.
- **Detection signal:** Memory profiling shows >50% of heap is deleted Items with full content intact; tombstone ratio climbs above 0.5 with no reclamation; sync payload sizes grow monotonically.

---

## Competing Patterns

### 1. Yjs GC: Mark-and-Sweep with Snapshot Dependency

**Mechanism:** Yjs stores operations in a `StructStore`. Deleted items are marked with a `deleted` flag. GC replaces deleted `Item` nodes with `GC` structs that retain the ID and length but discard content. The `GC` struct preserves the causal graph while freeing content memory.

**Snapshot interaction:** A Yjs `Snapshot` captures the `StateVector` (version) and `DeleteSet` at a point in time. Restoring a snapshot walks the StructStore and filters by version. If GC has run, items needed for the snapshot are gone -- the snapshot becomes inconsistent or unusable.

**Trade-offs:**
- GC reduces memory but is irreversible
- Snapshots taken before GC may break
- UndoManager stores undo steps as operations; GC can invalidate undo history
- GC must be coordinated: all peers must agree on a safe GC horizon

**When to use:** Long-lived documents where memory is a constraint and historical introspection beyond a fixed window is not required.

#### Yjs Production Deep Dive: Graduated Tombstone System

Yjs implements a **3-level graduated tombstone system** where deleted items
progress through increasingly aggressive reclamation stages:

| Level | State | What's preserved | Memory cost |
|-------|-------|-----------------|-------------|
| **0: Soft delete** | `Item.deleted = true` | Full item + content | Highest — content intact |
| **1: Content stripped** | `Item.content = ContentDeleted` | Item skeleton (ID, left/right pointers) | Medium — structure intact |
| **2: GC struct** | `GC` replaces `Item` | Only `id` + `length` | Minimal — clock-space only |

**GC algorithm flow** (triggered at transaction commit when `doc.gc = true`):

```
Transaction commit → cleanupTransactions()
  → fire observers
  → tryGcDeleteSet(tr, deleteSet, gcFilter)
      → for each deleted Item (not kept, passes filter):
          Item.gc(tr, parentGCd=false)
            → content.gc(tr)
            → replace content with ContentDeleted      [Level 0 → 1]
  → tryMerge(deleteSet, store)
      → merge adjacent GC/deleted structs              [Level 1 → 2]
  → emit update events
```

**Recursive cascade GC through nested types:** When `ContentType.gc()` is
called (an item's content is a nested Y.Map/Y.Array/Y.Text), it recursively
GCs ALL descendants with `parentGCd=true`. This flag causes child items to be
fully replaced with GC structs immediately (skipping Level 1), because the
parent container is being destroyed — preserving the child skeleton is
pointless.

**De-Factoring Evidence (cascade deletion):**
- **If removed:** Deleting a parent Y.Map leaves orphaned subtrees in the StructStore — unreachable via API but still encoded in sync payloads. Late operations integrate into phantom branches no user can see.
- **Detection signal:** StructStore item count grows even as visible document shrinks; users report "ghost content" reappearing after sync.

**Snapshot-GC mutual exclusion:** `createDocFromSnapshot()` throws a hard error
if GC has occurred on the document. Snapshots reference items by their position
in the StructStore — if GC has replaced Items with GC structs, the snapshot
cannot reconstruct the historical state. This is a **design constraint, not a
bug**: applications must choose between GC and snapshot capability.

**De-Factoring Evidence (snapshot-GC guard):**
- **If removed:** `createDocFromSnapshot()` silently returns corrupted documents with holes where GC'd content should appear. Versioning UI shows "version 47 is half blank" with no error.
- **Detection signal:** Error in production `Garbage-collection must be disabled in originDoc!`; architecture review reveals `new Doc({ gc: true })` alongside snapshot-dependent features.

**Silent discard of late-arriving operations:** When a remote operation arrives
referencing a parent that has been GC'd, the operation's `parent` is set to
`null` during integration. The operation itself is then GC'd. This is a
**silent data loss path** — no error is raised, the operation simply vanishes.

**De-Factoring Evidence (late-arrival discard):**
- **If removed:** Late-arriving operations referencing GC'd parents would crash the integration algorithm (null pointer) or queue forever, leaking memory. Peers offline during GC crash on reconnection.
- **Detection signal:** User reports "I made changes offline but they disappeared after sync" with no errors in logs; GC horizon is shorter than longest expected peer disconnection.

**GC safety boundaries** — three layers control what gets collected:

1. **`doc.gc` flag** — global on/off switch for the entire document
2. **`gcFilter(item): boolean`** — per-item callback that can exempt specific
   items from collection (e.g., items in a particular namespace)
3. **`item.keep` flag** — set by UndoManager's `keepItem()` to protect items
   referenced by undo stack entries. Clearing the undo stack releases items
   for GC.

**De-Factoring Evidence (GC safety boundaries):**
- **If removed:** Without `gcFilter`, all-or-nothing GC — no way to exempt metadata namespaces. Without `item.keep`, Ctrl+Z after GC silently fails to restore content or crashes.
- **Detection signal:** Undo silently does nothing on mature documents; feature request "GC everything except metadata/annotations"; UndoManager stack references items absent from StructStore.

**Clock-space continuity invariant:** GC structs preserve the clock range
(`id.client`, `id.clock`, `length`) of the original Item. This ensures
`findIndexSS()` binary search still works and state vectors remain valid
after GC. Adjacent GC structs from the same client are merged via
`mergeWith()`.

**De-Factoring Evidence (clock-space continuity):**
- **If removed:** GC creates holes in per-client arrays. `findIndexSS()` binary search returns wrong results, state vector comparison breaks, and the entire sync protocol collapses.
- **Detection signal:** Sync failures between peers with large version gaps; intermittent "missing struct" errors on long-lived documents; items integrating at wrong positions.

Source: `src/structs/Item.js`, `src/structs/GC.js`, `src/utils/Transaction.js`,
`src/utils/Snapshot.js`, `src/types/ContentType.js`

### 2. Automerge Compaction: Columnar Re-encoding

**Mechanism:** Automerge stores operations in a columnar binary format. Compaction re-encodes the operation history into a more compact representation without discarding causal information. The `Change` objects are merged and re-serialized.

**Trade-offs:**
- Preserves full history (no information loss)
- Reduces wire size and storage through better encoding, not deletion
- CPU cost at compaction time
- Document size still grows, just more slowly
- Branching/forking model means each branch carries its own history

**When to use:** When historical introspection (attribution, time travel, branch diffs) is a core requirement and you can tolerate larger documents.

### 3. Loro Hybrid GC

**Mechanism:** Loro uses a container-based architecture where different CRDT types (list, map, text) are composed as containers. GC operates at the container level with awareness of the hybrid structure. Fractional indices within list CRDTs can be compacted independently of map entries.

**Trade-offs:**
- More granular GC than Yjs (per-container, not whole-document)
- Container boundaries create natural GC scopes
- Newer library, less battle-tested
- GC semantics vary by container type

**When to use:** When different parts of the document have different GC requirements (e.g., text content can be aggressively GC'd but metadata maps should retain history).

### 4. No GC Ever (Accept Growth)

**Mechanism:** Never garbage collect. Accept that documents grow without bound.

**Trade-offs:**
- Simplest to implement and reason about
- Full convergence guarantee for any peer, regardless of sync gap
- Full historical introspection always available
- Memory and storage costs grow linearly with edit count
- Eventually hits practical limits (mobile devices, browser tabs)

**When to use:** Short-lived documents, documents with bounded edit histories, or when correctness is worth any resource cost.

---

## Decision Guide

```
Is historical introspection (attribution, time travel, snapshots) a core feature?
  YES --> Do you need introspection over the FULL history?
            YES --> Automerge compaction or no-GC
            NO  --> Yjs GC with a snapshot retention window
  NO  --> Is the document long-lived (months/years of edits)?
            YES --> Is the document structure heterogeneous (mixed types)?
                      YES --> Loro hybrid GC (per-container policies)
                      NO  --> Yjs GC with aggressive collection
            NO  --> No GC (accept growth)
```

---

## Anti-Patterns

### 1. GC Without Peer Coordination
Running GC on one peer while another peer is offline for weeks. When the offline peer reconnects, its operations reference tombstones that no longer exist. The sync protocol cannot reconcile, causing silent data loss or divergence.

**Fix:** Establish a GC horizon based on the oldest known peer state vector. Only GC operations that ALL known peers have acknowledged.

### 2. Snapshots Across GC Boundaries
Taking a snapshot, running GC, then trying to restore the snapshot. The snapshot references items that GC has deleted.

**Fix:** Either (a) retain all items referenced by any retained snapshot, or (b) serialize snapshots as full document state rather than references into the operation log.

### 3. Undo Stack Invalidation
GC deletes the items that an UndoManager operation would re-insert. The undo silently does nothing or produces a corrupted state.

**Fix:** Treat undo stack entries as GC roots. Do not collect any item referenced by an active undo stack. This couples undo depth to GC effectiveness -- a deep undo stack prevents meaningful GC.

### 4. Compaction as Silver Bullet
Assuming columnar re-encoding solves growth. It improves encoding efficiency but does not remove operations. A document with 100k operations compacted is still a document with 100k operations -- just stored in fewer bytes.

**Fix:** Set expectations. Compaction buys time, not a solution. If the document will receive unbounded edits, plan for eventual GC or document splitting.

### 5. Per-Document GC Policies in Multi-Document Systems
Applying the same GC policy to all documents regardless of their lifecycle. A scratchpad and a legal contract have different GC requirements.

**Fix:** GC policies should be per-document-type or per-document, not system-wide. Expose GC configuration at the document or collection level.

---

## Key Metrics to Monitor

- **Tombstone ratio:** `deleted_items / total_items`. Above 0.5 means the document is more tombstone than content.
- **StructStore size** (Yjs) or **operation count** (Automerge): Track growth rate over time.
- **GC reclamation rate:** How much memory does each GC pass actually free? Diminishing returns indicate most tombstones are pinned by snapshots or undo stacks.
- **Sync payload size:** If sync messages grow over time for the same document, GC is not keeping up or is not running.
- **Snapshot restore time:** If restoring a snapshot requires scanning the full StructStore, the document may need splitting rather than GC.

---

## Additional Patterns (from De-Factoring)

### Type Composition via AbstractType Hierarchy

Each nested type (Y.Map, Y.Array, Y.Text) is an independent CRDT instance linked to its parent via `_item` backref. Single-parent constraint enforces a proper tree; conflict resolution is scoped per-type (YATA for lists, LWW for maps).

**De-Factoring Evidence:**
- **If removed:** Without single-parent constraint, the type graph becomes a DAG — deleting one parent but not another creates inconsistent views across peers. Without `_item` backrefs, cascade deletion cannot find the parent.
- **Detection signal:** Bug "deleting item in view A removes content from view B"; data model shows attempts to nest the same Y.Type under multiple parents.

### UndoManager-GC Coordination

`keepItem()` sets `item.keep = true` on items referenced by undo stack entries, exempting them from GC. Clearing the undo stack releases items for collection.

**De-Factoring Evidence:**
- **If removed:** Undo becomes unreliable on long-lived documents. GC collects items referenced by the undo stack; Ctrl+Z silently does nothing or produces garbage from GC structs.
- **Detection signal:** Undo works in short sessions but fails in long ones; clearing undo history causes a sudden memory drop; users report "undo stopped working after I left the document open all day."

### Content Type Polymorphism

Items hold content via a polymorphic `content` field (`ContentString`, `ContentType`, `ContentFormat`, `ContentDeleted`, etc.). Each implements `integrate()`, `gc()`, `delete()`, `mergeWith()`, and encoding/decoding.

**De-Factoring Evidence:**
- **If removed:** Item becomes a god object with dozens of conditional branches. Adding a new content kind (e.g., `ContentEmbed`) requires shotgun surgery across the core CRDT, GC, sync encoding, and merge logic.
- **Detection signal:** Adding a new embeddable content type requires modifying core CRDT files; GC or sync code has switch/case on content kind; merge optimization only works for some content types.
