# FC1: Type Resolution
## The Axis of Type Safety vs. Runtime Flexibility

**Domain**: node-graph-evaluation-under-interactive-editing
**Seam coverage**: `TaggedValue`, `DynamicExecutor` (`Box<dyn ...>`), `node_registry()`, `Executor<I,O>` trait, `BorrowTree`

---

## The Problem: Procedural Graphs Need Typed Connections but Users Want Freedom

A node graph editor faces a type system paradox:

- **The compiler wants**: statically typed connections so mismatched wires are caught at graph-build time, enabling monomorphization and zero-cost abstractions.
- **The user wants**: the freedom to connect any output to any input and discover what happens, without the editor refusing connections or requiring type annotations.
- **The runtime needs**: a single execution path that can handle 100+ node types without combinatorial explosion of monomorphized variants.

The four patterns below represent fundamentally different resolutions to this tension. Each trades some combination of compile-time safety, runtime flexibility, and execution performance.

---

## Pattern 1: Fully Static Types (Compile-Time Monomorphization)

### Structure

Every node is a generic Rust function. Connections between nodes are resolved at Rust compile time. The compiler instantiates a concrete version of each node for each concrete type combination.

```rust
// Hypothetical fully static approach
fn blur_node<T: ImageLike>(input: T, radius: f32) -> T { ... }
fn color_adjust_node<T: ColorSpace>(input: T, brightness: f32) -> T { ... }

// Connection: types must match at Rust compile time
let blurred = blur_node(source_image, 5.0);
let adjusted = color_adjust_node(blurred, 1.2);
```

### When it works

- The set of node types and all valid connection topologies are known at Rust compile time
- Performance is critical: monomorphization eliminates vtable dispatch and enables inlining
- The graph structure is fixed (e.g., a shader pipeline, not a user-editable graph)

### When it breaks

- The user adds a new node type at runtime — this requires a new Rust compilation
- The user creates a connection that is valid in the domain (e.g., any raster image to any filter) but the specific type pair was not anticipated at compile time
- 100 node types with 10 possible input/output types yields up to 1000 monomorphized variants — compile time and binary size explosion

### Why Graphite does not use this

Graphite's graph is user-constructed at runtime. The set of valid node connections is not known at Rust compile time. A node that accepts `Raster<CPU>` may later need to accept `Raster<GPU>` — the type parameter is determined by what the upstream node produces, which is determined by the user's wiring, which is determined at runtime.

The `node_registry` macro system does generate monomorphized constructors for each (node, type) combination, but these are registered in a `HashMap` and looked up at runtime — not resolved at Rust compile time for the specific graph topology the user has constructed.

---

## Pattern 2: Runtime Type Erasure (Graphite's DynamicExecutor)

**Source files**:
- `node-graph/interpreted-executor/src/dynamic_executor.rs` — `DynamicExecutor`, `BorrowTree`, `TypeErasedBox`
- `node-graph/graph-craft/src/graphene_compiler.rs` — `Executor<I,O>` trait
- `node-graph/interpreted-executor/src/node_registry.rs` — `NODE_REGISTRY`

### Structure

Each node is stored as a `Box<dyn Node<Box<dyn DynAny>, Output = FutureAny>>` (a `TypeErasedBox`). The concrete type is erased at instantiation time. At execution time, the output is a `Box<dyn DynAny>` that must be downcasted to the expected type.

```rust
// node-graph/interpreted-executor/src/dynamic_executor.rs

/// An executor that uses Box<dyn ...> — no online compilation server required.
pub struct DynamicExecutor {
    output: NodeId,
    tree: BorrowTree,           // stores TypeErasedBox per node
    typing_context: TypingContext,
    orphaned_nodes: HashSet<NodeId>,
}

// BorrowTree stores nodes as SharedNodeContainer = Arc<NodeContainer>
// NodeContainer wraps TypeErasedBox<'static>
pub struct BorrowTree {
    nodes: HashMap<NodeId, (SharedNodeContainer, Path)>,
    source_map: HashMap<Path, (NodeId, NodeTypes)>,
}
```

At execution, the output node is called with a type-erased input, and the result is captured as a `TaggedValue` (see Pattern 4) via `eval_tagged_value`:

```rust
// dynamic_executor.rs
pub async fn eval_tagged_value<I>(&self, id: NodeId, input: I) -> Result<TaggedValue, String>
where
    I: StaticType + 'static + Send + Sync,
{
    let (node, _path) = self.nodes.get(&id).cloned()
        .ok_or("Output node not found in executor")?;
    let output = node.eval(Box::new(input));
    TaggedValue::try_from_any(output.await)
}
```

`TaggedValue::try_from_any` recovers the concrete type by checking `TypeId` at runtime and downcasting via `dyn_any::downcast`.

Node instantiation from the registry uses a constructor function signature:

```rust
// node-graph/interpreted-executor/src/node_registry.rs
type NodeConstructor = fn(Vec<SharedNodeContainer>) -> LocalFuture<'static, TypeErasedBox<'static>>;
// NODE_REGISTRY: HashMap<ProtoNodeIdentifier, (NodeConstructor, NodeIOTypes)>
```

The macro system (`#[node_macro::node]`) generates the monomorphized concrete constructor and registers it in `NODE_REGISTRY` at startup. The key insight: **monomorphization happens for each (node, type) combination, but the executor only sees `TypeErasedBox` at runtime**.

### What gets erased vs. what is preserved

| Information | At Graphite compile time | At graph execution time |
|---|---|---|
| Node function body | Monomorphized per type | Erased (vtable dispatch) |
| Input type | Concrete `StaticType` | `TypeId` in `DynAny` |
| Output type | Concrete `StaticType` | `TypeId` in `DynAny` → `TaggedValue` |
| Connection validity | Not checked | Checked by `TypingContext` |
| Node identity (NodeId) | Stable ID assigned by compiler | Present in `BorrowTree` |

### The `TypingContext` role

`TypingContext` holds the inferred types for all nodes in the current `ProtoNetwork`. Before instantiation, `DynamicExecutor::update()` calls `typing_context.update(&proto_network)` to infer types. A type mismatch here produces a `GraphError` that is surfaced to the user as a broken connection indicator in the UI — this is the closest Graphite gets to "type checking" the user's graph.

```rust
// dynamic_executor.rs
pub async fn update(&mut self, proto_network: ProtoNetwork)
    -> Result<ResolvedDocumentNodeTypesDelta, (ResolvedDocumentNodeTypesDelta, GraphErrors)>
{
    self.output = proto_network.output;
    self.typing_context.update(&proto_network).map_err(|e| { ... })?;
    // ...
    let (new_paths, old_nodes) = self.tree.update(proto_network, &self.typing_context).await?;
    // ...
}
```

### When it works

- The graph is user-constructed at runtime with dynamic topology
- 100+ node types need to be handled without Rust recompilation per graph topology
- The execution backend needs to be swappable (WASM interpreter vs GPU compiler) via the `Executor<I,O>` trait

### When it breaks

- Downcast failures at `TaggedValue::try_from_any` produce a `String` error with no source location
- Vtable dispatch overhead on every `node.eval()` call in the hot path
- `Box::leak` in the panic handler: `Err(e) => { Box::leak(e); ... }` — the panic payload is deliberately leaked to avoid the double-panic risk of dropping it, but this is a memory leak

---

## Pattern 3: Gradual Typing (TypeScript-Style Optional Annotations)

**Exemplar**: TypeScript type inference, mypy gradual typing

### Structure

Connections are typed by default (inferred), but can be explicitly annotated with `any` or left unannotated. Unannotated connections are treated as `unknown` and are not type-checked. The type checker warns but does not block on mismatches; runtime errors are possible.

```typescript
// TypeScript gradual typing — conceptual node graph analogy
interface BlurNode {
    input: ImageLike;    // typed: checked at graph-build time
    radius: number;      // typed: checked
    output: any;         // gradual: not checked, passes through
}
```

Gradual typing is common in node graph UIs where the tool wants to be helpful (show type mismatches) but not blocking (allow experimental connections).

### When it works

- The user population includes both technical users (who want type safety) and non-technical users (who want permissiveness)
- Type inference is available for most nodes, annotation is only needed for edge cases
- The type system is additive: you get more safety as you add more annotations, never less capability

### When it breaks

- The gradual type boundary (`any`) propagates: once a connection is typed `any`, downstream inferred types become `any`, defeating the type checking further down the graph
- Runtime errors from mismatched `any` connections are harder to diagnose than compile-time errors
- User confusion: the same connection works in one graph topology but fails in another because of downstream type constraints that propagate back upstream

### Graphite's approach to gradual typing

Graphite does not implement gradual typing in the classical sense. Instead, the `TypingContext` performs inference over the full graph before execution, and type mismatches are reported as `GraphError` entries. Nodes cannot opt out of type checking. This is closer to "full inference with error reporting" than "gradual typing."

The UI surfaces connection type information through `resolved_document_node_types` — the types inferred for each node are propagated back to the frontend so the canvas can show type labels on wires and highlight mismatches.

---

## Pattern 4: Tagged Union Values (Graphite's TaggedValue)

**Source files**:
- `node-graph/graph-craft/src/document/value.rs` — `TaggedValue` enum and macro

### Structure

`TaggedValue` is a large enum whose variants cover all concrete types that can flow through the graph. The macro `tagged_value!` generates the enum, its `Hash` implementation, and the `try_from_any` downcast:

```rust
// node-graph/graph-craft/src/document/value.rs
macro_rules! tagged_value {
    ($( $(#[$meta:meta])* $identifier:ident ($ty:ty) ),* $(,)?) => {
        #[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
        pub enum TaggedValue {
            None,
            $( $(#[$meta])* $identifier($ty), )*
            RenderOutput(RenderOutput),
            SurfaceFrame(SurfaceFrame),
            #[serde(skip)]
            EditorApi(Arc<WasmEditorApi>),
        }

        impl TaggedValue {
            pub fn to_dynany(self) -> DAny<'_> {
                match self {
                    Self::None => Box::new(()),
                    $( Self::$identifier(x) => Box::new(x), )*
                    // ...
                }
            }

            pub fn try_from_any(input: Box<dyn DynAny<'_> + '_>) -> Result<Self, String> {
                use std::any::TypeId;
                match DynAny::type_id(input.as_ref()) {
                    x if x == TypeId::of::<()>() => Ok(TaggedValue::None),
                    $( x if x == TypeId::of::<$ty>() =>
                        Ok(TaggedValue::$identifier(*downcast(input).unwrap())), )*
                    // ...
                    _ => Err(format!("Unknown type: {:?}", DynAny::type_id(input.as_ref())))
                }
            }
        }
    }
}
```

`TaggedValue` serves as the **boundary type** at the output of the executor: the interior of the graph uses type-erased `Box<dyn DynAny>`, but the output is recovered into a named variant before crossing the executor boundary. This ensures that:

1. Serialization works (serde on an enum with concrete variants, not on `Box<dyn Any>`)
2. The result can be pattern-matched by the UI layer without downcasting
3. The `Hash` implementation is deterministic for use in content-addressed caching

### The float hashing problem

```rust
// value.rs — manual Hash impl
// We must manually implement hashing because some values are floats
// and so do not reproducibly hash (see FakeHash below)
impl Hash for TaggedValue {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        core::mem::discriminant(self).hash(state);
        match self {
            Self::None => {}
            $(Self::$identifier(x) => { x.hash(state) }),*
            // ...
        }
    }
}
```

Float variants use their bit-pattern hash (via a `FakeHash` newtype that implements `Hash` for `f64`). This means `NAN` hashes consistently (same bits) but `+0.0` and `-0.0` hash differently despite being semantically equal. This is a known limitation accepted in exchange for deterministic hashing.

### TaggedValue as a closed set vs. open extension

`TaggedValue` is a **closed union**: adding a new type to the graph requires modifying the macro invocation in `value.rs`. This is a seam tension: the `node_registry()` pattern allows open extension of node types, but the type space they operate over is closed. A plugin author cannot add a new `TaggedValue::MyCustomType` without modifying core source.

This is the primary extensibility bottleneck: the `node_registry` can register new nodes, but those nodes can only produce and consume types already in `TaggedValue`.

### When it works

- The set of value types is stable and bounded
- Serialization of graph values (for save files) is required
- The graph output must be pattern-matched by non-Rust code (the TypeScript UI layer)
- Content-addressed hashing of graph outputs is needed

### When it breaks

- A new node category requires a new value type (extending the enum breaks the closed set)
- The enum grows very large: `#[allow(clippy::large_enum_variant)]` in the current source is a warning sign that some variants are significantly larger than others, increasing the stack cost of every `TaggedValue` value
- Compile times increase with each new variant added to the macro invocation

---

## Decision Guide

| Criterion | Fully Static | Runtime Erasure | Gradual Typing | Tagged Union |
|---|---|---|---|---|
| Type safety | Maximum (compile-time) | Runtime (TypeId check) | Variable (annotation density) | Runtime (pattern match) |
| Runtime flexibility | None (fixed topology) | Maximum | High | Medium (closed set) |
| Performance | Maximum (inlined) | Low (vtable dispatch) | Variable | Medium (match + clone) |
| Extensibility (new node types) | Recompile required | Registry entry | Annotation added | Enum variant added |
| Extensibility (new value types) | Recompile required | Registry entry | Any type | Enum variant in core |
| Serialization | Requires custom code | Not directly | Not directly | Built-in (serde enum) |
| Plugin/scripting support | No | Yes (node_registry) | Yes | No (closed enum) |
| Suitable for user-built graphs | No | Yes | Yes | Yes (output boundary) |

**Choose Fully Static** when: the graph topology is fixed, performance is critical, and Rust recompilation per graph change is acceptable (e.g., a shader compiler, not an interactive editor).

**Choose Runtime Erasure** when: the graph is user-constructed at runtime, the set of node types is open (extensible via registry), and you need a swappable execution backend.

**Choose Gradual Typing** when: you want type safety as a progressive enhancement, the user population ranges from technical to non-technical, and blocking on type errors would harm workflow.

**Choose Tagged Union** when: the set of value types is closed and stable, you need serialization and pattern matching at the executor boundary, and you are willing to accept the closed-set extensibility limit.

**In practice**: Graphite uses Runtime Erasure *inside* the executor and Tagged Union *at the executor boundary*. This is a sound combination: the interior is maximally flexible and the boundary is maximally safe.

---

## Anti-patterns and Consequences

### Anti-pattern: Passing `TaggedValue` through the interior of the graph

**Symptom**: A node accepts `TaggedValue` as its input type rather than a specific concrete type.

**Consequence**: The type erasure boundary moves inward. The `TypingContext` can no longer infer the connection type, because the node accepts anything. Type mismatch errors are deferred to runtime and produce unhelpful `String` errors. The `node_registry` cannot select the correct monomorphized constructor because the input type is not known.

**Fix**: Nodes should accept concrete types. `TaggedValue` belongs only at the executor output boundary and in serialization/deserialization paths.

### Anti-pattern: Matching on `TaggedValue` in node logic

**Symptom**: A node receives a `TaggedValue` input and pattern-matches on it to handle multiple types with different code paths.

**Consequence**: This is a manually written dynamic dispatch that duplicates what the registry's constructor selection already does. It also means the node cannot be type-inferred (its output type depends on runtime branch selection), breaking the `TypingContext` inference.

**Fix**: Use the registry to register separate nodes for each type (or a single generic node that is monomorphized per type by the macro). Let the `TypingContext` select the correct constructor.

### Anti-pattern: Leaking type-erased values across the executor boundary

**Symptom**: Code outside the executor (e.g., the UI message handler) receives a `Box<dyn DynAny>` directly instead of a `TaggedValue`.

**Consequence**: The Rust borrow checker cannot track the lifetime of the contained value. The UI code must perform its own `TypeId` check and downcast, duplicating the `try_from_any` logic. Serialization is impossible. If two versions of the downcast logic disagree on which `TypeId` maps to which type, silent data corruption occurs.

**Fix**: Always convert `Box<dyn DynAny>` to `TaggedValue` at the executor boundary via `TaggedValue::try_from_any`. Never pass `Box<dyn DynAny>` out of the executor layer.

### Anti-pattern: Adding a value type to `TaggedValue` without updating `node_registry` constructors

**Symptom**: A new variant `TaggedValue::MyTexture(MyTexture)` is added to the macro, but the `node_registry` is not updated with constructors for nodes that produce or consume `MyTexture`.

**Consequence**: `TypingContext` can infer the type in the network, but `BorrowTree::push_node()` fails with `GraphErrorType::NoConstructor` when it tries to instantiate a node that takes `MyTexture` as input. The error appears at runtime during the first graph execution with the new type, not at Rust compile time.

**Fix**: Adding a new value type is a two-step operation: (1) add the variant to `TaggedValue`, (2) register constructors in `node_registry` for every node that operates on that type. The macro system cannot enforce this pairing — it requires discipline or a test that exercises every `TaggedValue` variant through at least one registered node.

### Anti-pattern: Treating `Box::leak` in panic recovery as acceptable long-term

**Source**: `dynamic_executor.rs` — `Err(e) => { Box::leak(e); Err("Node graph execution panicked".into()) }`

**Symptom**: When a node panics during evaluation, the panic payload is leaked to avoid a double-panic.

**Consequence**: Each graph evaluation panic permanently leaks memory. In an interactive editor where a user can repeatedly trigger a panicking node (e.g., by setting a parameter to a pathological value), this is an unbounded memory leak.

**Fix**: Prefer `catch_unwind` with a payload that implements `Drop` safely, or use `Arc` instead of `Box` for the panic payload so it can be dropped without a double-panic risk. Alternatively, run panicking nodes in a subprocess with shared memory for the output.
