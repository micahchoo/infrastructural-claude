# Cross-Domain Pattern Map

Tracks which **force-cluster codebooks** recur across codebases and how they interact. Grows with each new codebook.

Source: 18 repos across 3 gap-analysis batches + 5 extraction loops. 20 codebooks total.

---

## 1. Codebook Universality Tiers (20 codebooks, 18 repos)

Every codebook is organized around a force cluster — a constellation of tensions that recur together. Tiers reflect how broadly each codebook applies.

### Tier 1: High universality (5+ repos)

| Codebook | Metadomain | Repos | Count |
|----------|------------|-------|-------|
| distributed-state-sync | State/Architecture | tldraw, excalidraw, yjs, penpot, Immich, Budibase, IIIF | 7 |
| interactive-spatial-editing | Interaction/UX | tldraw, excalidraw, penpot, yjs, IIIF | 5 |
| gesture-disambiguation | Interaction/UX | tldraw, excalidraw, penpot, krita, drafft-ink | 5 |
| rendering-backend-heterogeneity | Rendering Pipeline | tldraw, excalidraw, penpot, krita, drafft-ink, openseadragon | 6 |
| state-to-render-bridge | Rendering Pipeline | allmaps, weavejs, upwelling, iiif-manifest-editor, svelte-maplibre-gl, penpot | 6 |

### Tier 2: Cross-domain (3-4 repos)

| Codebook | Metadomain | Repos | Count |
|----------|------------|-------|-------|
| undo-under-distributed-state | State/Architecture | tldraw, excalidraw, penpot, yjs | 4 |
| constraint-graph-under-mutation | State/Architecture | tldraw, excalidraw, penpot, Budibase | 4 |
| optimistic-ui-vs-data-consistency | Interaction/UX | allmaps, penpot, weavejs | 3 |
| virtualization-vs-interaction-fidelity | Interaction/UX | penpot, Immich, openseadragon | 3 |
| media-pipeline-adaptation | Media Processing | Immich, ente, memories, neko | 4 |
| platform-adaptation-under-code-unity | Platform/Native Bridge | drafft-ink, krita, tldraw, ente, neko, memories | 6 |
| hierarchical-resource-composition | State/Architecture | tldraw, krita, penpot | 3 |
| embeddability-and-api-surface | State/Architecture | tldraw, excalidraw, yjs, memories, weavejs | 5 |

### Tier 3: Domain-specific (1-2 repos)

| Codebook | Metadomain | Repos | Count |
|----------|------------|-------|-------|
| crdt-structural-integrity | State/Architecture | yjs, upwelling-code, drafft-ink | 3 |
| schema-evolution-under-distributed-persistence | State/Architecture | tldraw, yjs | 2 |
| spec-conformance-under-creative-editing | State/Architecture | IIIF, allmaps | 2 |
| focus-management-across-boundaries | Interaction/UX | memories, weavejs | 2 |
| input-device-adaptation | Interaction/UX | krita, neko | 2 |
| text-editing-mode-isolation | Interaction/UX | tldraw, excalidraw | 2 |

### Composite

| Codebook | Metadomain | Combines |
|----------|------------|----------|
| annotation-state-advisor | Composite | distributed-state-sync + interactive-spatial-editing + constraint-graph + spec-conformance + annotation-specific concerns |

**Recognition prompt**: When you encounter a codebase, ask: *which force clusters are active here?* Tier 1 codebooks are likely present in any interactive or distributed system. Tier 2-3 depend on domain.

## 2. Tagged Interaction Pairs

Where codebooks co-activate, their interactions create **compound spaghetti**. Stored as tagged pairs — filter by any codebook name to find its interactions.

### Architectural x Architectural
```
distributed-state-sync ↔ undo-under-distributed-state:
  Undo fights sync — local undo must not revert remote operations
  Evidence: tldraw (mark-based undo), excalidraw (appState undo separation)

distributed-state-sync ↔ constraint-graph-under-mutation:
  Binding propagation must sync across clients without divergence
  Evidence: tldraw (binding changes as atomic side-effects), penpot (component propagation)

distributed-state-sync ↔ schema-evolution-under-distributed-persistence:
  Migrations must not break live sync between different-version clients
  Evidence: tldraw (bidirectional migrations), yjs (cross-version sync)

distributed-state-sync ↔ embeddability-and-api-surface:
  Sync layer owned by host app constrains embedded editor's data flow
  Evidence: yjs (provider injection), weavejs (SDK sync delegation)

distributed-state-sync ↔ crdt-structural-integrity:
  Sync relies on CRDT convergence guarantees; GC/compaction affects sync correctness
  Evidence: yjs (GC breaks undo references), upwelling (Automerge compaction)

distributed-state-sync ↔ hierarchical-resource-composition:
  Tree operations (reparenting, reordering) must converge across clients
  Evidence: tldraw (page/frame operations), penpot (layer sync)

undo-under-distributed-state ↔ constraint-graph-under-mutation:
  Undo must capture propagated side-effects from constraint resolution
  Evidence: tldraw (binding undo captures arrow+shape), excalidraw (container resize undo)

undo-under-distributed-state ↔ crdt-structural-integrity:
  Compacted/GC'd items break undo stack references
  Evidence: yjs (tombstone GC invalidates undo), upwelling (Automerge history pruning)

undo-under-distributed-state ↔ hierarchical-resource-composition:
  Undo must restore parent-child relationships atomically
  Evidence: tldraw (frame undo restores containment), penpot (group undo)

constraint-graph-under-mutation ↔ schema-evolution-under-distributed-persistence:
  Binding schemas may change across versions
  Evidence: tldraw (binding type evolution across migrations)

constraint-graph-under-mutation ↔ hierarchical-resource-composition:
  Bindings span tree levels (frame containment, group membership)
  Evidence: tldraw (frame bindings), penpot (component tree bindings)

crdt-structural-integrity ↔ hierarchical-resource-composition:
  Nested CRDT types in tree structures create convergence edge cases
  Evidence: yjs (nested Y.Map in Y.Array), drafft-ink (tree CRDT composition)

schema-evolution-under-distributed-persistence ↔ embeddability-and-api-surface:
  API versioning interacts with schema versioning — host may pin old version
  Evidence: tldraw (store schema version in SDK exports)
```

### Architectural x UX
```
gesture-disambiguation ↔ interactive-spatial-editing:
  Gesture layer IS the spatial editing entry point; share tool state machines
  Evidence: tldraw (StateNode hierarchy), excalidraw (inline dispatch)

optimistic-ui-vs-data-consistency ↔ distributed-state-sync:
  Optimistic display depends on sync conflict resolution strategy
  Evidence: allmaps (TerraDraw vs ShareDB), penpot (rebase-on-commit)

virtualization-vs-interaction-fidelity ↔ hierarchical-resource-composition:
  Virtual rendering of tree structures (layers, groups)
  Evidence: penpot (layer panel), Immich (album hierarchy)

focus-management-across-boundaries ↔ embeddability-and-api-surface:
  Embedded editors negotiate focus with host application
  Evidence: memories (Nextcloud iframe), weavejs (SDK embedding)

interactive-spatial-editing ↔ undo-under-distributed-state:
  Undo must restore selection state and tool mode, not just data
  Evidence: tldraw (selection in undo marks), excalidraw (appState undo)

interactive-spatial-editing ↔ constraint-graph-under-mutation:
  Bindings affect hit-testing and selection behavior
  Evidence: tldraw (arrow binding hit areas), penpot (component selection)

interactive-spatial-editing ↔ embeddability-and-api-surface:
  Tool state crosses API boundary when editor is embedded
  Evidence: tldraw (SDK tool control), excalidraw (controlled mode)
```

### Rendering x Architectural
```
rendering-backend-heterogeneity ↔ distributed-state-sync:
  Different clients may use different renderers but must display consistent state
  Evidence: penpot (SVG→WASM transition), openseadragon (WebGL→Canvas fallback)

rendering-backend-heterogeneity ↔ state-to-render-bridge:
  Renderer determines bridge output format — bridge must abstract over backend
  Evidence: tldraw (Canvas2D vs SVG export paths), krita (OpenGL vs software bridge)

rendering-backend-heterogeneity ↔ platform-adaptation-under-code-unity:
  Platform determines available renderers
  Evidence: drafft-ink (wgpu on native, WebGL on WASM), krita (OpenGL driver workarounds)

state-to-render-bridge ↔ distributed-state-sync:
  CRDT/OT state changes must be reconciled with imperative render APIs
  Evidence: allmaps (ShareDB→Konva), upwelling (Automerge→ProseMirror)

state-to-render-bridge ↔ optimistic-ui-vs-data-consistency:
  Render bridge introduces latency between mutation and display update
  Evidence: weavejs (Konva reconciliation lag), upwelling (ProseMirror decoration rebuild)

spec-conformance-under-creative-editing ↔ rendering-backend-heterogeneity:
  Export must conform to spec even though interactive render differs
  Evidence: tldraw (SVG export vs canvas render), allmaps (W3C annotation export)
```

### Rendering x UX
```
rendering-backend-heterogeneity ↔ gesture-disambiguation:
  Hit-testing must work across renderer backends
  Evidence: penpot (async WASM worker hit-test during pointer events)

media-pipeline-adaptation ↔ virtualization-vs-interaction-fidelity:
  Progressive loading feeds virtualization — thumbnail tiers match viewport resolution
  Evidence: Immich (multi-tier thumbnails in virtual scroll), openseadragon (tile loading)
```

### Platform x Everything
```
platform-adaptation-under-code-unity ↔ input-device-adaptation:
  Platform determines available input devices and APIs
  Evidence: krita (tablet APIs per OS), neko (keyboard lock API availability)

platform-adaptation-under-code-unity ↔ media-pipeline-adaptation:
  Native binary orchestration — platform determines codec/hardware availability
  Evidence: ente (Rust/WASM + Dart FFI), memories (PHP/exec for ffmpeg), neko (CGo for encoders)
```

**Usage**: When analyzing a codebase, grep this list for active codebooks. Dense nodes (many pairs) indicate compound spaghetti zones. A codebook should address every pair in which it appears.

## 3. Deferred Candidates (observed but not yet promoted to codebooks)

Tensions observed in extraction but not yet meeting the 2-repo threshold for codebook creation, or too narrow for independent codebook status.

| Candidate | Source repos | Count | Status | Decision |
|-----------|-------------|-------|--------|----------|
| export-fidelity-under-rendering-divergence | tldraw, excalidraw, penpot, krita | 4 | **Absorb** | Into rendering-backend-heterogeneity as export-vs-interactive axis. Not an independent force cluster — it's the same renderer abstraction tension applied to export pipelines. |
| gpu-context-lifecycle | krita, penpot | 2 | **Absorb** | Into rendering-backend-heterogeneity's fallback-and-feature-detection ref. GPU context loss is a specific failure mode within renderer heterogeneity, not a separate tension. |
| off-thread-compute-coordination | penpot, krita, allmaps, recogito2 | 4 | **Defer** | Genuine independent tension (main thread responsiveness vs compute correctness vs message passing overhead). But 4 repos across very different domains (canvas rendering, map tiling, text annotation) — need to verify the tension constellation is consistent, not 4 different problems sharing a surface symptom. Revisit after studying one more repo with explicit worker architecture. |
| async-job-graph-orchestration | Immich, Budibase, memories | 3 | **Absorb** | Into media-pipeline-adaptation for media contexts. The Budibase case (automation jobs) is different enough that it doesn't share the same force cluster — it's workflow orchestration, not media pipeline. The media cases (Immich, memories) are already covered by progressive-pipeline-patterns. |
| ml-inference-lifecycle | Immich, memories | 2 | **Defer** | Meets threshold but very narrow. Model loading/caching/fallback is a real tension but may be better addressed as a section within media-pipeline-adaptation rather than an independent codebook. Revisit when a 3rd repo with distinct ML inference patterns is studied. |
| encryption-boundary-under-feature-pressure | ente | 1 | **Defer** | Only 1 repo. Genuine tension but needs Matrix/Signal/Proton study to confirm the pattern constellation is consistent. |
| document-permission-granularity | recogito2, iiif-manifest-editor | 2 | **Defer** | Meets threshold but very narrow. Permission models are highly application-specific — unclear if the tension constellation transfers. Needs study of a collaborative editor with a fundamentally different permission model to confirm. |
| low-code-runtime-definition-duality | Budibase | 1 | **Defer** | Only 1 repo. Different domain from current codebook focus. Needs Retool/Appsmith study. |
| multi-datasource-abstraction | Budibase | 1 | **Defer** | Only 1 repo. Needs Metabase/Grafana study. |
| sync-transport-and-topology | weavejs, upwelling, iiif-manifest-editor | 3 | **Absorbed** | Into distributed-state-sync. |

**Previously promoted**: crdt-structural-integrity (Loop 4, 3 repos), hierarchical-resource-composition (Loop 4, 2 repos), spec-conformance-under-creative-editing (Loop 5, 2 repos), rendering-backend-heterogeneity (Loop 6, 6 repos), state-to-render-bridge (Loop 6, 4 repos), platform-adaptation-under-code-unity (Loop 6, 6 repos), media-pipeline-adaptation (Loop 6, 4 repos).

**Absorbed (Lifecycle audit, 2026-03-17)**: export-fidelity → rendering-backend-heterogeneity, gpu-context-lifecycle → rendering-backend-heterogeneity, async-job-graph → media-pipeline-adaptation.

**Promotion rule**: When a candidate is observed in a 2nd repo with the same tension constellation, promote it to the universality tiers and create a codebook stub.

---

## Using This Map

**During extraction (Stage 3)**: When you label a seam, check which codebook it belongs to. Look up that codebook's interaction pairs to understand compound spaghetti zones.

**During assembly (Stage 5)**: Update this file — add new codebooks to the tier table, new interaction pairs, or new deferred candidates.

**For cross-domain recognition**: When two repos share the same active interaction pairs, their codebooks likely share structural insights. Start extraction from the existing codebook's seam inventory.

**For codebook reuse**: Filter Section 2 by a codebook name to find all its interactions. Dense nodes (many pairs) indicate the hardest architectural problems.
