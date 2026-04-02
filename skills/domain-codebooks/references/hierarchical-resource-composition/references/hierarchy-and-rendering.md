# Hierarchy and Rendering Order

## The Problem

Render order (which element appears on top of which) depends on tree position, but users think in terms of spatial stacking ("move to front", "send to back"), not tree surgery. The hierarchy serves dual purposes — organizational grouping AND render ordering — and these purposes conflict.

A user drags a shape into a group for organizational reasons. That group happens to be lower in the tree. The shape disappears behind other content. The user didn't ask for a z-order change — they asked for grouping. But tree-ordered rendering made grouping and ordering the same operation.

## Competing Patterns

### 1. Pure Tree-Order Rendering

**How it works**: Render by depth-first traversal of the tree. A node's visual stacking is entirely determined by its position in the tree. "Move to front" means "move to last child of parent" or "reparent to a higher group."

**Production example — Krita**:
Krita's layer stack renders strictly by tree order. The bottom layer in the panel renders first (back). Groups composite their children internally, then the group result composites with siblings. Masks and filter layers modify their parent's output in tree order.

Key behavior:
- Moving a layer between groups changes its render order relative to layers in other groups
- A layer's z-order is LOCAL to its parent group — you cannot interleave layers from different groups
- "Merge down" flattens two adjacent siblings because they ARE adjacent in render order
- The layer panel IS the render order — no hidden complexity

**Strengths**: Predictable. Debuggable. The tree visualized in the panel is exactly what the renderer sees. Artists learn the model and work within it.

**Weaknesses**: "I want this layer in Group A but rendered above Group B" is impossible without restructuring. Organizational grouping and visual stacking cannot diverge.

### 2. Flat Array with Parent References

**How it works**: All elements live in a flat ordered array (or have a sort index). Parent references provide grouping but the flat order determines rendering. Elements within a group are constrained to be contiguous in the flat array, but their absolute position determines global z-order.

**Production example — Excalidraw**:
Excalidraw stores all elements in a flat array. `elements` is the source of truth for render order — first element renders at the back, last at the front. Groups are an overlay concept: elements share a `groupId` but their render position is their array index.

Key behavior:
- "Bring to front" is `splice` element to end of array
- Groups are visual sugar — selecting one element in a group selects all, but they don't form a render subtree
- Frame containment is checked spatially ("is this element's bounds within the frame's bounds?"), not by tree parentage
- No nesting depth limit because there's no real nesting — it's all one flat list

**Strengths**: Z-order operations are trivial array manipulations. No tree invariants to maintain for ordering. Multiplayer-friendly (array operations are simpler to merge than tree operations).

**Weaknesses**: Groups can't have group-level properties (group opacity, group blend mode) because there's no group node in the render pipeline. Frame containment is spatial, so moving a frame doesn't automatically move contained elements (requires explicit logic). "Elements in a group" can be non-contiguous in the array after certain operations, creating visual artifacts.

### 3. Hybrid: Pages + Containers with Fractional Indexing

**How it works**: A shallow tree (2-3 levels) provides containment. Within each container, elements are ordered by a fractional index (string sort key). Global render order is: container tree order for the coarse pass, fractional index for fine ordering within containers.

**Production example — tldraw**:
tldraw uses pages as top-level containers. Within a page, shapes have a `parentId` (page, frame, or group) and an `index` (fractional string). Rendering traverses: page children sorted by index, and for each frame/group, its children sorted by index, recursively.

Key behavior:
- `index` is a string like `"a1"`, `"a1V"`, `"a2"` — lexicographic sort gives render order
- Inserting between two shapes generates a new index between them without touching siblings
- Reparenting to a frame changes containment but the new index determines render position within the frame
- "Bring to front" within a frame generates an index greater than all siblings
- Cross-frame "bring to front" requires reparenting to the page level — containment and z-order are linked within a page but frames create z-order boundaries

**Strengths**: Fractional indexing eliminates reindex cascades. Shallow hierarchy keeps tree operations simple. Frame boundaries create predictable z-order scopes. Multiplayer-friendly — concurrent index generation produces valid (if not always ideal) orderings.

**Weaknesses**: Fractional index strings grow over time (needs periodic rebalancing, which is itself a multiplayer challenge). Cross-container z-ordering is limited — you can't put a shape "between" two frames without choosing a container.

## Decision Guide

| Factor | Pure Tree-Order | Flat Array + Parent Refs | Hybrid + Fractional Index |
|---|---|---|---|
| Target user | Professional (learns the model) | Casual (expects direct manipulation) | Mixed |
| Group-level rendering (opacity, blend) | Natural | Impossible without redesign | Possible at container level |
| "Bring to front" | Tree surgery | Array splice | Index regeneration |
| Cross-group z-ordering | Impossible by design | Trivial | Impossible across containers |
| Multiplayer complexity | High (tree merge) | Low (array merge) | Medium (index merge) |
| Nesting depth | Unlimited | None (fake groups) | Shallow (2-3) |
| Organizational grouping = visual stacking? | Always | Never enforced | Within containers: yes |

### When to Choose What

**Choose pure tree-order when**:
- Your domain has inherent compositional hierarchy (image editing: layers composite with blend modes)
- Group-level rendering properties are essential (group opacity, group masks)
- Users are professionals who will learn the tree model
- Single-user or turn-based collaboration

**Choose flat array when**:
- Z-order flexibility matters more than grouping semantics
- Groups are purely organizational (selection convenience, not render units)
- You want the simplest possible multiplayer story
- No group-level rendering properties needed

**Choose hybrid when**:
- You need containment (frames, pages) but also flexible ordering within containers
- Multiplayer is required but some hierarchy is necessary for the UX
- You can accept z-order boundaries at container edges

## Anti-Patterns

### The Z-Order Lie
Showing users a layer panel that implies tree-order rendering, but actually rendering from a separate z-index property. The panel and the canvas disagree. Users lose trust. Pick one source of truth and make the UI reflect it.

### The Unbounded Flatten
Letting users flatten/merge across group boundaries without warning that group-level properties (opacity, blend mode, masks) will be baked in. The operation is destructive and non-obvious. Show a preview. Make it undoable.

### The Containment Surprise
Spatially determining containment (element inside frame bounds = contained) without user confirmation. User moves an element near a frame, it "snaps" into the frame's hierarchy, changing its z-order scope. Require explicit drop-into-container gesture, not spatial proximity.

### The Index Explosion
Using fractional indexing without a rebalancing strategy. After many insert-between operations, index strings grow unbounded. Eventually they hit storage or comparison performance limits. Implement periodic rebalancing during idle moments — but coordinate rebalancing in multiplayer (all peers must agree on the new indices).

### The Orphan Group
Allowing groups to have zero or one children. A group with one child is indistinguishable from the child alone but adds tree complexity. A group with zero children is invisible garbage. Auto-dissolve groups that reach zero or one children (with undo support).

### The Render Order Amnesia
Not preserving relative render order during copy-paste across containers. User copies three shapes in a specific stacking, pastes into a different frame, and they arrive in arbitrary order. Capture relative order in the clipboard representation and reproduce it at the paste target.

## Additional Evidence

### Overlapping Virtual Hierarchies (Memories for Nextcloud)

**Source**: Memories — photo management app for Nextcloud (PHP backend, Vue 2 frontend, Go transcoder).

Memories demonstrates what happens when a single resource (a photo) exists simultaneously in multiple independent hierarchies, none of which is "the" hierarchy:

1. **Filesystem folder path**: The physical location in Nextcloud's storage. This is the only hierarchy the host platform (Nextcloud) natively understands.
2. **Albums**: Stored in Nextcloud Photos' tables (`photos_albums`, `photos_albums_files`). A photo can belong to multiple albums. Albums are flat — no nested albums.
3. **Face clusters**: AI-detected face groupings. A photo with three people appears in three face clusters.
4. **Place clusters**: Geographic groupings. A photo appears in one place cluster based on GPS data.
5. **Tag clusters**: User-assigned tags. A photo can have multiple tags.
6. **Time-based groupings**: Days, months, years — computed from EXIF timestamps. These are virtual (no DB rows), derived at query time.

**Why this matters for hierarchy and rendering**: Each hierarchy implies a different "render order" for the same set of photos. The timeline view orders by date. The album view orders by user-defined album position. The folder view orders by filename/path. The face cluster view orders by detection confidence. There is no single tree that determines display order — the active hierarchy context determines ordering.

**TimelineRoot virtual folder composition**: `TimelineRoot` builds a virtual folder hierarchy that may differ from the physical filesystem. It discovers external storage mount points inside timeline folders via `addMountPoints()` and injects them as additional query roots. The `baseChange()` method rewrites paths to scope queries to subfolders. This is a containment hierarchy that is *computed*, not stored — analogous to how tldraw's page contains frames, but here the "page" (TimelineRoot) dynamically discovers its "frames" (mount points).

**Key edge cases**:
- `.nomedia` exclusion propagation: A `.nomedia` file makes a folder invisible in the timeline, but external mounts *inside* excluded folders must still be evaluated — the mount might point to a non-excluded location. This is a containment-rule exception that breaks simple recursive propagation.
- Mount ordering: The order in which mount points are added to `TimelineRoot` affects which photos appear in timeline queries. This is an implicit render-order dependency on hierarchy construction order.

**Pattern classification**: This is closest to the **Flat Array + Parent Refs** pattern, but with *multiple independent parent-ref systems*. There is no single `parentId` — instead, a photo has a folder path, zero or more album memberships, zero or more cluster memberships, and computed time groupings. The "render order" (display sort) is determined by which parent-ref system is currently active in the UI, not by a single tree position.

**Contrast with Excalidraw**: Excalidraw's flat array gives each element one position in one ordering. Memories gives each photo *no inherent position* — position is always relative to the active hierarchy context. This is a more extreme version of the "organizational grouping vs render ordering" tension: not only do the two purposes conflict, but there are *five or more* organizational groupings that each imply a different render order.
