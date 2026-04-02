# Multiplayer Undo Scope and Conflict Resolution

## The Problem

When multiple users edit simultaneously, "undo" becomes ambiguous. Single-user undo has a clear mental model: reverse the last thing I did. In multiplayer, the undo stack interleaves with remote operations that arrived between local edits. Undoing a local action may need to account for remote operations that built on top of it. Three questions dominate:

1. **Whose operations get undone?** Local-only (undo only my actions) vs global (undo the last action by anyone). Every production system chooses local-only, but implementing it requires per-user operation tracking that interacts with the state representation.

2. **What happens when undo conflicts with concurrent remote state?** User A moves a shape, User B changes its color, User A undoes the move — does the color change survive? What if User B deleted the shape entirely? The answer depends on whether undo is modeled as an inverse operation, a state snapshot restoration, or a CRDT-native reversal.

3. **How does undo interact with reconnection?** If a user goes offline, makes edits, then reconnects, their undo stack contains operations that the server has never seen. Undoing after reconnection must produce correct results even when the document has diverged significantly during the offline period.

## Competing Patterns

### Pattern 1: Origin-Tracked CRDT Undo (Yjs UndoManager)

Yjs UndoManager uses `trackedOrigins` to scope undo to operations from specific origins (typically the local client ID). Each transaction is tagged with an origin, and only matching transactions enter the undo stack. Undo itself is a new CRDT transaction that produces inverse operations within the CRDT framework.

**When to use:** State lives in Yjs documents; need offline-capable undo that merges correctly on reconnect; want undo semantics handled by the CRDT layer rather than application code.

**When NOT to use:** Need custom undo semantics beyond what the CRDT provides (e.g., restoring selection state not in the CRDT); undo groups must span disconnected time periods; state partially lives outside Yjs.

```typescript
const undoManager = new Y.UndoManager(
  [yShapes, yStyles], // Shared types to track
  {
    trackedOrigins: new Set([doc.clientID]), // Only local edits
    captureTimeout: 0, // Manual grouping
  }
);

// Local edit — enters undo stack
doc.transact(() => {
  yShapes.set('rect-1', { x: 100, y: 200 });
}, doc.clientID); // origin = local client

// Remote sync — excluded from undo stack
Y.applyUpdate(doc, remoteUpdate, 'remote'); // origin = 'remote'

// Undo only reverses local transactions
undoManager.undo(); // Reverses rect-1 change, remote edits untouched
```

**Reconnection behavior:** Yjs UndoManager stores undo items as references to CRDT struct items. On reconnect, sync merges remote state via the standard Yjs sync protocol. Because undo items reference CRDT-internal structures (not application-level snapshots), undo after reconnection produces correct results — the CRDT ensures convergence even when the undo reverses operations that interleaved with remote changes during the offline period.

**Conflict with concurrent deletion:** If User A creates a shape and User B deletes it, User A's undo of the creation is a no-op (already deleted). If User A undoes a move on a shape User B deleted, the undo resurrects the shape via tombstone reversal — which may or may not be desired. Yjs provides `UndoManager.on('stack-item-popped')` to intercept and filter.

**Production:** WeaveJS (trackedOrigins scoped to local client, canUndo/canRedo exposed via events), papad (y-websocket collaborative annotation).

### Pattern 2: Mark-Based Diff Undo with Remote Exclusion (tldraw)

tldraw separates local and remote changes at the store level. `mergeRemoteChanges()` wraps all incoming sync updates and marks them as non-local. The undo stack only records diffs from local operations. Undo pops diffs back to the last named mark.

**When to use:** Diff-based reactive store (signals/atoms); need fine-grained control over undo grouping; state is not in a CRDT; sync is handled separately from undo.

**When NOT to use:** State lives in a CRDT (fighting two undo systems); need undo to survive offline/reconnect without explicit handling; complex concurrent conflict resolution needed.

```typescript
// Remote changes excluded from undo
store.mergeRemoteChanges(() => {
  store.put([remoteShape]);
});

// Local changes recorded as diffs
editor.mark('move-start');
editor.updateShape({ id: 'rect-1', x: 100, y: 200 });
// Undo pops diffs back to 'move-start' mark

editor.undo(); // Only reverses local diffs
```

**Conflict with concurrent deletion:** If a remote user deletes a shape that a local user moved, the local undo diff references a shape that no longer exists. tldraw's diff application recreates the shape from the stored `removed` entry in the diff — effectively resurrecting it. The sync layer then propagates this resurrection as a new creation.

**Reconnection behavior:** tldraw's undo stack stores `RecordsDiff` objects (before/after snapshots of each record). After reconnection, applying an old diff may conflict with remote state. The diff application uses put/remove semantics — it overwrites current state with the stored "before" values, which may clobber remote changes made during the offline period. This is acceptable for tldraw's use case (short disconnections, server-authoritative reconciliation) but not for long offline periods.

**Production:** tldraw (sync via room server, undo purely local).

### Pattern 3: Change-Based Undo with Causal History (Automerge)

Automerge tracks changes as causally-ordered units. Each change knows its dependencies (which changes it was built on). Undo can be modeled as creating a new change that inverts a previous change, with full awareness of the causal history. Unlike Yjs's item-level tracking, Automerge operates at the change level.

**When to use:** Need causal ordering guarantees; branching/merging document workflows (drafts, proposals); want undo to be a first-class change in the document history.

**When NOT to use:** Automerge doesn't ship a built-in UndoManager equivalent — you must build undo semantics on top of the change/diff primitives.

```typescript
// Automerge tracks changes with causal dependencies
let doc = Automerge.change(doc, 'move shape', d => {
  d.shapes['rect-1'].x = 100;
});

// To "undo", create an inverse change
const before = Automerge.getHistory(doc).at(-2)?.snapshot;
const after = doc;
// Compute inverse by diffing and apply as new change
let undone = Automerge.change(doc, 'undo: move shape', d => {
  d.shapes['rect-1'].x = before.shapes['rect-1'].x;
});

// Merge handles concurrent undo correctly via causal ordering
let merged = Automerge.merge(localDoc, remoteDoc);
```

**Reconnection behavior:** Automerge's sync protocol exchanges changes based on causal dependencies. After reconnection, all local changes (including undos) merge with remote changes. Because each change carries its causal parents, the merge is deterministic regardless of network ordering.

**Production:** upwelling-code (branching/drafts model where undo is implicit via branch revert).

### Pattern 4: Per-Client Inverse Stacks with Skip Semantics (Figma)

Figma maintains per-client undo stacks on the server. Each stack entry is an inverse operation. When a user undoes, the server applies the inverse. If the inverse conflicts with subsequent operations (e.g., the target was deleted by another user), the undo entry is silently skipped and the next entry is tried.

**When to use:** Server-authoritative architecture; want the server to handle conflict resolution; acceptable to silently skip conflicting undos.

**When NOT to use:** Offline-first (server must be reachable for undo); need client-side undo latency; unacceptable to silently lose undo steps.

**Figma's invariant** (Rasmus Andersson): "If you undo a lot, copy something, and redo back to the present, the document should not change." This constrains the undo model — redo must be the exact inverse of undo, and copy must not interact with the undo stack.

**Reconnection behavior:** Figma is server-authoritative — the undo stack lives on the server. On reconnection, the client receives the current document state and its undo stack is preserved server-side. No client-side reconciliation needed, but undo during disconnection is impossible.

**Conflict resolution rules:**
- Undo target deleted by another user: skip silently
- Undo target modified by another user: apply inverse against current state (may produce unexpected visual results)
- Undo of creation when another user added children: skip (deletion would orphan children)

**Production:** Figma, Google Slides (same skip semantics).

### Pattern 5: Delta Rebase with Version Exclusion (Excalidraw)

Excalidraw stores undo entries as `HistoryDelta` objects containing property-level diffs. On undo replay, `applyLatestChanges` rebases the stored delta against the current document state, accounting for concurrent modifications. Version numbers are excluded from the restored properties — every undo appears as a fresh edit to collaborators, preventing LWW version conflicts.

**When to use:** Need undo to coexist with LWW (last-writer-wins) sync without version conflicts; diff-based architecture; want undo to adapt to concurrent changes rather than skip or clobber.

**When NOT to use:** CRDT-based state (use CRDT-native undo); server-authoritative (use server-side stacks); simple single-user (overkill).

```typescript
// HistoryDelta excludes version fields on replay
const EXCLUDED_PROPERTIES = ['version', 'versionNonce'];

// applyLatestChanges rebases delta against current state
function applyLatestChanges(delta: HistoryDelta, currentElements: Map) {
  for (const [id, propDiff] of delta.elements) {
    const current = currentElements.get(id);
    if (!current) {
      // Fallback to snapshot for force-deleted elements
      const fallback = snapshot.get(id);
      if (fallback) { /* resurrect from snapshot */ }
      continue;
    }
    // Rebase: only restore properties that still differ
    for (const [prop, oldValue] of propDiff) {
      if (EXCLUDED_PROPERTIES.includes(prop)) continue;
      current[prop] = oldValue; // Apply inverse
    }
  }
}
```

**Reconnection behavior:** After reconnection, stored deltas are rebased against whatever state exists. The `containsVisibleChange` loop skips deltas that are now no-ops (concurrent edits already reverted the change). Version exclusion ensures the undo increment doesn't conflict with remote version numbers.

**Production:** Excalidraw (LWW sync with Firebase/custom server).

## Decision Guide

| Constraint | Recommended Pattern |
|-----------|-------------------|
| State in Yjs CRDT | Origin-tracked CRDT undo (Pattern 1) |
| State in Automerge CRDT | Change-based undo (Pattern 3) |
| Reactive store, no CRDT | Mark-based diff undo (Pattern 2) |
| Server-authoritative, always online | Per-client inverse stacks (Pattern 4) |
| LWW sync, peer-to-peer | Delta rebase with version exclusion (Pattern 5) |
| Must work offline and merge on reconnect | Pattern 1 (Yjs) or Pattern 3 (Automerge) |
| Silent skip of conflicting undo acceptable | Pattern 4 (Figma) |
| Need undo to adapt to concurrent changes | Pattern 5 (Excalidraw rebase) |
| Custom undo semantics beyond CRDT | Pattern 2 (tldraw) with application-level handling |

### Multiplayer Undo Scope Decision

| Question | If Yes | If No |
|----------|--------|-------|
| Can users undo each other's work? | Never in production. Always local-only. | -- |
| Must undo work offline? | CRDT-native (Patterns 1, 3) | Any pattern works |
| Is silent skip of conflicting undo acceptable? | Pattern 4 (Figma) | Pattern 5 (rebase) or Pattern 1 (CRDT) |
| Does undo need to resurrect deleted elements? | Snapshot fallback (Pattern 5) or tombstone reversal (Pattern 1) | Skip semantics (Pattern 4) |
| Must undo preserve concurrent modifications? | Rebase (Pattern 5) or CRDT merge (Pattern 1) | Overwrite (Pattern 2) or skip (Pattern 4) |

## Anti-Patterns

- **Global undo stack in multiplayer.** User B's Ctrl+Z reverts User A's work. Every production system uses per-user stacks. There are zero known exceptions in shipping collaborative editors.

- **Undo during offline without CRDT backing.** If undo is modeled as inverse operations applied to a local snapshot, reconnection produces diverged state. The local undo and the remote document have no common framework for reconciliation. Either use CRDT-native undo or accept that undo is unavailable offline.

- **Restoring version numbers on undo replay.** In LWW systems, undone elements carry old version numbers. The sync layer sees the undo as stale (lower version) and discards it. Undo appears to work locally but reverts a moment later when sync overwrites with the "newer" remote version. Always generate fresh version numbers for undo operations.

- **Tombstone-unaware undo in CRDT systems.** If GC compacts tombstones that the undo stack references, undo silently fails or crashes. Either prevent GC of items referenced by active undo stacks, or accept bounded undo depth tied to GC policy.

- **Undo resurrection without orphan handling.** Undoing a deletion resurrects an element, but if other users added children/bindings to it that were subsequently cleaned up, the resurrected element exists in an inconsistent context. Always validate structural integrity after undo resurrection.

- **Time-window batching for multiplayer undo.** Using `captureTimeout` (e.g., 500ms) to auto-group undo entries works for single-user but creates unpredictable grouping in multiplayer. A remote operation arriving during the timeout window may get grouped with local operations. Use explicit grouping (`stopCapturing()`, marks, or `CaptureUpdateAction`) instead.
