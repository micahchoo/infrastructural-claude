# CODEBOOK FC2: Batching and Dedup in Interactive Editors

**Force Cluster**: FC2 — Message-Passing Architecture in Stateful Editors
**Seams covered**: Seam 10 (`MessageDiscriminant` dedup), Seam 11 (`FrontendMessage` outbox), Seam 12 (`FRONTEND_UPDATE_MESSAGES` frame coalescing)
**Cross-references**: Excalidraw React reconciliation, tldraw `transact()` + `squashRecordDiffs`, Graphite discriminant lists

---

## The Problem

Interactive editors produce bursts of mutations. A single mouse-drag event may cause: tool state to update, the document graph to recompute, the canvas to re-render, rulers to redraw, layer panels to refresh, and history to record a new entry. If each mutation independently triggers a full UI update, the result is:

- **Redundant renders**: Rendering the canvas 5 times in a single 16ms frame produces no visible benefit and consumes CPU budget
- **UI flicker**: A partially-complete state (document updated, history not yet recorded) reaches the renderer mid-processing
- **Cascading invalidations**: A derived value recomputes before its dependencies have all updated, producing a temporarily inconsistent result

The core question: **How do you suppress redundant work without introducing stale-state bugs?**

Secondary tensions:
- Dedup correctness vs dedup granularity (which messages are safe to skip?)
- Batch atomicity vs update latency
- Frame-level coalescing vs immediate feedback for critical updates

---

## Pattern 1: No Dedup

**Exemplar**: Excalidraw — rely on React reconciliation

### Structure

Excalidraw's `ActionManager.executeAction` calls React's `setState` directly with the new `appState` and `elements`. React's reconciler diffs the virtual DOM and batches DOM mutations within its own scheduler. No application-level dedup or batching is implemented.

```ts
// Excalidraw pattern (simplified)
executeAction(action: Action) {
  const { appState, elements } = action.perform(
    this.getElementsIncludingDeleted(),
    this.getAppState(),
    // ...
  );
  this.setState({ appState, elements }); // React handles batching
}
```

React 18's automatic batching groups multiple `setState` calls within a single event handler into one render pass. This means that if two actions execute synchronously, React typically produces one render, not two.

### Properties
- **Zero application code**: No discriminant lists, no outbox, no frame counters
- **Framework-owned correctness**: React's diffing guarantees the DOM reflects the latest state, not intermediate states
- **Immediate consistency**: There is no buffering layer that could produce stale UI

### When it fits
- React-first architectures where the renderer is React itself
- Editors where mutations are infrequent enough that React's own batching is sufficient
- Teams that want to minimize custom infrastructure

### Cost
- React's batching only applies within React's scheduler. Mutations triggered by `setTimeout`, `Promise`, or WebSocket callbacks in React 17 and earlier do NOT batch automatically (fixed in React 18).
- Redundant renders are possible when actions fire outside React's event system.
- No application-level control: you cannot say "skip this render if the same update is already pending."

---

## Pattern 2: Discriminant-Based Dedup

**Exemplar**: Graphite `SIDE_EFFECT_FREE_MESSAGES` + `MessageDiscriminant`

### Structure

`MessageDiscriminant` is a lightweight copy of a message's variant path without its payload. It is derived at zero allocation cost via a `to_discriminant()` method on every message.

A `const` array `SIDE_EFFECT_FREE_MESSAGES: &[MessageDiscriminant]` lists message types that are idempotent: processing the same message twice produces the same result as processing it once. The dispatcher checks: if the current message's discriminant is already present in the current queue at the same depth, it skips the message.

```rust
// Graphite dispatcher.rs (conceptual)
const SIDE_EFFECT_FREE_MESSAGES: &[MessageDiscriminant] = &[
    MessageDiscriminant::Portfolio(PortfolioMessageDiscriminant::Document(
        DocumentMessageDiscriminant::RunDocumentGraph,
    )),
    // ... other idempotent messages
];

// In the dispatch loop:
if SIDE_EFFECT_FREE_MESSAGES.contains(&message.to_discriminant()) {
    if queue_already_contains(discriminant) {
        self.log_deferred_message(&message, ...);
        continue; // skip — an identical message is already pending
    }
}
```

`RunDocumentGraph` is the canonical example: when 5 mutations all enqueue "recompute the node graph", only one recomputation runs.

### Properties
- **Payload-free comparison**: Discriminants compare message type, not payload content. Two `RunDocumentGraph` messages with different parameters both deduplicate — the later one wins implicitly (the earlier was already dropped)
- **Opt-in**: Only explicitly listed messages are deduplicated. Non-listed messages always execute
- **Synchronous**: Dedup happens at enqueue time, not at a separate flush phase

### When it fits
- Editors with expensive recomputation (graph evaluation, layout passes) that multiple upstream mutations all trigger
- Message-based architectures where the message type alone (not its payload) determines dedup eligibility
- Cases where "run once" semantics are correct — the last-wins drop of intermediate payloads is acceptable

### Cost
- The `SIDE_EFFECT_FREE_MESSAGES` list is a manually-curated `const` array. Adding a new message domain and forgetting to add its "run" message to the list produces redundant expensive operations. There is no compiler enforcement.
- Payload-agnostic dedup is wrong for messages where the payload matters (e.g., "move layer X" and "move layer Y" have the same discriminant if they're the same enum variant, but different payloads — this would be a bug if they were accidentally deduplicated).
- Silent message drops are hard to debug without the `message_logging_verbosity` infrastructure.

---

## Pattern 3: Transactional Batching

**Exemplar**: tldraw `store.transact()`

### Structure

All mutations to the record store run inside an explicit transaction lambda. The store accumulates a diff (added/updated/removed records) during the transaction. Only when the transaction commits does the `StoreSideEffects.after(diff)` hook fire — once, with the complete diff. Subscribers (renderer, history, collaborative sync) receive one notification per transaction, not one per mutation.

```ts
// tldraw pattern (simplified)
editor.store.transact(() => {
  editor.store.put([shapeA_updated]);
  editor.store.put([bindingB_updated]);
  editor.store.put([pageC_updated]);
}); // → StoreSideEffects.after fires ONCE with all three changes merged
```

Transactions can be nested. Inner transaction commits are folded into the outer diff; the `after` hook fires only once when the outermost transaction commits.

### Properties
- **Structural batching**: The transaction boundary IS the batch boundary. No separate "flush" call needed.
- **All-or-nothing**: If code throws inside `transact()`, the partial diff is discarded (rollback semantics)
- **Diff-based subscribers**: Downstream code receives a complete diff, not a sequence of individual mutations — useful for collaborative sync (send one patch, not N patches)

### When it fits
- Flat record stores where the document model is a map of records
- Editors with collaborative sync where atomic diff batches map to network patches
- Use cases where rollback semantics are needed (validate-then-commit workflows)

### Cost
- Mutations must be inside `transact()` — ad-hoc mutations outside a transaction may fire `after` hooks per-mutation, defeating batching
- Rollback is all-or-nothing; there is no "commit some records, roll back others" within a single transaction
- Computed signals that depend on store records may read intermediate state inside a transaction if called synchronously — requires understanding of signal evaluation timing relative to transaction commits

---

## Pattern 4: Frame Coalescing

**Exemplar**: Graphite `FRONTEND_UPDATE_MESSAGES`

### Structure

A second `const` array, `FRONTEND_UPDATE_MESSAGES: &[MessageDiscriminant]`, lists messages that represent UI update requests (e.g., `DocumentStructureChanged`, `DocumentLayersChanged`). When the dispatcher encounters one of these messages, it does NOT process it immediately. Instead, it buffers it and defers processing until the next `AnimationFrame` message arrives — which is sent by the JavaScript host once per display frame (typically 60 Hz).

```rust
// Graphite dispatcher.rs (conceptual)
if FRONTEND_UPDATE_MESSAGES.contains(&message.to_discriminant()) {
    self.deferred_frontend_updates.insert(message.to_discriminant());
    continue; // skip now; will process on next AnimationFrame
}
```

This means 10 `DocumentStructureChanged` messages fired in one event handler become 1 UI update on the next frame.

### Properties
- **Frame-aligned**: UI updates align to display refresh, preventing sub-frame redundancy
- **Orthogonal to Pattern 2**: A message can be in both lists — it deduplicated within a pass AND coalesced to the next frame
- **Selective**: Not all messages are coalesced. Messages that need immediate feedback (e.g., `TriggerFontDataLoad`) bypass the buffer and flush immediately

### When it fits
- Editors where UI updates are driven by a requestAnimationFrame loop
- Cases where many mutations per frame are expected (dragging a slider, live-resizing)
- Architectures where the frontend and backend communicate over a message bridge (WASM, IPC) where batching reduces round-trip overhead

### Cost
- UI state can be up to one frame stale. For a 60 Hz display this is 16ms — imperceptible in most interactions, but potentially visible in latency-sensitive feedback (e.g., cursor position during pen input)
- The `FRONTEND_UPDATE_MESSAGES` list has the same manual-curation problem as `SIDE_EFFECT_FREE_MESSAGES`
- Immediate exceptions (messages that bypass the buffer) must be identified and hardcoded; getting this wrong produces either flickering (premature flush) or stale UI (missed flush)

---

## Pattern 5: Adjacent Entry Squashing

**Exemplar**: tldraw `squashHistoryEntries` / `squashRecordDiffs`

### Structure

tldraw's `HistoryManager` records undo entries. When a new entry arrives adjacent to the previous one (e.g., consecutive character insertions in a text field), the `squashHistoryEntries` function merges them: the combined entry covers the full range with a single before/after snapshot. This is structurally different from Pattern 3 (which batches at write time) — squashing happens at the history layer, after writes have committed.

```ts
// tldraw pattern (conceptual)
function squashHistoryEntries(prev: HistoryEntry, next: HistoryEntry): HistoryEntry {
  return {
    changes: squashRecordDiffs(prev.changes, next.changes),
    // before = prev.before, after = next.after
  };
}
```

`squashRecordDiffs` merges two diffs by applying the later diff's "after" values on top of the earlier diff's "before" values, collapsing intermediate states.

### Properties
- **Post-hoc**: Squashing runs after mutations commit, not during them — no need to predict squash eligibility before writing
- **History-semantic**: The squash boundary is a UX decision ("what constitutes one undo step") not a performance decision — though performance benefits
- **Composable**: `squashRecordDiffs` is a pure function on diffs, independently testable

### When it fits
- Editors with undo/redo where consecutive fine-grained mutations (typing, nudging) should form one undo step
- Architectures where the history layer is separate from the write layer
- Cases where the undo step boundary is defined by time or user intent, not by transaction boundaries

### Cost
- Squashing after the fact means intermediate states were briefly stored and then discarded — slightly more memory pressure than batching upfront
- Squash eligibility requires a predicate ("are these two entries squashable?") that can be subtle: text edits squash, but "insert then delete" should not squash into a no-op for undo purposes
- Does not help with render performance — squashing history does not reduce renders during the original mutations

---

## Decision Guide

| Force | Recommended Pattern |
|---|---|
| React architecture, infrequent mutations | Pattern 1 (No dedup — rely on React) |
| Expensive recomputation triggered by many upstream mutations | Pattern 2 (Discriminant dedup) |
| Document is a record store, need atomic diffs for sync | Pattern 3 (Transactional batching) |
| Many UI updates per animation frame, WASM/IPC bridge | Pattern 4 (Frame coalescing) |
| Consecutive fine-grained mutations should form one undo step | Pattern 5 (Squashing) |
| Need both render dedup AND undo coalescing | Pattern 2 + Pattern 5 together |
| Need both frame alignment AND idempotent dedup | Pattern 2 + Pattern 4 together (Graphite uses both) |

**Layering note**: Patterns 2, 4, and 5 are composable. Graphite uses Patterns 2 and 4 simultaneously. An editor using tldraw's store could combine Patterns 3 and 5. The patterns operate at different layers: Pattern 2 and 4 reduce processing/rendering work; Pattern 5 reduces undo history granularity.

---

## Anti-Patterns

**Deduplicating messages with payload-significant variants**
Adding a message to `SIDE_EFFECT_FREE_MESSAGES` when the message payload matters. If `MoveLayer(layer_id)` is marked side-effect-free and two `MoveLayer` calls for different layers arrive, the second is dropped. This silently skips an operation. The dedup list must only include messages where "run once" semantics are correct regardless of payload.

**Coalescing messages that require immediate user feedback**
Putting a cursor-update message into `FRONTEND_UPDATE_MESSAGES` defers it to the next animation frame. At 60 Hz this is 16ms. For cursor or hover feedback, this latency is perceptible. The frame coalescing list must only include messages whose staleness is invisible within one frame.

**Transaction-scoped mutations inside `StoreSideEffects` hooks**
Calling `store.put()` inside the `after` hook creates a new transaction. If that transaction also triggers the `after` hook, the result is an infinite update cycle. tldraw documents this constraint explicitly: `after` hooks must not write to the store.

**Manual flush without a lock**
Implementing an outbox (Pattern 4 variant) without ensuring the main-thread message loop is idle before flushing. If a flush fires while the loop is mid-processing, the frontend receives a partial state. Graphite avoids this by only flushing on `AnimationFrame`, which only arrives between event processing turns.

**Squashing into semantic no-ops**
`squashRecordDiffs(insertChar, deleteChar)` produces an empty diff — nothing changed. If this is stored as an undo entry, the user perceives an undo step that does nothing. Squash predicates must exclude inverse operations, not just consecutive same-type operations.
