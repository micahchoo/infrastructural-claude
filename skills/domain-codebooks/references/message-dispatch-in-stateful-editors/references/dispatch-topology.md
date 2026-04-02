# CODEBOOK FC2: Dispatch Topology in Stateful Editors

**Force Cluster**: FC2 — Message-Passing Architecture in Stateful Editors
**Seams covered**: Seam 8 (`MessageHandler<M,C>` trait), Seam 9 (`Message` enum), Seam 13 (`DeferMessageHandler`)
**Cross-references**: Excalidraw ActionManager, tldraw transact(), Penpot Potok, Krita KisStrokesQueue

---

## The Problem

A complex interactive editor has dozens of stateful subsystems: tool state, document state, layout, input handling, preferences, viewport, history. Mutations arrive from user gestures, timers, async results, and inter-subsystem signals. The core question is:

**How do you route a mutation request to the right subsystem(s), in the right order, without turning the codebase into a tangle of direct method calls?**

Secondary tensions:
- Type safety vs runtime flexibility
- Exhaustive routing vs extensibility cost
- Synchronous simplicity vs async completeness
- Monolithic dispatch vs handler autonomy

---

## Pattern 1: Flat Action Registry

**Exemplar**: Excalidraw `ActionManager`

### Structure

A central registry maps action names (strings) to `Action` objects. Each action carries: a `name`, a `perform` function (pure: `(elements, appState, ...) => { appState, elements }`), and optional `keyTest` / `contextItemLabel` metadata. The `ActionManager.executeAction(action)` method calls `perform`, then calls `setState` with the result.

```ts
// Excalidraw pattern (simplified)
const actionDeleteSelected: Action = {
  name: "deleteSelectedElements",
  perform: (elements, appState) => ({
    elements: deleteSelectedElements(elements),
    appState,
    commitToHistory: true,
  }),
};
actionManager.registerAction(actionDeleteSelected);
actionManager.executeAction(actionDeleteSelected);
```

### Properties
- **No queue**: Actions execute synchronously and immediately call `setState`
- **No type hierarchy**: Actions are identified by string name, not type
- **No inter-action messaging**: Actions cannot enqueue further actions; side effects go directly to React state
- **Pure `perform`**: The action function is a pure transform — state in, state out

### When it fits
- React-first architecture where React reconciliation handles update batching
- Actions map 1:1 to user gestures (undo, delete, copy) without cascading sub-operations
- Team wants discoverability via a flat registry rather than a type hierarchy

### Cost
- No compile-time exhaustiveness. Forgetting to register an action fails silently at runtime.
- Cannot express "action A triggers action B" without coupling A to ActionManager.
- Scaling to 50+ actions produces a flat registry with no structural grouping.

---

## Pattern 2: Hierarchical Typed Dispatch

**Exemplar**: Graphite `Message` enum + `MessageHandler<M,C>` trait

### Structure

Messages are a discriminated union organized hierarchically. The top-level `Message` enum wraps domain-specific sub-enums. A central dispatcher holds a struct of handlers, one per domain. Each handler implements `MessageHandler<M, C>` with a single `process_message(&mut self, message: M, responses: &mut VecDeque<Message>, context: C)` method.

```rust
// Graphite — utility_traits.rs:7
pub trait MessageHandler<M: ToDiscriminant, C> {
    fn process_message(&mut self, message: M, responses: &mut VecDeque<Message>, context: C);
    fn actions(&self) -> ActionList;
}

// Top-level enum (message.rs) — 15 domains
pub enum Message {
    Animation(AnimationMessage),
    Portfolio(PortfolioMessage),
    Tool(ToolMessage),
    KeyMapping(KeyMappingMessage),
    // ... 11 more
}
```

The dispatcher runs a **message loop**: dequeue a message, match its variant, construct the handler's context struct, call `process_message`. The handler appends further messages to `responses: &mut VecDeque<Message>`, which the dispatcher re-enqueues. This produces depth-first cascade: sub-messages from a handler run before the next sibling message.

A `Vec<VecDeque<Message>>` stack (not a flat queue) allows `schedule_execution(process_after_all_current: bool)` — handlers can choose whether sub-messages run immediately (pushed to current queue) or after all pending messages (pushed as a new queue level).

15 handler implementations: Animation, AppWindow, Broadcast, Clipboard, Debug, Defer, Dialog, InputPreprocessor, KeyMapping, Layout, MenuBar, Portfolio, Preferences, Tool, Viewport.

### Properties
- **Compile-time exhaustiveness**: The `match` in the dispatcher is exhaustive; the compiler rejects unhandled variants
- **Cascade semantics**: Sub-messages reuse the same dispatch loop — a handler can send any message to any domain
- **Domain isolation**: Each handler owns its state; cross-domain access goes through messages, not method calls
- **Context is explicit**: Each handler receives only the state it needs, assembled at dispatch time

### When it fits
- Large editors where subsystems must remain decoupled
- Mutation sequences that span multiple domains (e.g., a tool action that triggers document mutation, history recording, and a UI update)
- Teams that want exhaustiveness guarantees when adding domains

### Cost
- Adding a new domain requires 3-point modification: top-level enum, dispatcher match, `DispatcherMessageHandlers` struct
- Context construction is manual: adding a dependency to a handler requires editing the dispatcher
- Deep cascades are hard to trace in a debugger (though `message_logging_verbosity` mitigates this)

---

## Pattern 3: Observable Event Bus

**Exemplar**: Penpot Potok (`ptk/reify`)

### Structure

Events are ClojureScript records implementing the `ptk/Event` protocol. The dispatch function (`store/emit!`) puts events onto a `rx/Subject`. Handlers are subscribed streams. A `WatchEvent` protocol method returns an `Observable<Event>` — events can produce further events as a reactive stream, enabling async chains without explicit callbacks.

```clojure
;; Penpot pattern (simplified)
(defrecord MoveObjects [ids delta]
  ptk/UpdateEvent
  (update [_ state]
    (update-in state [:workspace-data] move-shapes ids delta))

  ptk/WatchEvent
  (watch [_ state _]
    (rx/of (dwu/commit-changes changes)
           (ptk/data-event :selection/update-bbox ids))))
```

### Properties
- **Observable chaining**: `WatchEvent` returns `Observable<Event>`, enabling async event chains (HTTP calls, timers) with the same event protocol
- **Protocol segregation**: An event implements `UpdateEvent` (sync state transform) OR `WatchEvent` (async side effects) OR both — concerns are separated by protocol, not by if-else
- **No exhaustive match**: New event types are added by implementing the protocol — no central registry modification
- **Backpressure-aware**: The rx pipeline can apply operators (debounce, merge, switchMap) directly to the event stream

### When it fits
- Clojure/ClojureScript stacks where immutable state + rx is natural
- Editors with significant async workflows (server sync, collaborative cursors) where Observable composition is cleaner than explicit state machines
- Teams comfortable with reactive mental models

### Cost
- Debugging reactive chains requires RxJS/rx devtools; stack traces cross async boundaries
- No compile-time exhaustiveness — silent drops if a handler stream has a bug
- Protocol dispatch is dynamic; TypeScript/Rust equivalents require trait objects with runtime overhead

---

## Pattern 4: Record-Diff Store

**Exemplar**: tldraw `transact()` + `squashRecordDiffs`

### Structure

The store holds records (shapes, bindings, pages) as a flat map. Mutations run inside `store.transact(() => { ... })`. The store tracks diffs (added/updated/removed records) during the transaction. `StoreSideEffects` provides `before`/`after` hooks that fire with the diff — reactive derivations and history recording both use this hook, not a message system.

```ts
// tldraw pattern (simplified)
editor.store.transact(() => {
  editor.store.put([updatedShape]);
  editor.store.put([updatedBinding]);
}); // → triggers StoreSideEffects.after(diff)
```

`squashRecordDiffs` merges adjacent diffs for undo history compaction. There is no message queue; mutations are direct store writes wrapped in transactions.

### Properties
- **No message indirection**: Mutations are direct store writes; the diff is the "message"
- **Atomic semantics**: All writes in a transaction commit or roll back together
- **Reactive derivation**: Computed signals (`computed(() => ...)`) derive from store records automatically; no explicit invalidation messages needed
- **History from diffs**: Undo/redo stores diffs, not message replays

### When it fits
- Editors where the document model is a flat record store (shapes, pages, bindings as rows)
- Teams that prefer reactive signals over message queues for derived state
- Use cases where atomic all-or-nothing semantics matter (collaborative conflict resolution)

### Cost
- Side effects (network sync, renderer calls) must be attached to `StoreSideEffects` hooks — can become an implicit global hook registry
- No built-in way to express "run this after all current transactions finish" without additional coordination
- Debugging requires diff inspection rather than readable message logs

---

## Pattern 5: Job Priority Queue

**Exemplar**: Krita `KisStrokesQueue` + `KisStrokeStrategy`

### Structure

Paint operations are `KisStrokeStrategy` objects submitted to a `KisStrokesQueue`. Strategies define jobs (initialization, data application, finishing) that run on a thread pool. The queue enforces sequencing: a `KisBarrierStrokeStrategy` blocks new strokes until all prior strokes complete. Concurrent vs sequential strategies coexist in the queue.

```cpp
// Krita pattern (conceptual)
class MyStrokeStrategy : public KisStrokeStrategy {
    void initStrokeCallback() override;      // runs once, thread-safe
    void doStrokeCallback(KisStrokeJobData*) override;  // per tile, concurrent
    void finishStrokeCallback() override;    // runs after all tiles complete
};
KisStrokeId id = image->startStroke(new MyStrokeStrategy());
image->addJob(id, new TileJobData(tile));
image->endStroke(id);
```

### Properties
- **Priority + ordering**: Jobs have priority levels; barriers enforce happens-before between stroke phases
- **Concurrent safe**: Tile-level jobs run in parallel; the strategy controls which parts are concurrent
- **No message hierarchy**: The "message" is the job data object; routing is by stroke strategy type, not by enum match
- **Thread model explicit**: The queue is designed for CPU-bound parallel rendering, not UI event handling

### When it fits
- Raster painting engines where per-tile parallelism is the primary optimization axis
- Editors where rendering and input handling run on separate threads with explicit synchronization
- Use cases requiring barrier semantics (wait for all tiles before committing to history)

### Cost
- Complex thread model; incorrect strategy implementations cause deadlocks or visual glitches
- Not suited to UI event handling where message order must be deterministic on the main thread
- Overhead of job scheduling is only worthwhile for CPU-intensive per-tile work

---

## Decision Guide

| Force | Recommended Pattern |
|---|---|
| Need compile-time exhaustiveness over message domains | Pattern 2 (Graphite hierarchical enum) |
| Need async event chains (HTTP, timers) inline with sync mutations | Pattern 3 (Penpot Observable bus) |
| Document model is a flat record store with reactive derivations | Pattern 4 (tldraw record-diff) |
| Actions map 1:1 to user gestures, React handles batching | Pattern 1 (Excalidraw flat registry) |
| CPU-bound rendering pipeline needing per-tile parallelism | Pattern 5 (Krita job queue) |
| Cross-domain cascade where A triggers B triggers C synchronously | Pattern 2 (Graphite — cascade via VecDeque) |
| Multiple domains must share state at dispatch time | Pattern 2 (Graphite — bespoke context structs) |

**Hybrid note**: Pattern 2 and Pattern 4 are not mutually exclusive. Graphite uses hierarchical dispatch; a future version could use a record-diff store as the document model while keeping the message dispatcher for routing.

---

## Anti-Patterns

**Direct cross-handler method calls**
Handler A holds a reference to Handler B and calls its methods directly. Breaks the encapsulation that message dispatch provides. Every refactor of B's API requires updating A. The de-factoring exercise: remove `MessageHandler` trait → every handler is ad-hoc, no uniform dispatch contract, and inter-handler dependencies become compile-time entanglements instead of runtime message sends.

**String-keyed dispatch at scale**
Using string action names (Pattern 1) for 50+ actions without namespacing. Silent failures when names drift. Acceptable at small scale; breaks down without a convention enforced by linting or types.

**Unbounded cascade without a stack depth limit**
Pattern 2's cascade is powerful but dangerous if a handler re-enqueues the same message type unconditionally. Without a cycle guard or depth limit, the message loop runs forever. Graphite's `Vec<VecDeque<Message>>` stack provides priority ordering but no cycle detection — this is a latent risk when adding new message cascades.

**Side effects inside `WatchEvent` returning cold observables**
In Pattern 3, if a `WatchEvent` returns a cold Observable that starts a network request each time it's subscribed, and the subscriber retries on error, the request fires multiple times. Observable-based dispatch requires careful hot/cold discipline.

**Transaction-scoped side effects in Pattern 4**
Calling `store.transact()` inside a `StoreSideEffects.after` hook creates nested transactions with unclear semantics. tldraw's hooks are designed to be read-only observers; mutations inside hooks bypass the normal transaction boundary.
