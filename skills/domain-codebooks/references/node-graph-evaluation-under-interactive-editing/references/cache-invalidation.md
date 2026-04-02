# FC1: Cache Invalidation
## The Axis of WHEN to Recompute

**Domain**: node-graph-evaluation-under-interactive-editing
**Seam coverage**: `MemoNetwork`, `MemoNode` (gcore), `BorrowTree::update()`, `SIDE_EFFECT_FREE_MESSAGES`

---

## The Problem: Over-invalidation vs. Under-invalidation

Cache invalidation in a node graph has two failure modes:

**Over-invalidation**: Discarding valid cached results that did not need to be recomputed. Cost is wasted CPU/GPU time and reduced interactivity. Example: recomputing a blur node whose parameters have not changed because an unrelated node upstream was touched.

**Under-invalidation**: Serving a stale cached result when the inputs have actually changed. Cost is incorrect renders — the user sees old data. In a graphics editor, this is a correctness bug, not just a performance bug.

The tension is asymmetric: **under-invalidation produces wrong output, over-invalidation produces slow output**. Most systems therefore err on the side of over-invalidation and tune performance afterward.

The five patterns below represent different points on the over/under spectrum and different mechanisms for tracking what is stale.

---

## Pattern 1: Conservative Full Invalidation (Graphite's MemoNetwork)

**Source files**:
- `editor/src/messages/portfolio/document/utility_types/network_interface/memo_network.rs`
- `node-graph/nodes/gcore/src/memo.rs`

### Structure

`MemoNetwork` wraps a `NodeNetwork` and lazily computes a hash of the network's content. The hash is cached in a `Cell<Option<u64>>` (interior mutability, no `&mut` required). Any mutable access to the network invalidates the hash immediately.

```rust
// editor/.../memo_network.rs
pub struct MemoNetwork {
    network: NodeNetwork,
    hash_code: Cell<Option<u64>>,
}

impl MemoNetwork {
    pub fn network_mut(&mut self) -> &mut NodeNetwork {
        self.hash_code.set(None);   // invalidate on ANY mutable access
        &mut self.network
    }

    pub fn current_hash(&self) -> u64 {
        let mut hash_code = self.hash_code.get();
        if hash_code.is_none() {
            hash_code = Some(self.network.current_hash());
            self.hash_code.set(hash_code);
        }
        hash_code.unwrap()
    }
}
```

The hash is **content-addressed**: two networks with identical structure and parameters produce the same hash, regardless of when they were created. This allows the executor to skip recompilation when the network hash has not changed between frames.

At the node level, `MemoNode` (opt-in, per-node) caches a single input-output pair:

```rust
// node-graph/nodes/gcore/src/memo.rs
async fn memo<I: Hash + Send + 'n, T: Clone + WasmNotSend>(
    input: I,
    #[data] cache: Arc<Mutex<Option<(u64, T)>>>,
    node: impl Node<I, Output = T>,
) -> T {
    let mut hasher = DefaultHasher::new();
    input.hash(&mut hasher);
    let hash = hasher.finish();

    // Cache hit: same hash as last call
    if let Some(data) = cache.lock().as_ref().unwrap().as_ref()
        .and_then(|data| (data.0 == hash).then_some(data.1.clone()))
    {
        return data;
    }

    let value = node.eval(input).await;
    *cache.lock().unwrap() = Some((hash, value.clone()));
    value
}
```

Only **one** input-output pair is cached per `MemoNode`. A different input evicts the single cached entry.

### Invalidation granularity

- `MemoNetwork` invalidates at graph level: any mutation to any node invalidates the top-level hash
- `MemoNode` invalidates at node level: any change to that node's specific input invalidates its cache
- There is no intermediate granularity (subgraph, layer group, etc.)

### When it works

- The network changes infrequently relative to the cost of re-evaluation
- The hash computation itself is cheap compared to re-evaluation
- Most frames re-execute the same graph with the same inputs (animation playback, viewport pan)

### When it breaks

- A user scrubs a single parameter at 60 events/sec: the network hash changes 60 times/sec, defeating the top-level cache
- `network_mut()` is called defensively (e.g., even for read-only operations that happen to take `&mut`) — every such call invalidates the hash unnecessarily
- The hash algorithm has collisions across different network states — this would cause under-invalidation (incorrectly treated as clean)

### What breaks if MemoNetwork is removed

Without `MemoNetwork`, the hash comparison that guards recompilation is impossible. Every message dispatch that might have changed the graph would trigger a full `Compiler::compile()` + `DynamicExecutor::update()` cycle, even for no-op mutations. This turns the dedup provided by `SIDE_EFFECT_FREE_MESSAGES` from a performance optimization into a strict necessity (the system only survives because message dedup reduces the rate of recompile triggers).

---

## Pattern 2: Fine-Grained Dirty Flags (Blender Dependency Graph)

**Exemplar**: Blender `DEG_` API

### Structure

Blender's dependency graph (`depsgraph`) assigns each node a `ComponentDepsNode` with a dirty flag per output tag. When a property changes, only the downstream nodes that depend on that specific property are marked dirty. Tags include geometry, transform, shading, and animation.

```c
// Blender — conceptual
void DEG_id_tag_update(ID *id, int flag) {
    // Walk forward edges from id, mark dependent nodes dirty
    // Only nodes that consume the flagged component type are dirtied
}
```

The key refinement over conservative invalidation: a node can be dirty for **geometry** but clean for **shading**. If only shading is requested, the geometry subgraph is not recomputed.

### When it works

- Nodes have well-defined output components with independent dirty flags
- Partial re-evaluation (e.g., only update the transform, not the mesh) is common
- The component decomposition is stable and known at design time

### When it breaks

- Output components are not cleanly separable (a node whose output depends on both geometry and shading simultaneously)
- The dirty flag tracking system itself becomes a source of bugs (missing a tag means stale data)
- User-defined nodes (script nodes) cannot declare their component dependencies ahead of time

### Adaptation gap for Graphite

Graphite nodes are generic functions (`Node<I, Output = O>`). They do not have a concept of output components. Adding fine-grained dirty flags would require nodes to declare dependency tags in the `node_registry` macro, and the executor to respect those tags during traversal. This is architecturally possible but would require changes to every node definition.

---

## Pattern 3: Reactive Auto-Tracking (tldraw Computed Signals)

**Exemplar**: tldraw `computed` / signia

### Structure

`computed` values automatically record which `atom`s they read during evaluation. This creates an implicit dependency graph. When an atom changes, only computed values that transitively read that atom are invalidated.

```typescript
// tldraw — conceptual
const shapeColor = atom('shapeColor', 'red')
const strokeWidth = atom('strokeWidth', 2)

const renderProps = computed('renderProps', () => {
    // Both atoms are recorded as dependencies during this call
    return { color: shapeColor.get(), width: strokeWidth.get() }
})

// Change only shapeColor → only renderProps is invalidated (not unrelated computeds)
shapeColor.set('blue')
```

The invalidation is **precise**: no false positives (a computed is not invalidated unless one of its actual dependencies changed), and no false negatives (any change to a dependency triggers invalidation).

### When it works

- Dependencies are stable across calls (the same atoms are read each time the computed runs)
- The overhead of dependency tracking (recording reads) is small relative to computation cost
- Atoms and computeds are defined at application startup, not constructed dynamically

### When it breaks

- Dynamic dependencies: if a computed conditionally reads different atoms based on a branch, the dependency set changes between runs. Reactive systems must re-execute to discover the new set after invalidation, which can cause cascading re-executions
- User-constructed graphs: the reactive system needs to know the dependency graph before execution, but in a node editor the graph is defined by the user at runtime
- Side effects: a computed that performs I/O or GPU upload cannot be safely re-triggered by auto-tracking without additional guards

### Adaptation gap for Graphite

The `Compiler::compile()` step resolves the dependency graph from the `NodeNetwork` into a flat `ProtoNetwork`. This is done once per compile, not lazily per read. Reactive auto-tracking would require wrapping every node input in a read-trackable atom, which conflicts with the current model where inputs are resolved at compile time and baked into `ConstructionArgs`.

---

## Pattern 4: LOD Proxy + Async Upgrade (Krita LodPreferences)

**Exemplar**: Krita `KisLodPreferences`, `KisUpdateScheduler`

### Structure

Krita maintains multiple levels of detail for each paint layer. During stroke input (high mutation rate), the compositor uses the lowest available LOD (e.g., 1/4 resolution) to produce a fast preview. When the stroke completes (mutation rate drops), an upgrade job is enqueued to recomposite at full resolution.

The cache is never "invalid" — it is always valid at some LOD. The question is whether the cached LOD is the requested LOD. If not, use the best available and upgrade asynchronously.

```
cache state per node: { lod0: valid, lod1: valid, lod2: stale }
request at lod2:
  → return lod1 (best available)
  → enqueue async upgrade job for lod2
  → when upgrade completes, notify display
```

### When it works

- There is a natural hierarchy of approximations (pixel grids, mip maps, mesh LOD)
- The user tolerates degraded quality during interaction (standard in raster painting, less so in vector editing)
- GPU/CPU parallelism allows background upgrades without blocking the UI

### When it breaks

- No valid approximation exists for the operation (exact boolean union, exact type rendering)
- The LOD upgrade is visible as a pop/flash in the UI (jarring for precision-sensitive operations)
- The LOD cache itself requires significant memory (storing multiple resolutions per node)

### Adaptation gap for Graphite

Graphite has no LOD concept in its current node API. The `Executor<I,O>` trait takes a single input and produces a single output with no quality parameter. Adding LOD would require either a new trait dimension or threading a quality hint through the `Context` / `Footprint` system that some nodes already use for viewport-aware rendering.

---

## Pattern 5: Content-Addressed Hashing (Nix/Bazel Style)

**Exemplars**: Nix package builds, Bazel hermetic builds; partially in Graphite's `MemoNetwork`

### Structure

Every node's cache key is a **cryptographic or structural hash of its complete inputs**, including all transitive upstream inputs. If the hash of a node's input matches the stored cache key, the cached output is used regardless of when it was computed or what other changes have occurred.

```
node_output_hash = hash(node_id, node_params, hash(upstream_node_1), hash(upstream_node_2))
```

This is **purely functional**: the same inputs always produce the same output. Under this model, invalidation is impossible — a hash match is a proof of validity.

Graphite's `MemoNetwork::current_hash()` is a partial implementation: it hashes the entire `NodeNetwork` structure to detect whether recompilation is needed. The `MemoNode` hashes its specific input to detect whether its individual cached output is still valid.

### When it works

- Operations are pure functions (same inputs → same outputs, no side effects)
- Hash computation is cheap relative to the operation
- Deduplication across sessions or users is valuable (shared build cache)

### When it breaks

- Operations have side effects (GPU state, file I/O) — hash equality does not guarantee output equality
- Hash collisions (rare but possible with non-cryptographic hashes like `DefaultHasher`)
- The hash of the input is more expensive to compute than the operation itself (rare but possible for small, fast nodes with large inputs)
- Floating-point inputs do not hash reproducibly across platforms (Graphite's `TaggedValue` has a `FakeHash` workaround for float variants)

### Graphite's FakeHash problem

```rust
// node-graph/graph-craft/src/document/value.rs
// We must manually implement hashing because some values are floats
// and so do not reproducibly hash (see FakeHash below)
#[allow(clippy::derived_hash_with_manual_eq)]
impl Hash for TaggedValue { ... }
```

Floats violate content-addressable hashing because `f64::NAN != f64::NAN` and platform-specific rounding can produce bitwise-different results for semantically equal computations. Graphite works around this with a custom `Hash` implementation that uses the bit pattern of floats, accepting that semantically equal floats with different bit patterns (e.g., `+0.0` vs `-0.0`) produce different hashes. This is a correctness risk for content-addressed caching.

---

## Decision Guide

| Criterion | Conservative Full | Fine-Grained Dirty | Reactive Auto-Track | LOD Proxy | Content-Addressed Hash |
|---|---|---|---|---|---|
| Implementation complexity | Low | High | Medium | Very High | Medium |
| Risk of stale renders | None (over-invalidates) | Low (if tags correct) | None (precise) | Low (LOD is valid) | None (hash is proof) |
| Overhead per mutation | Low | Medium (flag propagation) | Low (record reads) | Low (flag LOD stale) | High (hash inputs) |
| Works for GPU/raster ops | Yes | Yes | No (sync only) | Yes | Yes (if pure) |
| Works for user-built graphs | Yes | Needs node API | No (fixed graph) | Yes | Yes (if pure) |
| Memory overhead | Low | Low | Low | High (multi-LOD) | Medium (cache store) |
| Handles float inputs | Yes (hash issues) | Yes | Yes | Yes | Risky (hash stability) |

**Choose Conservative Full** when: simplicity is paramount, operations are expensive (makes over-invalidation cheap by comparison), and the graph mutation rate is low.

**Choose Fine-Grained Dirty** when: the graph has well-defined component outputs, partial re-evaluation is common, and you can afford to annotate every node with its component dependencies.

**Choose Reactive Auto-Track** when: the dependency graph is fixed at startup, operations are cheap, and you want zero-overhead re-renders for unchanged branches.

**Choose LOD Proxy** when: operations are raster/pixel-level, approximate results are acceptable during interaction, and you have parallel execution capacity.

**Choose Content-Addressed Hash** when: operations are pure functions, deduplication across sessions/users is valuable, and you can afford to hash all inputs (including transitive).

---

## Anti-patterns and Consequences

### Anti-pattern: Calling `network_mut()` for read-only operations

**Symptom**: Code takes `&mut MemoNetwork` and calls `network_mut()` to get a reference, even though it does not modify the network. The hash is invalidated unconditionally.

**Consequence**: Every such call forces a full rehash of the `NodeNetwork` on the next read of `current_hash()`. Over a 60fps frame budget with many such calls, this is measurable overhead.

**Fix**: Use `network()` (shared reference) for read-only access. Only call `network_mut()` when mutation is actually needed.

### Anti-pattern: Single-entry MemoNode for a node with multiple callers

**Symptom**: A `MemoNode` wrapping an expensive operation is shared (via `Arc`) between two downstream nodes that call it with different inputs alternately.

**Consequence**: The single-entry cache thrashes: every call from downstream A evicts the cache for downstream B, and vice versa. The node recomputes on every call, providing no memoization benefit.

**Fix**: Either give each downstream its own `MemoNode` instance, or use a multi-entry LRU cache instead of a single-entry one.

### Anti-pattern: Hashing mutable reference counts as "no change"

**Symptom**: A node's output contains an `Arc<T>`. The `TaggedValue` hash is based on the `Arc`'s pointer value (address). A new `Arc` containing the same data has a different address and therefore a different hash.

**Consequence**: The cache misses on every evaluation even though the data has not changed, because `Arc::new(same_data)` produces a new allocation with a new address.

**Fix**: Hash the contents of `Arc<T>`, not the pointer. In Graphite, most `TaggedValue` variants hash by value; the `Arc`-wrapped `WasmEditorApi` is explicitly handled.

### Anti-pattern: Treating LOD cache as always-valid for exact operations

**Symptom**: A vector boolean operation result is served from LOD-1 cache when LOD-0 (exact) is requested, on the assumption that the user "won't notice."

**Consequence**: Vector coordinates are wrong. Unlike raster operations where LOD degradation is visible as blur, vector operations produce topologically incorrect output at non-zero LOD. Boolean intersection of two paths at LOD-1 may completely miss intersections that exist at LOD-0.

**Fix**: LOD caching must be gated behind a node capability flag that only raster-safe nodes can set.
