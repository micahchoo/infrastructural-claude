# Element Ordering in Distributed State

**Force tension:** Array position is fast for local z-index manipulation but doesn't converge when multiple clients reorder simultaneously.

## The Problem

Canvas and layer-based editors need ordered collections — z-index determines what renders on top. Locally, `Array.splice` and swap operations are O(1) and trivial. But in multiplayer:

- **Two clients reorder simultaneously** — array indices diverge, no automatic convergence
- **Last-write-wins on arrays** — one client's reorder silently erases the other's intent
- **Insertion at index N** — meaningless when another client has already shifted the array

The core issue: array indices are *positional* (implicit from structure) not *intrinsic* (carried by the element). Distributed systems need intrinsic ordering.

## Competing Patterns

### 1. Fractional Indexing

**How it works:** Each element carries a sortable string/number key. Inserting between elements A (0.25) and B (0.5) assigns ~0.375. No other elements shift. Clients sort by this key to derive render order.

**Production examples:**
- **Figma** — pioneered fractional indexing for layer ordering in collaborative design
- **tldraw** — `IndexKey` type in `TLRecord` schema; ordering syncs through the store protocol; uses string-based fractional indices for arbitrary precision

**When to use:**
- Most collaborative canvas/layer editors
- When reordering is infrequent relative to other mutations
- When you want ordering to compose naturally with property-level LWW sync

**When NOT to use:**
- When elements are reordered hundreds of times per second (precision degrades fast)
- When you need the array itself for iteration-order-dependent logic beyond rendering

**Tradeoffs:**
- Simple to implement, no CRDT library needed
- Convergent — independent inserts between the same neighbors produce distinct keys
- Requires periodic rebalancing when keys grow too long (precision exhaustion)
- Concurrent inserts between the same two elements produce a *defined* but *arbitrary* relative order — acceptable for z-index, problematic for text

### 2. Dual Representation with Sync (Array + Fractional)

**How it works:** Maintain both an array (for fast local operations like "move to front") and fractional indices (for multiplayer convergence). A sync layer keeps them consistent.

**Production example:**
- **Excalidraw** — `syncMovedIndices` updates fractional indices after local array moves; `syncInvalidIndices` repairs inconsistencies. Validation is throttled to once per minute to avoid performance overhead. Neither representation is authoritative alone — they cross-validate.

**When to use:**
- When local performance for z-ordering operations is critical (frequent bring-to-front, send-to-back)
- When you're adding multiplayer to an existing array-based system and can't rewrite all ordering logic
- When you need both fast local iteration (array) and convergent sync (fractional)

**When NOT to use:**
- Greenfield projects — just use fractional indexing directly, dual representation adds complexity
- When ordering changes are rare — the sync overhead isn't justified

**Tradeoffs:**
- Best local performance (array operations are O(1))
- Adds a sync/validation layer that can have bugs (two sources of truth)
- Throttled validation means brief windows of inconsistency
- More code to maintain and reason about

### 3. CRDT Sequence Types

**How it works:** Use a CRDT array type (e.g., Yjs `Y.Array`, Automerge list) that handles concurrent insertions, deletions, and moves with guaranteed convergence.

**Production examples:**
- Any Yjs-based collaborative editor using `Y.Array` for element ordering
- Automerge lists with move operations

**When to use:**
- When you're already using a CRDT library for other state (document content, etc.)
- When ordering operations are complex (concurrent moves, not just inserts)
- When offline-first is a hard requirement and ordering must converge after long partitions

**When NOT to use:**
- Simple z-ordering in a canvas — this is overkill
- When you don't want a CRDT runtime dependency
- When bandwidth matters — CRDT sequences carry metadata overhead

**Tradeoffs:**
- Guaranteed convergence with strong semantics (including concurrent moves)
- Heavier: memory, bandwidth, and complexity overhead
- Interleaving anomalies possible with concurrent inserts at the same position
- Library lock-in

### 4. Server-Authoritative Array (Simple LWW)

**How it works:** Server holds the canonical array order. Clients send reorder operations; server applies them sequentially and broadcasts the result. Conflicts resolved by server ordering.

**When to use:**
- Always-connected architectures with low-latency server
- When ordering conflicts are rare (few concurrent reorderers)
- When simplicity matters more than offline support

**When NOT to use:**
- Offline-first or peer-to-peer architectures
- When reorder latency would be noticeable (optimistic local reorder then rollback is jarring)
- High-frequency reordering by multiple users

**Tradeoffs:**
- Simplest to implement and reason about
- No convergence issues — server is authoritative
- Requires round-trip for confirmed order; optimistic local reorder may flash/revert
- No offline support

## Decision Guide

1. **Are you already using a CRDT library for other state?** → Consider using its sequence type for ordering too (pattern 3). Consistency of approach may outweigh the overhead.
2. **Is this a greenfield collaborative editor?** → Start with fractional indexing (pattern 1). It's the best balance of simplicity and convergence.
3. **Are you retrofitting multiplayer onto an existing array-based system?** → Dual representation (pattern 2) lets you keep existing array logic while adding convergence.
4. **Is the system always-connected with a central server?** → Server-authoritative (pattern 4) if ordering conflicts are rare and latency is acceptable.
5. **How often do elements get reordered?** → High frequency favors patterns with fast local operations (2 > 1 > 4 > 3).

## Anti-Patterns

### Array.splice in multiplayer
Using raw array index operations in distributed state. Indices are positional, not intrinsic — concurrent splices at different indices corrupt ordering. Every production multiplayer editor has moved away from this.

### CRDT sequences for simple z-ordering
Using `Y.Array` or Automerge lists solely for layer stacking order. The overhead (memory, sync bandwidth, library dependency) isn't justified when fractional indexing achieves convergence with a single sortable property per element.

### Fractional indexing without rebalancing
Repeated insertions between the same two elements cause key length to grow without bound (binary subdivision exhausts precision). Production systems need periodic rebalancing — either on a timer (Excalidraw: 1/min validation) or when key length exceeds a threshold. Rebalancing must itself be a synchronized operation.

### Treating array order and fractional index as independently authoritative
If you use dual representation, one must be derivable from the other, or you need explicit cross-validation. Two independent sources of truth for the same semantic (render order) will diverge silently.
