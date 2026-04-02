# Diagnostic Framework

Per-force-cluster diagnostic questions. Answers select the right competing
pattern from the codebook. Questions are project-specific — answerable by
someone who knows their system.

---

## Architectural Force Clusters

### distributed-state-sync

1. **Collaboration topology**: Server-authoritative, peer-to-peer, or hybrid? Is there a central server that all clients sync through?
2. **Offline requirement**: Must the app work offline and sync later? How long might a client be disconnected?
3. **Conflict resolution priority**: When two users edit the same thing simultaneously, which wins — last write, merge, or manual resolution?
4. **State shape**: Is your shared state a flat key-value map, a tree/document, or a graph with cross-references?
5. **Persistence requirement**: Must state survive page refresh? Server restart? How is it stored?

**Pattern mapping**:
- Server-authoritative + always-online → OT or server-reconciled LWW
- P2P or offline-capable → CRDT (Yjs, Automerge)
- Simple key-value + server → LWW with server timestamp
- Complex document + offline → CRDT with persistence layer

### interactive-spatial-editing

1. **Tool diversity**: How many distinct tools does the editor have? (3-5 = simple, 10+ = complex)
2. **Mode transitions**: Do tools have sub-modes (e.g., rectangle tool: draw, resize, rotate)?
3. **Shape count**: Typical document size? (<100, 100-1K, 1K-10K, 10K+)
4. **Selection model**: Single select, multi-select, group select, nested select?
5. **Zoom range**: What zoom levels must work? Does hit-testing need to adapt?

**Pattern mapping**:
- Few tools, simple modes → inline dispatch (Excalidraw-style)
- Many tools, complex modes → hierarchical state machine (tldraw StateNode)
- 10K+ shapes → spatial index required (R-tree, quadtree)
- Nested selection → selection stack with scope tracking

### undo-under-distributed-state

1. **Undo scope**: Should undo revert only MY changes or anyone's changes?
2. **Undo granularity**: Character-level, operation-level, or logical-action-level?
3. **State layer**: CRDT, OT, or custom? Does the state layer have its own undo?
4. **Side effects**: Does undo need to capture constraint propagation (e.g., arrow follows shape)?
5. **Batch operations**: Do multi-step operations need atomic undo? (e.g., paste multiple shapes)

**Pattern mapping**:
- CRDT with own undo → CRDT-native undo (Yjs UndoManager)
- Custom state + local-only undo → command pattern or diff-based
- Need multiplayer undo scope → mark-based undo with scope tags
- Complex side effects → snapshot-based or event-sourcing undo

### constraint-graph-under-mutation

1. **Binding types**: What objects reference each other? (arrows→shapes, text→containers, frames→children)
2. **Propagation depth**: When one object changes, how far do effects cascade? (1-hop, multi-hop, unbounded)
3. **Undo interaction**: Must undo restore binding state atomically with the objects?
4. **Sync interaction**: Do bindings need to sync across clients? Are they derived or stored?
5. **Performance budget**: How many bindings per document? Real-time update required?

**Pattern mapping**:
- Simple 1-hop bindings → direct reference with update listener
- Multi-hop cascading → topological sort with change propagation
- Bindings + undo → atomic side-effect capture in undo stack
- Bindings + sync → store bindings in shared state, not derived

### schema-evolution-under-distributed-persistence

1. **Version spread**: How many client versions are active simultaneously? (1-2, 3-5, unbounded)
2. **Migration direction**: Can you require all clients to upgrade? Or must old clients keep working?
3. **State format**: JSON, binary, CRDT document? How is schema encoded?
4. **Breaking changes frequency**: How often does the schema change in incompatible ways?

**Pattern mapping**:
- Controlled rollout, few versions → forward-only migrations
- Long-lived old clients → bidirectional migrations (tldraw-style)
- CRDT state → version-gated compatibility layer
- Frequent breaking changes → schema registry with negotiation

### embeddability-and-api-surface

1. **Embedding context**: iframe, web component, npm package, or native SDK?
2. **API stability requirement**: Is this a public API with external consumers?
3. **State ownership**: Does the host app own the state, or does the embedded component?
4. **Customization depth**: Theming only, or deep behavioral customization?

**Pattern mapping**:
- iframe embedding → postMessage API, minimal surface
- npm package + public API → facade pattern, semver, API surface tracking
- Host owns state → controlled mode with state injection
- Deep customization → plugin system with sandboxing

### crdt-structural-integrity

1. **CRDT library**: Yjs, Automerge, or custom?
2. **Document lifetime**: Hours, days, months? How much history accumulates?
3. **GC requirement**: Can you garbage-collect tombstones? What breaks if you do?
4. **Type composition**: Nested CRDT types (Map in Array in Map)?

**Pattern mapping**:
- Long-lived docs → periodic compaction with snapshot
- Undo depends on history → careful GC boundaries
- Complex nesting → composition guards, flatten where possible
- Yjs → use built-in GC with configurable threshold

### hierarchical-resource-composition

1. **Tree depth**: Flat (1 level), shallow (2-3), or deep (unbounded)?
2. **Reparenting**: Can objects move between parents? How often?
3. **Ordering**: Does sibling order matter? What ordering scheme? (integer, fractional, lexicographic)
4. **Cross-tree references**: Do objects in different subtrees reference each other?

**Pattern mapping**:
- Flat + rare reorder → integer indices
- Frequent reordering → fractional indexing
- Deep + reparenting + sync → move operation with parent validation
- Cross-tree refs → separate binding layer (constraint-graph-under-mutation)

## UX Force Clusters

### gesture-disambiguation

1. **Competing gestures**: Which gestures can conflict? (drag vs scroll, tap vs long-press, pan vs select)
2. **Tool modes**: Does gesture meaning change based on active tool?
3. **Multi-touch**: Must you support pinch-zoom, two-finger pan, or multi-finger gestures?
4. **Event architecture**: React synthetic events, native DOM, or canvas hit-testing?
5. **Overlay layers**: Do UI overlays (menus, panels) need to intercept events before the canvas?

**Pattern mapping**:
- Few conflicts, simple tools → event delegation with priority
- Many tools with sub-modes → gesture arena / state machine arbitration
- Multi-touch → dedicated gesture recognizer pipeline
- Overlays + canvas → capture/bubble with z-order priority

### optimistic-ui-vs-data-consistency

1. **Update latency**: How long between user action and server confirmation? (<100ms, 100ms-1s, >1s)
2. **Conflict likelihood**: How often do two users edit the same thing? (rare, occasional, frequent)
3. **Rollback visibility**: If the server rejects, should the user see a visible rollback or silent correction?
4. **Loading states**: How do you indicate sync status? (none, subtle indicator, explicit states)

**Pattern mapping**:
- Low latency + rare conflicts → fire-and-forget optimistic
- High latency + frequent conflicts → rebase-on-commit with animation
- Visible rollback needed → dual source of truth with reconciliation
- Complex sync states → explicit lifecycle states (syncing/synced/conflict/offline)

### virtualization-vs-interaction-fidelity

1. **Item count**: How many items in the list/grid/canvas? (<1K, 1K-100K, 100K+)
2. **Interaction requirements**: Selection, keyboard nav, drag-and-drop on virtualized items?
3. **Variable sizing**: Are items same height or variable?
4. **Search/filter**: Must search highlight items outside the visible viewport?

**Pattern mapping**:
- <1K items → don't virtualize (complexity not worth it)
- Fixed-size items → windowed rendering (react-window style)
- Variable + keyboard nav → virtualized with focus management bridge
- Canvas with culling → viewport-based render with spatial index

### focus-management-across-boundaries

1. **Component boundaries**: Custom widgets, iframes, shadow DOM, or standard HTML?
2. **Keyboard shortcuts**: Global shortcuts that must work regardless of focus location?
3. **Modal/dialog stacking**: Multiple layers of focus traps?
4. **Focus restoration**: Must focus return to the previous element after closing a panel?

**Pattern mapping**:
- Standard HTML → native focus management, minimal intervention
- Custom widgets → roving tabindex with arrow key navigation
- Stacked modals → focus trap stack with LIFO restoration
- Global shortcuts → keyboard capture toggle (canvas vs UI mode)

### input-device-adaptation

1. **Input devices**: Mouse-only, touch-only, or multi-device?
2. **Pen features**: Pressure sensitivity, tilt, eraser button?
3. **Coarse/fine distinction**: Different behavior for finger vs pen vs mouse?
4. **Device switching**: Can users switch devices mid-session?

**Pattern mapping**:
- Mouse-only → standard pointer events
- Touch + mouse → pointer events with coarse/fine detection
- Pen with pressure → tablet event processing, pressure curves
- Dynamic switching → device capability detection with per-device settings

### text-editing-mode-isolation

1. **Text context**: Inline labels, rich text blocks, or full document editing?
2. **IME requirement**: Must support CJK input methods?
3. **Shortcut conflicts**: Do canvas shortcuts (Delete, arrow keys) conflict with text editing?
4. **Focus handoff**: How does the user enter/exit text editing mode?

**Pattern mapping**:
- Simple labels → contentEditable with blur-to-confirm
- Rich text → embedded text editor (ProseMirror, Slate) with mode gate
- Shortcut conflicts → keyboard capture toggle during text editing
- IME → composition event handling with commit-on-compositionend

## Rendering Pipeline

### rendering-backend-heterogeneity

1. **Backends in use**: Canvas2D, WebGL, SVG, or multiple?
2. **Export requirement**: Must export match interactive render exactly?
3. **Fallback needs**: What happens if WebGL context is lost or unavailable?
4. **Feature disparity**: Do some features only work in one backend?

### state-to-render-bridge

1. **State layer**: CRDT, OT, Redux, or custom?
2. **Render framework**: React, imperative Canvas, WebGL scene graph?
3. **Update granularity**: Full re-render, dirty-rect, or incremental?
4. **Decoration layer**: Non-state visual elements (selection, hover, cursors)?

## Cross-Cluster Compound Questions

When 2+ force clusters are active, ask these additional questions:

### distributed-state-sync + undo-under-distributed-state
- "When User A undoes, should it undo only their changes or the last change regardless of author?"
- "If User B's edit arrives while User A is mid-undo, what happens?"

### distributed-state-sync + constraint-graph-under-mutation
- "Do binding updates need to sync atomically with the objects they connect?"
- "Can a binding reference an object that another client just deleted?"

### gesture-disambiguation + interactive-spatial-editing
- "Does the active tool change how gestures are interpreted (e.g., draw mode vs select mode)?"
- "Can the user switch tools mid-gesture?"

### optimistic-ui-vs-data-consistency + distributed-state-sync
- "If sync is slow, should the user see stale data or optimistic data that might roll back?"
- "How do you handle the gap between local mutation and confirmed sync?"

---

## Worked Examples

### Example 1: Whiteboard app with Yjs and Canvas 2D

**Intake signals**: Multiple clients sharing state, spatial canvas with tools, undo in collaborative context, shapes with relationships.

**Active force clusters**: distributed-state-sync, interactive-spatial-editing, undo-under-distributed-state, constraint-graph-under-mutation, gesture-disambiguation.

**Key diagnostic answers**:
- Collaboration: P2P via Yjs → CRDT patterns
- Tools: 8 tools with sub-modes → hierarchical state machine
- Undo: Local-only undo → Yjs UndoManager with scope tracking
- Bindings: Arrows to shapes, 1-hop → direct reference with undo capture
- Gestures: Draw/select/pan conflict → state machine arbitration per tool

**Recommendations**: Load distributed-state-sync (mutation-sync, element-ordering), interactive-spatial-editing (interaction-modes, selection), undo-under-distributed-state (undo-redo, multiplayer-undo-scope), constraint-graph-under-mutation (binding-propagation), gesture-disambiguation (state-machine-patterns). Check cross-domain-map for all interaction pairs.

### Example 2: Offline-first React app with optimistic updates

**Intake signals**: Optimistic updates with server sync, offline requirement.

**Active force clusters**: optimistic-ui-vs-data-consistency, distributed-state-sync.

**Key diagnostic answers**:
- Latency: 200ms-2s, variable → need explicit sync states
- Conflicts: Occasional → rebase-on-commit
- Offline: Up to hours → CRDT or queue-based sync
- Rollback: Silent correction preferred → dual source of truth

**Recommendations**: Load optimistic-ui-vs-data-consistency (sync-lifecycle-states, rollback-strategies), distributed-state-sync (persistence, mutation-sync). Cross-domain interaction: optimistic display depends on sync conflict resolution strategy.

### Example 3: Diagram tool choosing between Canvas 2D and WebGL

**Intake signals**: Multiple rendering backends, 10K+ shapes.

**Active force clusters**: rendering-backend-heterogeneity, interactive-spatial-editing (for shape count).

**Key diagnostic answers**:
- Backends: Canvas2D primary, WebGL for performance, SVG for export
- Export: Must match exactly → renderer abstraction pattern
- Fallback: WebGL context loss → Canvas2D fallback required
- Features: Blur/shadow effects WebGL-only → feature detection layer

**Recommendations**: Load rendering-backend-heterogeneity (renderer-abstraction-patterns, fallback-and-feature-detection). For 10K+ shapes, also load interactive-spatial-editing (rendering-performance) for spatial indexing.
