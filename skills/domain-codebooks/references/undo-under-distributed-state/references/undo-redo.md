# Undo/Redo Patterns

## The Problem

Undo/redo appears simple — record what changed, reverse it on Ctrl+Z. In practice, annotation editors face a combinatorial explosion of edge cases that break naive implementations. Drag operations generate dozens of intermediate mutations per second, all of which must collapse into a single undo step. Batch operations (multi-select delete) must be atomic: partial undo of a batch corrupts state. And batched inverse computation is order-dependent — computing undo for step B against the original state instead of post-step-A state silently produces wrong results that surface only on undo.

Multiplayer compounds every problem. User B's undo must never revert User A's work, requiring per-user undo stacks. But per-user stacks interact badly with shared state: if User A deletes an object that User B moved, what does User B's undo do? The answer varies by product (silently skip, tombstone, compensate), and each choice has downstream implications for conflict resolution, offline support, and user trust.

A third dimension is scope: which mutations belong in the undo stack at all? View state (zoom, pan), navigation (page switches), and ephemeral state (cursor position, selection) must be excluded, but the boundary is ambiguous. Layer visibility is view state in single-user tools but document state in Figma. Without explicit per-mutation capture intent, the system guesses wrong — putting remote changes in the undo stack or making Ctrl+Z move the viewport instead of reverting content.

## Competing Patterns

## Pattern 1: Command pattern

Each mutation records an undo/redo operation pair.

**tldraw refinement -- history marks**: Group micro-operations into one undo step. Place a "mark" at drag start; everything between marks undoes as one unit.
```typescript
editor.mark('resize-start');
// ... many intermediate updates during drag ...
// Undo reverts everything back to the mark
```

**JOSM**: `Command` abstract class with `executeCommand()`/`undoCommand()`. `SequenceCommand` bundles compound operations.

## Pattern 2: Immutable snapshots

Every edit produces a new immutable state. Undo moves a pointer backward.

**iD editor**: `Action(graph) -> newGraph`, history is an array of graphs with a pointer. Structural sharing minimizes memory (unchanged entities share references).

Tradeoffs: Trivially simple, no inverse computation. But can't persist history, can't support multiplayer undo, memory grows with depth.

## Pattern 3: Event sourcing

Append-only log. Current state = replay all events.

**Production**: GeoGig (Git model for geodata), OSM changesets, QGIS (Qt QUndoStack + database SAVEPOINTs).

**When to use**: Audit trail, branching/merging annotation sets, regulatory compliance.

## Pattern 4: Diff-based undo/redo (reactive store architectures)

Every mutation as a structured diff: `{ added, updated: [before, after], removed }`. Undo applies reversed diff. The same diff serves three purposes: undo/redo, collaboration sync, and persistence.

**tldraw's RecordsDiff**:
```typescript
interface RecordsDiff<R> {
  added: Record<IdOf<R>, R>;
  updated: Record<IdOf<R>, [from: R, to: R]>;
  removed: Record<IdOf<R>, R>;
}
// Reversing: swap from/to, swap added/removed
```

**Undo stack stores Mark | Diff entries** -- marks are named checkpoints interleaved with diffs. Undoing pops diffs and applies reverses until reaching a mark. Gives "undo the whole drag" semantics without explicit command grouping:
```typescript
type HistoryEntry<R> =
  | { type: 'diff'; diff: RecordsDiff<R> }
  | { type: 'mark'; name: string };
```

**vs command pattern**: No per-type inverse functions needed -- diff already has the before state. New annotation types get undo for free.
**vs snapshots**: Diffs are small, networkable for sync, persistable incrementally.
**When to prefer**: Reactive stores that already track changes (tldraw, Zustand with middleware, MobX).

## Pattern 5: CRDT-native undo (Yjs UndoManager)

When state lives in a Yjs doc, `Y.UndoManager` tracks undo natively within CRDT transaction history. Undo itself is a valid CRDT operation that merges correctly with concurrent edits.

```typescript
const undoManager = new Y.UndoManager(
  [annotations, styles],
  {
    trackedOrigins: new Set([doc.clientID]),  // Only LOCAL edits
    captureTimeout: 500,  // Group rapid edits into one undo step
  }
);
```

**Critical: `trackedOrigins` scopes to local edits only.** Without it, Ctrl+Z undoes remote changes.
```typescript
// Local: origin matches trackedOrigins
doc.transact(() => { annotations.set('shape-1', data); }, doc.clientID);
// Remote: origin excluded
Y.applyUpdate(doc, update, 'remote');
```

**Ephemeral state**: Store under a shared type NOT tracked by UndoManager, or use an untracked origin.

**Drag batching**: Set `captureTimeout: 0`, call `undoManager.stopCapturing()` to force new undo groups manually.

**Beats command pattern when**: Multiplayer with offline (undo while offline merges correctly on reconnect). Complex nested state (handles arbitrarily nested Yjs Maps/Arrays automatically). Same primitive for sync + undo.

**Prefer command pattern when**: Custom undo semantics needed (restore selection not in CRDT), undoable state lives outside Yjs, or undo groups must span disconnected time periods.

**Production**: WeaveJS (trackedOrigins scoped to local client, canUndo/canRedo via events), papad (y-websocket collaborative annotation with per-user undo).

## Production Deep Dive: Excalidraw Delta-Based Undo

Excalidraw implements diff-based undo with several distinctive mechanisms that
address distributed-state challenges. These patterns build on Pattern 4 above.

### Three-Value CaptureUpdateAction

Every mutation callsite passes a `CaptureUpdateAction` to `Store.scheduleAction()`:

| Action | Snapshot update? | Increment type | Goes to undo? |
|--------|-----------------|----------------|---------------|
| `IMMEDIATELY` | Yes | `DurableIncrement` | Yes — emitted via `onDurableIncrementEmitter` |
| `NEVER` | Yes | `EphemeralIncrement` | No — remote sync, scene init |
| `EVENTUALLY` | Only if subscribers exist | `EphemeralIncrement` | Deferred — accumulated until next IMMEDIATELY |

The Store maintains two emitter channels: `onDurableIncrementEmitter` (consumed
by `History.record()`) and `onStoreIncrementEmitter` (public API for
sync/persistence). This dual-emitter architecture ensures history and sync
consume the same data pipeline but with different filtering.

**De-Factoring Evidence (Excalidraw -- Dual Emitter)**:
- **If removed:** A single event channel carries all increments. Drag operations (EVENTUALLY) produce 60 individual undo entries (one per animation frame) instead of one batched entry. Sync receives internal history-bookkeeping events that shouldn't propagate.
- **Detection signal:** Bug reports of "undo has too many tiny steps" for drags; undo subscriber with `if (!event.durable) return` filtering; single event bus with growing `type`/`category` fields to help consumers decide what to ignore.

Source: `packages/element/src/store.ts`

### HistoryDelta Version Exclusion

When replaying undo/redo, `HistoryDelta.applyTo` **excludes `version` and
`versionNonce`** from the restored properties. This means every undo/redo
appears as a fresh edit to collaborators — it gets a new version number rather
than restoring the old one. This prevents version conflicts during concurrent
editing where multiple peers might undo simultaneously.

Source: `packages/excalidraw/history.ts`

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Undone elements carry old version numbers; LWW reconciliation sees the undo as stale and discards it. Undo appears to do nothing, or flickers and reverts a moment later.
- **Detection signal:** Bug reports of "undo works but the change disappears a moment later" or "undo flickers"; undo replay restoring `version`/`updatedAt` metadata alongside content properties; no integration tests combining undo + concurrent remote edits.

### Snapshot Fallback for Force-Deleted Elements

When `ElementsDelta.applyTo` encounters an element ID in the delta that doesn't
exist in the current scene (force-deleted by another user or GC), it falls back
to the local `StoreSnapshot`:

```typescript
// In ElementsDelta.createGetter:
let element = elements.get(id);
if (!element) {
  // fallback to local snapshot for force-deleted elements
  element = snapshot.get(id);
}
```

`HistoryDelta` passes `snapshot.elements` as the fallback source. `StoreDelta`
(non-history application) passes `StoreSnapshot.empty()` — no fallback. This
means history can **resurrect force-deleted elements** from the snapshot, while
sync application cannot.

Source: `packages/element/src/delta.ts`

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Undo of a delta referencing a force-deleted element silently fails (element not found, delta skipped) or throws. The undo stack becomes corrupted -- pressing Ctrl+Z produces no visible effect.
- **Detection signal:** Bug reports of "Ctrl+Z does nothing" after a collaborator deleted an element, or "undo skips steps"; try/catch around delta application swallowing "element not found" errors; undo entries storing full element clones "just in case."

### Delta Rebase via applyLatestChanges

After applying a stored delta, `applyLatestChanges` recomputes the delta
against the actual current scene state. This handles concurrent modifications
that occurred between when the delta was recorded and when it's replayed. If
User B modified the same element between User A's action and User A's undo, the
delta adapts to what actually changed rather than blindly restoring stale state.

Source: `packages/excalidraw/history.ts`, `packages/element/src/store.ts`

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Undo blindly applies stored inverse against a diverged element state, producing a Frankenstein mix of old and current properties that surprises both users. Concurrent changes are clobbered.
- **Detection signal:** Bug reports of "after undo, element has weird mixed state" or "undo clobbers collaborator's changes"; undo deltas stored as frozen snapshots rather than computed diffs; no reconciliation step between stored delta and current state at replay time.

### Visible Change Loop

`History.perform` pops undo entries in a loop until finding one where
`containsVisibleChange` is true. This skips no-op deltas where remote edits
made the delta moot (e.g., undoing a color change that a collaborator already
reverted). Redo stack is only reset on non-empty element changes (not
appState-only changes).

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Concurrent edits that make stored deltas moot cause "dead" undo presses -- user presses Ctrl+Z and nothing visible happens, requiring multiple presses to reach an entry that actually changes something.
- **Detection signal:** Intermittent multiplayer-only reports of "Ctrl+Z does nothing" or "have to press Ctrl+Z multiple times"; undo handler popping exactly one entry without checking whether the applied delta produced a visible change.

### Comparison: Excalidraw Delta vs tldraw Mark-Based vs Yjs UndoManager

| Dimension | Excalidraw (delta) | tldraw (marks) | Yjs UndoManager |
|-----------|-------------------|----------------|-----------------|
| **Undo unit** | `StoreDelta` (property-level diff) | `RecordsDiff` squashed to mark | Transaction items |
| **Classification** | `CaptureUpdateAction` enum at callsite | `ChangeSource` filter (user/remote) | `trackedOrigins` set |
| **Stack entry** | Inversed `HistoryDelta` with property diffs | Squashed diffs between marks | StructStore items |
| **Collab filtering** | NEVER action + version exclusion | `ChangeSource !== 'user'` | Origin-based |
| **Force-delete recovery** | Snapshot fallback via `createGetter` | Record recreated from diff | Tombstones preserve; GC may lose |
| **Granularity** | Per-action (IMMEDIATELY/EVENTUALLY) | Per-mark (`editor.mark()`) | Per-transaction |
| **Delta rebase** | `applyLatestChanges` recomputes | squashToMark merges diffs | Implicit via OT |
| **Multi-step ops** | EVENTUALLY defers to next IMMEDIATELY | Multiple marks per interaction | Single transaction wraps all |
| **Sync integration** | Same `StoreIncrement` for history + sync | Separate `onChanges` callback | Separate sync protocol |
| **Empty undo skip** | Loop until `containsVisibleChange` | Marks with no diff are no-ops | Empty txns not stacked |
| **Redo reset** | Only on non-empty element changes | On any user change | On any tracked transaction |

## Multiplayer undo

**Critical rule**: Per-user undo stacks. User B's undo must never change User A's work.

- **Figma**: Per-client inverse-operation stacks. Conflicting undo (object deleted by someone else) silently skipped.
- **tldraw**: `mergeRemoteChanges` excluded from local undo stack entirely.
- **Google Slides**: Same as Figma -- conflicting undo silently skipped.

**Figma's invariant** (Rasmus Andersson): "If you undo a lot, copy something, and redo back to the present, the document should not change."

## Undo scope taxonomy

Only document mutations enter the undo stack. Mixing view state into undo creates confusing UX where Ctrl+Z moves viewport instead of reverting content.

| Bucket | Examples | Undo behavior |
|--------|----------|---------------|
| **Document mutations** | Create/delete/modify annotation, change geometry, edit properties | Primary undo stack (Ctrl+Z) |
| **View state** | Zoom, pan, scroll, layer visibility, filters | Separate stack or none. Some editors: Alt+Left/Right for "go back" |
| **Navigation** | Jump to annotation, open panel, switch page | Browser-style back/forward, not undo |

**Ambiguous cases in annotation editors:**
- **Selection**: Not undoable (Figma, tldraw, Excalidraw). Selection is targeting, not mutation. Exception: "select region of interest" as a saved annotation.
- **Tool/mode switch**: Not undoable (navigation).
- **Filter state**: Usually not undoable, but Felt treats some filter changes as undoable (view configuration in portable tier).
- **Layer visibility**: Per-user = not undoable. Shared document state (Figma component visibility) = undoable.

**Heuristic**: If included in an export, it's document state (undoable). If not, it's workspace state (not undoable).

**De-Factoring Evidence (Excalidraw -- Undo Scope Limited to Portable Tier)**:
- **If removed:** View state (zoom, pan, scroll, tool selection) enters the undo stack. Ctrl+Z cycles through viewport positions before reaching the content change the user wanted. In multiplayer, undoing shared viewport state moves another user's viewport.
- **Detection signal:** Bug reports of "Ctrl+Z changed my zoom instead of undoing my edit"; undo middleware with a growing `exclude`/`ignore` list; viewport position or tool selection stored in the same state slice as document content without tier separation.

**Selection configurability**: tldraw: `editor.run(() => { ... }, { history: 'ignore' })`. Excalidraw: selection is ephemeral.

## Batch transaction semantics

Batch mutations (multi-select delete, group move, bulk tag) must be **atomic for undo**.

**Partial-success failure mode**: Batch of N mutations, M < N succeed, undo replays M operations on state that expected N. Result: inconsistent state.

**Fix: validate-all-before-mutate-any.**
```typescript
// Bad: silent skip on missing -> partial undo
ids.reduce((state, id) => state.has(id) ? state.delete(id) : state, currentState);

// Good: validate then mutate
const missing = ids.filter(id => !currentState.has(id));
if (missing.length > 0) return err({ code: 'BATCH_VALIDATION', missing });
// ... then mutate all, record single undo entry
```

**For large batches** where validate-all is slow: use a **compensation log** (saga pattern) -- record each sub-operation as it succeeds, undo replays in reverse.

Universal pattern: Figma, tldraw (`selectAll -> delete`), Mapbox GL Draw (`draw.deleteAll`), Annotorious.

## Inverse computation for batched operations

When a batch does step A then step B, undo for B must be computed against state *after* A, not original state. Computing all inverses against original state corrupts on undo.

**Shadow-state accumulator (Penpot)**: Changes builder carries shadow document copy. After each change, applies it to shadow. Next inverse computed against shadow. Most explicit/debuggable.
```typescript
class ChangesBuilder {
  private shadow: DocumentState;
  addChange(change: Change): this {
    const inverse = computeInverse(change, this.shadow);  // Against accumulated state
    this.undoChanges.unshift(inverse);
    this.shadow = applyChange(this.shadow, change);
    return this;
  }
}
```

**Snapshot diffing (tldraw)**: Snapshot before batch, run all ops, diff before/after for single inverse. Simpler but loses per-op granularity.

**Store increments (Excalidraw)**: `storeIncrement` captures deltas per operation with inverse built in.

## Undo batching levels

Three orthogonal levels:

| Level | When | Example |
|-------|------|---------|
| **Stacking** | Compound ops within single event dispatch | "Group shapes" = reparent N children + create group + update bounds |
| **Transactions** | Interactive drags (many incremental updates -> one undo) | Drag-resize: 60+ mouse-moves = one entry. Timeout (e.g., 20s) auto-finalizes |
| **Groups** | Multi-step workflows spanning separate user actions | "Apply design token to all variants" = 5 property changes undone together |

**Production**:
- **Penpot**: `stack-undo?` flag, `start-undo-transaction`/`commit-undo-transaction` with 20s timeout, `undo-group` tags
- **tldraw**: `editor.mark('drag-start')` for transactions, `editor.run()` for stacking
- **Excalidraw**: `CaptureUpdateAction.IMMEDIATELY`/`EVENTUALLY`/`NEVER` enum

A transaction may contain stacked changes, and multiple transactions may be grouped.

## Nested undo contexts for sub-editing modes

When entering sub-edit mode (path/vertex editing, text editing within shape), undo scopes to that mode:
- **During**: Ctrl+Z undoes within sub-editor only
- **Confirm exit**: All sub-edit changes collapse to single parent entry
- **Cancel exit**: Revert to pre-edit snapshot

**Production**: Penpot (path editor own undo stack via RxJS, collapses on exit), Figma (vector edit mode scopes undo, enter/exit is boundary), Photoshop (text editing commits as single state on deselect).

## Per-mutation capture intent

Every mutation callsite must declare how it interacts with undo history:

| Mode | When | Maps to |
|------|------|---------|
| **IMMEDIATELY** | Local user edits (draw, move, delete) | Durable increment |
| **NEVER** | Remote sync, scene init, loading saved state | No increment |
| **EVENTUALLY** | Multi-step tool ops (complex path, multi-select alignment) | Ephemeral until committed |

Without explicit intent, the system must guess local vs remote -- leading to remote changes in undo stack or complex heuristics.

**Excalidraw's `CaptureUpdateAction` enum** implements this directly. Each `store.scheduleAction()` call declares intent.

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Every mutation flows through an undifferentiated channel; the system must guess local vs remote. Users press Ctrl+Z and undo a collaborator's rectangle. Multi-step tool ops produce N separate undo entries instead of one batched result.
- **Detection signal:** Bug reports of "Ctrl+Z undid something I didn't do"; `if (source === 'remote') return` guards scattered through undo logic rather than classified at the mutation site; undo stack grows during idle periods when only remote sync is active.

**Annotation-specific**: Generic apps don't need NEVER (no collab) or EVENTUALLY (no multi-step spatial tools). Annotation editors uniquely combine real-time collab + interactive drawing + direct manipulation.

## Multi-page/multi-canvas undo scope

| Approach | Used by | Pros | Cons |
|----------|---------|------|------|
| **Global** | Penpot, Adobe Illustrator | Cross-page ops undo cleanly, simple | Undo on page B reverts page A change, confusing in collab |
| **Page-scoped** | Figma, Google Slides | Predictable, collab-friendly | Cross-page ops harder, switching pages "hides" history |

**Default to page-scoped** for annotation editors (users work within one canvas). Use global when cross-page ops are frequent. **Hybrid**: global scope filtered to show only current-page entries.

## Decision guide

| Constraint | Recommended pattern |
|-----------|-------------------|
| Single-user, simple state | Immutable snapshots |
| Single-user, large state | Command pattern |
| Multiplayer, server-authoritative | Command pattern with per-client stacks |
| Multiplayer, CRDT-based (Yjs) | CRDT-native undo (UndoManager) |
| Multiplayer, offline-first | CRDT-native undo (handles merge on reconnect) |
| Audit trail / versioning | Event sourcing |
| Drag operations | Command + marks, or UndoManager captureTimeout:0 |
| Reactive store (signals/atoms) | Diff-based with mark checkpoints |
| Multi-page, work within one page | Page-scoped undo |
| Multi-page, frequent cross-page ops | Global or hybrid with page filtering |
| Undo + sync from same primitive | Diff-based or CRDT-native |

Deep dives: `sources/mutation-state.md`, `sources/tech-agnostic.md`.

## Additional Patterns (from De-Factoring)

### Selection Invalidation on Undo

After undo changes document state, selection references may point to elements that no longer exist (undoing a create) or fail to include elements that reappeared (undoing a delete). Without post-undo selection validation, property panels and click handlers operate on stale references, causing crashes or silent corruption.

Excalidraw treats selection as part of `appState` in the delta but validates it against the resulting element state after replay.

**De-Factoring Evidence (Excalidraw)**:
- **If removed:** Undoing a create leaves selection pointing at a non-existent element ID; undoing a delete restores the element but it is not selected. Downstream handlers crash or silently operate on ghosts.
- **Detection signal:** Bug reports of "after undo, properties panel shows data for a deleted element" or "clicking after undo causes a crash"; `if (selectedElement && !elements.has(selectedElement.id))` guards scattered throughout the codebase instead of centralized post-undo validation.

### Cross-Pattern Compound Failures

These undo-under-distributed-state patterns form a load-bearing web. Removing any two simultaneously creates compound failures that neither pattern alone would prevent. Key interactions from Excalidraw de-factoring:

- **Capture Intent + Version Exclusion removed:** Remote changes enter undo stack AND carry old versions -- undo of remote change creates version conflict cascade.
- **Snapshot Fallback + Delta Rebase removed:** Undo of deleted element fails (no fallback) AND undo of modified element clobbers concurrent changes (no rebase) -- undo is broadly broken in multiplayer.
- **Visible Change Loop + Delta Rebase removed:** No-op deltas are not skipped AND deltas are not rebased -- user sees both "undo does nothing" and "undo produces wrong state."
- **Scope to Portable Tier + Selection Invalidation removed:** View state in undo stack AND stale selection -- Ctrl+Z restores old viewport position with stale selection pointing to off-screen elements.

## Anti-Patterns

- **Global undo stack in multiplayer.** User B's Ctrl+Z reverts User A's work. Always use per-user undo stacks with `trackedOrigins` (Yjs) or `mergeRemoteChanges` exclusion (tldraw).
- **View state in the undo stack.** Zoom, pan, scroll, selection, and tool switches are not document mutations. Mixing them in makes Ctrl+Z move the viewport instead of reverting content. Heuristic: if it's not in an export, it's not undoable.
- **Computing batch inverses against original state.** When a batch does step A then step B, undo for B must be computed against state *after* A. Computing all inverses against the pre-batch state corrupts on undo. Use a shadow-state accumulator or snapshot diffing.
- **Partial-success batch mutations.** If M of N operations succeed silently, undo replays M inverses on state that expected N. Validate all before mutating any, or use a compensation log.
- **No capture intent on mutations.** Without explicit IMMEDIATELY/NEVER/EVENTUALLY classification, the system must guess local vs remote — leading to remote changes in the undo stack or dropped local changes.
- **Shallow undo groups for drag operations.** Recording every intermediate `pointermove` as a separate undo entry forces users to Ctrl+Z dozens of times to undo one drag. Use marks (tldraw) or `captureTimeout: 0` + `stopCapturing()` (Yjs) to group drag operations.
- **Amending the previous commit after hook failure.** When a pre-commit hook fails, the commit didn't happen — `--amend` modifies the previous commit, destroying unrelated work. Always create a new commit after fixing hook failures.
