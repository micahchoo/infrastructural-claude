# Sync Lifecycle States

## The Problem

Every collaborative or server-synced application must manage the gap between "user did something" and "server confirmed it." During this gap, the UI is showing speculative state. The application needs a state machine that tracks where each piece of data sits in the sync lifecycle — and the UI must communicate this to the user without being noisy.

The tension: **users expect the UI to feel instant, but data has latency, and the UI must degrade gracefully when sync stalls, conflicts, or fails.**

**De-Factoring Evidence (no explicit sync states):**
- **If removed:** Without a sync state machine, every component must independently guess whether data is fresh, stale, or in-flight. Sync indicators become impossible or misleading. Error recovery degrades to "refresh the page." Components show confirmed data reverting to stale snapshots because nothing tracks what's pending.
- **Detection signal:** UI flickers between states after save; stale data reappears after navigation; no visual feedback during slow network; error states are catch-all toasts with no recovery path.

---

## Competing Patterns

### 1. Explicit State Machine (Penpot Pattern)

**Mechanism:** Penpot's `persistence.cljs` maintains a FIFO queue of commit IDs with an index of commit data. Each commit carries `file-revn` (file revision number) and `file-vern` (file version number). The client tracks `revn` in a global atom (`revn-data`) and uses `max` of local and server revisions.

States:
- **Idle** — no pending commits, local state matches server
- **Pending** — commits in queue, not yet sent to server
- **Persisting** — one commit actively being sent (`run-persistence-task` processes one at a time)
- **Lagged** — server responds with `lagged`, indicating remote changes arrived between client's last known revision and current one; client must merge
- **Error** — persistence failed; `discard-persistence-state` is invoked as a nuclear option

**Trade-offs:**
- Serial commit processing is simple but creates head-of-line blocking
- The `discard-persistence-state` nuclear option suggests edge cases in the pending+lagged combination aren't fully resolved
- Revision numbers give deterministic ordering but don't handle concurrent edits from the same client

**Key files:**
- `/frontend/src/app/main/data/persistence.cljs` — persistence queue, serial task runner
- `/frontend/src/app/main/data/changes.cljs` — commit pipeline, local application

### 2. Document Sync Events (Yjs Pattern)

**Mechanism:** Yjs exposes sync state through `Doc.on('sync', isSynced)` and `Doc.on('connection-error')`. The provider (e.g., y-websocket) manages the handshake:

States:
- **Connecting** — WebSocket handshake in progress
- **Syncing** — initial state exchange (SyncStep1/SyncStep2 protocol messages)
- **Synced** — all known updates exchanged, steady-state incremental sync
- **Disconnected** — connection lost, local edits continue accumulating
- **Error** — unrecoverable provider failure

**Trade-offs:**
- Document-level, not operation-level — you know the doc is synced but not which specific operations
- `transaction.origin` discriminates local vs remote but doesn't track per-operation confirmation
- Reconnection automatically replays missed updates via state vector comparison
- No built-in "conflict" state because CRDTs resolve conflicts silently

**When to use:** CRDT-based systems where conflict resolution is automatic and the UI only needs coarse sync status.

### 3. Implicit Dual-Truth (Allmaps Pattern)

**Mechanism:** Allmaps has no explicit sync state machine. The `MapsState` class holds a ShareDB document (`this.#doc`). On local mutation, `this.#doc.submitOp(...)` fires and `this.#maps = this.#doc.data` updates immediately. Remote operations arrive via `#handleOperation(op, localOperation)` and dispatch typed CustomEvents.

States (implicit):
- **In-sync** — no local operations pending (indistinguishable from idle)
- **Local-ahead** — during a drag, TerraDraw state is ahead of ShareDB; `handleDrawChange` tracks visually, `handleDrawFinish` performs the actual sync
- **Remote-update** — incoming op triggers remove+re-add of features, causing potential flicker
- **Diverged** — if `submitOp` is rejected by server, no rollback mechanism exists

**Trade-offs:**
- Simplest to implement — OT library handles ordering
- No rollback means rejected operations leave ghost state in TerraDraw
- Remote operations do full feature remove+add rather than coordinate update, causing visual disruption
- `$state.raw` prevents fine-grained Svelte 5 reactivity — entire maps object reassigned on every operation

**Key files:**
- `apps/editor/src/lib/state/maps.svelte.ts` — MapsState, ShareDB integration
- `apps/editor/src/lib/components/views/Georeference.svelte` — event handler bridge

### 4. Block-Until-Ready (Anti-Pattern)

**Mechanism:** Disable all UI interaction until server confirms. Show loading spinner on every mutation.

**Detection signal:** Buttons disabled during save. Modal spinners on form submission. Navigation blocked until response.

**Why it persists:** Eliminates the entire consistency problem by eliminating optimism. Acceptable for infrequent, high-stakes operations (payment, account deletion) but catastrophic for creative tools where users expect sub-frame feedback.

---

## Decision Guide

| Factor | State Machine (Penpot) | Sync Events (Yjs) | Implicit Dual-Truth (Allmaps) |
|--------|----------------------|-------------------|----------------------------|
| Sync model | Server-authoritative | CRDT local-first | OT server-mediated |
| Granularity | Per-commit | Per-document | Per-operation (implicit) |
| Conflict handling | Rebase + discard fallback | Automatic CRDT merge | OT transform, no rollback |
| UI feedback possible | Rich (queue depth, revision gap) | Coarse (synced/unsynced) | None built-in |
| Implementation cost | High | Low (provider handles it) | Lowest |
| Failure recovery | Discard pending + reload | Reconnect + replay | Refresh page |

**Choose explicit state machine** when: server-authoritative with collaborative editing, need sync indicators, must handle partial failure gracefully.

**Choose sync events** when: using CRDTs, conflicts auto-resolve, UI only needs connection status.

**Choose implicit dual-truth** when: prototyping, single-user with optional collaboration, willing to accept visual glitches on conflict.

---

## Anti-Patterns

### 1. Sync State in Component Local State
Storing sync status in React/Svelte component state rather than a global store. Components unmount and lose sync context. Remounting shows stale "synced" status.

**Fix:** Sync lifecycle is application-level state. Store it in the data layer alongside the document.

### 2. Boolean `isSaving` Instead of State Machine
A single `isSaving: boolean` cannot represent the full lifecycle. It collapses pending, persisting, lagged, and error into two states.

**Fix:** Use an explicit enum or state machine. Even `'idle' | 'pending' | 'saving' | 'error' | 'conflict'` is vastly better than a boolean.

### 3. No Distinction Between "Never Synced" and "Synced Then Disconnected"
A fresh document that hasn't connected yet and a document that lost connection mid-edit have completely different recovery semantics.

**Fix:** Track connection history. "Never synced" means no server state exists. "Disconnected" means server state exists but may have diverged.

### 4. Swallowing Sync Errors Into Console Logs
Persistence errors logged but not surfaced to the user. The UI shows "saved" while data is actually lost.

**Fix:** Sync errors must propagate to the UI layer. At minimum, a persistent indicator that says "changes not saved."

---

## Key Metrics to Monitor

- **Pending queue depth** — how many unconfirmed operations are in flight (Penpot: commit queue length)
- **Revision gap** — difference between local and server revision numbers (detects lagged state)
- **Time-to-confirm** — p95 latency from local mutation to server acknowledgment
- **Rollback frequency** — how often optimistic state must be reverted (indicates conflict rate)
- **Reconnection replay size** — bytes/operations replayed on reconnect (indicates offline accumulation)
