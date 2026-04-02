# FC3 Codebook: Document-Graph Abstraction

**Force Cluster**: Graph-as-Document Model
**Seams covered**: 15 (`NodeNetworkInterface`), 16 (`LayerNodeIdentifier ↔ NodeId`), 17 (`GraphOperationMessage`), 20 (`EditorHandle` WASM bridge)

---

## The Problem

A computation graph is a powerful but alien data structure. Nodes have IDs, not names. Connections are edges, not containment. Evaluation order is topological, not sequential. Yet users expect to work with *documents*: named layers, hierarchical groups, properties like fill and stroke, selection, copy/paste.

The core design question: **how much document-model abstraction do you layer over the graph, and where does that abstraction live?**

The tension is irreducible:
- More abstraction → easier UI, harder extensibility, risk of leaky abstraction
- Less abstraction → raw graph power, steeper learning curve, every tool author must understand graph internals
- Flat abstraction → fast, predictable, hard to represent nondestructive chains
- Deep abstraction → full nondestructive power, expensive to maintain the mapping

---

## Pattern 1: Flat Element Array

**Example**: Excalidraw

**Structure**: A single ordered `elements: ExcalidrawElement[]` array. Each element is a plain object with `id`, `type`, `x`, `y`, `width`, `height`, and style fields. Groups are represented by a shared `groupIds: string[]` array on each element — no parent node, no tree.

**Document model**: The array IS the document. Serialization is trivial (`JSON.stringify`). Undo is snapshot-based — clone the array before each mutation.

**What this buys**:
- Zero indirection. Every operation reads/writes the same flat array.
- Collaboration is simple: operational transforms on array indices.
- Predictable performance: O(n) scans are fast at typical document sizes.
- New element types require adding fields, not registering with a system.

**What this costs**:
- No compositing. Elements cannot feed into each other procedurally.
- Groups are a post-hoc hack (shared groupIds), not a first-class hierarchy.
- No nondestructive effects. A blur is baked into pixel data.
- Scaling to 10k+ elements requires spatial indexing bolted on the side.

**When to choose**: Collaborative whiteboard tools, annotation layers, simple diagramming. Wrong choice when nondestructive editing, effects pipelines, or deep hierarchy are requirements.

---

## Pattern 2: Hierarchical Shape Tree

**Example**: Penpot (Clojure map `{uuid -> shape}`), Figma (scene tree)

**Structure**: A map from UUID to shape record. Each shape has a `parent` UUID and an ordered `children` vector. Component instances store a `component-id` linking to the master; sync propagates changes from master to all instances (analogous to graph edges, but implemented as explicit sync passes).

**Document model**: The tree IS the document. Operations are pure functions over the map. Undo stores before/after maps (structural diff).

**What this buys**:
- Familiar parent/child mental model matches design tool conventions.
- Component sync gives a constrained form of "graph edge" (master → instance propagation) without a general graph engine.
- Clojure persistent data structures make undo/redo cheap (structural sharing).
- Flat map lookup is O(1) by UUID.

**What this costs**:
- Component sync is ad-hoc graph semantics bolted onto a tree — it does not generalize to arbitrary node chains.
- Effects are applied in a fixed order per node type; no user-composable effect graph.
- Adding a new compositing mode requires modifying the renderer, not adding a node.
- Deep nesting creates long ancestor chains that must be walked for transform accumulation.

**When to choose**: Design tools requiring component libraries, master/instance relationships, and team collaboration where a general graph engine would be overkill.

---

## Pattern 3: Compositing Node Tree

**Example**: Krita (`KisImage` + `KisNode` tree)

**Structure**: `KisImage` owns a tree of `KisNode` subclasses (paint layers, group layers, adjustment layers, masks). Each node computes pixel data; the compositing engine walks the tree bottom-up, blending each node's output with its sibling chain using the node's blend mode. The tree topology is fixed by node type — a group layer always composites its children; an adjustment layer always modifies its parent region.

**Document model**: The tree IS the document AND the compositing graph. `KisNodeVisitor` provides uniform traversal for operations (export, flatten, clone).

**What this buys**:
- No impedance mismatch: the compositing pass IS the document structure.
- Users understand layer stacks; the graph is invisible.
- Adding a new layer type (e.g., `KisColorizeMask`) adds a `KisNode` subclass without touching the core.
- Strong invariants: a paint layer always produces pixels; masks always clip.

**What this costs**:
- Fixed topology. You cannot wire two paint layers' outputs into a custom blend without a new node type.
- Adjustment layers can only operate on their position in the stack — no cross-branch references.
- The "graph" has no cycles, no fan-in beyond what node types permit, no user-composable DAG.
- Extending with a procedural generator (e.g., a noise fill that feeds into a distort) requires a full plugin, not a node connection.

**When to choose**: Pixel-painting applications where compositing semantics are fixed and users should not be exposed to a graph.

---

## Pattern 4: General DAG with Facade

**Example**: Graphite (`NodeNetworkInterface` wrapping `NodeNetwork`)

**Structure**: The document is an arbitrary DAG of `DocumentNode`s stored in `NodeNetwork`. Each node has typed inputs, outputs, and a `ProtoNodeIdentifier` linking it to an executable implementation. `NodeNetworkInterface` (6524 LOC, 209 public methods) is a Facade that provides document-level semantics over raw graph operations: layer ordering, metadata caching, transaction management, click-target computation, and frontend sync.

The identity mapping between domains is explicit: `LayerNodeIdentifier` wraps a `NodeId` and provides layer-domain operations (parent, children, ancestors, descendants) that are computed by traversing the graph. `GraphOperationMessage` (20+ variants: `FillSet`, `StrokeSet`, `TransformSet`, `NewVectorLayer`, etc.) maps document-level intent to specific node mutations.

**Document model**: The graph IS the document. A "layer" is a node whose primary output feeds into the scene's compositing chain. A "fill" is an upstream node whose output connects to a fill input port. Grouping is a subgraph. Effects are node chains.

**What this buys**:
- Full nondestructive pipeline: any node's output can feed any downstream input.
- Users can expose the graph directly for advanced workflows (node editor panel).
- New effects require adding a node type, not modifying the compositor.
- The same graph engine handles vector, raster, text, procedural geometry, and arbitrary future types.

**What this costs**:
- The Facade (`NodeNetworkInterface`) becomes a 6500-LOC gravity well. Every new document feature requires a new method.
- `LayerNodeIdentifier ↔ NodeId` translation adds indirection to every layer operation — and the mapping can become stale if the graph is mutated without going through the Facade.
- `GraphOperationMessage` variants are tightly coupled to graph structure: `FillSet` must know which upstream node to find/create for a fill input. Adding a new property often requires a new variant AND new graph traversal logic.
- Onboarding cost: contributors must understand both document semantics and graph topology.
- The WASM boundary (`EditorHandle`) requires all graph state to be serde-serializable, constraining type choices.

**De-factoring thought experiment**: Remove `NodeNetworkInterface`. Every tool handler must now call raw graph APIs: find the right upstream node, mutate it, invalidate caches, push frontend updates, and manage transaction state — all inline. The graph becomes a write-only system with no document-level invariants enforced at the boundary.

**When to choose**: Procedural content creation tools (Houdini, Blender, Substance Designer model) where the graph IS the creative primitive and power users will work with it directly. Wrong choice for simple drawing tools where the graph would always be hidden.

---

## Pattern 5: Normalized Record Store

**Example**: tldraw (`TLStore` — `Record<TLRecordType, TLRecord>`)

**Structure**: A flat normalized store mapping record IDs to typed records (`TLShape`, `TLPage`, `TLCamera`, `TLDocument`, etc.). Parent/child relationships are encoded as `parentId` fields on records, not as structural nesting. Queries traverse the store by filtering/indexing on field values.

**Document model**: The store IS the document. Real-time collaboration is built in: the store is a CRDT-like structure where changes are represented as `RecordsDiff` patches that can be applied, inverted (undo), or merged (collab). The schema versioning system allows migrations without breaking stored documents.

**What this buys**:
- Real-time collaboration is a first-class citizen, not an afterthought.
- Schema versioning handles document format evolution.
- Any tool can query any record by type without knowing the tree structure.
- Undo/redo is `RecordsDiff` inversion — cheap and granular.
- No tree traversal required to find a shape; direct map lookup.

**What this costs**:
- No procedural evaluation. Records are static data; there is no engine that computes one record's value from another.
- Effects require baking into the record's field values — no nondestructive chain.
- "Hierarchy" is a query over `parentId` fields, not a structural property.
- Adding a new record type requires schema registration and migration versioning.

**When to choose**: Multiplayer whiteboard and diagramming tools where collaboration and schema evolution are primary concerns and procedural computation is not needed.

---

## Decision Guide

| Criterion | Flat Array | Shape Tree | Compositing Tree | DAG + Facade | Record Store |
|---|---|---|---|---|---|
| Nondestructive effects | No | No | Partial (fixed) | Yes | No |
| User-composable graph | No | No | No | Yes | No |
| Real-time collaboration | Simple | Moderate | Hard | Hard | Native |
| Undo complexity | Snapshot | Structural diff | Snapshot | Transaction SM | Record diff |
| Onboarding cost | Very low | Low | Medium | High | Medium |
| New effect type | Schema field | Node subclass | Node subclass | New node type | Schema field |
| Document = visible structure | Yes | Yes | Yes | Via Facade | Yes |

**Primary decision axis**: Do users need to compose effects procedurally? If yes, go toward DAG. If no, go toward flat/tree and gain collaboration and simplicity.

**Secondary axis**: Is real-time collaboration a launch requirement? If yes, normalized record store gives it for free. Adding collaboration to a DAG-based system requires a significant architectural investment.

---

## Anti-patterns

**Implicit graph in a tree**: Adding "smart objects" or "live effects" to a shape tree without a proper graph engine. Each effect type becomes a special case in the renderer with hardcoded ordering. (Seen in early versions of many design tools before they added proper effects panels.)

**Graph without a Facade**: Exposing raw graph APIs to all message handlers. Tool authors must understand graph topology to change a fill color. Graph invariants (e.g., "a layer node's first upstream must be a transform node") are maintained by convention, not enforcement.

**Facade without encapsulation**: A Facade that grows to 200+ methods and is directly mutated by callers who then also call internal methods for "just this one case." The Facade becomes a namespace, not a boundary.

**Identity mapping without invalidation**: Caching `LayerNodeIdentifier → NodeId` mappings that can become stale when the graph is structurally mutated. Silent corruption: the layer panel shows layers that no longer correspond to existing nodes, or vice versa.

**Topology assumptions in message variants**: `GraphOperationMessage::FillSet` works by finding the node at a specific graph position relative to the layer node. If a user manually rearranges the graph, `FillSet` may modify the wrong node or fail silently. The message variant has implicit preconditions about graph topology that are not enforced by the type system.
