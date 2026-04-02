# Atomic Side Effects

How to ensure that propagated changes from binding resolution are atomically
grouped with the triggering mutation — for undo, sync, and persistence.

---

## The Problem

A user moves a rectangle. Three arrows bound to it update their endpoints. The
user presses Ctrl+Z. What happens?

**Without atomicity:** Undo reverses the rectangle move. The arrows still have
their updated endpoints, now pointing to the rectangle's old position incorrectly
— or worse, the undo system recorded 4 separate operations (1 move + 3 arrow
updates) and the user must press Ctrl+Z four times.

**With atomicity:** Undo reverses the rectangle move AND all three arrow updates
in a single step. The canvas returns to its exact prior state.

The core challenge: the mutation system must treat "direct change + all
propagated effects" as a single atomic unit across three subsystems:

1. **Undo/redo** — one entry on the undo stack
2. **Persistence** — one write to storage
3. **Distributed sync** — one message to peers

---

## Competing Patterns

### 1. Transaction Wrapping

**How it works:** Before a mutation, open a transaction. All changes (direct and
propagated) are recorded within the transaction. On commit, the transaction
becomes a single undo entry, a single persistence write, and a single sync
message.

**Mechanism:**
```
beginTransaction()
  mutateShape(rect, { x: newX })        // direct change
  updateBoundElements(rect)              // propagation (mutates arrows)
commitTransaction()                      // all changes → one atomic unit
```

**Example — tldraw's store transactions:**

tldraw's `Store` supports transactions natively. The `Editor` wraps mutation
methods in `this.store.mergeRemoteChanges()` or batch operations. All record
changes within a transaction are captured as a single `RecordsDiff`. The history
system records one undo entry per transaction, containing the inverse diff for
all changed records.

The key insight: the Store doesn't know about bindings. It only knows about
records changing within a transaction boundary. Binding propagation is an editor
concern — the store just captures whatever changes happen between begin/commit.

**Tradeoffs:**
- Clean separation: store handles atomicity, editor handles propagation
- Works with any propagation strategy (immediate, deferred, solver)
- Requires discipline: forgetting to open a transaction before propagation
  breaks atomicity silently
- Nested transactions need a policy (flatten? independent? error?)

### 2. Delta Capture with Propagation Metadata

**How it works:** Every change produces a delta (before/after snapshot of
affected fields). Propagated changes produce their own deltas. All deltas from
one user action are tagged with a shared action ID and grouped.

**Mechanism:**
Each mutation returns its delta. Propagation returns additional deltas. The
system groups them:
```
ActionGroup {
  id: "action-123",
  deltas: [
    { element: "rect-1", field: "x", before: 100, after: 200 },  // direct
    { element: "arrow-1", field: "points", before: [...], after: [...] },  // propagated
    { element: "arrow-2", field: "points", before: [...], after: [...] },  // propagated
  ]
}
```

**Example — Excalidraw's delta system:**

Excalidraw captures changes as `Delta` objects that record the before and after
state of modified elements. When `updateBoundElements()` runs after a shape
mutation, it mutates the bound elements in place — but the change tracking
system captures deltas for ALL elements modified since the last snapshot.

The delta system doesn't distinguish "direct" from "propagated" at capture time.
It snapshots element state before and after the entire operation. This means the
undo entry naturally includes both the direct change and all side-effects,
because the snapshot boundary encompasses the full operation.

The critical design: snapshot boundaries align with user actions, not with
individual element mutations. One drag operation = one snapshot interval = one
undo entry, regardless of how many elements were modified by propagation.

**Tradeoffs:**
- Naturally captures everything that happened between snapshot boundaries
- No explicit transaction API needed — just snapshot at the right moments
- Deltas are serializable for sync and persistence
- Before/after snapshots can be large for complex propagation
- Snapshot timing must be precise: too early or too late breaks atomicity

### 3. Event Sourcing with Derived Events

**How it works:** The system records only user-initiated commands (events).
Propagated effects are derived by replaying the command against the current
state. Undo removes the command; replay recomputes the correct state.

**Mechanism:**
```
CommandLog: [
  { type: "move", elementId: "rect-1", dx: 100, dy: 0 }
]
// No propagated changes stored — they're recomputed from bindings on replay
```

Undo = remove last command, rebuild state from remaining commands.

**Example — Penpot's change algebra:**

Penpot's changes are data that describe transformations. When a change is
applied, the application layer computes all consequences (including containment
updates). Undo applies the inverse change, which also triggers its own
propagation. Because the data is immutable and changes are pure functions, replay
is deterministic.

The change algebra composes: `change1 + change2 = compound_change`. The compound
change includes both the direct mutation and propagated effects. Inverting the
compound change inverts everything atomically.

**Tradeoffs:**
- Elegant: only user intent is stored, everything else is derived
- Minimal storage: command log is compact
- Replay can be expensive for long command histories
- Propagation must be deterministic (same command + same state = same result)
- Non-trivial to implement when propagation has side-effects on ordering

---

## Decision Guide

**Choose Transaction Wrapping when:**
- You have (or plan to build) a record store with transaction support
- Multiple subsystems modify state during propagation
- You want propagation strategy to be independent of atomicity mechanism
- You're using tldraw's architecture or similar store-centric designs

**Choose Delta Capture when:**
- You want minimal API surface (no explicit transaction calls)
- Snapshot timing is well-defined (pointer-down to pointer-up, or similar)
- You need the deltas themselves for sync or persistence
- You're using Excalidraw's architecture or similar in-place mutation designs

**Choose Event Sourcing when:**
- You want the command log to be the source of truth
- Propagation is deterministic and you can afford replay
- You're using an immutable state architecture
- You want to avoid storing derived state entirely
- You're using Penpot's architecture or similar functional designs

---

## Combining Atomicity with Distributed Sync

The atomicity boundary must align with the sync boundary. Three strategies:

**1. Sync the atomic group.** Send all deltas (direct + propagated) as one sync
message. Peers apply the entire group. Simple but sends derived state over the
wire, risking conflicts on derived fields.

**2. Sync only the direct mutation, re-derive on each client.** Each client runs
its own propagation after applying the synced mutation. No derived state crosses
the wire. Requires deterministic propagation across clients. This is the
preferred approach when feasible.

**3. Hybrid.** Sync the direct mutation plus binding metadata. Peers re-derive
propagated effects using the binding metadata as hints. Handles cases where
binding state might differ across clients (e.g., concurrent binding creation).

---

## Anti-Patterns

### 1. Undo Per Element

Each element mutation gets its own undo entry. Moving a shape with 5 bound
arrows creates 6 undo entries. The user must press Ctrl+Z 6 times. Fix: group
all changes from one user action into one undo entry.

### 2. Propagation Outside Transaction

Direct mutation is inside a transaction, but the propagation call happens after
commit. The propagated changes land in a separate transaction (or worse, no
transaction). Fix: ensure propagation runs before the transaction commits.
Lint for this: any call to `updateBoundElements` (or equivalent) must be inside
an active transaction.

### 3. Derived State in Undo Stack

Storing propagated effects explicitly in the undo stack when they could be
re-derived. Leads to conflicts when the binding graph has changed between
do and undo (e.g., a binding was added or removed by another operation).
Fix: store only direct mutations in the undo stack; re-derive propagated
effects on both do and undo. Requires deterministic propagation.

### 4. Non-Deterministic Propagation

Propagation produces different results depending on iteration order, floating
point accumulation, or randomness. Breaks event sourcing (replay diverges),
breaks sync strategy 2 (clients disagree on derived state). Fix: sort by stable
ID at every decision point, use deterministic math, avoid hash-map iteration
where order matters.

### 5. Constraint Replay Passthrough (Side-Effect Disable During Undo)

During undo/redo replay in tldraw, side effects are explicitly disabled
(`sideEffects.setIsEnabled(false)`) before replaying the stored diff. This
works because binding propagation writes back to the store *within the same
batch* as the triggering mutation, so the recorded diff already contains the
fully-propagated state. On replay, restoring the raw diff is sufficient — no
re-propagation needed.

This prevents **double-propagation**: if side effects ran during replay, the
binding resolution would fire again on already-resolved state, potentially
producing incorrect results or infinite cascades.

**Key invariant:** If your propagation system writes derived state into the
same store transaction as the source mutation, the undo diff is
self-contained. You can skip all side-effect/propagation logic on replay.

**When this breaks:** If propagation has external effects (network calls, DOM
mutations, analytics) that must also be reversed, disabling side effects during
replay is insufficient. Those effects need their own compensation logic.

Source: `packages/editor/src/lib/editor/Editor.ts` (~lines 884-893),
`packages/store/src/lib/Store.ts` (~lines 1239-1271).

### 6. Unbounded Transaction Scope

A transaction is opened but propagation triggers further mutations that trigger
further propagation, all within the same transaction. The transaction grows
without bound, holding locks and accumulating memory. Fix: bound cascade depth
(see SKILL.md Principle 4), and set a maximum transaction size with a clear
error if exceeded.
