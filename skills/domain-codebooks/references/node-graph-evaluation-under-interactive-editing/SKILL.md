---
name: node-graph-evaluation-advisor
description: >-
  Architectural advisor for systems where a computation graph must evaluate interactively — visual programming, shader editors, spreadsheets, procedural content tools. NOT for static DAG scheduling, build systems, or data pipelines without interactive feedback loops.

  Triggers: node graph evaluation, procedural graph, visual programming execution, shader graph compilation, lazy evaluation interactive, incremental computation graph, graph caching strategy, node dirty propagation, graph recompilation, evaluated node graph, computation graph performance, interactive graph feedback, graph memoization, node execution order, graph type resolution

  Diffused triggers: "graph is slow to update", "how to cache node results", "evaluation blocks the UI", "dirty flag propagation", "when to recompile the graph", "incremental vs full evaluation", "type erasure in node graphs", "node execution order", "tagged value enum getting too large"

  Libraries: wgpu, vello, Graphite, Blender geometry-nodes, Houdini, Nuke, Substance Designer

  Skip: static build graphs (Bazel, Make), ETL pipelines, CI/CD DAGs, neural network training graphs, database query planning, reactive UI state management (use state-to-render-bridge)
---

# Node Graph Evaluation Under Interactive Editing

Advisor for the tension between incremental/lazy evaluation of a procedural computation graph and real-time interactive feedback during editing.

## Step 1: Classify

1. **Graph type** — procedural content (geometry, shaders, compositing), reactive signals (derived UI state), or hybrid?
2. **Evaluation trigger** — user-driven (explicit "run"), mutation-driven (every edit), or frame-driven (animation)?
3. **Scale** — dozens of nodes (shader graph) or thousands (large document)?
4. **Type model** — statically typed connections, dynamically typed, or gradual?
5. **Platform** — native (can use threads), WASM (single-threaded), or both?

## Step 2: Identify Active Forces

| Force | Active when... | Reference |
|-------|---------------|-----------|
| Evaluation latency vs responsiveness | Graph has >50 nodes or expensive operations | **evaluation-strategy** |
| Cache invalidation scope | Users drag/tweak parameters frequently | **cache-invalidation** |
| Type safety vs flexibility | Nodes have heterogeneous input/output types | **type-resolution** |

## Step 3: Cross-References

| Related Codebook | Interaction |
|-----------------|-------------|
| **interactive-spatial-editing** | Tool interactions trigger graph re-evaluation; snapping/overlays need fast response |
| **message-dispatch-in-stateful-editors** | Graph evaluation is dispatched via messages; dedup prevents redundant runs |
| **graph-as-document-model** | The graph IS the document; mutations flow through the document facade |
| **rendering-backend-heterogeneity** | Graph output feeds into rendering; CPU vs GPU evaluation paths |

## Principles

1. **Evaluation is the bottleneck, not mutation.** Graph edits are cheap (insert node, change connection). Evaluating the changed graph is expensive. All optimization effort should target evaluation, not mutation.

2. **Conservative invalidation is safe but slow.** Graphite's `MemoNetwork` invalidates the hash on any `network_mut()` call — even reads through mutable reference. This is correct but over-invalidates. The upgrade path is fine-grained dirty tracking (Blender) or reactive signals (tldraw).

3. **Full recompilation is the simplest correct approach.** Graphite's `Compiler::compile()` recompiles the entire graph on every change. This is O(n) but avoids incremental compilation bugs. Only invest in incremental compilation when profiling proves it's the bottleneck.

4. **Type erasure is the graph extensibility tax.** `DynamicExecutor` uses `Box<dyn>` for runtime flexibility at the cost of compile-time type checking. `TaggedValue` is the closed-enum alternative — simpler but requires modifying the enum to add types. Choose based on extensibility requirements.

5. **Dedup at the message level, not the graph level.** Graphite's `SIDE_EFFECT_FREE_MESSAGES` dedup prevents redundant `RunDocumentGraph` messages rather than trying to detect redundant evaluations. This is simpler and catches the common case (multiple mutations during a single drag).
