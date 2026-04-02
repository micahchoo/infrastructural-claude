# Production Systems Analysis: Node Graph Evaluation

Enrichment source covering Blender, Houdini, and Substance Designer.
Cross-referenced against Graphite, Krita, tldraw, Excalidraw (from initial extraction).

## Key Architectural Insight

All production systems converge on **forward dirty marking (push) followed by backward demand evaluation (pull)**, differing only in granularity:
- **Blender**: scene-object/component level (coarse)
- **Houdini**: per-node/per-parameter micronode level (fine)
- **Substance**: per-node GPU texture level (medium, but GPU-accelerated)
- **Graphite**: conservative full hash invalidation (coarsest — MemoNetwork)
- **Krita**: async stroke queue with LOD proxy (medium, latency-optimized)

---

## Blender Geometry Nodes / Dependency Graph

**Source files**: `depsgraph_tag.cc`, `deg_eval_flush.cc`, `deg_eval.cc`

### Evaluation: Incremental tag→flush→evaluate (3-phase)

1. **Tag** — `DEG_id_tag_update()` marks `IDRecalcFlag` on modified data-block, translated to `(NodeType, OperationCode)` via `depsgraph_tag_to_component_opcode()`
2. **Flush** — `deg_graph_flush_updates()` BFS from `graph->entry_tags` through DAG. Tricolor states: `{NONE, SCHEDULED, DONE}`. Queue: `std::deque<OperationNode*>`
3. **Evaluate** — `deg_evaluate_on_refresh()` runs only scheduled operations in topological order

### Cache Invalidation: Fine-grained component tagging

Each `IDNode` has multiple `ComponentNode`s (`TRANSFORM`, `GEOMETRY`, `ANIMATION`, `BATCH_CACHE`). Only matching component is flushed — material change doesn't invalidate geometry VBOs. Render engines receive bitfield flags for selective GPU resource invalidation.

### Type System: Typed Fields

- `Field<T>` is immutable directed-tree of `FieldNode`s (lazy, per-element)
- Field tree built at graph construction, evaluated only when `FieldEvaluator` invoked with `FieldContext`
- Strong static typing via `Field<T>` wrappers; dynamic fallback via `GField`

### Interactive Performance

- Window owns depsgraph → multiple viewports at different states simultaneously
- Copy-on-write via `DEG_create_shallow_copy()`; geometry arrays reference-counted
- Three update modes: continuous, on-mouse-up, manual

---

## Houdini / SideFX Cooking System

**HDK classes**: `OP_Node`, `SOP_Node`, `DEP_MicroNode`, `SOP_Verb`

### Evaluation: Demand-driven pull, lazy with eager dirty propagation

- `needToCook(OP_Context&)` — each node decides if cooking needed before any work
- `getCookedGeoHandle(OP_Context&)` — pull interface triggering lazy cook chain
- `cookMySop()` — pure virtual, actual geometry computation (only if `needToCook` returns true)

### Dirty Propagation: DEP_MicroNode graph

- Micro-dependency graph beneath OP network
- `propagateDirtyMicroNode()` — dirty signal propagates without full re-evaluation
- Per-parameter dependency tracking: `rebuildParmDependency(int parm_index)`
- Extra input/output nodes for expression references beyond wired inputs

### Time-Dependency

- `OP_Context` carries time; nodes declare `isTimeDep`
- Time-independent nodes cache indefinitely; time-dependent invalidate per frame
- DOP simulation cache: per-node, configurable memory limits, evicts earliest frames

### Interactive Modes

- **Always** (cook on every drag), **On Mouse Up** (cook when drag ends), **Manual** (Force Update only)
- `SOP_Verb`: stateless "verb" object enabling thread-safe parallel cooking of multiple instances

---

## Substance Designer / Adobe Substance Engine

### Evaluation: Incremental GPU-accelerated

- DAG of image-processing nodes; each output is a GPU texture
- On parameter change, only downstream nodes re-evaluate
- Per-node output cache in GPU memory; node re-cooked only if inputs/params changed
- `.sbsar` compiled format pre-bakes topology → skip graph traversal at runtime

### GPU Compute Architecture

- Each node maps to GPU shader passes (fragment or compute shaders)
- Node outputs stay on GPU; data never leaves unless explicitly read back
- Two backends: GPU (real-time) and CPU (headless/server fallback)
- Resolution is graph-level parameter (`$outputsize`) → LOD by changing one param

### Real-Time Preview

- Reduced resolution (128x128/256x256) during drag, full resolution on mouse-up
- Matches Houdini's "On Mouse Up" pattern
- Incremental: typically single fragment shader pass per dirty node

### Type System

- Grayscale (1-channel) vs Color (RGBA) wire types; enforced at connection time
- Scalar parameters drive shader uniforms, not node wires

---

## Cross-System Comparison

| Dimension | Blender | Houdini | Substance | Graphite | Krita |
|---|---|---|---|---|---|
| Eval strategy | Incremental 3-phase | Demand pull, lazy | Incremental GPU | Full recompile | Async stroke queue |
| Dirty granularity | Per-component | Per-parameter micronode | Per-node texture | Full hash | Per-layer LOD |
| Cache unit | Component on ID | Per-node GU_Detail | GPU texture | MemoNetwork hash | Tile cache |
| Parallelism | BLI_task_parallel | SOP_Verb + PDG | GPU shaders | Single-threaded WASM | Multi-threaded queue |
| Interactive trick | Per-viewport graph | Always/OnMouseUp/Manual | LOD via $outputsize | SIDE_EFFECT_FREE dedup | LOD proxy layers |
| Type system | Field<T> + GField | GA_Attribute typed | Grayscale/Color | TaggedValue enum | Pixel compositing |
| CoW/isolation | DNA ID CoW | GU_Detail handle | GPU texture isolation | Clone on undo | — |
