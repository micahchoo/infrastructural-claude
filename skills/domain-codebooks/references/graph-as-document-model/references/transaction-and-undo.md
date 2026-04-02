# FC3 Codebook: Transaction and Undo

**Force Cluster**: Graph-as-Document Model
**Seams covered**: 18 (`TransactionStatus` — Started/Modified/Finished), 17 (`GraphOperationMessage` as atomic unit)

---

## The Problem

Graph mutations are low-level: connect this port, set this input value, insert this node. A single user action (e.g., "move layer") may require dozens of individual graph mutations: update transform node input, invalidate downstream caches, update metadata, push frontend state. If each mutation is a separate undo step, pressing Ctrl+Z after a move produces nonsensical intermediate states.

The core design question: **what is the unit of undo?**

Forces in tension:
- **Atomicity vs granularity**: The undo unit should match user intent (one action = one undo step), but users also want fine-grained undo for long sequences.
- **Safety vs simplicity**: Rollback on failure requires storing enough state to reverse partial mutations, but snapshot-before-mutation is expensive for large graphs.
- **Collaboration vs isolation**: Undo in a collaborative system must not revert other users' changes — but local undo stacks are cheap.
- **Nested transactions**: Compound operations (e.g., "paste with transform") need undo atomicity, but simple operations should not pay the overhead of transaction bookkeeping.

---

## Pattern 1: Snapshot-Based Undo

**Examples**: Excalidraw (clone `elements` array), early Krita, many game editors

**Mechanism**: Before any mutation, clone the entire document state. The undo stack is a stack of complete prior states. Undo = pop from stack, set as current state. Redo = push current state, pop from redo stack.

**Implementation sketch**:
```
// Before mutation
const snapshot = JSON.parse(JSON.stringify(elements));
undoStack.push(snapshot);
// Mutate
elements[i].x += 10;
```

**What this buys**:
- Trivially correct. No partial state, no inversion logic.
- Undo and redo are O(1) operations (pointer swap on persistent data structures).
- No need to define "inverse" for any operation.
- Works correctly even if mutations have side effects outside the document model.

**What this costs**:
- Memory: each snapshot is a full copy. For a 10MB document with 100 undo steps, that is 1GB of undo history.
- With persistent/immutable data structures (Clojure, Immer), structural sharing reduces this to near-zero for small mutations — but only if the mutation is expressed as a pure transformation.
- Not suitable for mutable graph structures with pointer-based identity (Rust `NodeNetwork`).
- Collaboration: you cannot merge two independent snapshot histories.

**Structural sharing optimization** (Penpot/Clojure): Clojure's persistent maps share unchanged subtrees. A mutation that changes one shape reuses all unmodified shape records. Snapshot cost becomes proportional to the size of the change, not the document.

**When to choose**: Simple documents with small state, or systems built on persistent data structures. Wrong choice for Rust-native graph structures or very large documents.

---

## Pattern 2: Command Pattern Undo (Inverse Operations)

**Examples**: Most desktop applications (LibreOffice, Inkscape), classic GoF Command pattern

**Mechanism**: Each mutation is expressed as a `Command` object with `execute()` and `undo()` methods. The undo stack stores command objects, not snapshots. Undo calls `command.undo()` which applies the inverse operation.

**Implementation sketch**:
```rust
trait Command {
    fn execute(&mut self, state: &mut AppState);
    fn undo(&mut self, state: &mut AppState);
}

struct MoveLayerCommand { layer_id: NodeId, dx: f64, dy: f64 }
impl Command for MoveLayerCommand {
    fn execute(&mut self, s: &mut AppState) { s.translate(self.layer_id, self.dx, self.dy); }
    fn undo(&mut self, s: &mut AppState)    { s.translate(self.layer_id, -self.dx, -self.dy); }
}
```

**What this buys**:
- Memory efficient: only the delta is stored, not the full snapshot.
- Composable: commands can be grouped into `MacroCommand` (composite) for atomicity.
- Serializable: command history can be replayed for collaboration or crash recovery.
- Well-understood pattern with decades of precedent.

**What this costs**:
- Every operation must define its own inverse. For graph operations, inverses are non-trivial: "delete node" must store the full node definition to undo; "connect edge" must record which edge was displaced.
- Inverses can be wrong. A `MoveLayerCommand` whose inverse is `-dx, -dy` breaks if another operation moved the layer in between (though in single-user systems this is rare).
- Compositing commands that modify shared state (e.g., two commands that both modify the same node's inputs) require careful ordering.
- The inverse of "create node with auto-generated ID" must store the generated ID for later deletion — requiring mutation of the command object after execution.

**When to choose**: Desktop applications with a finite, well-understood set of operations and no collaboration requirement. Good default for mid-complexity tools.

---

## Pattern 3: Transaction State Machine

**Example**: Graphite (`TransactionStatus` enum in `network_interface.rs:6486`)

**Mechanism**: `NodeNetworkInterface` tracks a `TransactionStatus` field with three states:

```rust
#[derive(Clone, Copy, Debug, Default, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum TransactionStatus {
    Started,
    Modified,
    #[default]
    Finished,
}
```

The lifecycle:
1. `start_transaction()` → sets `Started`
2. Any graph mutation calls `transaction_modified()` → transitions `Started → Modified` (idempotent if already `Modified`)
3. `finish_transaction()` → sets `Finished`; the dispatcher interprets this as a signal to push an undo checkpoint

The `Modified` state distinguishes "transaction opened but nothing changed yet" from "transaction has real mutations." This prevents empty undo steps when a transaction is opened speculatively (e.g., while the user is hovering before dragging).

**What this buys**:
- Lightweight: no command objects, no snapshot allocation. The state machine is a single enum field.
- Groups arbitrary sequences of graph mutations into a single undo step — the tool handler opens a transaction, performs all mutations (fill set, transform set, metadata update), then closes it.
- The `Started → Modified` transition allows tools to open transactions eagerly without polluting the undo stack on no-ops.
- Compatible with the existing message-dispatch architecture: the dispatcher checks `TransactionStatus` after each message cycle.

**What this costs**:
- No rollback. If a mutation fails mid-transaction, the graph is in a partially-mutated state. There is no `Rollback` or `Aborted` state.
- No nesting. A transaction opened inside another transaction flattens — there is no stack of transaction contexts.
- The actual undo snapshot (or diff) must be computed elsewhere. `TransactionStatus` only marks *when* to take a checkpoint; the checkpointing mechanism is separate.
- Thread unsafety: `TransactionStatus` is on `NodeNetworkInterface` which is owned by the document. If multiple message handlers run concurrently (currently they do not, but future concurrency would break this).
- The three-state machine is easy to misuse: forgetting to call `finish_transaction()` leaves the status in `Started` or `Modified`, suppressing future undo checkpoints.

**De-factoring thought experiment**: Remove `TransactionStatus`. Every graph mutation becomes its own undo step. Pressing Ctrl+Z after dragging a layer would undo one pixel of movement at a time — or whichever granularity the lowest-level graph mutation operates at. User experience degrades immediately.

**When to choose**: Message-dispatch architectures where operations are expressed as high-level messages (not low-level graph mutations) and a single-threaded event loop serializes all mutations. The state machine is a lightweight, good-enough solution for single-user nondestructive editors.

---

## Pattern 4: Record-Diff Undo

**Example**: tldraw (`RecordsDiff<R>` — `{ added, removed, updated }`)

**Mechanism**: Every store mutation produces a `RecordsDiff` — a typed diff describing which records were added, removed, or updated (as `[before, after]` pairs). The undo stack stores these diffs. Undo = apply the inverse diff (swap added/removed, swap before/after in updated). Adjacent diffs from the same user action are squashed into one before pushing to the undo stack.

**Implementation sketch**:
```typescript
type RecordsDiff<R> = {
  added:   Record<Id, R>
  removed: Record<Id, R>
  updated: Record<Id, [R, R]>  // [before, after]
}
// Inverse: swap added↔removed, flip [before,after] → [after,before]
function invertDiff<R>(diff: RecordsDiff<R>): RecordsDiff<R> { ... }
```

**What this buys**:
- Collaboration-native: diffs can be sent to other clients. Undo is "apply inverse diff locally" without affecting others' changes (with appropriate CRDT or OT logic).
- Memory efficient: only the changed records are stored, not the full document.
- Schema-versioned: diffs reference records by ID and type, so they survive schema migrations.
- Squashing makes the undo stack match user intent without explicit transaction management.

**What this costs**:
- Squashing is heuristic: adjacent diffs are squashed if they occur "within the same action." Determining action boundaries requires either time-based windowing or explicit action markers — which reintroduces a form of transaction management.
- Diff inversion is not always semantically correct: if record A's `parentId` points to record B, and both are deleted in one diff, inverting restores A before B might exist again (ordering matters).
- Not applicable to systems with non-record state (e.g., Rust graph structures with pointer identity, GPU-side textures).

**When to choose**: Collaboration-first tools built on normalized record stores. The diff model and collaboration model align naturally, making this the obvious choice in that context.

---

## Pattern 5: Operational Transform / CRDT Undo

**Examples**: Google Docs (OT), Automerge (CRDT), Yjs (CRDT)

**Mechanism**: Every local mutation is expressed as an operation (OT) or a conflict-free action (CRDT) that can be applied in any order and converge to the same result. Undo is a special operation that marks a prior operation as "retracted" — the system recomputes state without the retracted operation, which may require replaying all subsequent operations against the retracted base.

**What this buys**:
- True collaborative undo: undoing your change does not undo other users' changes that happened concurrently.
- Convergence guarantees: two clients applying operations in different orders end up with the same document.

**What this costs**:
- Extremely complex to implement correctly. OT requires a central server to serialize operations; CRDT requires carefully chosen data types.
- "Intention preservation" (what the user intended to undo) is philosophically difficult in concurrent editing — especially for non-commutative operations like graph edge modifications.
- Performance: replaying all operations after a retraction is O(n) in history length.
- Not practical for single-user applications; significant complexity cost with no benefit unless collaboration is a hard requirement.

**When to choose**: Only when real-time collaborative editing with per-user undo is a hard requirement and the team has the capacity to implement and maintain the complexity.

---

## Decision Guide

| Criterion | Snapshot | Command/Inverse | Transaction SM | Record Diff | OT/CRDT |
|---|---|---|---|---|---|
| Implementation effort | Very low | Medium | Low | Medium | Very high |
| Memory per undo step | Full doc size | Delta only | Delta (elsewhere) | Delta only | Delta only |
| Rollback on failure | Yes (pop snapshot) | Yes (call undo()) | No | Yes (invert diff) | Partial |
| Nested transactions | Yes (nested snapshots) | Yes (MacroCommand) | No | Via squash | N/A |
| Collaboration-compatible | No | With server coordination | No | Yes (native) | Yes (native) |
| Correct for complex graph ops | Yes | Requires careful inverse | Depends on snapshot | Requires record model | Requires OT/CRDT design |

**Primary decision axis**: Is real-time collaboration a requirement? If yes, use Record-Diff or OT/CRDT. If no, Transaction State Machine (Graphite's approach) is the lowest-overhead solution for single-user nondestructive editors with a message-dispatch architecture.

**Secondary axis**: How complex are your inverse operations? If every graph mutation has a trivially invertible counterpart, Command Pattern is clean. If mutations have complex side effects and non-trivial inverses, Snapshot is safer (with persistent data structures to control cost).

---

## Anti-patterns

**Undo of undo**: A transaction that itself calls `undo`, which modifies state, which triggers another transaction. The state machine has no way to represent "this is an undo transaction" vs "this is a normal mutation transaction." Undo must be implemented outside the transaction boundary.

**Missing `finish_transaction()`**: In Graphite's model, if a message handler opens a transaction but returns early on an error path without calling `finish_transaction()`, the next user action will be merged into the same undo step. A `defer`-like mechanism (Rust's `Drop` trait on a transaction guard) prevents this.

**Too-fine undo granularity**: Treating each graph-level mutation (set one input, connect one edge) as an undo step. The user presses Ctrl+Z and gets half of a layer move. The fix is always to group mutations by user intent, not by graph operation count.

**Too-coarse undo granularity**: Grouping unrelated operations into one transaction because they happen in the same message cycle. If a tool handler processes two unrelated user intents in one message (e.g., "create node" and "rename node" triggered by two separate UI events batched together), they become one undo step. Message batching must respect transaction boundaries.

**Undo stack pollution from speculative opens**: Opening a transaction, checking some condition, then closing without modifying — if the state machine does not distinguish `Started` from `Modified`, an empty undo step is pushed. Graphite's `Started → Modified` transition prevents this.

**Inverse operation brittleness**: Defining a `MoveCommand` whose undo is `translate(-dx, -dy)` without accounting for transform-space. If the parent's transform changed between execute and undo (e.g., the layer was reparented), the inverse produces the wrong result. Store world-space snapshots, not relative deltas, for transform undos.
