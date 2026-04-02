---
name: codebase-diagnostics
description: >-
  Progressive multi-level codebase analysis — maps architecture from business domain
  down to runtime behavior across 8 zoom levels with 6 cross-cutting lenses.
  Persists findings as architecture docs, mulch records, and seeds issues.
  Use when: "what is this codebase?", "onboard me", "map this project",
  "diagnose this repo", "analyze architecture", "what are the subsystems?",
  entering an unfamiliar project, understanding brownfield codebases.
  Also use when seam-identification or shadow-walk alone isn't enough —
  when you need the full picture, not just one facet.
  Do NOT trigger for: implementation planning (use writing-plans),
  debugging (use systematic-debugging), code review (use interactive-pr-review),
  quick orientation without persistence (use hybrid-research onboarding mode).
---

# Codebase Diagnostics

Conductor, not performer. This skill sequences zoom levels, dispatches to existing analysis skills, and persists the assembled picture. It never reads source files or classifies code directly — every analysis action dispatches to an existing skill or Explore agent. The orchestrator owns the map; delegates draw each region.

Six diagnostic frames — origami (space), watershed (flow), stratigraphy (time), knot theory (complexity), pruning (readiness), lock picking (constraint order) — form a pipeline threaded through the waves. Each frame's output feeds the next; their interactions surface what none sees alone. See `references/diagnostic-frames.md` for the full vocabulary.

`[eval: dispatch-not-perform]` Skill contains no direct file-reading — all analysis via dispatch.

## Zoom Levels

How much of the codebase is in focus. Always start at Domain; go as deep as needed.

| # | Level | Question | Primary tool | Secondary |
|---|-------|----------|-------------|-----------|
| 1 | Domain | What business problem does this solve? | foxhound + README/docs | Context MCP (domain libs) |
| 2 | Ecosystem | What external world does it participate in? | foxhound sync_deps + manifests | Context MCP (external APIs) |
| 3 | Infrastructure | What runs it? | codebase-analytics.sh | observability-scan.sh |
| 4 | Subsystem | What are the major functional boundaries? | seam-identification (survey+label) | — |
| 5 | Component | What are the building blocks within a subsystem? | quality-linter shared assessment | codebase-analytics.sh |
| 6 | Contract | What are the interfaces? Do implementations fulfill contracts or just satisfy the type system? | characterization-testing | pattern-advisor |
| 7 | Module | What are the key files, classes, functions? | shadow-walk (scoped) | quality-linter (file-level) |
| 8 | Behavior | What happens at runtime? | shadow-walk (flow tracing) | domain-codebooks |

## Cross-Cutting Lenses

Applied at whichever zoom level is in focus. Not every lens applies everywhere.

| Lens | What it reveals | Most relevant at |
|------|----------------|-----------------|
| Data | Schemas, transformations, ownership, flow | Domain, Subsystem, Contract, Behavior |
| Configuration | Tunable vs hardcoded, feature flags, env vars | Infrastructure, Component |
| Security | Trust boundaries, secrets, auth/authz surfaces | Ecosystem, Infrastructure, Contract |
| Quality | Test coverage, lint health, type safety, stub density (see `../../references/stub-detection.md`) | Component, Module, Contract |
| Evolution | Era strata (index fossils, faults, partial migrations), churn hotspots, lithified temporaries | Subsystem, Component, Module |
| Convention | Naming, organization, patterns, team culture | Component, Module |

---

## Phase 1: Sweep

`[criteria-precommit: sweep]` Before starting: (1) all 8 zoom levels will have findings or explicit "not applicable," (2) project shape detected, (3) `_meta.json` written with staleness hashes, (4) every `<!-- INCOMPLETE -->` marker has a seed proposal.

### Entry

Check for `docs/architecture/_meta.json`. If exists, run `bash ~/.claude/scripts/architecture-staleness.sh <project-root>` — re-scan only stale levels, skip to Phase 2 after. If missing, full inventory across all 8 levels.

At every level, search foxhound for reference patterns (`search_references("<concept>")`) and load domain-codebooks when force clusters emerge. This grounds analysis in what's been seen before, not just first principles.

### Wave 1 — Foundation (parallel, independent)

Dispatch three agents simultaneously:

- **Domain agent** — foxhound + README/docs analysis. Writes `docs/architecture/domain.md`.
- **Ecosystem agent** — foxhound `sync_deps` + manifest scanning. Dates dependency vintages — which eras of the ecosystem are represented. Writes `docs/architecture/ecosystem.md`.
- **Infrastructure agent** — `codebase-analytics.sh` + env/docker/CI scan via `observability-scan.sh`. Collects **index fossils** — syntax patterns (`var` vs `let`/`const`, `require` vs `import`), framework version markers, API style indicators — and records them as era markers. These date strata faster than git log and survive squashed history. Writes `docs/architecture/infrastructure.md`.

After all three return, build the **inter-wave context summary** (see schema below) and run **project shape detection**.

**Inline check (Wave 1→2):** All 3 docs exist, project shape is one of: monolith, microservices, monorepo, library, scripts. If any fails: `[SNAG]`, attempt recovery, proceed with partial context.

### Wave 2 — Subsystem Discovery (needs Wave 1)

Dispatch one agent:

- **Subsystem agent** — seam-identification scoped to survey and labeling only (steps 1-2, skip skeleton trace). Also traces primary data/request flows from entry points to terminals — mapping **flow basins**. Where basins disagree with structural boundaries, record the divergence (indicates either misidentified boundary or **stream capture** — a module that gradually absorbed adjacent responsibilities). Flow basin data determines **drainage density** per region.

Writes `docs/architecture/subsystems.md`.

**Gate: Wave 2→3 — gate-enforcer `decision-check`**

This is the highest-leverage gate: Wave 3 dispatches up to 4 agents per subsystem, so wrong boundaries waste all downstream work. Gate-enforcer checks:
- **WYSIATI:** Directories/packages not covered by any subsystem?
- **Overconfidence:** Could a "monolith" actually be a "monorepo"?
- **Substitution:** Do subsystems answer what the user asked, or did seam-identification find what was easy?
- **Era compatibility:** Do boundaries cross fault lines (partial migrations where fossils show different eras on each side)?
- **Flow coherence:** Do flow basins align with structural boundaries?

PASS → Wave 3. BLOCK → re-run or surface to user.

### Wave 3 — Per-Subsystem Deep Analysis (needs Wave 2)

For each subsystem, dispatch up to four agents:

- **Component agent** — quality-linter scoped to the subsystem. Runs **stratigraphy**: faults (partial migrations), diagenesis (TODO/hack comments on load-bearing code), metamorphism (modern syntax hiding ancient assumptions). Note inverted strata: newer code carrying older patterns because copied from old code.
- **Contract agent** — characterization-testing at subsystem boundaries. Runs **knot analysis**: count dependency crossings weighted by era distance. Classify tangles as prime (irreducible — accept or redesign) or composite (accidental — always separable). Flag **security pins**: bidirectional serialization, shared mutable state with ordering constraints, load-bearing event listener order.
- **Module agent** — shadow-walk scoped to key files. Uses drainage density to set resolution: high-density regions get function-level scrutiny, low-density get module-level. Flags **deadwood** — dead code, unused imports, orphaned modules — as zero-risk removal candidates before structural refactoring.
- **Behavior agent** — shadow-walk flow tracing. Identifies **endorheic basins** — state that accumulates without flushing (growing caches, unbounded queues, never-expiring sessions). Also detects **stream capture** by cross-referencing flow traces with era markers.

**Concurrency cap:** Max 8 agents. If `subsystem_count * 4 > 8`, split into sub-waves by subsystem. Prioritize by risk: highest churn, lowest test coverage first.

Each agent writes to `docs/architecture/subsystems/<name>/<doc>.md`.

**Cross-cutting pattern detection:** When the same pattern appears in 2+ subsystems (shared error handling, repeated data transformation, identical code structures), promote to `docs/architecture/cross-cutting/patterns.md` immediately — don't wait for Wave 4. Also promote stream capture, endorheic basins, and fault lines that span subsystems. For each, check foxhound `search_patterns("<pattern>")` for existing codebook coverage.

`[eval: cross-cutting-detection]`

**Inline check (Wave 3→4):** At least 1 subsystem has ≥2 analysis docs. No subsystem has all 4 agents failed.

### Wave 4 — Synthesis (needs all prior waves)

Dispatch agents for:

- **Cross-cutting synthesis** — read all docs, identify patterns spanning 2+ subsystems. Run cross-frame interactions: (1) weight crossings by era distance, (2) predict response growth after cuts, (3) compute knot complement as parallelism map, (4) check origami × stratigraphy feasibility. Writes `docs/architecture/cross-cutting/*.md`.
- **Risk aggregation** — compile risk signals into a prioritized map. Six dimensions: spatial location, temporal era, flow impact, tangle complexity, readiness to absorb change, constraint ordering. Severity tiers: **Fatal** (blocks action), **Warning** (flag but proceed), **Info** (note and continue). Only fatal vetoes. Writes `docs/architecture/risk-map.md`.
- **Evolution analysis** — churn hotspots, architectural drift, decision history. Integrates stratigraphy: fault lines, diagenetic code, metamorphic modules. Writes `docs/architecture/evolution.md`.

`[eval: zoom-coverage]` All 8 levels produced findings or marked "not applicable."

**Gate: Phase 1→2 — gate-enforcer `claim-verification`**

Before presenting to user. Checks: every subsystem in overview exists in subsystems.md, every risk signal traces to a doc, doc paths exist on disk, no INCOMPLETE sections presented as complete.

### Inter-Wave Context Format

Structured JSON passed between waves. Build incrementally — never pass raw findings.

```json
{
  "project_shape": "<shape>",
  "subsystems": [
    {
      "name": "", "root_path": "", "risk_signals": [],
      "key_dependencies": [], "boundary_type": "",
      "drainage_density": "high|low|mixed", "flow_basin_aligned": true
    }
  ],
  "infrastructure": { "databases": [], "queues": [], "ci": "", "deployment": "" },
  "domain_summary": "",
  "era_markers": [{"pattern": "", "era": "", "locations": []}],
  "flow_basins": [{"entry": "", "terminal": "", "subsystems_touched": []}],
  "faults": [{"location": "", "era_a": "", "era_b": "", "type": ""}],
  "crossings": [{"boundary": "", "count": 0, "era_weighted_count": 0, "classification": ""}]
}
```

See `references/codebase-mapping-schema.md` for the full schema.

### Error Handling

If a dispatched skill fails mid-wave:
1. Write what was gathered with `<!-- INCOMPLETE: <reason> -->` marker
2. Continue — downstream waves receive the summary minus the failed section
3. `[SNAG] <skill> failed at zoom level <level> for <subsystem>: <reason>`
4. Seed the gap: `source:codebase-diagnostics, type:incomplete-analysis`

---

## Phase 2: Drill (User-Directed)

`[criteria-precommit: drill]` Each drill produces a doc update. Drill into a subsystem triggers full seam-identification (steps 1-5). New findings update inter-wave context.

After Sweep presents the map, the user navigates interactively.

**Two modes:** Exploration (deeper, wider, lateral — just looking) skips readiness. Assessment (user asks about changing/refactoring/separating something) activates it. Default to exploration. Switch when language signals modification intent.

### Readiness Protocol (assessment drills only)

1. **Deadwood first.** Dead code, unused imports, orphaned modules — zero-risk removals that reduce dependency graph noise. Sometimes eliminates crossings entirely.
2. **Check the collar.** Does the cut point have tests and interfaces to absorb change? No collar = prep work (characterization tests, interface definition) before cutting.
3. **Map likely response growth.** After separation, identify 2-3 likely redirection paths. Flag modules lacking interfaces to absorb redirected flow. The value is asking before cutting, not predicting precisely.
4. **Classify the cut.** Crown reduction (shrink public API surface — too-wide interface) or crown thinning (clean internal coupling behind a reasonable interface)? Different diagnosis, different cut pattern.

### Drill directions

| Direction | Example | What happens |
|-----------|---------|--------------|
| **Deeper** | "zoom into auth's payment component" | Dispatch at next zoom level, scoped |
| **Wider** | "now do the same for billing" | Repeat Wave 3 for new subsystem |
| **Lateral** | "how do auth and billing communicate?" | characterization-testing at shared boundary |
| **Stop** | "I've seen enough" | Proceed to Phase 3 |

When drilling into a subsystem, dispatch **full** seam-identification (all 5 steps) — Wave 2 only ran abbreviated survey+label.

**Dynamic sequencing.** Don't commit to drill order upfront. After each drill, re-evaluate remaining seams — resolving one constraint changes leverage scores. Sequence by downstream unknotting potential, not local crossing count. (Size threshold: re-evaluate only if `subsystem_count > 3`.)

After each drill, two integrity checks:
- **False-set check:** Apply pressure to adjacent seams. Does the decoupling hold, or did a downstream module rely on a side effect?
- **Security-pin check:** If a seam resists and gives inconsistent feedback, classify as security pin — needs an explicit coordinator, not direct separation.

---

## Phase 3: Synthesize

`[criteria-precommit: synthesize]` overview.md exists, risk-map.md exists, _meta.json hashes recalculated, all seed proposals triaged, all mulch records tagged `source:codebase-diagnostics`.

Runs at exit.

1. **Update `overview.md`** — architecture summary. Elevator pitch.
2. **Update `cross-cutting/`** — patterns from Drill spanning subsystems.
3. **Update `risk-map.md`** — aggregated risk signals from all levels.
4. **Update `_meta.json`** — recalculate staleness hashes via `git log -1 --format=%H -- <source_glob>`.
5. **Update `README.md`** — add/update Architecture section (never overwrite other content):
   ```markdown
   ## Architecture
   See [Architecture Overview](docs/architecture/overview.md) for the full system map.
   **Subsystems:** <list> | **Last analyzed:** <date> | **Stale:** <list or "none">
   ```
6. **Feature list extraction** — for projects with user-facing behavior (not Library/Scripts): read behavior.md docs, emit `feature_list.json` entries for each traced flow. This is the regression baseline: existing features `passes: true`, new features from brainstorming append as `passes: false`. Append-only — only `passes` mutates.
7. **Mulch records** — session-level architectural insights via `ml record` with `source:codebase-diagnostics` tags.
8. **Seeds triage** — collect proposals from agents, deduplicate, assign priority, create via `sd create`.
9. **Check closed seeds** — `sd list --label source:codebase-diagnostics` for completed work since last run. Update docs accordingly.

**Gate: Phase 3 exit — gate-enforcer `close-loop`** verifies persistence: mulch records exist, seeds created or explicitly dropped, hashes match, no orphaned INCOMPLETE markers.

`[eval: doc-persistence]` `[eval: staleness-works]`

---

## Flow Map Emission (Task-Scoped)

When invoked for a specific brownfield task (not a general sweep), emit a task-specific flow map.

### When to emit
- Brainstorming requests Deep tier (3+ subsystems or no architecture docs)
- Ad-hoc work triggers Standard-without-brainstorming (multiple subsystems, existing docs)
- Tier calibration escalates mid-task

### Output

Path: `docs/architecture/flows/<task-slug>.md`

````markdown
# Flow Map: <flow name>

**Task context:** <what prompted this>
**Tier:** standard|deep
**Date:** YYYY-MM-DD

## Flows

### Primary: <flow name>
**Observable trigger:** <user action or API call>
**Observable outcome:** <what the caller sees>

| Step | Node | File | Receives | Produces |
|------|------|------|----------|----------|
| N | node-name | path/to/file.ts:line | input type | output type |

(Mark change site with **[CHANGE SITE]** in Node column)

## Contracts
(Type definitions at each flow boundary)

## Cross-Subsystem Boundaries
| Boundary | Subsystems | Seam type | Risk |
|----------|-----------|-----------|------|
````

**Required zoom levels:** L4 (Subsystem) + L6 (Contract) + L7 (Module) minimum. Add L8 (Behavior) when task changes contracts or risk-map flags high-risk. L1-L3 not needed for task-scoped flows.

Flow maps are derived from general docs, not replacements. First run produces general docs as a side effect. Flow maps are task-scoped and short-lived — `_meta.json` tracks them.

`[eval: flow-map-emission]` `[eval: project-shape-adaptation]`

---

## Project Shape Detection

Run after Wave 1. Determines doc tree structure and Wave 3 scoping.

| Signal | Shape |
|--------|-------|
| Workspace files, `packages/` or `apps/` dirs | **Monorepo** |
| Multiple Dockerfiles, docker-compose 3+ services | **Microservices** |
| Single manifest, no server, exports in main/index | **Library** |
| <20 files, no framework, script-like entry points | **Scripts** |
| None of the above | **Monolith** |

### Doc Tree by Shape

| Doc | Monolith | Microservices | Monorepo | Library | Scripts |
|-----|----------|---------------|----------|---------|---------|
| overview.md | Required | Required | Required | Required | Required |
| domain.md | Required | Required | Required | Required | Optional |
| ecosystem.md | Required | Required | Required | Required | Optional |
| infrastructure.md | Required | Required | Required | Optional | Optional |
| subsystems.md | Required | Required | Required | Skip | Skip |
| subsystems/\<name\>/ | Required | Per-service | Per-package | Skip | Skip |
| cross-cutting/ | Required | Required | Required | Optional | Skip |
| risk-map.md | Required | Required | Required | Required | Optional |
| evolution.md | Optional | Optional | Optional | Optional | Skip |

**Library:** Skip subsystems. Focus on `contracts.md` (public API) and `behavior.md` (usage flows) at top level.
**Scripts:** `overview.md` + `infrastructure.md` + `behavior.md` at most. Three files, not twelve.

---

## Dispatch Templates

Each agent receives: zoom level, subsystem scope, lenses, skill delegation, output path, cross-references, inter-wave context JSON, and common footer for mulch/seed proposals.

Full templates in `references/dispatch-templates.md` — one per zoom level plus common footer. Load at wave dispatch start.

Key constraints:
- Level 4: seam-identification steps 1-2 only (survey + label)
- Levels 5-8: inter-wave context from Waves 1+2, scoped to one subsystem
- All levels: agents propose seeds as JSON, never create directly

---

## Persistence

### Mulch Records

| Finding type | Record type | Tags |
|-------------|-------------|------|
| Architectural choice | `decision` | `scope:<subsystem>, zoom:<level>, source:codebase-diagnostics` |
| Recurring pattern | `pattern` | `scope:<subsystem>, zoom:<level>, lens:<which>` |
| Naming/org style | `convention` | `scope:<subsystem>, zoom:<level>, lens:convention` |
| Broken assumption | `failure` | `scope:<subsystem>, zoom:<level>, source:codebase-diagnostics` |
| Useful doc/resource | `reference` | `scope:<subsystem>, zoom:<level>` |

Dedup: `ml search "scope:<subsystem>"` before recording. Update existing records rather than duplicating.
`[eval: mulch-enrichment]`

### Seeds

| Signal | Type | Priority |
|--------|------|----------|
| No tests at trust boundary | `task` | High |
| 0% type coverage | `task` | Medium |
| Dead code / unreachable module | `task` | Low |
| Missing docs for public API | `task` | Medium |
| Architectural question needing human | `question` | Blocks |
| Pattern that should be shared | `feature` | Low |

Agents propose, orchestrator triages in Phase 3. Deduplicate (same file + same finding = one seed).
`[eval: seeds-actionable]`

## Reference

Full schemas for `_meta.json`, inter-wave context, seed proposals, mulch conventions, and doc table: `references/codebase-mapping-schema.md`. Load at Phase 1 start.
