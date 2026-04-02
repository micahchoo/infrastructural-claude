---
name: hierarchical-resource-composition
description: >-
  Force tension: tree integrity vs reordering freedom vs undo coherence vs
  sync convergence. Users build content in hierarchical containers — layers in
  groups, shapes in frames, canvases in manifests, chapters containing sections.
  They expect to freely drag, reparent, reorder, flatten, and merge these
  containers while the system enforces structural invariants.

  Triggers: "layer group hierarchy reordering", "reparenting operations",
  "tree flattening or merge", "containment validation", "z-order from tree
  position", "recursive transforms through groups", "DAG vs strict tree",
  "hierarchical undo scope", "render order from tree structure",
  "fractional index ordering", "nested group transforms".

  Brownfield triggers: "reparenting corrupts z-order with fractional indices",
  "deleting a frame loses contained shapes and undo can't restore hierarchy",
  "simultaneous layer reordering causes conflicts in multiplayer",
  "rotating a nested group breaks recursive transforms",
  "containment validation on every drag frame kills performance",
  "moving a group doesn't move its children",
  "flattening a group loses metadata",
  "pasting into different hierarchy level produces wrong z-order",
  "undo after reparent restores to wrong parent".

  Symptom triggers: "reparenting a group from one frame to another corrupts
  z-order because fractional indexing doesnt handle cross-subtree moves",
  "delete a frame and shapes are orphaned because undo restores them
  separately", "two users reordering layers simultaneously causes CRDT
  conflicts", "rotating a parent group rotates children around their own
  center instead of group center", "containment validation on every drag
  frame traverses entire tree and is slow with 500 shapes".

cross_codebook_triggers:
  - "containment hierarchy affects hit-testing and spatial transforms (+ interactive-spatial-editing)"
  - "deep hierarchy forces virtualization but virtualized nodes can't participate in drag-reparent (+ virtualization-vs-interaction-fidelity)"

  Loaded via domain-codebooks router. Also consulted by pattern-advisor
  for tree/hierarchy architecture decisions.
---

# Hierarchical Resource Composition

## Force Tension

**Tree integrity** vs **reordering freedom** vs **undo coherence** vs **sync convergence**.

Users build content in hierarchical containers — layers in groups, shapes in frames, canvases in manifests, chapters containing sections. They expect to freely drag, reparent, reorder, flatten, and merge these containers while the system silently enforces structural invariants (no cycles, valid nesting depth, correct render order, consistent undo boundaries). In multiplayer, concurrent tree mutations must converge to identical structure on all peers.

The core tension: every operation that makes restructuring easier (flat arrays, loose parent refs) makes integrity harder, and every operation that makes integrity easy (immutable trees, strict schemas) makes restructuring rigid.

## Triggers — Use This Codebook When You See

- Layer/group hierarchy with user-driven reordering
- Reparenting operations (drag node to new parent)
- Tree flattening or merge operations (flatten group, merge layers)
- Containment validation (frame contains shapes, range spans canvases)
- Z-order that depends on tree position
- Recursive transforms propagated through groups
- DAG vs strict tree structure decisions
- Hierarchical undo scope (undo within a group vs globally)
- Render/composition order derived from tree structure

## Brownfield Triggers — Existing Pain Points

- "Reparenting breaks undo" — move operation not captured as atomic reversible unit
- "Moving a group doesn't move its children" — parent-child binding is soft/implicit
- "Layer order desyncs in multiplayer" — tree position used for ordering without CRDT-safe index
- "Flattening a group loses metadata" — flatten destroys intermediate nodes without preserving their properties
- "Adding nested groups breaks containment validation" — validator assumes fixed depth
- "Pasting into a different hierarchy level produces wrong z-order" — clipboard doesn't carry positional context
- "Undo after reparent restores to wrong parent" — undo captures property diff, not structural diff

## Skip — Out of Scope

- File system hierarchies (different invariants, OS-managed)
- DOM tree manipulation (browser-managed, different lifecycle)
- Database tree structures (nested sets, materialized paths, closure tables — persistence patterns, not interactive mutation)
- Organizational charts (read-heavy, rarely user-restructured in real time)
- Abstract syntax trees (compiler-managed, not user-restructured)

## Cross-References

| Codebook | Relationship |
|---|---|
| `constraint-graph-under-mutation` | A hierarchy IS a constraint graph. Parent-child edges are constraints. Reparenting is constraint mutation. |
| `undo-under-distributed-state` | Hierarchical undo scope is the hardest variant — does "undo" reverse a move within the subtree or globally? |
| `interactive-spatial-editing` | Containment hierarchy affects hit-testing, selection, and spatial transforms. Frame membership changes what "select all" means. |
| `virtualization-vs-interaction-fidelity` | Deep or wide hierarchies force virtualization, but virtualized nodes can't participate in drag-reparent, keyboard traversal, or selection until materialized — the hierarchy depth drives the virtualization boundary. |

## Decision Axes

When entering this problem space, the first structural decisions are:

1. **Tree vs DAG**: Can a node have multiple parents? (IIIF ranges: yes. Layer groups: no.)
2. **Position encoding**: Tree-order (Krita), fractional index (tldraw), flat array + parentId (Excalidraw)?
3. **Mutation style**: Immutable snapshots, mutable-with-hooks, event-sourced, CRDT?
4. **Integrity enforcement**: Validate-on-mutate vs validate-before-commit vs eventual consistency?
5. **Undo granularity**: Per-node, per-subtree, or global?

See `get_docs("domain-codebooks", "hierarchical-resource tree mutation")` and `get_docs("domain-codebooks", "hierarchical-resource hierarchy rendering")` for detailed pattern analysis.
