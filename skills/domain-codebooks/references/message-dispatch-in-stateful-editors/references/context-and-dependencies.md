# CODEBOOK FC2: Context and Dependencies in Message Handlers

**Force Cluster**: FC2 — Message-Passing Architecture in Stateful Editors
**Seams covered**: Seam 8 (`MessageHandler<M,C>` trait — context type parameter), Seam 14 (context construction in dispatcher)
**Cross-references**: tldraw computed signals, traditional DI containers, global state approaches

---

## The Problem

A message handler for "move selected layer" needs: the current document, the selection state, the viewport transform, and possibly preferences. These live in other handlers' state. The handler cannot call the dispatcher (it would re-enter). It cannot import other handlers directly without creating cycles.

**How does a handler get access to state it doesn't own, without tight coupling or re-entrant dispatch?**

Secondary tensions:
- Least-privilege (give handlers only what they need) vs ergonomics (giving them everything is simpler)
- Compile-time safety (borrow checker catches missing deps) vs runtime flexibility (add deps without recompilation)
- Explicit wiring (readable but verbose) vs implicit wiring (concise but magical)

---

## Pattern 1: Global Mutable State

**Classic approach — the baseline to compare against**

### Structure

Handlers access dependencies through a globally accessible singleton (thread-local, `static Mutex<T>`, or process-global). There is no explicit dependency parameter. A handler reaches into global state directly.

```rust
// Classic anti-example
fn process_message(&mut self, message: ToolMessage, responses: &mut VecDeque<Message>) {
    let doc = GLOBAL_APP_STATE.lock().unwrap().active_document(); // reaches into global
    // ...
}
```

### Properties
- **Zero wiring**: No context struct, no constructor argument, no DI framework
- **Invisible dependencies**: A handler's full dependency surface is only visible by reading its implementation
- **Thread-unsafe by default**: Requires `Mutex` or `RwLock` for any multi-threaded use, and lock ordering must be manually maintained

### When it fits
- Scripts and prototypes where correctness matters less than speed of iteration
- Architectures with a single-threaded event loop where re-entrancy is impossible by construction (and even here, global state makes testing hard)

### Cost
- Testing requires manipulating global state — tests cannot run in parallel without careful isolation
- Every handler is implicitly coupled to every other handler's state layout
- Refactoring any piece of global state requires auditing all handlers

---

## Pattern 2: Manual Context Construction

**Exemplar**: Graphite — bespoke context struct per handler, assembled in the dispatcher

### Structure

Each handler's `process_message` signature takes a context type parameter `C`. The context type is a bespoke struct containing only the state that handler needs — not a god-object. The dispatcher constructs the context for each handler before calling `process_message`, pulling values from sibling handlers' state.

```rust
// Graphite — utility_traits.rs
pub trait MessageHandler<M: ToDiscriminant, C> {
    fn process_message(&mut self, message: M, responses: &mut VecDeque<Message>, context: C);
}

// Bespoke context for KeyMapping handler
pub struct KeyMappingMessageContext<'a> {
    pub input: &'a InputPreprocessorMessageHandler,
    pub actions: ActionList,
}

// Dispatcher constructs it manually (dispatcher.rs ~line 210)
Message::KeyMapping(message) => {
    let input = &self.message_handlers.input_preprocessor_message_handler;
    let actions = self.collect_actions();
    self.message_handlers.key_mapping_message_handler
        .process_message(message, &mut queue, KeyMappingMessageContext { input, actions });
}
```

The context is assembled from `&self.message_handlers.*` — Rust's borrow checker ensures the mutable borrow of the target handler and the immutable borrows of its dependencies do not alias.

### Properties
- **Least privilege**: Each handler's context type documents exactly what it can see. A handler that does not need preferences cannot accidentally read them.
- **Compile-time checked**: If the dispatcher fails to pass a required field, the code does not compile
- **No framework**: Context construction is plain struct initialization — no reflection, no container registration, no attribute macros
- **Readable wiring**: The dispatcher is the single file where dependencies are wired; grep `KeyMappingMessageContext` to see exactly what `KeyMapping` depends on

### When it fits
- Rust codebases where the borrow checker provides the safety guarantee
- Architectures where the set of handlers is fixed and known at compile time (15 handlers in Graphite's case)
- Teams that prefer explicit, auditable wiring over convention-based injection

### Cost
- **Adding a dependency requires modifying the dispatcher**: If `ToolMessageHandler` needs access to `PreferencesMessageHandler`, the developer must add it to `ToolMessageContext` AND update the dispatcher's construction code. This is the 3-point modification problem (enum + handler + context).
- **Context structs proliferate**: 15 handlers × bespoke context = 15 context structs to maintain. Some are `()` (no context needed), some are rich structs.
- **No late binding**: Dependencies are resolved at dispatch time, not lazily. A handler cannot say "give me preferences only if I need to access them."

---

## Pattern 3: Dependency Injection Container

**Traditional DI — Java Spring / .NET / InversifyJS style**

### Structure

A container maps interface types (or tokens) to implementations. Handlers declare their dependencies as constructor parameters or property annotations. The container resolves the full dependency graph at startup and injects instances.

```typescript
// Traditional DI (TypeScript / InversifyJS style)
@injectable()
class ToolMessageHandler {
    constructor(
        @inject(TYPES.PreferencesHandler) private prefs: IPreferencesHandler,
        @inject(TYPES.DocumentHandler) private doc: IDocumentHandler,
    ) {}

    processMessage(message: ToolMessage): void {
        const snap = this.prefs.getSnapSettings(); // injected, no global state
    }
}

const container = new Container();
container.bind<IPreferencesHandler>(TYPES.PreferencesHandler).to(PreferencesHandler);
container.bind<ToolMessageHandler>(ToolMessageHandler).toSelf();
const handler = container.get(ToolMessageHandler);
```

### Properties
- **Testability**: Inject mock implementations in tests — no global state manipulation
- **Decoupled interfaces**: Handler code depends on an interface type, not a concrete sibling handler
- **Late binding**: Container resolves dependencies at runtime — swap implementations without recompiling consumers
- **Auto-wiring**: Container can resolve transitive dependencies automatically, reducing boilerplate

### When it fits
- Large OOP codebases (Java, C#, TypeScript) where interface segregation is a first-class design concern
- Teams with strong testing culture where every handler needs to be independently unit-testable with mocks
- Architectures where implementations swap at runtime (e.g., different storage backends in dev vs prod)

### Cost
- **Runtime resolution errors**: Missing bindings fail at runtime, not compile time (unless using a code-generation approach)
- **Hidden dependency graphs**: The container knows the full graph; a developer reading handler code cannot see its dependencies without checking the container configuration
- **Framework overhead**: Reflection-based DI adds startup cost and makes tree-shaking in front-end bundles harder
- **Not idiomatic in Rust**: Rust's ownership model and lack of reflection make traditional DI containers awkward; manual wiring (Pattern 2) is idiomatic instead

---

## Pattern 4: Reactive Derivation

**Exemplar**: tldraw — `computed()` signals derive from store records

### Structure

Instead of passing state to handlers, derived state is computed lazily from a reactive store. A `computed(() => ...)` signal re-evaluates when its store dependencies change. Handlers (in tldraw's model, methods on the `Editor` class) read from the store and from computed signals directly — no context injection needed.

```ts
// tldraw pattern (simplified)
class Editor {
    // Derived state — no explicit passing needed
    readonly selectedShapeIds = computed(() =>
        this.store.get(this.currentPageId)?.selectedShapeIds ?? []
    );

    readonly selectedShapes = computed(() =>
        this.selectedShapeIds.value.map(id => this.store.get(id))
    );

    moveSelectedShapes(delta: Vec2) {
        // Reads derived signal inline — no context parameter
        const shapes = this.selectedShapes.value;
        this.store.transact(() => {
            for (const shape of shapes) {
                this.store.put([{ ...shape, x: shape.x + delta.x }]);
            }
        });
    }
}
```

Computed signals are memoized — they only recompute when dependencies change. Reading `selectedShapes.value` inside `moveSelectedShapes` costs nothing if selection has not changed since last read.

### Properties
- **Pull, not push**: Handlers pull the state they need at call time; no one pushes context to them
- **Automatic dependency tracking**: The reactive system tracks which store records each computed reads — invalidation is automatic
- **No context structs**: Handlers are methods on a class with `this.store` access; no bespoke context types needed
- **Lazy evaluation**: Computed values are only recalculated when read, and only if dependencies changed — no redundant work

### When it fits
- Editors built on a reactive signal system (MobX, Solid.js, Svelte stores, Preact signals)
- Document models that are flat record stores with many derivable views (selection, z-order, visible shapes)
- Teams that prefer derived state over explicit message passing for read access

### Cost
- **Write paths still need coordination**: Reactive signals handle reads elegantly, but writes still need to be coordinated (via `transact()` in tldraw's case). The context problem is not fully solved for write dependencies.
- **Observable over-computation**: If a computed signal has a wide dependency set, it re-evaluates on any change to any dependency — requires careful scoping of what each signal reads
- **Debugging reactivity**: When a computed value is wrong, tracing the reactivity graph to find the stale source requires specialized devtools (MobX devtools, etc.)
- **Not suited for Rust without runtime overhead**: Rust's `Arc<RwLock<T>>` approach to reactive signals introduces locking overhead and loses the borrow-checker's static safety guarantees

---

## Decision Guide

| Force | Recommended Pattern |
|---|---|
| Rust, borrow checker provides safety, fixed handler set | Pattern 2 (Manual context construction) |
| TypeScript/Java/C#, testing culture requiring mocks | Pattern 3 (DI container) |
| Document model is a reactive store, reads vastly outnumber writes | Pattern 4 (Reactive derivation) |
| Prototype, single-threaded, correctness secondary | Pattern 1 (Global state — only acceptable as a starting point) |
| Need to audit exactly what each handler can access | Pattern 2 (context structs are self-documenting) |
| Need to swap implementations at runtime | Pattern 3 (DI container) |
| Need to minimize boilerplate for many small handlers | Pattern 4 (signals) or Pattern 3 (auto-wired DI) |

**Hybrid note**: Pattern 2 and Pattern 4 address different sides of the same problem. Pattern 2 manages write-time dependency passing (what state does a handler need to mutate?). Pattern 4 manages read-time dependency access (what state can a handler observe?). An architecture combining tldraw's reactive store (reads via signals) with Graphite's explicit context (writes via bespoke contexts) would address both sides cleanly.

---

## Anti-Patterns

**God context struct**
One context type shared by all handlers: `struct AppContext { portfolio: &Portfolio, prefs: &Preferences, input: &Input, ... }`. Passes everything to every handler. Loses least-privilege entirely. The compiler no longer tells you which handlers depend on which state. Testing requires constructing the full context even for handlers that only need one field.

**Re-entrant dispatch for dependency access**
A handler that needs document state enqueues a `GetDocumentState` message and waits for the response. This re-enters the dispatcher from within the dispatcher — either deadlocking (if the dispatcher uses a mutex) or producing unexpected message ordering (if it doesn't). Dependencies should be passed as context, not fetched via messages.

**Context passed by value containing large state**
Constructing a context struct that clones large data structures per message. Graphite's contexts use references (`&'a InputPreprocessorMessageHandler`), not owned copies. Passing owned copies of document state per message would make dispatch O(n) in document size.

**Circular context dependencies**
Handler A's context requires state from Handler B, and Handler B's context requires state from Handler A. The dispatcher cannot construct both contexts simultaneously without introducing shared mutable references. This is a design smell indicating A and B are too tightly coupled and should share a single handler or extract a common dependency.

**Implicit global via thread-local**
Using `thread_local! { static STATE: RefCell<AppState> }` as a "not technically global" global. Provides slightly better isolation than a true global, but retains all the testability and auditability problems. Tests running in the same thread share the thread-local. This pattern appears in legacy code being migrated from globals — it is not a destination pattern.

---

## De-factoring: What Happens Without Manual Context Construction

The de-factoring exercise for Seam 14: remove bespoke context structs, have handlers access global state instead.

**Immediate effects**:
1. The borrow checker can no longer enforce that a handler doesn't mutate state it's only supposed to read. The compiler was providing a safety guarantee that disappears.
2. Adding a new handler no longer requires touching the dispatcher — which sounds like a win, but means dependencies are invisible. A handler silently gaining access to all state is an anti-pattern, not a feature.
3. Testing a single handler requires constructing and populating global state — tests become integration tests by default.

**Downstream effects**:
4. Refactoring state layout (e.g., moving a field from `Portfolio` to `Document`) requires finding all handlers that access it — grep replaces the compiler.
5. Concurrent execution becomes dangerous: two handlers running on different threads both read/write global state without the borrow checker's aliasing guarantees.

The manual context construction pattern's verbosity (15 context structs) is load-bearing. It is the mechanism by which the architecture enforces the dependency boundaries that make the system auditable and testable.
