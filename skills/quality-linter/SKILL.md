---
name: quality-linter
description: >-
  Evaluate and design quality-assurance architecture for code projects. Deeply
  analyzes a project's tests, linter rules, and formatter configs as a unified
  system — judging quality, extracting team contracts, identifying force clusters,
  and designing QA infrastructure for model idempotency and output standardization.
  Two modes: Evaluate (brownfield deep analysis of existing test/linter/formatter
  quality) and Design (greenfield or post-Evaluate QA architecture). Use when:
  "are these tests any good", "what should we test", "evaluate QA", "design test
  strategy", "is this test useful", "audit test quality", "what does the test suite
  reveal", "what contracts does this team enforce", brownfield onboarding, or when
  architecture-discovery/brainstorm-to-ship pipelines need QA context.
  Also use when /simplify recommendations need deeper QA assessment, or when
  pattern-advisor needs force cluster context from QA artifacts.
  Do NOT use for: setting up eslint/ruff/prettier (model handles natively),
  eval-protocol decision quality, code review of human-written code
  (use interactive-pr-review), debugging (use systematic-debugging),
  or running tests.
---

# Quality Linter

Evaluate and design QA architecture by reading tests, linters, and formatters as a unified system.

Two modes:
- **Evaluate** — brownfield deep analysis: are the tests good? What do they reveal about team intent? What force clusters exist?
- **Design** — greenfield or post-Evaluate: what QA infrastructure should this project have?

Both modes share a common assessment layer. Tool configuration (installing eslint, running prettier) is explicitly out of scope — models handle that natively.

**First decision:** Is this greenfield or brownfield? Route determines entire workflow. (See Greenfield Detection.)

## Shared Assessment Layer

Runs first regardless of mode. This is in-skill reasoning over deterministic signals — not a script extension.

### Step 1: Run codebase-analytics

```bash
~/.claude/scripts/codebase-analytics.sh
```

Read these sections from the output:
- **QA INFRASTRUCTURE** — linters, formatters, hooks, baselines, test-topology
- **LANGUAGES** — determines stack (Rust vs JS vs Python changes everything)
- **FRAMEWORK** — test runner conventions, linting ecosystem
- **CHURN** — hottest files reveal where risk concentrates
- **ARCHETYPE SIGNALS** — monorepo detection, test ratio, entry points, extension dirs

### Step 2: Build the assessment

From the codebase-analytics output, produce:

1. **Stack profile** — language, framework, test runner, linter, formatter. This determines which classifications and patterns apply.

2. **Hotspot map** — cross-reference CHURN (hottest files) against test-topology (which directories have tests). Files with high churn but no tests are risk zones. Files with high churn and extensive tests are well-defended.

3. **Seam sample** — where are the architectural joints? Check for prior seam-identification output: `ml search "scope:seam"`. If found, use it. Otherwise infer seams from codebase-analytics: entry points, extension dirs, package boundaries.

4. **Test-to-seam mapping** — which seams have tests, which don't. Sample strategy: read `min(20, total_test_files * 0.3)` test files, always prioritizing:
   - Tests adjacent to hotspots (high-churn modules)
   - Tests at seams (module boundaries, entry points)
   - If fewer than 5 test files exist, read all of them

5. **Contract signals** — interpret QA signals as team intent:

| Signal | Contract it reveals |
|---|---|
| `--max-warnings 0` in lint config | Zero-tolerance: team considers these errors, not suggestions |
| Inline suppressions (`eslint-disable`, `noqa`) | Acknowledged debt — suppressed rules mark known tensions |
| Snapshot test files | Those surfaces are stable contracts — changes trigger visual review |
| Coverage thresholds in CI | Team's definition of "enough" testing |
| Pre-commit hooks configured | Team enforces quality at commit time, not just CI |
| No QA infrastructure at all | Team has not invested in automated quality enforcement |

**Greenfield subset:** When QA INFRASTRUCTURE output is empty (no linters, no test files, no formatters detected), only stack profile and archetype signals are produced. Skip hotspot map, seam sample, and test-to-seam mapping — Design mode receives a minimal assessment and works forward-looking.

## Evaluate Mode

Use in brownfield projects. Runs after the shared assessment. Four phases that read tests, linters, and formatters as a **unified system** — not three separate audits.

### Phase 1: Test Quality Audit

For each test file in the sample, classify:

| Classification | Meaning | Signal |
|---|---|---|
| **Purposeful** | Tests a real invariant or contract | Assertion targets behavior, not implementation. Would catch a real bug. For property-based characterization patterns (4 invariant types from signatures), load `characterization-testing/references/property-based-characterization.md`. |
| **Trivial** | Tests something obvious or tautological | "constructor sets properties", "returns true when true" |
| **Fragile** | Coupled to implementation, breaks on refactor | Mocks internal details, asserts call counts, tests private methods |
| **Orphaned** | Tests code that no longer exists or matters | Import paths broken, tested module deleted, feature deprecated |
| **Missing-the-point** | Tests exist at this seam but test the wrong thing | Testing CSS classes instead of accessibility, testing HTTP status instead of response contract |

The same classification framework applies to **linter rules** and **formatter configs**:

| Artifact | Purposeful | Trivial | Fragile |
|---|---|---|---|
| **Test** | Asserts real invariant | Asserts tautology | Asserts implementation detail |
| **Linter rule** | Enforces architectural constraint | Enforces obvious style | Triggers on context-dependent code |
| **Formatter config** | Eliminates all style discretion | Covers only one file type | Conflicts with linter auto-fix |

A suppressed linter rule in the same module where tests are fragile is a stronger signal than either alone. Look for cross-artifact reinforcement and contradiction.

### Phase 2: Linter & Formatter Quality Audit

For linter configs:
- **Boilerplate or customized?** Default configs mean the team hasn't thought about what to enforce. Custom rules signal intentional architectural decisions.
- **Architectural or just style?** Rules like "no circular imports" enforce structure. Rules like "prefer single quotes" enforce taste. Both matter, but differently.
- **Suppressions: strategic or spray-and-pray?** Scoped, documented suppressions mark known force boundaries. Scattered `eslint-disable` everywhere means the team gave up.
- **Reinforcement or contradiction?** Do linter rules and tests agree about what matters? A linter enforcing immutability while tests mock mutable state is a contradiction signal.

For formatter configs:
- **Coverage complete?** Does the formatter handle all file types in the project, or just some?
- **Ambiguity eliminated?** A well-configured formatter leaves zero style decisions to the contributor (human or model).

### Phase 3: Force Cluster Identification

From the unified test + linter + formatter analysis, identify competing forces — tensions where the codebase resolves a design tradeoff:

- What tensions do the tests reveal? Tests enforcing immutability in one module but mutation in another suggest a state management force cluster.
- What do suppressions reveal? Disabling a rule in specific files often marks a force boundary where the general rule doesn't apply.
- What contradictions exist between test assertions, linter rules, and formatter behavior?

**Codebook matching:** For each candidate, foxhound `search_patterns` to check for existing domain-codebook coverage — codebook patterns inform what tests/rules *should* enforce. For the de-factoring protocol and Kerievsky Test (validating forces are real, not cargo-cult), load `pattern-extraction-pipeline/references/forces-analysis-guide.md`.

**Undocumented clusters:** Where no codebook match exists, record the force cluster as a first-class discovery. These feed the codebook ecosystem — they don't require a codebook to be valuable. Undocumented clusters become seeds candidates for pattern-extraction-pipeline.

### Phase 4: Contract Extraction

Synthesize what the team actually enforces, drawing from all prior phases:

- **"This team treats X as load-bearing"** — tested, linted, CI-gated. Changes here trigger review.
- **"This team ignores Y"** — no tests, suppressed lint, no CI gate. Changes here are unguarded.
- **"This team is conflicted about Z"** — tests exist but are fragile/trivial, linter rules suppressed inconsistently. The team knows this matters but hasn't resolved how.

These contract statements are the most valuable output for other skills. They tell writing-plans where safety nets exist, characterization-testing what to focus on, and pattern-advisor what the team's actual architectural priorities are.

### Evaluate Output

1. **Findings file** — write a file named exactly `qa-assessment.md` (hyphenated, lowercase) to `.mulch/assessments/` (falls back to project root if no `.mulch/`). The file must use `# QA Assessment: <project>` as its title. Readable narrative with structured consumer sections (see Diffusion below).

2. **Mulch records** — one per identified force cluster:
   ```bash
   ml record <force-cluster-domain> --type convention \
     --description "<what the force cluster is>" \
     --classification tactical \
     --tags "scope:<module>,source:quality-linter,mode:evaluate,lifecycle:discovered"
   ```
   Domain names mirror domain-codebooks organization (e.g., `state-management`, `error-handling`), not a generic "testing" domain.

3. **Seeds issues** — for undocumented force clusters warranting codebook extraction:
   ```bash
   sd create --title "Codebook gap: <force-cluster-name>" \
     --type task \
     --labels "force-cluster,codebook-gap" \
     --body "Discovered by quality-linter evaluate in <project>. <description of competing forces>."
   ```

## Design Mode

Two entry paths. Both use the **same rubric as Evaluate** — the classification framework, force cluster identification, and contract analysis all apply. The difference is posture: instead of "are these tests good?" Design asks "what would good tests look like here?"

### Greenfield Path

When no QA infrastructure exists (detected from the shared assessment's greenfield subset). Design produces a QA architecture from scratch.

**Ground everything in the actual codebase.** For each Layer 2 test target, name the specific type, function, or module path you found — e.g., "property test for `Freehand.pressures: Vec<f64>` normalization (found in `drafftink-core/src/shapes.rs`)" not "property test for pressure normalization." If you can't cite a real construct, you're hallucinating a test target — foxhound `search` to verify. Every Layer 2 entry needs a `(found in <path>)` or `(observed in <module>)` grounding annotation.

**Step 1: Map seams first.** The seam map is the scaffolding everything else hangs on. Name each seam (S1, S2...) with its boundary description, the modules on each side, and whether the boundary is explicit (interface/trait exists) or implicit (coupled code that should be separated). Identify missing seams — boundaries that should exist but don't (traits to extract, modules to decouple, interfaces to make explicit). Missing seams become both architectural recommendations and test boundary targets.

**Step 2: Hang tests on seams.** Each Layer 2 test targets a specific seam. The test quality classifications become design targets:
- Design tests that would classify as Purposeful — targeting real invariants at real seams, not boilerplate
- Explicitly avoid designing tests that would classify as Trivial, Fragile, or Missing-the-point
- Every test recommendation must reference which seam (S1, S2...) it validates

**Step 3: Identify force clusters from seam interactions.** Apply force cluster identification forward-looking — what tensions will this project face based on the seam topology? Force clusters emerge where seams interact or where competing concerns share a boundary. For each force cluster, check codebook coverage via foxhound `search_patterns`. Report match status — codebook match, partial match, or gap (candidate for pattern-extraction-pipeline).

**Step 4: Design the three layers.** Now produce the three-layer design, grounded in the seam map and force clusters. Define what the team *should* enforce, not just what they do.

**Step 5: Sequence into waves.** Don't dump everything at once. Sequence: (1) formatter + basic lints (immediate consistency), (2) boundary tests at identified seams, (3) property tests for domain invariants, (4) AI-specific rules. Each wave builds on the previous.

**Step 6: Write consumer handoff sections.** Produce `## For characterization-testing`, `## For writing-plans`, and `## For pattern-advisor` sections referencing specific seams and force clusters — these tell downstream skills what was designed and why.

**Platform and environment awareness.** Check whether the project targets multiple platforms (native + WASM, desktop + mobile, server + edge), multiple languages (Go + Vue, Rust + JS), or multiple deployment targets (CLI + daemon, library + app). If so, the QA design must address environment divergence — but only when evidenced in the codebase. Don't assume dual-target architecture if the source shows a single target.

If a domain-codebook exists for the project's domain, connect codebook patterns to testable properties. Example: "codebook says CRDT merge must be commutative" becomes "design a property test for merge commutativity."

### Brownfield Path

Runs after Evaluate. Evaluate's findings are **design constraints** — not just data. "Evaluate found team treats undo as load-bearing but tests are fragile" shapes the entire QA architecture, not just the undo tests.

Three concerns:
- **Gap-fill** — seams with no tests, force clusters with no enforcement. Propose specific tests and rules.
- **Improve** — trivial, fragile, or missing-the-point tests. Propose replacements that test actual invariants.
- **Architect** — given the full picture, propose the target QA architecture: what to keep, what to replace, what to add, and the migration path from current to target.

### Three-Layer Design

Both paths produce recommendations across three layers:

| Layer | Purpose | Examples |
|---|---|---|
| **AI-specific** | Catch model failure modes | No phantom imports, no unnecessary error handling, no over-abstraction, no hallucinated APIs, no invented test utilities |
| **Code-specific** | Enforce architectural invariants | Module boundary tests, contract tests at seams, property tests for domain invariants, dependency direction rules |
| **Contributor-agnostic** | Standardize all output | Formatter config eliminating style discretion, naming conventions, file structure rules, import ordering |

### Design Output

1. **QA architecture doc** — `qa-design.md` written to `.mulch/assessments/` (falls back to project root if no `.mulch/`). What to test, at what level, with what patterns, organized by the three layers.

2. **Diffusion-ready blocks** — structured sections appended to the findings file (`qa-assessment.md`). In greenfield (no prior Evaluate), creates the findings file with design-oriented consumer sections.

## Diffusion

Knowledge flows to other skills through three mechanisms.

### Findings File (session-scoped)

`qa-assessment.md` with named sections per consumer:

```markdown
## For characterization-testing
[Modules to characterize: untested seams, hotspots without coverage]

## For writing-plans
[Safety net map: which seams are protected, which aren't. Risk zones.]

## For verification-before-completion
[Team contracts to verify: "this project enforces X, check before claiming done"]

## For pattern-advisor
[Force clusters found, with codebook match/gap status]
```

### Mulch Records (durable, cross-session)

One record per force cluster. Domains chosen by the force clusters themselves, mirroring domain-codebooks organization. Tags: `scope:<module>`, `source:quality-linter`, `mode:evaluate|design`, `lifecycle:discovered|active`.

### Seeds Issues (actionable future work)

For undocumented force clusters. Creates issues that surface as triggers for pattern-extraction-pipeline.

## Degenerate Cases

| Condition | Behavior |
|---|---|
| **No tests at all** | Skip Phase 1. Entire project is a gap-fill target for Design. Record "zero test coverage" as a contract signal. |
| **No linters or formatters** | Skip Phase 2 linter/formatter portions. Record "no static analysis" as a contract signal. |
| **No tests, no linters, no formatters** | Greenfield subset. Skip Evaluate — route directly to Design greenfield path. |
| **Zero force clusters identified** | Record "no force clusters detected" in findings. Skip mulch/seeds for clusters. Proceed to contract extraction. |
| **No codebook match for any cluster** | All clusters tagged `lifecycle:discovered`. All become seeds candidates. Expected for projects outside the codebook ecosystem. |
| **codebase-analytics.sh missing QA section** | Fall back to manual file-signal detection (glob for test files, linter configs). Warn about degraded assessment. |
| **Seam-identification not run** | Infer seams from directory structure only. Lower-confidence sample — note in findings. |

## Pipeline Integration

This skill plugs into existing pipelines as a stage:

- **architecture-discovery**: `map(seam-id) -> evaluate-qa(this) -> characterize -> extract -> codebook`
- **hardening**: `evaluate-qa(this) -> test(TDD) -> attack(adversarial)`
- **brainstorm-to-ship**: when brainstorming detects brownfield (QA INFRASTRUCTURE non-empty), routes through architecture-discovery as prerequisite before planning

## References

Load the relevant reference before the workflow step that uses it.

- `references/contract-signals.md` — signal interpretation table: what suppressions, CI gates, snapshots, and coverage thresholds reveal about team intent. Load during Shared Assessment Layer.
- `references/test-classifications.md` — 5-category rubric (Purposeful/Trivial/Fragile/Orphaned/Missing-the-point) with real examples and classification decision tree. Load during test classification.
- `references/three-layer-rubric.md` — three-layer quality rubric: AI-specific failure modes, code-specific architectural patterns, contributor-agnostic formatting rules. Load during Design mode.
- `references/force-cluster-protocol.md` — step-by-step protocol for identifying force clusters from QA artifacts, validation criteria, and cross-skill export format. Load during force cluster identification.

`[eval: contract-extracted]` Extracted contracts cite specific lint rules, test assertions, or CI gates — not abstract statements.
`[eval: force-cluster-organized]` QA recommendations map to identified force clusters, not generic best practices.
`[eval: cicd-optional]` CI/CD proposed only when existing CI infrastructure is present — projects without CI get local-only recommendations.
`[eval: seam-first]` Greenfield: map seams first (Step 1), then hang tests on seams (Step 2). Tests without seam anchors are untethered.
