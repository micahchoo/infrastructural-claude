# Dispatch Templates

Structured prompts sent to each dispatched agent during codebase-diagnostics
Sweep phase. All templates share a common footer for mulch recording and seed
proposals.

## Common Footer (appended to every template)

```
Record mulch for significant findings:
  ml record <domain> --type <type> --tags "scope:<subsystem>,zoom:<level>,source:codebase-diagnostics"

Propose seeds as structured JSON (one per line, do NOT create seeds directly):
  {"finding": "<what>", "file": "<path>", "line": null, "severity": "high|medium|low", "seed_type": "task|question|feature", "reason": "<why actionable>"}

Before recording mulch: ml search "scope:<subsystem>" to check for existing records. Update rather than duplicate.
```

## Level 1: Domain

```
You are analyzing zoom level DOMAIN of [PROJECT].
Subsystem scope: all.
Apply lenses: Data.

Tasks:
1. Use foxhound search("<project-name> purpose") and search("<project-name> domain")
   to discover what this project does.
2. Read README.md, CONTRIBUTING.md, and any docs/ directory for stated purpose.
3. Use Context MCP get_docs for domain-specific libraries found in manifests.
4. Identify: business problem, bounded contexts, ubiquitous language, user personas.

Write findings to: docs/architecture/domain.md
Include cross-references: [ecosystem](ecosystem.md) | [subsystems](subsystems.md)

Inter-wave context from prior levels: (none — this is Wave 1)
```

## Level 2: Ecosystem

```
You are analyzing zoom level ECOSYSTEM of [PROJECT].
Subsystem scope: all.
Apply lenses: Security.

Tasks:
1. Run foxhound sync_deps("<project-root>") to index and categorize dependencies.
2. Scan package manifests (package.json, Cargo.toml, go.mod, pyproject.toml, etc.).
3. Use Context MCP search_packages and get_docs for significant dependencies.
4. Identify: external APIs, sister repos, deployment targets, platform constraints.
5. Date dependency vintages — group dependencies by the era they represent
   (e.g., jQuery-era vs React-era, Express 3.x vs 4.x vs 5.x, callback-based
   vs Promise-based libraries). Record which eras are represented in the
   dependency tree for stratigraphy in later waves.

Write findings to: docs/architecture/ecosystem.md
Include cross-references: [domain](domain.md) | [infrastructure](infrastructure.md)

Inter-wave context from prior levels: (none — this is Wave 1)
```

## Level 3: Infrastructure

```
You are analyzing zoom level INFRASTRUCTURE of [PROJECT].
Subsystem scope: all.
Apply lenses: Configuration, Security.

Tasks:
1. Run: bash ~/.claude/scripts/codebase-analytics.sh
   Read sections: LANGUAGES, FRAMEWORK, ARCHETYPE SIGNALS, QA INFRASTRUCTURE.
2. Run: bash ~/.claude/scripts/observability-scan.sh
3. Identify: Docker/container setup, CI/CD pipelines, database configs,
   queue/cache systems, env architecture, deployment topology.
4. Collect INDEX FOSSILS — scan source code for era-dating patterns:
   - Syntax markers: `var` vs `let`/`const`, `require()` vs `import`
   - Framework markers: class components vs hooks, Express middleware patterns,
     jQuery vs modern DOM APIs
   - API style: `$.ajax` vs `fetch` vs `axios`, callbacks vs Promises vs
     async/await, REST vs GraphQL
   - Build markers: Webpack configs vs Vite/esbuild, CommonJS vs ESM
   Record each fossil with its locations in the inter-wave context as
   era_markers with confidence: "high" (multiple fossils agree), "medium"
   (single fossil type), or "low" (fossils may have been erased by
   formatters/linters — fall back to git log era clustering or dependency
   vintages from ecosystem agent). If no fossils found, say so — don't
   guess eras.

Write findings to: docs/architecture/infrastructure.md
Include cross-references: [ecosystem](ecosystem.md) | [subsystems](subsystems.md)

Inter-wave context from prior levels: (none — this is Wave 1)
```

## Level 4: Subsystem

```
You are analyzing zoom level SUBSYSTEM of [PROJECT].
Subsystem scope: all.
Apply lenses: Data, Evolution.

IMPORTANT: Perform seam-identification steps 1-2 ONLY (Survey + Label).
Do NOT perform steps 3-5 (skeleton trace). We need boundary identification,
not deep structural analysis. Full trace happens later during Drill.

Tasks:
1. Survey: run the project mentally, read README, get directory structure,
   identify main entry points and data flow paths.
2. Label: for each identified boundary, record location, type (object/link/
   extension), enabling point, and what varies.
3. Classify boundaries as: service boundary (separate process), module boundary
   (shared process), or implicit boundary (coupled code that should separate).
4. Map FLOW BASINS — trace primary data/request flows from each entry point
   to its terminal output. Each complete flow path defines a basin. Record
   which subsystems each basin touches. Where flow basins disagree with
   structural boundaries (a flow crosses a boundary you'd expect it to stay
   within, or two structurally separate regions share a single basin), flag
   the divergence — it indicates either a misidentified boundary or STREAM
   CAPTURE (a module that gradually absorbed adjacent responsibilities).
   Mark all flow basins as `validated: false` — these are hypothesized from
   static entry→output tracing, not confirmed by runtime analysis. Full
   validation happens in Phase 2 shadow-walk. Downstream agents must not
   treat hypothesized basins as ground truth.
5. Estimate DRAINAGE DENSITY per region — count flow paths per structural
   unit. High density (many fine-grained flows) means Wave 3 analysis needs
   function-level granularity. Low density (few major flows) means module-level
   analysis suffices. Record in inter-wave context so Wave 3 agents calibrate.
6. Cross-reference era markers from Wave 1 against boundary locations. Flag
   boundaries where index fossils differ on each side — these sit on FAULT
   LINES (partial migrations). Record in inter-wave context as faults.

Write findings to: docs/architecture/subsystems.md
Include cross-references: [domain](../domain.md) | [infrastructure](../infrastructure.md)

Inter-wave context from prior levels (structured summary):
[ORCHESTRATOR INSERTS WAVE 1 CONTEXT JSON HERE]
```

## Level 5: Component

```
You are analyzing zoom level COMPONENT of [SUBSYSTEM] in [PROJECT].
Subsystem scope: [SUBSYSTEM_ROOT_PATH].
Apply lenses: Quality, Evolution, Convention.

Tasks:
1. Run quality-linter shared assessment scoped to [SUBSYSTEM_ROOT_PATH].
2. Identify building blocks: major classes/modules, their responsibilities,
   internal dependency graph within the subsystem.
3. Map hotspots: cross-reference churn data against test coverage within
   this subsystem.
4. Identify architectural patterns in use (MVC, hexagonal, event-driven, etc.).
5. Run STRATIGRAPHY within this subsystem:
   a. FAULTS — scan for partial migrations. Where one component uses pattern X
      (e.g., async/await) but a component it depends on still uses pattern Y
      (e.g., callbacks), record the fault with both era labels and location.
   b. DIAGENESIS — find TODO/hack/temporary/workaround comments in code that
      predates its current role. If a "temporary" module is now imported by 5+
      other modules, it has lithified. Flag: the ground is softer than it looks.
   c. METAMORPHISM — identify modules with modern syntax (current framework,
      current language features) but ancient data-flow assumptions, error
      handling patterns, or concurrency models. The superficial era and deep
      era differ. These pass review but fail under load.
   d. INVERTED STRATA — newer files carrying older patterns (copied from old
      code). Check: does file creation date match its pattern era?
   Record all faults in the inter-wave context.

Write findings to: docs/architecture/subsystems/[NAME]/components.md
Include cross-references: [contracts](contracts.md) | [modules](modules.md) | [subsystems](../subsystems.md)

Inter-wave context from prior levels (structured summary):
[ORCHESTRATOR INSERTS WAVE 1+2 CONTEXT JSON HERE]
```

## Level 6: Contract

```
You are analyzing zoom level CONTRACT of [SUBSYSTEM] in [PROJECT].
Subsystem scope: [SUBSYSTEM_ROOT_PATH].
Apply lenses: Data, Security.

Tasks:
1. Run characterization-testing at [SUBSYSTEM] boundaries — focus on interfaces
   exposed to other subsystems and external consumers.
2. Identify: public APIs, event contracts, shared types, database schemas owned
   by this subsystem, message formats.
3. Assess contract health: are interfaces explicit (typed, documented) or
   implicit (convention-based, undocumented)?
4. Use pattern-advisor to check if contract patterns match known good patterns.
5. Run KNOT ANALYSIS at each boundary:
   a. Count dependency CROSSINGS — imports, calls, data flows that cross the
      boundary in each direction.
   b. WEIGHT by era distance — use era markers from inter-wave context.
      Same-era crossings score 1x (may be intentional). Cross-era crossings
      score proportional to era distance (flag for investigation — era
      distance suggests accidental coupling, but intentional cross-era
      coupling exists, e.g. plugin systems). Report both raw and
      era-weighted counts. Era weight is a *priority signal* for where to
      look, not a classification.
   c. Assess SEPARABILITY: could this coupling be separated without
      redesigning both sides? If yes = accidental (separable, the joins
      are refactoring targets). If no = essential (the modules genuinely
      need this coupling — accept or redesign the boundary). This is a
      judgment call, not a formal classification — state your reasoning.
   d. Flag SECURITY PINS — coupling that actively resists separation:
      bidirectional serialization (A serializes for B AND B serializes for A),
      shared mutable state with ordering constraints, event systems where
      listener registration order is load-bearing. These need an explicit
      coordinator (event bus, mediator, adapter), not direct decoupling.
   Record crossings in the inter-wave context.

Write findings to: docs/architecture/subsystems/[NAME]/contracts.md
Include cross-references: [components](components.md) | [behavior](behavior.md) | [data-flow](../../cross-cutting/data-flow.md)

Inter-wave context from prior levels (structured summary):
[ORCHESTRATOR INSERTS WAVE 1+2 CONTEXT JSON HERE]
```

## Level 7: Module

```
You are analyzing zoom level MODULE of [SUBSYSTEM] in [PROJECT].
Subsystem scope: [SUBSYSTEM_ROOT_PATH].
Apply lenses: Quality, Evolution, Convention.

Tasks:
1. Run shadow-walk scoped to [SUBSYSTEM_ROOT_PATH] — identify key files,
   classes, and significant functions.
2. Focus on: high fan-in modules (structural), high-churn modules (risk),
   and modules at subsystem boundaries (contractual).
3. Assess naming conventions, file organization patterns, import structure.
4. Calibrate analysis RESOLUTION using drainage density from inter-wave context:
   - If drainage_density is "high": analyze at function/method level. Many
     fine-grained flows mean coupling is granular — module-level analysis
     will miss critical dependencies.
   - If drainage_density is "low": analyze at module/file level. Few major
     flows mean coupling is coarse — function-level analysis is wasted effort.
   - If drainage_density is "mixed": use high resolution at boundaries,
     low resolution in interiors.
5. Flag DEADWOOD — dead code, unused imports, orphaned modules, feature-flagged
   code where the flag was retired. Report as zero-risk removal candidates.
   Deadwood removal should PRECEDE any structural refactoring because:
   (a) zero risk, (b) reduces noise in dependency graphs making real seams
   easier to see, (c) sometimes eliminates crossings entirely — what looked
   like a tangled dependency involved a dead module.
   FLAG OBVIOUS DEADWOOD ONLY — unused exports, unreachable modules, retired
   flags. Do NOT attempt to prove liveness for ambiguous cases. Cap effort
   at 15 minutes; move on if uncertain.

Write findings to: docs/architecture/subsystems/[NAME]/modules.md
Include cross-references: [components](components.md) | [behavior](behavior.md)

Inter-wave context from prior levels (structured summary):
[ORCHESTRATOR INSERTS WAVE 1+2 CONTEXT JSON HERE]
```

## Level 8: Behavior

```
You are analyzing zoom level BEHAVIOR of [SUBSYSTEM] in [PROJECT].
Subsystem scope: [SUBSYSTEM_ROOT_PATH].
Apply lenses: Data, Security.

Tasks:
1. Run shadow-walk flow tracing through [SUBSYSTEM] — trace the primary
   execution paths from entry points to outputs.
2. Identify: request/response flows, state machines, error propagation paths,
   async patterns, retry/timeout behavior.
3. Load relevant domain-codebooks if force clusters were identified at this
   subsystem — check which behavioral pattern the codebase chose.
4. Detect ENDORHEIC BASINS — subsystems or components that accumulate state
   without flushing. Look for:
   - Caches that grow without eviction policies
   - Queues that accept without bounded capacity
   - Log buffers or session stores with no expiry
   - Any data path where you can trace data IN but never trace it OUT
   These are sources of production incidents (memory pressure, disk
   exhaustion) invisible to static dependency analysis.
5. Detect STREAM CAPTURE — cross-reference flow traces with era markers from
   inter-wave context. Look for modules whose flow scope EXPANDED across eras:
   a function that in era A handled only its own concerns but in era B also
   handles requests that structurally belong to adjacent modules. The captured
   flow looks natural in the current architecture — only flow + time analysis
   reveals it as territory absorbed over time. Flag with the capture timeline.

Write findings to: docs/architecture/subsystems/[NAME]/behavior.md
Include cross-references: [contracts](contracts.md) | [modules](modules.md) | [data-flow](../../cross-cutting/data-flow.md)

Inter-wave context from prior levels (structured summary):
[ORCHESTRATOR INSERTS WAVE 1+2 CONTEXT JSON HERE]
```
