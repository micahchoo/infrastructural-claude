# FC3 Codebook: Node Type Extensibility

**Force Cluster**: Graph-as-Document Model
**Seams covered**: 19 (`DefinitionIdentifier` registries — 3 separate registries requiring manual sync), 20 (`EditorHandle` WASM bridge)

---

## The Problem

A node graph engine needs to know: given a `ProtoNodeIdentifier` (or equivalent), how do I execute this node? How do I display it in the UI? What are its input/output types? What default parameters does it have?

This information must live *somewhere*. The design question is: **where is it registered, when, and by whom?**

Forces in tension:
- **Open/Closed**: You want to add new node types without modifying core files — but the core executor must know all node types to compile the graph.
- **Type safety vs runtime flexibility**: Compile-time registration gives full type checking on node I/O but requires recompilation to add nodes. Runtime registration allows plugins but sacrifices type safety at the boundary.
- **Registry fragmentation**: Node execution, UI display, and serialization may each need their own registry. Keeping them in sync is a maintenance burden. Merging them into one creates coupling between unrelated concerns.
- **Compile time vs startup time**: Macro-generated registries bloat compile time; dynamic registries add startup overhead (library loading, reflection).

---

## Pattern 1: Static Registration (Compile-Time Known Node Set)

**Examples**: Simple shader graph editors, early versions of many procedural tools

**Mechanism**: All node types are enumerated in a single `NodeType` enum or a `match` statement in the executor. Adding a new node type means adding a new variant and a new `match` arm.

```rust
enum NodeType { Add, Multiply, Blur, Invert, /* ... */ }

fn execute(node_type: NodeType, inputs: &[Value]) -> Value {
    match node_type {
        NodeType::Add => inputs[0] + inputs[1],
        NodeType::Blur => blur(inputs[0], inputs[1]),
        // ...
    }
}
```

**What this buys**:
- Exhaustive match: the compiler enforces that all node types are handled.
- Zero runtime overhead: dispatch is a direct branch on an enum discriminant.
- Easy to understand: the complete set of node types is visible in one place.
- No registration step: the enum IS the registry.

**What this costs**:
- Adding any node type requires modifying the core enum and executor — violates Open/Closed.
- The `match` arm grows unboundedly; 200 node types become 200-arm matches scattered across the codebase.
- No way to add nodes without recompilation (no plugin support).
- I/O type information must also be in the match, creating parallel switch statements that drift out of sync.

**When to choose**: Closed tools with a small, fixed node set (< 30 types) where plugin extensibility is explicitly not a goal. Good for embedded scripting engines or domain-specific shader languages.

---

## Pattern 2: Macro-Generated Registry

**Example**: Graphite (`into_node!`, `async_node!` macros in `node-graph/interpreted-executor/src/node_registry.rs`)

**Mechanism**: Node implementations are Rust structs/functions tagged with derive macros or registered via macro invocations at the call site of a registry builder function. At startup, `node_registry()` constructs a `HashMap<ProtoNodeIdentifier, HashMap<NodeIOTypes, NodeConstructor>>` — a two-level map keyed first by node identity, then by the concrete I/O type instantiation.

```rust
fn node_registry() -> HashMap<ProtoNodeIdentifier, HashMap<NodeIOTypes, NodeConstructor>> {
    let mut node_types: Vec<(ProtoNodeIdentifier, NodeConstructor, NodeIOTypes)> = vec![
        into_node!(from: Table<Graphic>, to: Table<Graphic>),
        into_node!(from: Table<Vector>,  to: Table<Vector>),
        async_node!(graphene_core::memo::MonitorNode<_, _, _>,
                    input: Context, fn_params: [Context => Table<Graphic>]),
        // ... hundreds of entries
    ];
    // build HashMap from vec
}
```

Each macro call expands to a tuple that encodes: the `ProtoNodeIdentifier` (derived from the type path), the concrete `NodeIOTypes` (input/output type pair), and a `NodeConstructor` (a closure that instantiates the node for a given type environment).

**What this buys**:
- Monomorphized performance: each concrete I/O instantiation is compiled to specialized code. No dynamic dispatch in the hot execution path.
- Type safety: the macro system catches type mismatches at compile time.
- Adding a new node type adds one or more macro calls to the registry file — no modification to core dispatch logic.
- The two-level map (identity × I/O types) allows a single logical node (e.g., `MonitorNode`) to serve many different I/O type combinations, each compiled separately.

**What this costs**:
- **Three separate registries that must be manually kept in sync** (seam 19): the executor registry (`node_registry()`), the UI node definition registry (which controls display name, categories, input widgets), and the serialization registry (which maps `ProtoNodeIdentifier` to/from stored strings). Adding a node type requires touching all three; the compiler does not catch missing entries in the UI or serialization registries.
- Compile time: hundreds of `async_node!` macro calls generate substantial amounts of monomorphized code. Cold compile time is significantly impacted.
- The macro API is not self-documenting. `async_node!(T, input: X, fn_params: [X => Y])` requires understanding the macro's expansion to know what is being registered.
- Dynamic/plugin nodes are impossible: the registry is sealed at compile time.
- The registry function is a single large vec literal — merge conflicts in that file are common.

**De-factoring thought experiment**: Remove `DefinitionIdentifier` registries entirely. The executor has no way to look up a node constructor from a stored graph. Every graph loaded from disk must be re-typed by hand. The UI has no way to present node properties because it does not know what inputs a `ProtoNodeIdentifier` expects.

**When to choose**: Performance-critical Rust-native graph engines where monomorphized execution is a requirement and plugin extensibility is not needed. The compile-time cost is the accepted tradeoff for runtime performance.

---

## Pattern 3: Plugin Architecture

**Examples**: Krita (C++ shared libraries via `KisGeneratorRegistry`), Blender Python add-ons, GIMP plug-ins

**Mechanism**: The application defines a plugin interface (C ABI, Python protocol, or scripting API). Plugins are loaded at startup (or on demand) and register their node/filter/generator types with a central registry. The registry maps string identifiers to vtable-backed factory objects.

**Krita example**:
```cpp
// Plugin registration
class KisMyFilter : public KisFilter {
    KisMyFilter() : KisFilter(KoID("myfilter", i18n("My Filter"))) {}
    void process(KisPaintDeviceSP, const QRect&, const KisFilterConfigurationSP, ...) override;
};
// In plugin .so:
K_EXPORT_PLUGIN(KisMyFilterFactory("kritamyfilter"))
```

The `KisFilterRegistry` loads all `.so` files in the plugin directory at startup. Tools query the registry by ID string.

**What this buys**:
- True extensibility without recompilation of the core.
- Third-party developers can ship node types independently.
- Plugin isolation: a crashed plugin does not crash the host (if properly sandboxed).
- The registry is the single source of truth — no parallel registries for different concerns.

**What this costs**:
- C ABI instability: a plugin compiled against one version of the API breaks silently against another version. Version management is a maintenance burden.
- No type safety at the plugin boundary. Plugin inputs/outputs are untyped (`void*` or variant types) at the ABI level.
- Dynamic loading adds startup latency (library discovery, dlopen, symbol resolution).
- Plugin discovery conventions (directory scanning, manifest files) add complexity.
- Security: arbitrary code loaded at runtime.
- For WASM deployment (Graphite), dynamic library loading is not supported — the entire node graph engine must be compiled to a single WASM module.

**When to choose**: Desktop applications with a third-party developer ecosystem where extensibility beyond the core team is a business requirement. Not viable for WASM or secure sandboxed environments.

---

## Pattern 4: Schema-Driven Definitions

**Examples**: Substance Designer (XML node definitions), Unreal Material Editor (USF-backed node schema), Shadertoy-style graph editors

**Mechanism**: Node types are defined in data files (XML, JSON, YAML) that describe inputs, outputs, display names, default values, and behavior (as shader code strings or script references). A schema loader parses these at startup and builds the runtime registry. New node types are added by adding new schema files, not by writing code.

**Substance Designer example** (conceptual):
```xml
<node-definition id="com.example.MyBlend" label="My Blend" category="Blending">
  <inputs>
    <input id="A" type="color4" label="Input A"/>
    <input id="B" type="color4" label="Input B"/>
    <input id="amount" type="float" default="0.5" label="Blend Amount"/>
  </inputs>
  <output type="color4"/>
  <implementation language="glsl">
    // GLSL shader body referencing inputs by name
    return mix(A, B, amount);
  </implementation>
</node-definition>
```

**What this buys**:
- Non-programmer extensibility: artists and technical directors can add node types by writing schema + shader code without touching the application source.
- Hot-reload: schema files can be reloaded without restarting the application.
- Uniform UI: the schema's input definitions drive widget generation — no parallel UI registry needed.
- Serialization is implicit: the schema ID is the serialized form of the node type.

**What this costs**:
- Performance: schema-driven nodes execute through a shader compiler or interpreter pipeline. They cannot be monomorphized by the Rust compiler.
- Type safety is deferred to schema validation, not compile-time checking.
- Complex node behavior (stateful nodes, nodes that require access to document metadata) is awkward to express in declarative schema.
- The schema language becomes a DSL that must be documented, versioned, and maintained.
- No Rust type system integration: inputs are stringly-typed at the schema boundary.

**When to choose**: Material editors and shader graph tools where the node execution model is uniform (shader evaluation) and non-programmer extensibility is a primary goal. Poor fit for general computation graphs with heterogeneous types (Graphite's `Table<Graphic>`, `Table<Vector>`, `Table<Raster<CPU>>`, etc.).

---

## Decision Guide

| Criterion | Static Enum | Macro Registry | Plugin (.so) | Schema-Driven |
|---|---|---|---|---|
| Compile-time type safety | Full | Full (within macro) | None at ABI | Schema validation only |
| Runtime performance | Best | Best (monomorphized) | Vtable dispatch | Shader/interpreter |
| Add node without recompile | No | No | Yes | Yes (schema reload) |
| Third-party extensions | No | No | Yes | Yes |
| WASM-compatible | Yes | Yes | No | Partial (GLSL via WebGL) |
| Parallel registry problem | N/A | Yes (3 registries) | Single registry | Single (schema IS registry) |
| Non-programmer extensibility | No | No | Partial | Yes |
| Cold compile time impact | Low | High | Low | Low |

**Primary decision axis**: Does the node type set need to be extensible at runtime (plugin support or non-programmer authoring)? If yes, choose Plugin or Schema-Driven. If no and WASM deployment is required, Macro Registry is the appropriate choice.

**Secondary axis**: Is execution performance critical? Macro-generated monomorphized code (Graphite) is fastest. Vtable-dispatched plugins add one indirection. Schema-driven shader nodes add full compilation overhead per execution.

**Registry fragmentation mitigation**: If using Macro Registry, consider a single registration site that emits data for all three concerns (executor, UI, serialization) in one macro call, rather than three separate registration passes. This requires the macro to know about all three registries — coupling UI metadata into the executor crate — which is its own tradeoff (see anti-patterns).

---

## Anti-patterns

**Three registries, one truth**: Having separate registration steps for executor, UI display, and serialization with no compile-time enforcement that all three are in sync. This is Graphite's current state (seam 19): adding a node requires three separate registration sites. The symptom: a node that executes correctly but has no entry in the UI registry shows up as an unnamed "Unknown" node in the panel; a node missing from the serialization registry causes silent deserialization failures on documents saved with that node type.

**String-keyed registries without versioning**: Using bare string identifiers (`"myFilter"`) as registry keys without a versioning scheme. When a node is renamed or its I/O signature changes, all existing documents containing that node break on load. The fix: version the identifier (`"com.example.myFilter/v2"`) and register migration handlers.

**Macro as documentation substitute**: Macro-generated registries that are compact but opaque. `async_node!(T, input: X, fn_params: [X => Y])` is not self-explaining. A reader encountering this for the first time cannot determine the node's purpose, categories, display name, or default parameters without finding the corresponding UI registry entry. Document the registration conventions explicitly.

**Plugin boundary type erasure**: Defining the plugin ABI as `fn execute(inputs: Vec<f64>) -> Vec<f64>` to avoid the parallel-registry problem. This loses all structural typing, makes I/O type mismatch a runtime error, and prevents the editor from computing type-correct connection suggestions.

**Schema language creep**: Starting with a simple JSON schema for node inputs and gradually adding `if/else` conditionals, `computed` fields, `depends_on` expressions, and embedded script snippets until the schema language is an undocumented Turing-complete DSL. At that point, a code-based registration approach would have been simpler and more maintainable.

**Monomorphization explosion**: Registering a generic node type for every possible I/O type combination. In Graphite's registry, `MonitorNode` is registered with 25+ distinct `fn_params` type combinations, each producing a separate monomorphized function. This multiplies binary size and compile time. The fix: profile which combinations are actually used at runtime and prune unused entries; or introduce a dynamic dispatch path for rarely-used type combinations.
