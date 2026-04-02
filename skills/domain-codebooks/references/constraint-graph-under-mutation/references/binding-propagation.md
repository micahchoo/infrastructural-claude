# Binding Propagation

How canvas applications maintain relational invariants when elements connected by
bindings are mutated.

---

## The Problem

Without a binding system, connected elements desync immediately:

- **Orphaned arrows.** User moves a rectangle; the arrow that pointed to it
  stays behind, endpoint floating in empty space. The user must manually
  reattach. At scale (complex diagrams with dozens of connections), this makes
  the tool unusable.

- **Desynced text.** A text element is logically "inside" a container shape. The
  user resizes the container; the text doesn't reflow. Or the text grows; the
  container doesn't expand. Either way, text overflows or whitespace gaps appear.

- **Broken containment.** A frame groups child elements. The user moves the
  frame; children stay behind. Or a child is dragged out of the frame but the
  frame's children list isn't updated, causing ghost membership.

- **Inconsistent deletion.** Delete a shape; arrows bound to it now point to
  nothing. Delete a container; its text element is orphaned. Delete a frame; its
  children lose their parent but don't know it.

The core issue: **mutations are local but relationships are global.** Every
mutation to one element must check and potentially update every element bound to
it.

---

## Competing Patterns

### 1. Immediate Propagation

**How it works:** After every mutation to an element, immediately traverse its
bindings and update all dependents. The update function runs synchronously before
control returns to the caller.

**Example — Excalidraw `binding.ts`:**

Excalidraw's `updateBoundElements()` is called after any element mutation that
might affect bindings. It:
1. Looks up all elements bound to the mutated element via `boundElements` array
2. For each bound arrow, recalculates the binding point on the shape's surface
3. For bound text, recalculates position relative to the container
4. Mutates the bound elements in-place

The binding descriptor stores: `{ id: string, type: "arrow" | "text" }` on the
shape, and `{ elementId: string, focus: number, gap: number }` on the arrow
endpoint.

Key functions in the 2940-LOC file:
- `bindLinearElement` — establishes a new arrow-to-shape binding
- `unbindLinearElement` — removes a binding (on delete or explicit detach)
- `updateBoundElements` — the propagation entry point
- `getHeadingForBindableElement` — geometric calculation for where an arrow
  meets a shape's surface

**Tradeoffs:**
- Simple mental model: mutation + propagation is one synchronous operation
- Guaranteed consistency: no intermediate state is visible
- Performance risk: deep cascades or many bindings can blow the frame budget
- Ordering sensitivity: if A binds to B binds to C, must propagate in order

**De-Factoring Evidence (from tldraw binding analysis):**
- **If removed (batch boundary):** Group-move fires N individual propagations; arrows "jitter" to intermediate positions before settling. Redundant computation when one arrow is bound to multiple moving shapes.
- **Detection signal:** `setTimeout` or `requestAnimationFrame` used to "wait for all updates to finish" before propagating; `isUpdating` flags to suppress propagation during batch operations.

### 2. Deferred Batch Propagation

**How it works:** Mutations are queued. At the end of a batch (e.g., end of a
drag operation, end of a transaction), all bindings are resolved in one pass.

**Example — tldraw Editor facade:**

tldraw's `Editor` class centralizes all mutations through methods like
`updateShape()`. The editor:
1. Applies the direct mutation to the shape record in the store
2. Marks affected bindings as dirty
3. At the end of the update batch, runs binding resolution for all dirty bindings
4. The `Bindings` system processes each binding type through its `ShapeUtil`

Different `ShapeUtil` subclasses define different binding semantics — an arrow
shape handles bindings differently than a sticky note. The polymorphic dispatch
through the editor facade ensures all types are handled uniformly.

**Tradeoffs:**
- Better performance: one propagation pass per batch, not per mutation
- Handles multi-element mutations naturally (move 5 shapes at once)
- More complex: intermediate state exists during the batch
- Must ensure the batch boundary is well-defined

**De-Factoring Evidence (from tldraw binding analysis):**
- **If removed (batch boundary):** Each individual record change triggers immediate propagation; moving a group of shapes fires N individual updates with arrows snapping to intermediate positions between each. Result is O(n*m) instead of O(n+m).
- **Detection signal:** Bug reports of "arrows jitter when moving a group of shapes"; debouncing hacks that introduce timing-dependent bugs.

### 3. Immutable Data with Explicit Propagation

**How it works:** State is immutable. Every mutation produces a new state tree.
Propagation is a pure function: `propagate(oldState, mutation) -> newState`
where `newState` includes both the direct change and all cascaded effects.

**Example — Penpot frame containment:**

Penpot uses Clojure's immutable data structures. A frame's children are stored
as an ordered list of IDs in the frame's data. When a shape is moved:
1. The change is described as data (the "change algebra")
2. The change is applied to produce a new state
3. Frame containment is checked: did the shape move into or out of a frame?
4. If so, additional changes are generated (update old frame's children list,
   update new frame's children list, update shape's parent reference)
5. All changes are composed into a single compound change

**Tradeoffs:**
- Propagation is explicit and testable (pure function)
- No hidden mutation — the constraint graph is visible in the change algebra
- Natural fit for undo (reverse the compound change)
- Memory pressure from copying (mitigated by structural sharing)
- Must be disciplined about composing all related changes

### 4. Constraint-Edge-as-Record (tldraw)

**How it works:** Bindings are first-class records in the same store as shapes
and pages. Each binding is a directed edge `{fromId, toId, props}` with a type
key dispatching to a registered `BindingUtil`. The binding is a peer record
type — not a property embedded on shapes.

**Core type:**
```typescript
interface TLBaseBinding<Type extends string, Props extends object> {
  id: TLBindingId;
  typeName: 'binding';
  type: Type;          // strategy key (e.g., 'arrow')
  fromId: TLShapeId;   // source shape
  toId: TLShapeId;     // target shape
  props: Props;         // type-specific data
  meta: JsonObject;
}
```

**Five architectural seams:**

1. **Plugin Registration (Strategy Pattern)** — `BindingUtil` subclasses are
   registered at editor init via `bindingUtils` map. Each type defines its own
   lifecycle hooks. New binding types are added without modifying the editor.
   (`packages/editor/src/lib/editor/Editor.ts`)

2. **Store Side-Effects (Observer Pattern)** — The editor registers
   `beforeCreate/afterCreate/beforeChange/afterChange/beforeDelete/afterDelete`
   hooks on the `binding` record type via `StoreSideEffects`. Each hook
   dispatches to the relevant `BindingUtil`. Side effects are **disabled during
   undo/redo replay** (`sideEffects.setIsEnabled(false)`).
   (`packages/store/src/lib/StoreSideEffects.ts`)

3. **Shape-Change Propagation (Mediator Pattern)** — When a shape changes, the
   editor looks up all bindings via `bindingsIndex` (a `Computed` that diffs
   against the last epoch). Directional callbacks fire:
   `onAfterChangeFromShape` / `onAfterChangeToShape` with `{binding,
   shapeBefore, shapeAfter, reason}`. Parent changes propagate recursively to
   descendants with `reason: 'ancestry'`.
   (`packages/editor/src/lib/editor/derivations/bindingsIndex.ts`)

4. **Shape Deletion Cascade (Lifecycle Hook)** — When a shape is deleted, all
   bindings involving that shape receive `onBeforeDeleteFromShape` /
   `onBeforeDeleteToShape`. The `BindingUtil` decides the policy: delete the
   binding, delete the other shape, or leave it orphaned. Arrow bindings
   typically delete the binding and leave the arrow with a free endpoint.

5. **Undo/Redo Integration (Record-Level Replay)** — Since bindings are store
   records, they participate in undo/redo automatically via `HistoryManager`
   diffs. During replay, side effects are disabled and raw record state is
   restored directly. No cascading propagation occurs because the recorded diff
   already includes the propagated state.

**Comparison with excalidraw's property-embedded approach:**

| Dimension | tldraw (record-based) | excalidraw (property-embedded) |
|-----------|----------------------|-------------------------------|
| **Binding storage** | First-class `binding` records in store | `boundElements[]` on shape + `startBinding`/`endBinding` on arrow |
| **Lookup** | Computed index over binding records (`bindingsIndex`) | Linear scan of `boundElements` array |
| **Adding types** | Register new `BindingUtil` — no core changes | Modify `binding.ts` monolith (2940 LOC) |
| **Deletion** | Lifecycle hooks per type decide policy | Symmetric cleanup in `unbindLinearElement` |
| **Undo** | Automatic (bindings are records in the diff) | Implicit (delta snapshot includes bound element changes) |
| **Sync** | Binding records sync like any other record | Bound properties sync as part of element updates |
| **Extensibility** | Plugin-friendly (strategy dispatch) | Monolithic (all types in one file) |
| **Tradeoff** | More records in store, indirection cost | Simpler (fewer entities), but rigid |

**Tradeoffs:**
- Enables plugin registration and clean type-keyed dispatch
- Computed indices provide incremental binding lookup (no full scan)
- Clean deletion semantics via per-type lifecycle hooks
- More records in the store (one per binding, not embedded on shapes)
- Indirection: resolving a binding requires a store lookup vs. reading a property

**De-Factoring Evidence (from tldraw binding analysis):**

*Record-based edges:*
- **If removed:** Bindings become dual-write properties on both shape endpoints. Missed writes leave one end pointing at a stale or deleted target — excalidraw's most persistent bug class. Undo must track property pairs rather than record add/remove.
- **Detection signal:** `element.boundElements` arrays kept in sync across two records with no transactional guarantee; "arrow still points to deleted shape" bugs.

*Computed index:*
- **If removed:** Every shape mutation must scan all bindings to find affected ones, blowing the 16ms frame budget at drag frequency. Without epoch-based diffing, the index either rebuilds too aggressively (perf bottleneck) or too lazily (stale during multi-step ops).
- **Detection signal:** `bindings.filter(b => b.fromId === shapeId || b.toId === shapeId)` in a hot loop; "moving a shape with no bindings is slow."

*Type-keyed strategy dispatch:*
- **If removed:** All binding logic collapses into one monolithic handler. Adding a new binding type means editing the central file, risking regressions in existing types. Plugin extensibility becomes impossible.
- **Detection signal:** switch/case on binding type in propagation logic; single binding handler file growing past 1000 LOC; "adding [new element type] broke arrow bindings."

*Isolation vs. deletion callback separation:*
- **If removed:** A single `onBindingRemoved` handler cannot distinguish "user unbound arrow" from "target shape was deleted." Unbinding deletes the arrow (wrong), or deletion leaves arrow pointing at (0,0) with no visual indicator.
- **Detection signal:** `onBindingRemoved` handler with `if (isShapeBeingDeleted)` branches; "unbinding an arrow from a shape deletes the arrow."

*Replay passthrough (side-effects disabled during undo):*
- **If removed:** Side effects fire during undo replay, causing double-propagation — arrows end up in wrong positions after undo. Infinite loops possible when undo-triggered propagation cascades. Two clients undoing the same op diverge if propagation depends on local state.
- **Detection signal:** "undo moves arrow to wrong position"; undo is as slow or slower than the original operation; undo system has special-case logic for "also update bindings after restoring shapes."

### 5. Constraint Solver

**How it works:** Bindings are declared as constraints (e.g., "arrow endpoint
must lie on shape boundary"). A solver runs after mutations to find a state
satisfying all constraints.

**Tradeoffs:**
- Most general: handles cycles, competing constraints, soft constraints
- Most expensive: solver convergence is not guaranteed in bounded time
- Rarely used in production canvas apps (overkill for typical binding types)
- Used in CAD tools, not typically in collaborative whiteboard/diagramming apps

---

## Decision Guide

**Choose Immediate Propagation when:**
- Binding graph is shallow (1-2 levels)
- Mutations are infrequent (discrete commits, not continuous drag)
- Simplicity is valued over batch optimization
- You need guaranteed consistency at every point in time

**Choose Deferred Batch when:**
- Mutations are frequent (drag at 60 Hz) or multi-element
- You already have a transaction/batch concept in your architecture
- Performance is critical and you can tolerate brief intermediate inconsistency
- The editor facade pattern is already in use

**Choose Immutable + Explicit Propagation when:**
- You're using an immutable state architecture (Clojure, Redux-style)
- Testability and auditability of propagation logic is important
- You need change composition for undo/sync
- You can afford the memory overhead of structural sharing

**Avoid Constraint Solver unless:**
- You have genuinely cyclic constraints
- You're building a CAD tool with geometric constraints
- You have budget for solver complexity and non-convergence handling

---

## Anti-Patterns

### 1. Implicit Propagation via Getters

Binding resolution happens inside getter functions (e.g., `arrow.getEndpoint()`
dynamically computes the bound position). The constraint graph is invisible.
Undo doesn't work because there's nothing to reverse — the getter recomputes
from current state. Performance is unpredictable because every property access
may trigger traversal.

### 2. Listener Spaghetti

Each binding type registers event listeners (`shape.on('move', updateArrows)`).
Propagation order depends on listener registration order. Cascades are invisible.
Testing requires firing events. Debugging requires tracing callback chains.

### 3. Over-Propagation

Every mutation triggers full graph traversal regardless of which bindings are
affected. Move a shape with no bindings? Still traverses the entire binding
graph. Fix: check if the mutated element has any bindings before starting
propagation. Excalidraw does this — `updateBoundElements` returns early if the
element's `boundElements` array is empty.

### 4. Propagation Without Dirty Tracking

In batch mode, re-resolving ALL bindings instead of just the ones affected by
mutations in this batch. Fix: maintain a dirty set of binding IDs that need
resolution. tldraw's approach of marking affected bindings during mutation and
resolving only those in the batch pass.

### 5. Asymmetric Binding Lifecycle

Creating a binding updates both ends (shape's `boundElements` and arrow's
`startBinding`), but deletion only cleans up one end. Leaves dangling references
that cause crashes or ghost bindings. Fix: binding create and destroy must be
symmetric — always update both ends, and use a single function for each to
enforce this.

---

## Additional Patterns (from De-Factoring)

### Pattern Interdependence

The six patterns in tldraw's constraint-edge-as-record system (record-based edges,
computed index, strategy dispatch, isolation/deletion separation, replay passthrough,
batch boundary) form a mutually dependent unit. Removing any one creates pressure
that distorts the others — e.g., record-based edges without batch boundaries produce
jitter; batch boundaries without replay passthrough produce undo bugs. Incremental
adoption of individual patterns fails; they must be adopted as a cohesive system.

Source: `/mnt/Ghar/2TA/DevStuff/Patterning/canvases-annotations-sharing/tldraw/binding-defactor.md`
