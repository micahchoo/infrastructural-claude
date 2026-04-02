---
name: graph-as-document-advisor
description: >-
  Architectural advisor for systems where a computation graph serves as the primary document model while presenting familiar editing UX (layers, groups, undo). NOT for graph databases, knowledge graphs, or static document formats.

  Triggers: graph as document, node network document model, layer abstraction over graph, procedural document, nondestructive editing architecture, graph-based undo, node type extensibility, document graph facade, graph transaction model, layer-to-node mapping, graph operation message, node definition registry

  Diffused triggers: "users see layers but it's a graph underneath", "how to undo graph mutations atomically", "adding new node types is painful", "facade API is getting too large", "graph operations need to look like document edits", "three registries to keep in sync", "layer panel doesn't match graph structure"

  Libraries: Graphite, Blender, Krita, Houdini, Nuke, Substance Designer, Unreal Blueprints

  Skip: graph databases (Neo4j, ArangoDB), knowledge graphs (RDF, ontology editors), static file formats (SVG, PDF), pure layer-tree editors without computation, workflow automation graphs
---

# Graph-as-Document Model

Advisor for the tension between using a computation graph as the primary document model (for nondestructive power and flexibility) and presenting familiar document-editing UX (layers, groups, undo).

## Step 1: Classify

1. **Graph topology** — fixed tree (Krita compositing), user-authored DAG (Graphite), or arbitrary with cycles?
2. **Abstraction gap** — how far is the graph structure from the user's mental model? Layers≈tree (small gap) vs arbitrary DAG (large gap)?
3. **Evaluation model** — graph is evaluated to produce output (Graphite), or graph IS the output (Krita compositing)?
4. **Extensibility** — closed node set (known at compile time) or open (plugins, user scripts)?
5. **Collaboration** — single-user (undo is simple) or multi-user (undo scope matters)?

## Step 2: Identify Active Forces

| Force | Active when... | Reference |
|-------|---------------|-----------|
| Document-graph abstraction | Users need layer/group UX but data is a graph | **document-graph-abstraction** |
| Transaction atomicity | Multiple graph mutations must undo as one step | **transaction-and-undo** |
| Node type extensibility | New node types added regularly; multiple registries involved | **node-type-extensibility** |

## Step 3: Cross-References

| Related Codebook | Interaction |
|-----------------|-------------|
| **node-graph-evaluation-under-interactive-editing** | After document mutation, graph must re-evaluate to show results |
| **message-dispatch-in-stateful-editors** | Document operations are dispatched as messages (GraphOperationMessage) |
| **undo-under-distributed-state** | Transaction model determines undo granularity |
| **hierarchical-resource-composition** | Layer hierarchy is a view into the graph structure |
| **rendering-backend-heterogeneity** | Graph evaluation output feeds into rendering pipeline |

## Principles

1. **The facade is the most important seam.** Graphite's `NodeNetworkInterface` (209 public methods, 6524 LOC) IS the document API. Its size reflects the abstraction gap between graph and document. If the facade grows too large, the abstraction is leaking — consider splitting by concern.

2. **Identity mapping is bidirectional.** `LayerNodeIdentifier ↔ NodeId` must work in both directions. Users select layers (→ need NodeId for graph ops), graph operations produce nodes (→ need LayerNodeIdentifier for UI). If either direction is lossy, bugs emerge.

3. **Transactions without rollback are optimistic.** Graphite's `TransactionStatus` (Started/Modified/Finished) has no rollback state. If a mutation fails mid-transaction, the graph may be inconsistent. This works when mutations are simple and rarely fail. Add rollback when mutation complexity grows.

4. **Three-registry sync is the extensibility bottleneck.** Adding a node type in Graphite requires updating: (a) the executor registry (`node_registry`), (b) the UI registry (`DOCUMENT_NODE_TYPES`), and (c) the property overrides (`NODE_OVERRIDES`, `INPUT_OVERRIDES`). Macro generation helps but doesn't eliminate the sync requirement.

5. **Graph operations should be topology-agnostic.** `GraphOperationMessage::FillSet` assumes a specific node arrangement to find the fill node. If the graph topology changes (user rewires nodes), the operation may modify the wrong node. Operations should locate targets by semantic role, not positional assumption.
