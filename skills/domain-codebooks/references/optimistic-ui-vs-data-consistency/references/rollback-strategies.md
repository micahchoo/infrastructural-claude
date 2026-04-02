# Rollback Strategies

## The Problem

When an optimistic mutation is rejected, conflicts with a remote change, or needs to be undone, the UI must revert to a correct state. The difficulty scales with how many mutations can be in-flight simultaneously and how interleaved local and remote changes are.

A single pending mutation that fails is simple: discard it, restore previous state. But collaborative editing produces situations where multiple local mutations are pending, remote mutations have arrived and been displayed, and the user has continued editing on top of speculative state. Rolling back one mutation in this stack requires replaying everything after it.

**De-Factoring Evidence (no rollback strategy):**
- **If removed:** Rejected operations leave ghost state — a deleted item reappears, a moved shape snaps to a wrong position, a renamed file shows its old name. Users learn to refresh the page after every conflict. Collaborative editing becomes a source of data corruption rather than productivity.
- **Detection signal:** Items that reappear after deletion. Properties that revert to old values seconds after being set. "Phantom" state that exists locally but not on server. Users reporting "my changes disappeared."

---

## Competing Patterns

### 1. Rebase-on-Commit (Penpot Pattern)

**Mechanism:** Penpot's `apply-changes-localy` in `changes.cljs` implements a rebase strategy when pending commits exist in the persistence queue:

1. **Undo all pending changes** — walk the queue backwards, applying each commit's undo-changes
2. **Apply new changes** on the clean base state
3. **Re-apply all pending changes** (including the new one) on top

This ensures that the local state is always "server-confirmed state + pending local changes in order." When the server responds with `lagged` (indicating remote changes arrived), the same rebase occurs: undo pending, apply remote, re-apply pending.

**The persistence queue:** `persistence.cljs` maintains a FIFO queue processed serially by `run-persistence-task`. On error, `discard-persistence-state` nukes the entire queue — a nuclear fallback when rebase cannot resolve the situation.

**Triple-state consistency:** With the WASM renderer active, changes must be applied to three representations simultaneously:
- ClojureScript application state (the source of truth for UI)
- Server-side persisted state (the source of truth for collaboration)
- WASM renderer model (the source of truth for canvas display)

`apply-changes-localy` calls `wasm.shape/process-shape-changes!` to push changes into WASM, meaning a rebase must also rebase the WASM state.

**Undo interaction:** `undo.cljs` implements open transactions that accumulate changes over time (up to 20s timeout). An undo during rebase must revert the user's logical action, not the rebased representation of it. Undo groups allow multiple operations to revert as a unit.

**Trade-offs:**
- Preserves local intent across remote changes
- Rebase is O(pending * changeset_size) on every new commit
- Error recovery is all-or-nothing (discard entire queue)
- Triple-state rebase (CLJS/WASM/server) multiplies complexity
- Undo transactions spanning a rebase boundary are conceptually fragile

**Key files:**
- `/frontend/src/app/main/data/changes.cljs` — `apply-changes-localy`, rebase logic
- `/frontend/src/app/main/data/persistence.cljs` — queue, serial persistence, discard
- `/frontend/src/app/main/data/workspace/undo.cljs` — transaction accumulation, groups
- `/frontend/src/app/main/data/workspace/notifications.cljs` — `handle-file-change` for remote merge

### 2. Version-Nonce Reconciliation (Excalidraw Pattern)

**Mechanism:** Excalidraw's `reconcileElements()` in `data/reconcile.ts` resolves local vs. remote element conflicts using two fields:
- `version` — incremented on each mutation
- `versionNonce` — random value set on each mutation, used for deterministic tiebreaking

When a remote update arrives:
1. Compare local and remote versions of each element
2. Higher version wins
3. On version tie, lower `versionNonce` wins (deterministic across all peers)
4. **Special cases:** Elements currently being edited (`editingTextElement`), resized (`resizingElement`), or newly created (`newElement`) are always kept local regardless of version

**No explicit rollback:** Instead of rolling back and replaying, Excalidraw treats each element independently. The reconciliation is a per-element merge, not a document-level rebase. This means:
- Local wins during active editing (UI state leaks into data-layer decisions)
- Remote wins for idle elements
- No queue of pending operations — each sync is a full state comparison
- Fractional index validation runs on throttled 1-minute intervals to catch ordering inconsistencies

**Trade-offs:**
- Simple per-element merge avoids rebase complexity
- UI state (`editingTextElement`) leaking into reconciliation creates coupling
- Full state comparison on each sync is O(elements) but avoids operation queuing
- Version ties are resolved deterministically but arbitrarily — no semantic merge
- No operation-level rollback; entire elements are replaced atomically

**Key files:**
- `packages/excalidraw/data/reconcile.ts` — `reconcileElements()`
- `packages/element/src/store.ts` — version/nonce tracking

### 3. No Rollback — Fire-and-Forget (Allmaps Pattern)

**Mechanism:** Allmaps has no rollback capability. When `mapsState.replaceGcp()` calls `this.#doc.submitOp(...)`:
- Local state updates immediately via `this.#maps = this.#doc.data`
- If the operation is rejected by the ShareDB server, no mechanism rolls back the TerraDraw feature

The dual-source-of-truth design means TerraDraw and ShareDB can diverge permanently on rejection. During a drag, TerraDraw state is ahead of ShareDB (only synced on `handleDrawFinish`). Remote operations trigger full feature remove+add rather than incremental updates.

**Trade-offs:**
- Zero implementation cost for rollback
- Relies entirely on the OT library (ShareDB) to prevent rejection
- Divergence on rejection is silent — no error state, no user notification
- Acceptable when: operations rarely fail, the cost of ghost state is low, users can manually correct

**Key files:**
- `apps/editor/src/lib/state/maps.svelte.ts` — submitOp with no error handling

### 4. Dual-Layer State (Ente Pattern)

**Mechanism:** Separate the store into confirmed state and optimistic state. The UI always reads from the optimistic layer. On server confirmation, promote optimistic to confirmed. On failure, discard the optimistic layer and the UI reverts to confirmed state.

**Pending mutation sets:** Ente tracks which mutations are pending (unconfirmed). Each pending mutation is a discrete unit that can be individually promoted or discarded. Upload status progresses through phases (queued, uploading, processing, complete) with the gallery showing optimistic entries throughout.

**Trade-offs:**
- Clean conceptual separation — confirmed state is always consistent
- Memory overhead: two copies of affected state
- Merge complexity when multiple pending mutations overlap on the same data
- Discarding an optimistic mutation may invalidate subsequent pending mutations that built on it
- Works best for independent mutations (file uploads, settings changes); struggles with interdependent mutations (collaborative document editing)

### 5. CRDT Automatic Merge (Yjs/Loro/Automerge)

**Mechanism:** CRDTs eliminate explicit rollback by design. Every operation is eventually applied everywhere in a convergent order. Conflicts are resolved by the data structure's semantics (last-writer-wins register, sequence CRDT ordering, counter addition).

**No rollback needed because:** operations are never rejected. They may be reordered, but they are always applied. The UndoManager provides user-facing undo by generating inverse operations, not by rolling back state.

**Trade-offs:**
- No rollback logic to implement
- Conflict resolution semantics may not match user intent (LWW can silently discard work)
- Undo is operation-based (generate inverse) not state-based (restore snapshot)
- Garbage collection of CRDT metadata is a separate concern (see crdt-structural-integrity codebook)

---

## Decision Guide

| Factor | Rebase-on-Commit (Penpot) | Version Reconciliation (Excalidraw) | Fire-and-Forget (Allmaps) | Dual-Layer (Ente) | CRDT Auto-Merge |
|--------|--------------------------|-----------------------------------|--------------------------|-------------------|-----------------|
| Rollback granularity | Operation-level | Element-level | None | Mutation-level | N/A (no rejection) |
| Pending mutations | Ordered queue | None (full state compare) | None | Independent set | N/A |
| Conflict resolution | Rebase + replay | Version + nonce tiebreak | OT server decides | Discard optimistic | CRDT semantics |
| Failure mode | Discard queue (nuclear) | Remote wins by default | Silent divergence | Discard one mutation | N/A |
| Undo interaction | Complex (transaction spanning rebase) | History delta filtering | None | Discard optimistic layer | Inverse operations |
| Best for | Server-authoritative collab | Peer-to-peer element editing | Simple single-user + optional sync | Independent mutations (uploads) | Local-first collab |

---

## Anti-Patterns

### 1. Rollback Without Cascading
Rolling back mutation A while mutations B and C (which depend on A's result) remain applied. The state becomes internally inconsistent.

**Fix:** Track mutation dependencies. When rolling back A, identify and roll back or rebase all dependent mutations. Penpot's "undo all pending, reapply" approach handles this by construction.

### 2. Optimistic UI with No Error Path
Showing optimistic state but having no code path for what happens when the server rejects it. The happy path works; the error path is "hope it doesn't happen."

**Fix:** Every optimistic mutation must have a corresponding rollback handler, even if it's just "remove from display and show error toast."

### 3. Rollback Flicker
Rolling back causes a visible state transition: item appears, disappears, reappears at a different position. Users perceive this as a bug.

**Fix:** Batch rollback + re-apply into a single render frame. Use `requestAnimationFrame` or framework batching to ensure the intermediate (rolled-back) state is never painted.

### 4. Undo Stack Corruption During Rollback
The rollback itself generates undo entries, so undoing after a rollback replays the rollback rather than the user's prior action.

**Fix:** Rollback operations must be tagged as non-undoable (see mutation-annotation-patterns.md). Use `NEVER`/non-tracked origin for all rollback mutations.

### 5. Nuclear Discard as Primary Strategy
Using "discard all pending and reload from server" as the first response to any conflict, rather than attempting per-mutation resolution.

**Fix:** Reserve nuclear discard for genuinely unrecoverable states. Attempt per-mutation rollback first. Track how often nuclear discard fires — if frequent, the conflict resolution strategy needs improvement.

---

## Key Metrics to Monitor

- **Rollback frequency** — how often optimistic state is reverted (high rate suggests over-optimism or high conflict)
- **Rollback latency** — time from rejection to UI correction (should be imperceptible, <16ms)
- **Cascade depth** — average number of dependent mutations rolled back per conflict
- **Nuclear discard rate** — frequency of full-queue discard vs. per-mutation rollback
- **Ghost state incidents** — user-reported instances of phantom state that doesn't match server
