# Tree Mutation Patterns

## The Problem

Insert, move, and delete operations in a user-facing resource hierarchy must maintain structural invariants: no cycles, correct parent-child relationships, valid nesting depth, and consistent ordering — all while feeling instant to the user and converging correctly in multiplayer.

The challenge escalates with hierarchy depth. A flat list has one invariant (ordering). A two-level hierarchy adds containment. A deep hierarchy adds transitive containment, nesting-depth limits, type-based nesting rules (e.g., "a mask can only be a child of a layer, not a group"), and recursive property propagation (visibility, opacity, transforms).

## Competing Patterns

### 1. Immutable Tree with Path-Based Updates

**How it works**: The tree is an immutable data structure. Mutations produce a new root, sharing unchanged subtrees (structural sharing). Nodes are addressed by path from root.

**Characteristics**:
- Natural undo: keep previous roots
- Path invalidation: a sibling insert changes all subsequent paths
- Snapshot isolation: readers never see partial mutations
- Memory pressure from deep trees with frequent mutations

**Production example — Krita (KisNodeManager)**:
Krita's `KisNode` tree uses a hybrid: the node tree itself is mutable, but mutations go through a command pattern (`KisProcessingApplicator`) that produces undoable operations. Each command captures before/after state. The node tree is the source of truth, but the command log provides immutable history.

Key insight: Krita separates *structural mutations* (add/remove/reparent node) from *property mutations* (change opacity, toggle visibility). Structural mutations are heavyweight commands; property mutations are lightweight signals. This matters because structural mutations affect render pipeline topology while property mutations only affect render parameters.

**When to choose**: Single-user applications with deep trees where undo fidelity matters more than sync. Good when tree structure changes are infrequent relative to property changes.

### 2. Mutable Tree with Validation Hooks

**How it works**: Nodes hold direct parent/children references. Mutations modify in place. Pre-mutation hooks validate invariants; post-mutation hooks propagate side effects.

**Characteristics**:
- Simple mental model: "just move the node"
- Validation logic can grow complex (hook ordering, re-entrancy)
- Hard to make concurrent-safe without locks
- Undo requires explicit inverse operation recording

**Production example — tldraw**:
tldraw stores shapes in a flat record store (`TLStore`) with `parentId` and `index` fields. The "tree" is implicit — reconstructed by querying shapes with a given parentId. Reparenting is just updating `parentId` and `index`. Validation happens in the store's `onBeforeChange` hooks.

Key insight: tldraw avoids deep tree structures by limiting nesting. Pages contain shapes. Frames contain shapes. Groups contain shapes. But frames don't contain frames (in practice). This sidesteps most deep-hierarchy problems.

The `index` field uses fractional indexing (string-based sort keys) so inserting between two siblings never requires reindexing other siblings — critical for multiplayer convergence.

**When to choose**: When hierarchy is shallow (2-3 levels max) and multiplayer is a requirement. Flat-store-with-parent-refs is the most sync-friendly non-CRDT pattern.

### 3. Event-Sourced Tree Operations

**How it works**: All mutations are expressed as events (NodeAdded, NodeMoved, NodeDeleted). Current state is derived by replaying events. Tree is a projection.

**Characteristics**:
- Perfect audit trail
- Undo is event reversal (but: not all events are trivially reversible)
- Multiplayer via event broadcast + conflict resolution
- Rebuild cost grows with event count; needs snapshotting

**Production example — IIIF Manifest Editor (manifest-editor-core)**:
The IIIF manifest editor uses a vault (normalized store) with change tracking. Ranges create a DAG structure (a canvas can appear in multiple ranges). Mutations are captured as change descriptors. The vault reconciles by re-normalizing after each batch of changes.

Key insight: When your hierarchy is actually a DAG (shared children), event sourcing lets you reason about "which parent initiated this change" — information lost in a snapshot-based approach. The manifest editor needs this because reordering canvases within one range shouldn't affect their position in another range.

**When to choose**: When you need full history, when the hierarchy is a DAG rather than a strict tree, or when multiplayer conflict resolution needs operation-level granularity.

### 4. CRDT Tree

**How it works**: Tree structure is represented using CRDT types (Yjs nested maps/arrays, Loro tree type). Mutations are local-first and merge automatically across peers.

**Characteristics**:
- Automatic convergence without central server
- "Move" is delete + insert (can cause duplication or loss under concurrent edits without move operation)
- Yjs arrays handle concurrent inserts well; concurrent moves are hard
- Schema validation must happen post-merge (invalid states are transiently possible)

**Production example — drafft-ink**:
drafft-ink uses Loro CRDT for its canvas hierarchy. Shapes, groups, and layers are stored in Loro's tree structure. Loro provides a dedicated `MovableTree` type that handles concurrent moves without duplication — a significant advantage over Yjs where move = delete + insert.

Key insight: The choice of CRDT library determines your tree mutation semantics. Yjs nested types give you concurrent insert/delete but not atomic move. Loro's `MovableTree` gives you atomic move but with specific conflict resolution rules (last-writer-wins on parent). Know your library's semantics before designing your hierarchy.

**When to choose**: Local-first multiplayer is a hard requirement. Accept that conflict resolution will sometimes produce surprising results and design UI to surface/resolve those surprises.

## Decision Guide

| Factor | Immutable Tree | Mutable + Hooks | Event-Sourced | CRDT Tree |
|---|---|---|---|---|
| Hierarchy depth | Deep (5+) | Shallow (2-3) | Any | Shallow-medium |
| Multiplayer | Hard | Medium (with fractional index) | Medium | Native |
| Undo fidelity | Excellent | Manual | Excellent | Library-dependent |
| DAG support | Awkward | Natural (multi-parent refs) | Natural | Library-dependent |
| Implementation complexity | Medium | Low | High | Medium (library does work) |
| Performance at scale | Good (structural sharing) | Best | Needs snapshots | Library-dependent |

## Anti-Patterns

### The Phantom Reparent
Storing parent-child as a property on the child (`node.parentId = x`) without also updating the parent's children list. Creates ghost nodes — children that think they belong to a parent that doesn't know about them. Always make reparent a transaction that updates both sides.

### The Fragile Path
Addressing nodes by path (`/root/group1/layer3`). Any structural change (insert sibling, reparent ancestor) invalidates paths. Use stable IDs, resolve paths at read time.

### The Recursive Validate
Running full-tree validation after every mutation. O(n) per operation makes bulk operations O(n^2). Validate only the affected subtree. Better: maintain invariants incrementally via pre-mutation checks.

### The Sync-Naive Move
Implementing move as delete + insert in a multiplayer context without atomic move semantics. Concurrent moves can duplicate or lose nodes. Either use a CRDT with move support (Loro) or implement a move operation with tombstone + redirect.

### The Undo-Unaware Reparent
Capturing reparent for undo as "set parentId to old value" without capturing the index/position within the old parent's children list. Undo restores the parent but puts the node at the wrong position.

### The Type-Blind Nesting
Allowing any node type under any parent. Then discovering that "mask inside mask" or "page inside frame" creates nonsensical render/behavior. Define a nesting grammar upfront: which node types can be children of which parent types, and at what maximum depth.

## Additional Evidence

### Flat Collection-Membership with Cross-Collection Operations (Ente)

**Source**: Ente Photos — E2E encrypted photo platform (Go server, Flutter mobile, TS/React web).

Ente uses a flat collection-to-file membership model rather than a tree hierarchy. Collections (albums, folders, favorites, uncategorized) are top-level containers; files belong to collections via membership rows. There is no nested collection support — the hierarchy is strictly one level deep.

**Why this matters for tree mutation**: A single file can belong to multiple collections simultaneously. This makes cross-collection operations (move, share, trash) into multi-parent graph mutations rather than simple reparent operations:

- **Move**: Removing a file from collection A and adding to collection B must be atomic. If the file also belongs to collections C and D, those memberships are unaffected — but the user may not realize the file still "exists" elsewhere.
- **Share**: Sharing a collection grants access to all its files. But a file in a shared collection may also belong to a private collection. The sharing operation doesn't propagate — it's scoped to the collection, not the file.
- **Trash**: "Move to trash" must propagate across all collection memberships. A file trashed from one collection must be removed from all collections owned by that user, or the trash semantics become incoherent.
- **Key hierarchy coupling**: Each collection has its own encryption key. A file's key is encrypted with the collection key. Multi-collection membership means the file key is encrypted multiple times, once per collection. Removing a file from a collection means deleting one encrypted-key binding without affecting others.

**Pattern**: This is the **Mutable + Hooks** pattern (Pattern 2) applied to a flat structure. The "tree" is only one level deep, but the multi-parent membership creates DAG-like mutation complexity. Validation hooks must ensure: (a) at least one collection membership remains for non-trashed files, (b) trash propagates across all memberships, (c) sharing scopes to collection boundaries, not file boundaries.

**Contrast with IIIF manifest editor**: Both handle multi-parent membership, but IIIF uses event-sourced mutations because range ordering matters per-parent. Ente uses direct DB mutations because collection membership is unordered — a file is "in" a collection or not, with no positional semantics.
