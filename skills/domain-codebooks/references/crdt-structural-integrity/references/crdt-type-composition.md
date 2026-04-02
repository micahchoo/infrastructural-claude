# CRDT Type Composition

## The Problem

Real applications don't use a single CRDT type. They compose them: a map of arrays of text blocks, a list of objects each containing a map, a tree of nodes where each node holds a text CRDT. Each composition layer multiplies the conflict resolution complexity.

The fundamental challenge: **conflict resolution semantics at each nesting level interact in ways that are not obvious from the semantics of each level in isolation.**

A concurrent insert into a Y.Array inside a Y.Map behaves differently than a concurrent insert into a standalone Y.Array, because the map entry itself might be concurrently deleted -- and the conflict resolution for "insert into a deleted container" is a policy choice, not a mathematical inevitability.

---

## Competing Patterns

### 1. Yjs Shared Types (Y.Map, Y.Array, Y.Text, Y.XmlFragment)

**Architecture:** Yjs provides a fixed set of shared types that can be nested. Each shared type is a first-class CRDT with its own conflict resolution. Nesting is achieved by setting a shared type as a value within another shared type.

**Composition rules:**
- A shared type can only belong to ONE parent. Moving a shared type is delete-from-old + insert-into-new (not atomic).
- Deleting a parent does NOT recursively delete children in the StructStore. The children become orphaned but their operations persist (important for undo).
- Y.Map uses last-writer-wins (LWW) for same-key concurrent sets. The "winner" is determined by client ID ordering, not timestamp.
- Y.Array uses the YATA algorithm for concurrent inserts. Position is determined by the left/right origin items at the time of insertion.
- Y.Text is a specialized Y.Array with formatting attributes. Concurrent format changes on overlapping ranges merge attribute maps.
- Y.XmlFragment extends Y.Array with XML-specific operations.

**Nesting conflict example:**
- Peer A sets `map.set("key", new Y.Array())`
- Peer B sets `map.set("key", new Y.Text())`
- LWW resolves: one type wins, the other is tombstoned
- Any operations applied to the losing type by its creating peer become no-ops targeting a tombstoned parent

**Trade-offs:**
- Well-understood, battle-tested
- Fixed type vocabulary limits expressiveness
- No move operation (delete + insert is not atomic under concurrency)
- Orphaned children after parent deletion consume memory until GC

### 2. Automerge Nested Objects

**Architecture:** Automerge models the document as a JSON-like tree. Objects, arrays, and text are native types. Every object gets an internal object ID. Operations target objects by ID, not by path.

**Composition rules:**
- Objects can be nested arbitrarily
- Concurrent modifications to the same key in an object produce a "conflict" that surfaces both values. The application must resolve.
- Arrays use a list CRDT (RGA-based) for concurrent inserts
- Text is a specialized array of characters with marks (formatting spans)
- Object IDs are stable across edits -- moving a reference is possible by storing the object ID

**Nesting conflict example:**
- Peer A sets `doc.key = { nested: "a" }`
- Peer B sets `doc.key = { nested: "b" }`
- Both values are retained as conflicts on `doc.key`
- Application must call `getConflicts()` and resolve

**Trade-offs:**
- Richer conflict model (conflicts are surfaced, not auto-resolved)
- Application must handle conflicts -- more work, more control
- Object ID indirection enables move semantics
- Branching model means nested edits on different branches can be diffed and merged
- Conflict resolution is ultimately application-level, not library-level

### 3. Loro Containers

**Architecture:** Loro uses typed containers as the unit of composition. Each container has a container ID and a CRDT type. Containers can reference other containers, forming a tree.

**Composition rules:**
- Containers are explicitly typed (List, Map, Text, Tree, MovableList)
- MovableList is a first-class type -- move operations are atomic, unlike Yjs delete+insert
- Tree container provides native tree CRDT (parent-child relationships with move)
- Fractional indexing within list containers allows position-preserving inserts
- Each container can be independently snapshotted or GC'd

**Nesting conflict example:**
- Concurrent moves of the same tree node to different parents are resolved by the Tree CRDT's move semantics (prevents cycles, picks a winner)
- This is a structural improvement over "delete + insert" in Yjs which can lose the subtree

**Trade-offs:**
- Richest type vocabulary (especially Tree and MovableList)
- Container-level granularity enables per-type GC policies
- Newer, less ecosystem support
- Fractional index overhead in list containers (index entropy over time)

---

## Decision Guide

```
Does your data model require MOVE operations (reordering lists, reparenting tree nodes)?
  YES --> Does it involve tree structures (parent-child)?
            YES --> Loro Tree container (native move, cycle prevention)
            NO  --> Loro MovableList or Automerge (object ID indirection)
  NO  --> Is surfacing conflicts to the application acceptable?
            YES --> Automerge (richer conflict model, branching)
            NO  --> Yjs (auto-resolved via LWW and YATA, simpler application code)

How deep is your nesting?
  1-2 levels --> Any library handles this well
  3+ levels  --> Prefer Automerge or Loro (object ID / container ID indirection)
                 Yjs deep nesting creates complex orphan chains on deletion
```

---

## Anti-Patterns

### 1. Path-Based References to Nested Types
Storing references to nested CRDT objects by their path (e.g., `"doc.layers[3].name"`) instead of by their CRDT identity (item ID, object ID, container ID). Concurrent operations can change the path without invalidating the reference.

**Fix:** Always reference nested CRDT objects by their stable identity. In Yjs, this is not directly exposed -- use a Y.Map with stable keys rather than Y.Array indices for referenced objects. In Automerge, use object IDs. In Loro, use container IDs.

### 2. Implicit Type Assumptions After Concurrent Edits
Assuming a map value is still a Y.Array after concurrent edits. If another peer replaced it with a Y.Text (or deleted the key entirely), operations on the assumed type will silently fail or corrupt state.

**Fix:** Always check the type of a nested value before operating on it. In reactive frameworks, observe the parent for changes and re-resolve nested references.

### 3. Deep Nesting Without Structural Boundaries
Nesting CRDTs 5+ levels deep without intermediate structural boundaries. This makes GC difficult (can't GC a subtree without walking from root), makes sync expensive (every nested operation must include its full path for context), and makes conflict resolution opaque.

**Fix:** Flatten where possible. Use a map-of-maps with stable IDs instead of deeply nested trees. If deep nesting is required, use Loro's container architecture which provides natural boundaries.

### 4. Concurrent Container Type Changes
Allowing concurrent operations to change the CRDT type of a nested value (e.g., replacing a Y.Array with a Y.Map at the same key). The losing type's operations become unreachable but still consume space.

**Fix:** Use a schema or type constraint layer. If a key's type is fixed at schema level, concurrent type changes are prevented at the application layer. Alternatively, use Automerge's conflict surfacing to detect and resolve type changes explicitly.

### 5. Array Index Arithmetic Across Peers
Computing array indices on one peer and sending them to another peer as plain integers. Between computation and receipt, concurrent inserts/deletes can shift all indices.

**Fix:** Never transmit raw array indices across peers. Use CRDT item IDs to identify positions. In Yjs, use `Y.createRelativePositionFromTypeIndex()` to create a position that survives concurrent edits. In Automerge, reference by object ID. In Loro, use fractional indices.

### 6. Atomic Multi-Container Operations Without Transactions
Modifying multiple nested containers expecting atomicity, without wrapping in a transaction. If the operation fails halfway or is interleaved with concurrent operations, the document enters an inconsistent intermediate state.

**Fix:** Use Yjs `doc.transact()`, Automerge `doc.change()`, or Loro's transaction API. These ensure all modifications within the transaction are applied as a single operation in the causal history.

---

## Yjs Production Deep Dive: Ownership and Cascade Semantics

### Single-Parent Tree with `_item` Backrefs

Every Yjs shared type (`AbstractType` subclass) maintains an `_item` backref
pointing to the `Item` that contains it. This enforces a **strict single-parent
rule**: a shared type can belong to exactly one parent Item. The document forms
a proper tree, not a DAG.

```
Doc (root)
  └─ Y.Map ("root map")          _item → Item#1
       ├─ Y.Array ("shapes")     _item → Item#2
       │    ├─ Y.Map (shape-1)   _item → Item#3
       │    └─ Y.Map (shape-2)   _item → Item#4
       └─ Y.Text ("title")       _item → Item#5
```

**Integration of nested types:** When a `ContentType` is integrated into the
document (via `ContentType.integrate()`), it sets the child type's `_item`
backref and calls the type's `_integrate()` method, which connects it to the
document's event system. If a type's `_item` is already set to a different
parent, the behavior is undefined — the single-parent constraint must be
maintained by the application layer.

**Implication for moves:** Moving a shared type between parents is NOT atomic.
It requires delete-from-old + insert-into-new, creating a window where the type
exists in neither location. During this window, concurrent operations targeting
the type may be lost (late-arrival discard if the old parent is GC'd).

### Per-Type Conflict Resolution

Each Yjs shared type implements its own conflict resolution, scoped entirely
within that type's linked list of Items:

| Type | Algorithm | Resolution |
|------|-----------|------------|
| **Y.Array** | YATA | Concurrent inserts ordered by left/right origin items + client ID tiebreaker |
| **Y.Map** | LWW (Last Writer Wins) | Same-key concurrent sets resolved by client ID ordering (not timestamp) |
| **Y.Text** | YATA + attributes | Character ordering via YATA; concurrent format changes merge attribute maps |
| **Y.XmlFragment** | YATA (inherits from Y.Array) | Same as Y.Array for child ordering |

**Cross-type conflicts don't exist** because each type is an independent CRDT
instance. A concurrent insert into a Y.Array and a concurrent set on the Y.Map
that contains it are resolved independently — the map's LWW may tombstone the
array entirely, making the array insert a no-op targeting a deleted parent.

### ContentType Cascade on Deletion

When a parent Item containing a nested type (`ContentType`) is GC'd:

1. `Item.gc()` calls `content.gc(tr)` on the `ContentType`
2. `ContentType.gc()` walks the nested type's entire item linked list
3. Each child item is GC'd with `parentGCd=true`, which causes immediate
   replacement with GC structs (no intermediate ContentDeleted stage)
4. If any child item itself contains a `ContentType`, the cascade recurses

This recursive cascade ensures that GC'ing a Y.Map containing a Y.Array of
Y.Text objects will GC the entire subtree. The `parentGCd=true` flag is the
mechanism that distinguishes "this item was independently deleted" from "this
item's parent container was destroyed" — the latter is more aggressive.

**Memory implication:** A single `map.delete(key)` where the value is a deeply
nested type tree can trigger GC of thousands of items in one transaction commit.
This is correct but can cause latency spikes.

Source: `src/types/AbstractType.js`, `src/types/YMap.js`, `src/types/YArray.js`,
`src/types/ContentType.js`, `src/structs/Item.js`

---

## Key Considerations

- **Schema evolution:** Adding new nested types to a document schema requires careful migration. Old peers that don't know about the new type will ignore or tombstone its operations.
- **Observation granularity:** Observing changes at the root level of a deeply nested document is expensive. Prefer observing at the relevant nesting level. Yjs `observeDeep` vs `observe` is this trade-off.
- **Serialization cost:** Deeply nested documents produce larger sync messages because each operation must encode its path context. Flatter structures produce smaller, more efficient sync payloads.
- **Testing:** Test concurrent operations at EVERY nesting level. Bugs in composition almost always appear as "works fine with sequential edits, breaks with concurrent edits at specific nesting depths."
