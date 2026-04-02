---
name: pattern-advisor
description: >-
  Produce concrete architectural recommendations for a specific project by loading
  domain codebooks and running diagnostic intake. Triggers on specific project
  decisions: "which pattern for X in my project", "advise on my architecture",
  "recommend an approach given my constraints", "evaluate my architecture".
  Also brownfield: "pattern X isn't working", "stuck between two approaches",
  "we chose X — was that right?".
  Distinguishing test: Is the user making a SPECIFIC architectural
  decision for THEIR project? If yes, use this. Browsing/learning?
  Use domain-codebooks.
  Do NOT trigger for: implementation planning ("plan the implementation of X"),
  open-ended brainstorming without project constraints, debugging specific errors,
  or general pattern education without a project context.
---

# Pattern Advisor

Produces project-specific architectural recommendations by combining diagnostic
intake with domain codebook knowledge. This is the "consulting" layer on top of
the codebook "library."

If `.mulch/` exists: `mulch prime` at start, `mulch record` pattern selections at end.

## Workflow

### Step 1: Intake — Identify Active Force Clusters

Ask the user to describe their system. Then identify which force clusters are active
by checking for these signals:

| Signal | Force Cluster |
|--------|---------------|
| Multiple clients sharing state | distributed-state-sync |
| Spatial canvas/editor with tools | interactive-spatial-editing |
| Undo/redo in collaborative context | undo-under-distributed-state |
| Shapes/objects with relationships | constraint-graph-under-mutation |
| Data format versioning with live clients | schema-evolution-under-distributed-persistence |
| Library/SDK/embedded editor | embeddability-and-api-surface |
| CRDT-based state layer | crdt-structural-integrity |
| Tree/hierarchy of objects | hierarchical-resource-composition |
| Editing content in a standard format | spec-conformance-under-creative-editing |
| Multiple gesture types competing | gesture-disambiguation |
| Optimistic updates with server sync | optimistic-ui-vs-data-consistency |
| Large lists/grids with interaction | virtualization-vs-interaction-fidelity |
| Complex keyboard nav / focus zones | focus-management-across-boundaries |
| Pen/touch/mouse input | input-device-adaptation |
| Text editing inside canvas | text-editing-mode-isolation |
| Multiple rendering backends | rendering-backend-heterogeneity |
| CRDT/OT state driving render | state-to-render-bridge |
| Cross-platform with native bridges | platform-adaptation-under-code-unity |
| Media processing pipeline | media-pipeline-adaptation |

### Step 2: Diagnostic Questions

For multi-frame diagnostic lenses (origami/watershed/stratigraphy/knot/pruning/lock-picking), load `codebase-diagnostics/references/diagnostic-frames.md`.

For each active force cluster, ask 3-5 diagnostic questions from
`references/diagnostic-framework.md`. These questions are project-specific —
the answers select the right pattern from the codebook's competing patterns.

Ask all diagnostic questions in a single batch (don't drip-feed). Group by
force cluster. Mark optional questions with "(if applicable)".

### Step 2b: Discovery

Before loading codebooks, foxhound `search_references` for how reference projects solved these force clusters. If `.mulch/` exists, `search` with `project_root` for prior pattern decisions.

`bias:reframe` — Before recommending, articulate the strongest counter-argument to the pattern you're leaning toward. If you can't find one, you haven't explored alternatives enough. `[NO_COUNTER: searched X, Y, Z — confidence: high]` if genuinely none.

### Step 3: Load Codebooks

1. **Load codebooks**: `get_docs("domain-codebooks", "<force-cluster>")` — 2-4 keywords per query.
   For the de-factoring protocol and Kerievsky Test (real forces vs over-engineering), load `pattern-extraction-pipeline/references/forces-analysis-guide.md`.
2. **Verify API compatibility**: `get_docs("<lib>", "<api>")` — patterns citing deprecated APIs erode trust. `bias:overconfidence` — training data may reference renamed APIs; confirm via indexed docs.
3. **Cross-cluster interactions**: `get_docs("domain-codebooks", "cross-domain interaction pairs")`. `bias:availability` — if recommendations come from a narrow set, check at least one codebook outside the obvious match.
4. If 2+ force clusters are active, query for compound zones: `get_docs("domain-codebooks", "<cluster-a> <cluster-b> compound")`

### Step 4: Recommend

For each active force cluster, produce:

1. **Selected pattern** — which competing pattern fits this project
2. **Rationale** — why, tied to the diagnostic answers ("Because your sync is
   server-authoritative and you need offline support, Pattern C fits better than
   Pattern A which assumes always-online")
3. **Accepted tradeoffs** — what the user gives up with this choice
4. **Anti-patterns to avoid** — specific pitfalls from the codebook
5. **Cross-cluster interactions** — where this choice constrains or is constrained
   by choices in other active force clusters

### Step 5: Caveat & Gap Signaling

If any loaded codebook is thin or missing:

1. **Thin codebook** (Tier 3 or few references):
   - Note the limitation to the user
   - Append to `pattern-extraction-pipeline/references/enrichment-roadmap.md`
     § Gap Log: timestamp, codebook name, what was missing, user's domain context
2. **Missing codebook** (force cluster has no codebook):
   - Suggest using pattern-extraction-pipeline to create one
   - Append to enrichment-roadmap.md § Deferred Candidate Status with the
     user's domain description
   - **Codebook gap**: If foxhound/codebook lookup returns empty for a domain with competing forces, record it: `~/.claude/scripts/codebook-gap.sh record "Force: X vs Y vs Z" "Leads: [repos/files seen]. Context: [what you were doing]"`
3. **Unclear discrimination** (two patterns seem equally valid):
   - Present both with the discriminating factors still needed
   - Note this as a potential enrichment opportunity

This closes the lifecycle loop: advisor usage surfaces gaps → roadmap
accumulates them → next audit prioritizes them → enrichment fills them.

## Quality Standards

- Cite specific competing patterns from codebook references — generic advice ("Pattern A is generally better") lacks the diagnostic connection that makes recommendations actionable
- Diagnostic questions should be answerable by someone who knows their project, not require research
- Rationale connects diagnostic answers to pattern selection — this is the value-add over just reading the codebook
- Cross-cluster interactions reference specific interaction pairs from the cross-domain map
- Never fabricate patterns or production examples not in the codebooks

If `.mulch/assessments/qa-assessment.md` exists, read `## For pattern-advisor` — QA force clusters and team contracts constrain pattern selection.

`[eval: approach]` Ran diagnostic intake before recommending — did not jump to solutions.
`[eval: scavenge]` Checked indexed sources, mulch, and codebase before reasoning from first principles.
`[eval: completeness]` Recommendation references specific codebook patterns, not abstract advice.
`[eval: guardrail]` bias:reframe and bias:availability both fired before final recommendation.
`[eval: contract-lens]` QA signals checked as team contracts before recommending patterns.
