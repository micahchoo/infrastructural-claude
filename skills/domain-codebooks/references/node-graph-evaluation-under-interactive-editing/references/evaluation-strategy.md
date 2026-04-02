# FC1: Evaluation Strategy
## The Axis of HOW the Graph Is Evaluated

**Domain**: node-graph-evaluation-under-interactive-editing
**Seam coverage**: `Executor<I,O>` trait, `Compiler::compile()`, `DynamicExecutor`, `SIDE_EFFECT_FREE_MESSAGES`

---

## The Problem: Why Naive Evaluation Destroys Interactivity

A node graph editor faces a fundamental throughput problem: the user interacts continuously (mouse moves, parameter knobs, live preview toggles) while the document *is* the graph. Every pointer move during a drag can mutate a node parameter. If each mutation synchronously re-evaluates the entire graph, the UI thread stalls and the editor becomes unusable.

The naive model:

```
user_event → mutate_graph → evaluate_graph_fully → render → user_event → ...
```

For a graph with 100+ nodes where some nodes perform pixel-level raster operations (blur, gradient mesh, dehaze), this collapses to single-digit FPS within seconds of interaction.

The design tension: **how much evaluation to defer, and at what granularity to invalidate cached results**.

The five patterns below represent real choices made by production systems, each with a different trade-off surface.

---

## Pattern 1: Eager Full Re-evaluation

**Exemplar**: Excalidraw

### Structure

Every mutation to any element triggers a complete redraw of the entire scene. There is no graph, no caching, and no invalidation logic. The renderer is called unconditionally on each state change.

```typescript
// Excalidraw: every action dispatches setState, which triggers a full render pass
setState({ elements: updatedElements });
// → React reconciler → ExcalidrawCore.render() → canvas drawAll()
```

### When it works

- Scene is flat (no dependency graph)
- Operations are cheap (vector 2D transforms, no raster processing)
- Frame budget is ample relative to scene complexity

### When it breaks

- Any operation with superlinear cost (convolution, mesh deformation, compositing layers)
- Deep hierarchies where a root change cascades to thousands of descendants
- Real-time parameter scrubbing (slider at 60 events/sec × expensive op = 60 full renders/sec)

### Consequences of forced adoption in a node graph

If Graphite removed its evaluation pipeline and adopted eager full re-evaluation:
- Every pointer move during drag triggers a full `BorrowTree::eval_tagged_value()` call on the output node, pulling the entire subgraph
- No dedup: `RunDocumentGraph` fires on every `PointerMove` event
- All memoized intermediate results (`MemoNode` caches) are bypassed because the graph is not queried incrementally

---

## Pattern 2: Reactive Signal Derivation

**Exemplar**: tldraw (`@tldraw/state` / signia)

### Structure

State is split into `atom` (mutable root) and `computed` (derived). A `computed` records which atoms it read during its last evaluation. On atom write, only the computed values that transitively depend on that atom are marked stale. Re-reads trigger lazy recomputation.

```typescript
// tldraw — conceptual
const camera = atom('camera', { x: 0, y: 0, zoom: 1 })
const viewport = computed('viewport', () => {
  const { x, y, zoom } = camera.get()  // recorded as dependency
  return screenToWorld(x, y, zoom)
})

transact(() => {
  camera.set({ ...camera.get(), zoom: 1.5 })
  // viewport not recomputed yet — only marked stale
})
// viewport.get() → recomputes now, on demand
```

`transact()` batches multiple atom writes into a single invalidation pass, preventing intermediate states from triggering cascading recomputation.

### When it works

- Dependency graph is known at write time (reactive tracking)
- Most reads are read-heavy, write-sparse
- Operations are cheap enough to recompute synchronously on the read path

### When it breaks

- Nodes with expensive side effects (GPU texture upload, network fetch) cannot be safely re-triggered by auto-tracking
- Cycle detection is non-trivial in user-constructed graphs
- The user graph topology changes (new connections) require re-wiring the reactive dependency map, which is expensive

### Adaptation gap for Graphite

Graphite's graph is user-constructed at runtime — the dependency topology is not known at compile time. Reactive auto-tracking requires a fixed call graph. The `node_registry` approach (registering concrete node types via macros) means dependencies are resolved during `Compiler::compile()`, not during reactive tracking. A reactive layer would need to sit above the existing compilation pipeline.

---

## Pattern 3: Demand-Driven Async Evaluation

**Exemplar**: Krita (`KisUpdateScheduler`, `KisStrokeStrategy`)

### Structure

Mutations are submitted as **stroke jobs** to an async queue. The scheduler distinguishes job types:

- **Sequential**: must not overlap with any other job (graph-mutating operations)
- **Concurrent**: can run in parallel with other concurrent jobs (read-only compositing)
- **Barrier**: must wait for all preceding jobs to complete

During stroke execution, Krita renders LOD (Level of Detail) proxies — low-resolution versions of the full compositing result. The LOD render uses downsampled tiles so the display stays responsive. When the stroke job completes, a full-resolution upgrade job is enqueued.

```cpp
// Krita — conceptual
class KisStrokeStrategy {
    virtual KisStrokeJobData* createInitJob() = 0;
    virtual KisStrokeJobData* createDabJob(const KisPaintInformation&) = 0;
    virtual KisStrokeJobData* createFinishingJob() = 0;
};
// Scheduler drains queue, assigns jobs to worker threads by type
```

The LOD render is a form of approximate evaluation: the user sees a degraded-but-fast result during interaction, and the precise result materializes after the interaction ends.

### When it works

- Operations are naturally decomposable into tiles or LOD levels
- The "approximate fast" result is visually acceptable during interaction
- CPU cores are available for background workers

### When it breaks

- Operations where there is no valid approximation (e.g., vector boolean operations — the result is either exact or wrong)
- Synchronization overhead for the scheduler exceeds the cost of just running the operation
- Operations that depend on the full-resolution result of a prior operation (no valid LOD chain)

### Adaptation gap for Graphite

Graphite's `DynamicExecutor` runs the full graph on each call. Adding LOD would require nodes to declare a "low-res mode" and the executor to thread that mode through the call chain — a significant API change to `Node::eval()`. The `Executor<I,O>` trait currently has no concept of resolution or quality level.

---

## Pattern 4: Interpreted Pipeline Execution (Graphite's Approach)

**Source files**:
- `node-graph/graph-craft/src/graphene_compiler.rs` — `Compiler` struct and `Executor<I,O>` trait
- `node-graph/interpreted-executor/src/dynamic_executor.rs` — `DynamicExecutor`, `BorrowTree`
- `editor/src/dispatcher.rs` — `SIDE_EFFECT_FREE_MESSAGES` dedup

### Structure

Graphite separates graph evaluation into three stages:

**Stage 1 — Compilation** (`Compiler::compile`): The user-facing `NodeNetwork` (document model) is transformed into a flat `ProtoNetwork`. This involves flattening subgraphs, resolving scope inputs, eliminating identity nodes, and assigning stable node IDs. The compiler does not execute any node logic.

```rust
// node-graph/graph-craft/src/graphene_compiler.rs
pub struct Compiler {}

impl Compiler {
    pub fn compile(&self, mut network: NodeNetwork)
        -> impl Iterator<Item = Result<ProtoNetwork, String>>
    {
        network.populate_dependants();
        for id in node_ids { network.flatten(id); }
        network.resolve_scope_inputs();
        network.remove_redundant_id_nodes();
        let proto_networks = network.into_proto_networks();
        proto_networks.map(|mut proto_network| {
            proto_network.insert_context_nullification_nodes()?;
            proto_network.generate_stable_node_ids();
            Ok(proto_network)
        })
    }
}

pub trait Executor<I, O> {
    fn execute(&self, input: I) -> LocalFuture<'_, Result<O, Box<dyn Error>>>;
}
```

**Stage 2 — Instantiation** (`BorrowTree::new` / `update`): The `ProtoNetwork` is walked and each node is instantiated as a `Box<dyn ...>` using the constructor from `node_registry::NODE_REGISTRY`. Nodes are stored in a `HashMap<NodeId, SharedNodeContainer>`. On re-runs, `BorrowTree::update()` diffs the old and new `ProtoNetwork` and only instantiates changed nodes, reusing unchanged ones.

**Stage 3 — Execution** (`DynamicExecutor::execute`): The output node is called with the input. Each node's `eval()` pulls from its input nodes recursively. `DynamicExecutor` implements `Executor<I, TaggedValue>`.

```rust
// node-graph/interpreted-executor/src/dynamic_executor.rs
impl<I> Executor<I, TaggedValue> for &DynamicExecutor
where I: StaticType + 'static + Send + Sync + std::panic::UnwindSafe
{
    fn execute(&self, input: I) -> LocalFuture<'_, Result<TaggedValue, Box<dyn Error>>> {
        Box::pin(async move {
            let result = self.tree.eval_tagged_value(self.output, input);
            let wrapped = std::panic::AssertUnwindSafe(result).catch_unwind().await;
            match wrapped {
                Ok(result) => result.map_err(|e| e.into()),
                Err(e) => { Box::leak(e); Err("Node graph execution panicked".into()) }
            }
        })
    }
}
```

**Dedup layer** (`SIDE_EFFECT_FREE_MESSAGES`): The dispatcher deduplicates `RunDocumentGraph` and `SubmitActiveGraphRender` messages in the queue. If the same message appears multiple times (e.g., from multiple `PointerMove` events in one frame), only the last occurrence is dispatched.

```rust
// editor/src/dispatcher.rs (line ~48)
const SIDE_EFFECT_FREE_MESSAGES: &[MessageDiscriminant] = &[
    MessageDiscriminant::Portfolio(PortfolioMessageDiscriminant::Document(
        DocumentMessageDiscriminant::NodeGraph(NodeGraphMessageDiscriminant::RunDocumentGraph)
    )),
    MessageDiscriminant::Portfolio(PortfolioMessageDiscriminant::SubmitActiveGraphRender),
    // ...
];
```

### When it works

- Graph topology changes frequently (user rewires nodes)
- Nodes have heterogeneous types that cannot be monomorphized at compile time
- The same executor can be reused across runs with minimal re-instantiation cost
- The compilation step is cheap relative to execution (true for most node graphs)

### When it breaks

- The compilation step (`Compiler::compile`) is a full recompile on every graph change — no incremental compilation
- Every run of `DynamicExecutor::execute` walks the full output-to-input chain; there is no skipping of unchanged subgraphs within a single execution
- Panic recovery (`catch_unwind`) adds overhead and loses precise error location

---

## Pattern 5: Dirty Propagation

**Exemplars**: Substance Designer, Houdini ("cooking"), Blender dependency graph

### Structure

Each node maintains a **dirty flag**. When a node's inputs change, it marks itself dirty and propagates the dirty signal downstream to all dependent nodes. On render, only dirty nodes recompute. The propagation is forward (push), the recomputation is on-demand (pull).

```
NodeA (dirty) → NodeB (dirty) → NodeC (dirty) → Output
                              → NodeD (clean, no recompute needed)
```

Substance Designer adds a refinement: **cook ordering**. Nodes are cooked in topological order. If a node is clean, its cached output is used. If dirty, it is cooked and its output replaces the cache.

### When it works

- Graph topology is stable (user rarely rewires)
- Many nodes are clean on a given frame (sparse updates)
- Node outputs are large (textures, meshes) and expensive to recompute

### When it breaks

- Dirty propagation itself has cost: for highly connected graphs, a single upstream mutation can dirty most of the graph
- The dirty flag is conservative: it marks a node dirty even if the upstream change did not change the node's output value
- Requires persistent node identity across graph mutations (stable IDs), which complicates undo/redo

### Adaptation gap for Graphite

Graphite's `BorrowTree::update()` partially implements this: it diffs the old and new `ProtoNetwork` and only re-instantiates changed nodes. However, the execution step still walks the full graph from the output node on every run. Adding dirty propagation at execution time would require nodes to cache their last output and check whether their input hash changed before recomputing — which is what the `MemoNode` (see `node-graph/nodes/gcore/src/memo.rs`) provides at a per-node opt-in level.

---

## Decision Guide

| Criterion | Eager Full | Reactive Signal | Demand Async (LOD) | Interpreted Pipeline | Dirty Propagation |
|---|---|---|---|---|---|
| Graph topology changes frequently | Neutral | Bad (re-wire cost) | Neutral | Good | Bad (dirty map rebuild) |
| Operations are cheap | Required | OK | Wasteful | OK | Wasteful |
| Operations are expensive (raster/GPU) | Bad | Bad | Good | OK | Good |
| User constructs graph at runtime | N/A (no graph) | Bad | Neutral | Good | Good |
| Need exact results during interaction | Good | Good | Bad (LOD is approx) | Good | Good |
| Team size / complexity budget | Minimal | Medium | High | High | Medium |
| Undo/redo with stable node identity | Neutral | Medium | Hard | Medium | Required |

**Choose Eager Full** when: there is no graph, operations are O(n) with small constant, and frame rate is not a concern.

**Choose Reactive Signal** when: the dependency graph is known at write time, operations are synchronous and cheap, and you want zero-overhead re-renders for unchanged branches.

**Choose Demand Async (LOD)** when: operations are raster/GPU-heavy, approximate previews are acceptable during interaction, and you have multiple CPU/GPU cores to exploit.

**Choose Interpreted Pipeline** when: the graph is user-constructed at runtime, types are heterogeneous, and you need a swappable execution backend (WASM, GPU, CLI).

**Choose Dirty Propagation** when: graph topology is stable, node outputs are large and expensive, and you have a persistent node identity scheme.

---

## Anti-patterns and Consequences

### Anti-pattern: Re-running the full pipeline on every pointer event

**Symptom**: `RunDocumentGraph` is enqueued on every `PointerMove` without dedup.

**Consequence**: At 60 pointer events/sec with a 50-node graph, the executor runs 60 times/sec regardless of whether the user has finished dragging. On Graphite, this is prevented by `SIDE_EFFECT_FREE_MESSAGES` deduplication in the dispatcher.

**What breaks if removed**: Every pointer move during drag triggers a full `BorrowTree::eval_tagged_value()` call. For raster nodes (blur, dehaze), this is a multi-millisecond operation, resulting in single-digit FPS during drag.

### Anti-pattern: Full recompile on every parameter change

**Symptom**: `Compiler::compile()` is called every time a node parameter changes, even if the graph topology (connections) has not changed.

**Consequence**: The compilation step (flatten, resolve scopes, generate stable IDs) is O(n nodes) and involves allocation. For a 100-node graph changed 60 times/sec, this is 6000 compile passes/sec before any evaluation occurs.

**Mitigation**: Separate parameter-only changes (which only require re-execution, not re-compilation) from topology changes (which require both). Graphite's `MemoNetwork` hash allows detecting whether the network has actually changed before triggering a recompile.

### Anti-pattern: Synchronous evaluation on the UI thread

**Symptom**: `DynamicExecutor::execute()` is awaited on the UI event loop without yielding.

**Consequence**: The UI thread blocks for the duration of graph evaluation. For async GPU operations, this causes the event loop to stall waiting for the GPU fence.

**Mitigation**: Graphite's `Executor<I,O>` trait returns a `LocalFuture`, allowing the evaluation to be driven by an async runtime that can interleave with other tasks.

### Anti-pattern: Bypassing the Executor trait for one-off evaluations

**Symptom**: Code calls `BorrowTree::eval()` directly instead of going through `DynamicExecutor::execute()`.

**Consequence**: Panic recovery (`catch_unwind`), type erasure via `TaggedValue`, and the strategy-swappable `Executor<I,O>` seam are all bypassed. The evaluation is no longer observable by the introspection / monitor node system.
