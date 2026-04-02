---
name: constraint-graph-under-mutation
description: >-
  Force tension: maintaining relational invariants across a graph of dependent
  elements when individual elements are mutated, with cascading propagation that
  must be atomic with undo and compatible with distributed sync.

  The four-way tension: binding integrity vs mutation performance vs undo
  coherence vs distributed sync compatibility.

  NOT static dependency graphs, build systems, module resolution, pure
  rendering/layout without mutable bindings, or one-directional data flow
  without back-propagation.

  Triggers: "element bindings", "constraint propagation", "cascading updates",
  "arrow-to-shape binding", "text-to-container binding", "frame containment",
  "group transforms", "relational invariants across mutations",
  "side-effect atomicity", "dependent element update", "binding graph traversal",
  "node-edge port binding update", "batch-delete side-effect ordering",
  "binding type dispatch and priority".

  Brownfield triggers: "undo the drag but the arrow stays in the new position",
  "text auto-resize creates infinite loop with container", "deleting a frame
  leaves orphan shapes after undo", "arrow bindings broke multiplayer sync with
  duplicate mutations", "batch-delete produces inconsistent state depending on
  iteration order", "visual node editor is slow with 500+ connections during
  drag", "adding a new binding type broke existing arrow bindings",
  "propagation system doesn't distinguish between binding types",
  "moving a shape doesn't update its bound arrows", "existing binding system
  doesn't handle the new shape type", "cascade propagation is stale after
  refactoring the store", "delete cascade leaves orphaned bindings",
  "bindings work in isolation but break under undo".

  Symptom triggers: "tldraw-based editor arrows connecting shapes drag a shape arrow
  endpoint follows undo the drag arrow stays in new position binding doesn't
  participate in undo transaction constraint propagation interact with undo",
  "text labels auto-resize container shape text grows container expands but
  expanding container re-layouts text creating infinite loop prevent cascading
  propagation cycles in this binding",
  "frame containment whiteboard shapes inside frame move when frame moves deleting
  frame should delete children or reparent them delete cascade atomic with undo
  leaves orphan shapes after undo",
  "arrow bindings broke multiplayer sync client A drags bound shape binding
  propagation runs on client A generates mutations client B also gets drag runs
  propagation creating duplicate mutations conflict in CRDT",
  "constraint system shapes bound to other shapes arrows labels containment
  batch-delete multiple shapes order of side-effects matters deleting shape A
  triggers unbinding from shape B but shape B also being deleted inconsistent
  state depending on iteration order",
  "visual node editor nodes have ports connected by edges moving a node should
  update all connected edge positions naive implementation recalculates every
  edge on every frame during drag slow with 500 plus connections",
  "adding new binding type shape-to-grid snapping existing arrow bindings
  misbehaving propagation system doesn't distinguish between binding types
  grid snap triggers arrow re-routing when it shouldn't".

  Diffused triggers: "move a shape and connected arrows follow",
  "resize container to fit text", "delete a frame and handle children",
  "undo should reverse all cascaded changes", "group transform propagates
  to children", "the binding system is getting unmaintainable",
  "arrows point to the wrong place after I changed the shape system",
  "cascade depth blows up after adding nested frames".

  Libraries: excalidraw (binding.ts, delta system), tldraw (Bindings,
  ShapeUtil, Editor facade), penpot (frame containment, change algebra).

  Production examples: excalidraw binding.ts, tldraw Editor.ts, penpot
  constraint hierarchy.
---

# Constraint Graph Under Mutation

When elements in a canvas are connected by bindings (arrows to shapes, text to
containers, children to frames), every mutation to one element may require
propagated updates to others. This codebook covers how to design, traverse, and
atomically commit those cascading changes.

---

## Step 1: Classify

Answer these questions to determine which patterns apply:

1. **What binding types exist?** Geometric (arrow endpoint locked to shape
   edge), containment (child inside parent frame), semantic (text reflow inside
   container), structural (group membership)?

2. **Are bindings bidirectional?** Does mutating either end trigger propagation,
   or is there a clear owner/dependent direction?

3. **How deep can cascades go?** One level (arrow updates when shape moves) or
   multi-level (move frame -> move children -> update their bindings)?

4. **What is the mutation frequency?** Per-frame during drag (60 Hz) vs discrete
   commits (on pointer-up)?

5. **Must propagated effects be undoable as a unit?** Can the user undo "move
   shape" and expect all arrow updates to reverse, or are they independent?

6. **Is the state distributed?** Must propagated changes sync to other clients
   atomically, or is this single-client only?

---

## Step 2: Load Reference

| Scenario | Reference | Key Pattern |
|---|---|---|
| Arrow/shape binding semantics, text-container reflow | `get_docs("domain-codebooks", "constraint-graph binding propagation")` | Immediate propagation with binding descriptors |
| Making cascaded changes atomic with undo | `get_docs("domain-codebooks", "constraint-graph atomic side-effects")` | Transaction wrapping, delta capture |
| Propagated changes must sync to peers | **cross-ref:** distributed-state-sync | CRDT-compatible delta batching |
| Undo must reverse propagated + direct changes | **cross-ref:** undo-under-distributed-state | Inverse delta grouping |
| Bindings interact with hit-test and selection | **cross-ref:** interactive-spatial-editing | Bound element selection policies |

---

## Step 3: Advise

### When mutation frequency is high (drag operations at 60 Hz):

Defer full propagation. Compute a lightweight "hint" position during drag and
run full constraint resolution on pointer-up. Excalidraw does this: during drag,
arrow endpoints are approximated; on commit, `updateBoundElements` runs the full
binding resolution.

### When bindings form a DAG (no cycles):

Topological-order propagation is correct and efficient. Process changed nodes,
then propagate to dependents in topo order. Each node is visited once.

### When bindings can form cycles:

You need either a constraint solver (expensive, rare in canvas apps) or
cycle-breaking rules (one binding "wins" priority). Most production apps avoid
cyclic bindings by design.

### When undo is required:

Wrap direct mutation + all propagated side-effects in a single transaction. The
undo system reverses the entire transaction. See
`get_docs("domain-codebooks", "constraint-graph atomic side-effects")`.

### When distributed sync is required:

Propagated changes should be computed locally on each client from the same
binding rules, rather than syncing the propagated results. Sync the direct
mutation; let each client re-derive the cascaded effects. This avoids conflicts
on derived state. Exception: if propagation is non-deterministic or expensive,
sync the results and use last-writer-wins on derived fields.

---

## Cross-References

- **distributed-state-sync** — Propagated changes must eventually reach other
  clients. The question is whether you sync derived state or re-derive it.
- **undo-under-distributed-state** — Undo must reverse all propagated effects
  atomically, even when other clients have since made changes.
- **interactive-spatial-editing** — Bindings affect hit-testing (click an arrow
  midpoint vs its bound shape), selection (select a bound group), and drag
  behavior (which elements move together).

---

## Principles

1. **Bindings are data, not code.** Store binding relationships as explicit data
   structures (binding descriptors with source, target, type, parameters) rather
   than implicit callback wiring. This makes them serializable, inspectable, and
   syncable.

2. **Propagation order is deterministic.** Given the same graph and the same
   mutation, propagation must produce the same result regardless of insertion
   order, iteration order, or client. Sort by stable ID when topo order has ties.

3. **Direct and derived changes are distinguishable.** The system must know which
   changes were user-initiated and which were propagated. This is essential for
   undo (reverse the group), sync (re-derive vs replicate), and conflict
   resolution (user intent wins over derived state).

4. **Cascade depth is bounded.** Unbounded propagation is a bug. Set a maximum
   cascade depth and treat exceeding it as an error (likely a cycle or
   misconfigured binding). Production systems rarely need more than 3 levels.

5. **Broken bindings are an expected state.** When a bound target is deleted, the
   binding enters a "dangling" state rather than crashing. The system must handle
   dangling bindings gracefully: detach the endpoint, show a visual indicator, or
   delete the dependent element.

6. **Performance budget: propagation must fit in the mutation frame.** If
   propagation cannot complete within the frame budget (16ms for 60fps), split
   into immediate (visual hint) and deferred (full resolution) phases.
