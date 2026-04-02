# Mutation Annotation Patterns

## The Problem

In a collaborative application with undo/redo, every state mutation has an origin: the local user typed something, the undo system reverted something, or a remote peer's change arrived via sync. The system must behave differently for each origin — local mutations are undoable and trigger sync, undo mutations revert without creating new undo entries, and remote mutations update display without entering the local undo stack.

Without explicit annotation, every mutation looks the same to the store. The system cannot distinguish "user moved a shape" from "remote peer moved a shape" from "undo system restored a shape." This forces UI-layer hacks, invisible state corruption, and undo stacks that replay remote changes.

**De-Factoring Evidence (no mutation classification):**
- **If removed:** Undo replays remote changes the user never made. Sync broadcasts undo operations as new edits, creating infinite loops. History becomes a mix of local and remote entries with no way to filter. Reconciliation treats local in-progress edits the same as confirmed remote state.
- **Detection signal:** Undo reverts someone else's work. Typing triggers sync of the same content twice. History panel shows entries the user didn't create. Remote changes re-enter the undo stack on application.

---

## Competing Patterns

### 1. CaptureUpdateAction Enum (Excalidraw Pattern)

**Mechanism:** Excalidraw defines a `CaptureUpdateAction` enum with three values that must be passed to every mutation site:

| Value | Semantics | Example |
|-------|-----------|---------|
| `IMMEDIATELY` | Undoable user action; captured in history and broadcast | Shape creation, property change, deletion |
| `NEVER` | Remote update or internal bookkeeping; skip history | Reconciled remote elements, cursor position |
| `EVENTUALLY` | Ephemeral in-progress action; deferred capture | Drag mid-flight, resize handle movement |

`store.scheduleAction()` is called from `App.tsx` (line 2696) to set the capture policy before each state update. `StoreDelta` captures element + appState diffs. `HistoryDelta extends StoreDelta` adds version/nonce exclusion to filter non-undoable changes.

**The annotation burden:** Every action file (`actionProperties.tsx`, `actionGroup.tsx`, `actionDeleteSelected.tsx`, etc.) and every mutation path in the 8000+ line `App.tsx` must explicitly declare its capture policy. Missing or wrong annotations cause:
- `IMMEDIATELY` on a remote update → remote changes pollute local undo stack
- `NEVER` on a user action → action becomes non-undoable with no visible feedback
- `EVENTUALLY` without a corresponding `IMMEDIATELY` on pointer-up → change is silently lost from history

**The EVENTUALLY-to-IMMEDIATELY transition:** Drag operations use `EVENTUALLY` during pointer-move (creating deferred deltas) and must transition to `IMMEDIATELY` on pointer-up. This transition is managed in the same App.tsx pointer event handlers, coupling gesture-disambiguation to mutation annotation.

**Trade-offs:**
- Complete control over what enters history and sync
- Every new mutation site must know about and correctly use the enum
- Annotation errors are silent — wrong classification doesn't crash, it corrupts history
- Scales poorly: adding a new capture category requires auditing every call site

**Key files:**
- `packages/element/src/store.ts` (1037 lines) — StoreDelta, CaptureUpdateAction, scheduleAction
- `packages/element/src/delta.ts` (2066 lines) — delta diffing, HistoryDelta
- `packages/excalidraw/app/App.tsx` — mutation call sites throughout

### 2. Transaction Origin Tagging (Yjs Pattern)

**Mechanism:** Yjs transactions accept an `origin` parameter: `doc.transact(() => { ... }, origin)`. The origin is an arbitrary value (typically a string or object reference) that flows through to observers via `transaction.origin`. Consumers filter by origin:

```
// UndoManager only captures local transactions
undoManager = new Y.UndoManager(ymap, {
  trackedOrigins: new Set([null, 'local'])
})

// Sync provider tags remote updates
doc.transact(() => { applyUpdate(doc, remoteUpdate) }, 'remote')

// Observer can branch on origin
ymap.observe(event => {
  if (event.transaction.origin === 'remote') {
    // update display only
  } else {
    // local change, maybe trigger side effects
  }
})
```

**Trade-offs:**
- Origin is a convention, not a type — nothing enforces that origins are used correctly
- UndoManager's `trackedOrigins` set provides clean filtering without per-site annotation
- Works at transaction granularity, not per-operation — all operations in a transaction share one origin
- Third-party code can break conventions by omitting origin or using unexpected values

**When to use:** CRDT systems where the data layer (Yjs) already provides transaction semantics. The annotation is centralized at the transaction boundary rather than distributed across mutation sites.

### 3. No Annotation — Structural Inference (Allmaps Anti-Pattern)

**Mechanism:** Allmaps' `MapsState.#handleOperation(op, localOperation)` receives a boolean `localOperation` parameter from ShareDB. This is the only discrimination — local vs. remote, binary, with no further classification.

**Consequences:**
- No undo system exists — there's nothing to filter
- All operations are fire-and-forget; the only "rollback" is the user manually re-dragging
- Remote operations do full feature remove+add in TerraDraw because there's no way to know if a remote update is a coordinate change vs. a full replacement
- Works only because the interaction model is simple enough that the binary distinction suffices

**When to use:** Only in systems where undo is not required and operations are coarse-grained enough that binary local/remote distinction is sufficient.

---

## Decision Guide

| Factor | CaptureUpdateAction (Excalidraw) | Transaction Origin (Yjs) | Binary local/remote (Allmaps) |
|--------|--------------------------------|-------------------------|------------------------------|
| Granularity | Per-mutation-site | Per-transaction | Per-operation (binary) |
| Undo filtering | Explicit per-action | Centralized via trackedOrigins | None |
| Annotation burden | Every call site | Transaction boundaries only | None |
| Error visibility | Silent corruption | Silent but fewer sites | N/A |
| Extensibility | Add enum values + audit all sites | Add origin strings | N/A |
| Prerequisite | Custom store architecture | Yjs or similar transaction model | OT with local flag |

**Choose per-site annotation** when: building a custom collaboration stack without CRDT transactions, need fine-grained capture timing (immediate vs. deferred), undo must handle ephemeral states differently.

**Choose transaction origin** when: using a CRDT with transaction support, can centralize sync and undo at provider boundaries, want to avoid distributed annotation burden.

**Choose binary/none** when: no undo requirement, simple interaction model, willing to accept no rollback capability.

---

## Anti-Patterns

### 1. Annotation Without Validation
Adding capture categories but never testing that each call site uses the right one. The annotation becomes cargo cult — present but not verified.

**Fix:** Integration tests that assert undo stack contents after specific user flows. "Create shape, undo, verify shape gone" catches `NEVER` misclassification.

### 2. Ephemeral-to-Committed Transition Bugs
Drag uses `EVENTUALLY`, pointer-up should promote to `IMMEDIATELY`, but early return paths (ESC during drag, focus loss, touch cancel) skip the promotion. The change exists in the document but not in undo history.

**Fix:** The transition from ephemeral to committed must be guaranteed by the gesture system, not by each action handler. A centralized "commit pending ephemeral" on any gesture-end event.

### 3. Origin Proliferation
Adding new origin strings for each feature ("toolbar-color-change", "keyboard-shortcut-delete", "context-menu-paste") when the undo/sync system only needs to know local-vs-remote.

**Fix:** Origins should classify by _behavior category_ (local-undoable, local-non-undoable, remote, system), not by feature. Keep the origin vocabulary small.

### 4. UI State Leaking Into Mutation Classification
Excalidraw's reconciliation checks `localAppState.editingTextElement`, `resizingElement`, `newElement` to decide whether to keep local or remote state. This means the data layer's conflict resolution depends on transient UI state.

**Fix:** Mutation annotations should carry enough information that the data layer can resolve conflicts without querying UI state. Tag in-progress edits at mutation time, not at reconciliation time.

---

## Key Metrics to Monitor

- **Annotation coverage** — percentage of mutation sites with explicit capture/origin tags (100% is the goal)
- **Undo stack pollution** — remote entries appearing in local undo (should be zero)
- **Ephemeral leak rate** — EVENTUALLY/deferred changes that never promote to IMMEDIATELY (indicates transition bugs)
- **Origin vocabulary size** — number of distinct origin values in use (smaller is better)
