# Enrichment Roadmap

Generated: 2026-03-17. Last updated: 2026-03-21 (enrichment, absorb execution, off-thread-compute promotion, deferred evaluation).

---

## 1. Codebook Health Scores

Scored against 7 eval criteria from quality-criteria.md. Score = count of criteria likely met based on structural audit (reference file count, tier, repo count). Detailed content audit required for precise grading.

| Codebook | Tier | Repos | Ref Files | Quality Score (0-7) | Priority |
|----------|------|-------|-----------|---------------------|----------|
| distributed-state-sync | 1 | 7 | 4 | 6 | Low |
| interactive-spatial-editing | 1 | 5 | 4 | 6 | Low |
| gesture-disambiguation | 1 | 5 | 3 | 5 | Medium |
| rendering-backend-heterogeneity | 1 | 6 | 4 | 6 | Low |
| undo-under-distributed-state | 2 | 4 | 2 | 5 | Medium |
| constraint-graph-under-mutation | 2 | 4 | 2 | 5 | Medium |
| optimistic-ui-vs-data-consistency | 2 | 3 | 3 | 5 | Medium |
| state-to-render-bridge | 2 | 4 | 2 | 5 | Medium |
| virtualization-vs-interaction-fidelity | 2 | 3 | 3 | 5 | Medium |
| media-pipeline-adaptation | 2 | 4 | 4 | 5 | Low |
| platform-adaptation-under-code-unity | 2 | 6 | 2 | 4 | Medium |
| hierarchical-resource-composition | 2 | 3 | 2 | 5 | Medium |
| embeddability-and-api-surface | 2 | 5 | 2 | 4 | Medium |
| crdt-structural-integrity | 3 | 3 | 2 | 4 | Medium |
| schema-evolution-under-distributed-persistence | 3 | 2 | 2 | 4 | Low |
| spec-conformance-under-creative-editing | 3 | 2 | 2 | 4 | Low |
| focus-management-across-boundaries | 3 | 3 | 4 | 5 | Low |
| input-device-adaptation | 3 | 4 | 4 | 5 | Low |
| text-editing-mode-isolation | 3 | 4 | 3 | 5 | Low |
| annotation-state-advisor | composite | 5+ | 5 | 6 | Low |
| off-thread-compute-coordination | 2 | 5 | 2 | 5 | Low |

## 2. Thin Areas

Specific gaps per codebook requiring enrichment.

### Resolved (2026-03-21): Previously Critical — Zero Reference Files
- **focus-management-across-boundaries**: Enriched with 3 reference files from VS Code (roving-tabindex, cross-panel-delegation, shadow-dom-piercing). Now 4 refs total. Sources: VS Code ActionBar, ViewPaneContainer, dom.ts shadow utilities. One contradiction documented (querySelectorAll vs shadow DOM piercing).
- **input-device-adaptation**: Enriched with 3 reference files from Krita + tldraw (pressure-tilt-pipeline, pointer-event-normalization, input-profile-configuration). Now 4 refs total. Sources: Krita KisPaintingInformationBuilder/KisInputManager/KisShortcutConfiguration, tldraw InputsManager, drafft-ink.
- **text-editing-mode-isolation**: Enriched with 2 reference files from ProseMirror + tldraw + Excalidraw (ime-composition-guards, focus-handoff-and-shortcut-isolation). Now 3 refs total. Sources: ProseMirror input.ts/domobserver.ts, tldraw EditingShape.ts/dom.ts, Excalidraw textWysiwyg.tsx.

### Resolved (2026-03-21): Previously High — Tier 1 Codebooks with Few References
- **rendering-backend-heterogeneity**: Absorbed gpu-context-lifecycle (4 patterns from Krita/Penpot) and export-render-divergence (4 patterns from Excalidraw/tldraw/Penpot). Now 4 refs total. SKILL.md updated with new axes.

### Remaining High
- **gesture-disambiguation**: 3 refs, but overlay-event-interception may overlap with state-machine-patterns. Verify orthogonality.

### Resolved (2026-03-21): Previously High — Media Pipeline Absorb
- **media-pipeline-adaptation**: Absorbed ml-inference-pipeline (4 patterns from Immich/Memories) and async-job-orchestration (4 patterns from Immich/Memories). Now 4 refs total. SKILL.md updated with new triggers and axes.

### Medium: Missing Axes
- **distributed-state-sync**: element-ordering axis has only 2 competing patterns (fractional indexing vs integer). Consider: lexicographic ordering (Figma), hybrid approaches.
- **platform-adaptation-under-code-unity**: 6 repos but only 2 refs. Missing: FFI bridge lifecycle, WASM-native interop patterns.
- **embeddability-and-api-surface**: 5 repos but only 2 refs. Missing: plugin sandboxing patterns, SDK versioning.

## 3. Deferred Candidate Status

From cross-domain-map.md Section 3. Evaluated 2026-03-21.

| Candidate | Repos | Decision | Target | Rationale |
|-----------|-------|----------|--------|-----------|
| export-fidelity-under-rendering-divergence | 4 | **Absorbed** | rendering-backend-heterogeneity | DONE 2026-03-21. 4 patterns added (dual static, SVG-as-IR, parallel pipeline, isExporting flag). |
| gpu-context-lifecycle | 2 | **Absorbed** | rendering-backend-heterogeneity | DONE 2026-03-21. 4 patterns added (RAII lock, pixel capture, fence sync, guard-and-init FSM). |
| off-thread-compute-coordination | 5 | **Promoted** | New Tier 2 codebook | DONE 2026-03-21. Confirmed via Sharp/libvips. 2 refs, 8 patterns, router updated. |
| async-job-graph-orchestration | 3 | **Absorbed (media)** | media-pipeline-adaptation | DONE 2026-03-21. 4 patterns added (event-driven DAG, time-bounded cron, queue lifecycle, backend registry). Budibase evidence remains with low-code-runtime candidate. |
| ml-inference-lifecycle | 2 | **Absorbed** | media-pipeline-adaptation | DONE 2026-03-21. 4 patterns added (TTL-cached model, delegated ML, multi-runtime session, dependency-aware batching). |
| document-permission-granularity | 2 | **Remain deferred** | — | Both repos (recogito2, iiif-manifest-editor) are IIIF tools — same narrow domain, no cross-domain validation. |
| low-code-runtime-definition-duality | 1 | **Remain deferred** | — | Only Budibase. Needs Retool/Appsmith/Tooljet. |
| multi-datasource-abstraction | 1 | **Remain deferred** | — | Only Budibase. Needs Metabase/Grafana. |
| encryption-boundary-under-feature-pressure | 1 | **Remain deferred** | — | Only ente. Needs Matrix SDK/Signal/Proton Mail clients. |

## 4. Repo Scouting Recommendations

Repos tagged by which codebooks they'd enrich.

### For Tier 1 Expansion

| Repo | Would Enrich | Rationale |
|------|-------------|-----------|
| Figma (developer docs/plugins) | rendering-backend-heterogeneity | WebGL + Canvas2D + export pipeline, GPU context management |
| Konva.js | rendering-backend-heterogeneity, gesture-disambiguation | Multi-backend canvas lib with hit-testing and event delegation |
| Leaflet / MapLibre | gesture-disambiguation, virtualization-vs-interaction-fidelity | Map gesture handling, tile-based virtualization |

### For Deferred Candidate Confirmation

| Repo | Would Confirm | Rationale |
|------|--------------|-----------|
| Retool / Appsmith | low-code-runtime-definition-duality | Builder vs runtime tension, datasource abstraction |
| Grafana | multi-datasource-abstraction | Canonical multi-datasource dashboard |
| Element (Matrix) | encryption-boundary-under-feature-pressure | E2E encryption with rich features |

### Selection Criteria Applied
- All open-source with readable architecture
- Must exhibit force-cluster tension (not just use the technology)
- Architectural patterns visible in source (not hidden behind framework)
- 1K+ stars and active maintenance preferred
- Different tech stacks from existing evidence (diversity)
- Disqualified: thin wrappers, CRUD apps, tutorial/demo repos

## 5. Enrichment Priorities

Ordered list of recommended next actions (updated 2026-03-21).

1. ~~**[Critical]** Extract reference files for focus-management-across-boundaries~~ DONE (3 refs added from VS Code)
2. ~~**[Critical]** Extract reference files for input-device-adaptation~~ DONE (3 refs added from Krita + tldraw)
3. ~~**[Critical]** Extract reference files for text-editing-mode-isolation~~ DONE (2 refs added from ProseMirror + tldraw + Excalidraw)
4. ~~**[High]** Expand rendering-backend-heterogeneity~~ DONE (gpu-context-lifecycle + export-render-divergence absorbed, 2 refs added)
5. ~~**[High]** Evaluate deferred candidates~~ DONE (see Section 3 — 5 absorbed/promoted, 4 remain deferred)
6. ~~**[High]** Execute absorb: ml-inference + async-job-graph into media-pipeline-adaptation~~ DONE (2 refs added)
7. ~~**[Medium]** Confirm off-thread-compute-coordination~~ DONE (promoted to Tier 2, confirmed via Sharp/libvips)
8. **[Medium]** Add FFI bridge lifecycle and WASM-native interop to platform-adaptation-under-code-unity
9. **[Medium]** Add plugin sandboxing and SDK versioning to embeddability-and-api-surface
10. **[Medium]** Verify gesture-disambiguation reference orthogonality
11. **[Low]** Add sources/ directories to codebooks with deep extraction evidence
12. **[Low]** Create eval sets for codebooks missing them

### Gap Log (from pattern-advisor usage)

_Empty — pattern-advisor not yet deployed. Gaps will accumulate here as the advisor surfaces thin areas during real project consultations._
