---
name: pattern-extraction-pipeline
description: >-
  Extract patterns from reference codebases into structured codebooks organized
  by force clusters (competing forces that produce spaghetti when unresolved).
  Four modes: extraction (full pipeline for new codebooks), audit
  (grade existing codebooks and regenerate enrichment roadmap), enrichment
  (add production examples to existing codebooks from new repos), and
  de-factoring (remove patterns to discover what forces they actually resolve).

  TRIGGER when: creating a pattern library or codebook from a reference codebase;
  auditing codebook health or enrichment priorities; enriching an existing
  codebook with evidence from a new repo; understanding why a pattern exists
  by removing it and observing what breaks.

  DO NOT trigger for: using an existing codebook (use the library's own skill);
  code exploration without artifact intent (use hybrid-research); shipping code;
  debugging; code review.

  Distinguishing test: Are you creating or improving a reusable reference artifact
  from studying someone else's code? If yes, use this.
---

# Pattern Extraction Pipeline

The factory that creates domain pattern libraries. Codebooks are organized by
**force clusters** — groups of competing forces that produce spaghetti when unresolved.

## Force-Cluster Scoping

Codebooks are scoped by the **tension that makes code bad**, not by project, technology,
or application type.

### What a force cluster IS:
- The **tension** that makes a problem hard (consistency vs responsiveness vs durability)
- Cross-project (tldraw, Excalidraw, Figma all face the same tension)
- Inclusive of variants (CRDTs, OT, LWW are competing resolutions of the same forces)

### What a force cluster is NOT:
- A project ("weavejs patterns") — too narrow, doesn't transfer
- A technology ("CRDT patterns") — solution-oriented, misses the problem
- An application type ("canvas editor patterns") — too broad, mixes unrelated forces

### Force cluster vs composite recipe:
- **Force cluster**: One tension, multiple competing resolutions. Usable independently.
- **Composite recipe**: Combines 2-3 force clusters for a specific domain.

## What This Produces

A new skill directory with SKILL.md + references/:

- **SKILL.md**: Frontmatter with force tension description + trigger/negative space. Body: classify → load reference → advise + cross-references to related codebooks.
- **Reference files**: Each covers one axis of the force cluster. Structure: The Problem → 3-6 competing patterns (each with when-to-use, when-NOT, code examples, production examples from 2+ real systems) → decision guide → anti-patterns with consequences.

See `references/codebook-template.md` for the exact format.

## The Pipeline

Three stages. Orient → Extract → Assemble.

**Context init** before starting:
- Foxhound `search` with `project_root` — includes mulch automatically.
- If `.seeds/` exists: `sd ready` for related issues.
- If project has a package manifest: `sync_deps(root)` to index deps.

### Stage 1: Orient — Identify force clusters

1. Run the project. Read its README. Survey the codebase structure.
2. Identify **force clusters** — the competing forces that make this codebase's domain hard. Ask: "where does this codebase fight spaghetti? What tensions does its architecture resolve?" For translating QA artifacts (suppressions, CI gates, coverage) into force pairs, load `quality-linter/references/force-cluster-protocol.md`.
3. For each force cluster, check: does an existing codebook cover it? If yes, this is enrichment (add examples). If no, a new codebook is needed.

Foxhound `search_references` to discover indexed reference projects, `search_patterns` to check existing codebook coverage before extracting.

### Stage 2: Extract — Map patterns and document forces

This is the intellectual core. For each force cluster:

1. **Find seams** — substitution points where behavior changes without editing surrounding code (interfaces, DI points, plugins, middleware). See `references/seam-types.md`. Use LSP (goToDefinition, findReferences) to trace dependency chains.
2. **Label each seam** with its pattern name and force cluster. Group by force cluster, not by module.
3. **De-factor**: Mentally remove each pattern. What becomes painful? If the answer is "nothing" — the pattern is over-engineering. Document this honestly. See `references/forces-analysis-guide.md`.
4. **Research competing approaches**: Find 2+ production systems that solve the same tension differently.
5. **Draft reference files** following `references/codebook-template.md`. Each file covers one axis with: The Problem, 3-6 competing patterns, decision guide, anti-patterns with consequences.

`bias:overconfidence` — Before assembling the codebook, verify each claimed pattern actually exists in the reference code with sufficient evidence. How do you know each pattern is real and not inferred from training data?

### Stage 3: Assemble — Package and validate

1. **Package as skill**: Create SKILL.md + references/ directory in `domain-codebooks/`.
2. **Write the trigger description** naming the force tension (not the solution technology). Include cross-references to related codebooks.
3. **Check quality** against `references/quality-criteria.md`:
   - Force-cluster scoped, not project/tech-scoped
   - 3+ competing patterns per reference file (not prescriptions)
   - Decision gates with project-specific questions
   - Anti-patterns with consequences
   - Concrete code examples (not pseudocode)
   - Production examples from 2+ systems
   - Cross-references to related codebooks
4. **Update cross-domain map** — add entries to `references/cross-domain-map.md`.
5. **Update domain-codebooks router** — add the new codebook to the router's SKILL.md table.

## Audit Mode

When auditing existing codebooks:

1. Scan all codebooks in `domain-codebooks/` — count reference files, assess completeness
2. Score each against quality criteria (completeness, depth, shape, boundary, production examples, de-factoring evidence, trigger discrimination)
3. Regenerate `references/enrichment-roadmap.md` with prioritized recommendations

## De-factoring Mode

When you need to understand *why* a pattern exists — not just *what* it is:

1. Identify a pattern in the codebase (via seam-identification or Stage 2)
2. Actually remove it — in a worktree or throwaway branch. Replace Strategy with a switch. Replace Observer with direct calls. Flatten Pipeline into one function.
3. Run characterization tests. What breaks reveals structural forces. What doesn't break reveals the pattern may be over-engineering.
4. Document the forces: what became painful, what coupling was exposed, what extensibility was lost
5. Feed results into codebook reference files as de-factoring evidence

This is the inverse of refactoring-to-patterns. Where extraction tells you "this is a Strategy pattern," de-factoring tells you "this is a Strategy pattern *because* adding a new shape type without it requires touching 14 files."

See `references/forces-analysis-guide.md` for the protocol and common force pairs.

## Enrichment Mode

When adding evidence from a new repo to existing codebooks:

1. Orient on the new repo (Stage 1)
2. For each force cluster that maps to an existing codebook, extract new examples
3. Add production examples and competing patterns to existing reference files
4. Follow `references/enrichment-protocol.md`

## Mulching

If `.mulch/` exists: `mulch prime` at start, `mulch record --tags <situation>` new codebook decisions at end. Close the loop on applied mulch records: `ml outcome <domain> <id> --status success/failure`.

If `.mulch/assessments/qa-assessment.md` exists, read `## For pattern-advisor` — QA force clusters constrain the design space for extraction.

`[eval: force-cluster-organized]` Codebook organized by competing forces (tensions), not by features, modules, or topics.
`[eval: claims-grounded]` Every pattern cites specific code locations (file:line or module:function), not abstract references.
`[eval: qa-contracts-checked]` Before extracting, checked lint configs and test assertions for implicit team contracts.
