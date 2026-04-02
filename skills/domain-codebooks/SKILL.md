---
name: domain-codebooks
description: >-
  Architectural and UX pattern codebooks for systems with competing design forces.
  Covers 24 domains: distributed state/sync, spatial editing, undo/redo, gesture disambiguation,
  focus management, virtualization, optimistic UI/rollback, input devices, text editing, constraint solving,
  schema evolution/migration, embeddability, CRDTs, hierarchical composition, spec conformance,
  rendering pipelines, platform adaptation, media pipelines, annotation systems, node graph
  evaluation, message dispatch, graph-as-document models, off-thread compute, and interactive
  spatial editing.
  SYMPTOM TRIGGERS — use when the user describes: undo breaks or undo shortcut conflicts,
  sync conflicts or broken bindings during collab, gesture handlers fighting or pointer event
  conflicts, focus escapes or keyboard shortcut scoping, scroll jank or virtualization of large
  lists, drag-drop targeting errors, z-ordering or layering bugs, bounding box or hit-testing
  issues, GPU memory or texture reuse, node graph evaluation order, annotation data flow,
  event bus or message dispatch wiring, schema migration for saved formats, cursor position in
  rich text, constraint solving for snap-to-grid or alignment, platform-specific keyboard
  shortcuts, race conditions in state, embedding an editor as a component, render pipeline
  conversion, off-thread compute coordination, CRDT merge strategy.
  ACTION TRIGGERS — use when the user asks: "how should we architect", "which pattern for",
  "how should I structure", "design the", "what's the right approach for".
  BROWNFIELD TRIGGERS — use when the user reports: "keeps breaking", "race condition in",
  "state gets out of sync", "not working during collaboration", "broken after concurrent edit".
  Also fires alongside brainstorming, writing-plans, and systematic-debugging when domain
  forces are detected.
  Do NOT trigger for: general code questions, pure CSS/styling (use userinterface-wiki),
  code review, or domains without a codebook (route to pattern-extraction-pipeline).
---

# Domain Codebooks

Pattern libraries organized by **force clusters** — groups of competing forces that produce
spaghetti code when unresolved. Codebooks are faceted (combinable), not hierarchical.

Before loading codebooks: `ml search "<force-cluster>"` for prior architectural decisions (if `.mulch/` exists).

## Codebook Index

| Keywords | Codebook | Path |
|----------|----------|------|
| CRDT, sync, conflict, consistency, LWW, OT | distributed-state-sync | `references/distributed-state-sync/` |
| canvas, selection, hit-test, snapping, mode FSM | interactive-spatial-editing | `references/interactive-spatial-editing/` |
| undo, redo, history, command pattern | undo-under-distributed-state | `references/undo-under-distributed-state/` |
| binding, constraint, arrow, container, cascade | constraint-graph-under-mutation | `references/constraint-graph-under-mutation/` |
| migration, schema, versioning, backward compat | schema-evolution-under-distributed-persistence | `references/schema-evolution-under-distributed-persistence/` |
| embed, SDK, API surface, plugin sandbox | embeddability-and-api-surface | `references/embeddability-and-api-surface/` |
| tombstone, GC, compaction, CRDT internals | crdt-structural-integrity | `references/crdt-structural-integrity/` |
| layer, group, frame, reparent, z-order | hierarchical-resource-composition | `references/hierarchical-resource-composition/` |
| W3C, IIIF, GeoJSON, SVG, spec fidelity | spec-conformance-under-creative-editing | `references/spec-conformance-under-creative-editing/` |
| drag, scroll, pan, gesture, pointer, touch | gesture-disambiguation | `references/gesture-disambiguation/` |
| optimistic, rollback, stale, dual source | optimistic-ui-vs-data-consistency | `references/optimistic-ui-vs-data-consistency/` |
| virtual scroll, viewport, DOM recycling | virtualization-vs-interaction-fidelity | `references/virtualization-vs-interaction-fidelity/` |
| focus trap, tabindex, keyboard nav, shadow DOM | focus-management-across-boundaries | `references/focus-management-across-boundaries/` |
| pen, touch, mouse, pressure, stylus | input-device-adaptation | `references/input-device-adaptation/` |
| IME, inline edit, text input, canvas text | text-editing-mode-isolation | `references/text-editing-mode-isolation/` |
| WebGL, Canvas2D, SVG, renderer, GPU fallback | rendering-backend-heterogeneity | `references/rendering-backend-heterogeneity/` |
| CRDT→render, reconciler, state bridge | state-to-render-bridge | `references/state-to-render-bridge/` |
| cross-platform, FFI, native bridge, conditional | platform-adaptation-under-code-unity | `references/platform-adaptation-under-code-unity/` |
| thumbnail, transcode, codec, media pipeline | media-pipeline-adaptation | `references/media-pipeline-adaptation/` |
| node graph, evaluation, lazy, incremental, caching, dirty propagation, compiler | node-graph-evaluation-under-interactive-editing | `references/node-graph-evaluation-under-interactive-editing/` |
| message dispatch, command pattern, dedup, batching, handler context, editor commands | message-dispatch-in-stateful-editors | `references/message-dispatch-in-stateful-editors/` |
| graph document, layer facade, node registry, transaction, nondestructive, graph undo | graph-as-document-model | `references/graph-as-document-model/` |
| worker thread, Web Worker, thread pool, off-thread, concurrency, parallelism, determinism | off-thread-compute-coordination | `references/off-thread-compute-coordination/` |
| **annotation system** (composite) | annotation-state-advisor | `references/annotation-state-advisor/` |

## Routing

1. **Match keywords** from the user's problem to the index above
2. **Indexed lookup**: `get_docs("domain-codebooks", "<matched keywords>")` — 2-4 keywords from the matched row. Sufficient for routing, pattern lookup, and quick recommendations.
3. **Reference implementations**: `search_references("<force-cluster>")` to ground advice in real code, not just theory.
4. **Full codebook Read** (fallback): Only when indexed lookup returns thin results or you need the complete reference for in-depth multi-pattern advising.
5. **Multiple matches?** Load all matching codebooks. The hardest bugs live at force-cluster intersections.
6. **Annotation/canvas/map editor?** Load `annotation-state-advisor/` — it's a composite that routes to sub-codebooks internally.
7. **No codebook matches?** Route to `pattern-extraction-pipeline` to create one.
   Record gaps: `~/.claude/scripts/codebook-gap.sh record "Force: X vs Y vs Z" "Leads: [repos/files seen]. Context: [what you were doing]"`
8. **API compatibility**: For fast-moving libs (React, Next.js, Svelte), verify patterns via `get_docs("<lib>", "<api name>")` before recommending.

## Diffusion Protocol

When co-loading alongside brainstorming, writing-plans, or systematic-debugging:
- Load silently — don't announce "loading a codebook"
- Integrate into the active skill's output, don't replace it
- Cite source: "Per [codebook]: ..."
- If the codebook is thin, caveat: "limited evidence, validate against your codebase"

## Quality Caveat

Check codebook completeness before advising. If a codebook has no reference files and few inline patterns, warn the user — thin guidance is better than none, but fabricated patterns erode trust. Verify recommendations against `get_docs` or reference code rather than training data alone; if the codebook is thin for this scenario, say so.

## Cross-References

- **pattern-advisor**: For project-specific recommendations (not browsing/learning) — the "consulting" layer on top of this "library"
- **pattern-extraction-pipeline**: When no codebook matches and the domain has competing forces — create a new one. For the de-factoring protocol (remove pattern, feel pain, validate forces), load `pattern-extraction-pipeline/references/forces-analysis-guide.md`.
- **quality-linter**: Force clusters from QA assessment feed codebook selection (check `.mulch/assessments/qa-assessment.md`)

`[eval: approach]` Pattern recommendations reference actual codebase interfaces, not abstract examples.
`[eval: completeness]` All force clusters matching the user's problem were identified and loaded.
`[eval: depth]` Cross-codebook interactions checked when 2+ codebooks loaded.
`[eval: target]` Correct codebook matched — not a generic code question routed through codebooks.
