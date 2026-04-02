# Contract Signal Reference

QA artifacts are externalized team decisions. Each signal below encodes a force boundary or enforcement posture. Read them as contracts, not metrics.

---

## Signal Interpretation Table

| Signal | What It Reveals | Contract Language |
|--------|----------------|-------------------|
| Suppression spray (scattered, no pattern) | Team silenced a rule without understanding the boundary. Rule is formally on, practically off. | `ignores` |
| Surgical suppression (scoped, documented, few) | Real architectural exception. Module is structurally different. Force boundary, not debt. | `load-bearing` |
| CI gate + `continue-on-error: false` | Hard contract. Check is a merge blocker. Changes must satisfy before ship. | `load-bearing` |
| CI gate + `continue-on-error: true` | Advisory. Team wants signal but hasn't closed the ratchet. Rule added, codebase not yet cleaned. | `conflicted` |
| Coverage threshold present | Team committed to a quality floor. Number encodes velocity/quality tradeoff: 80%+ = quality-first, 40–60% = pragmatic, absent = not a team concern. | `load-bearing` (if enforced) |
| No coverage threshold despite test runner | Coverage can regress silently. Team either hasn't addressed it or chose not to constrain. | `ignores` |
| Snapshot tests dense in one module | Output surface treated as frozen contract. Team decided this API must not change without explicit review. | `load-bearing` |
| Snapshot tests everywhere (spray) | Snapshots used as substitute for purposeful assertions. Regression brake preventing all change, not guarding real contracts. | `conflicted` |
| Pre-commit hooks active | Quality is a contributor gate. Faster feedback loop than CI-only. | `load-bearing` |
| Pre-commit hooks commented out or empty | "We tried and stopped." Infrastructure abandoned — rules too noisy or tooling too slow. | `ignores` |
| Test files co-located with source | Tests grew organically with code. Correlates with purposeful assertions. | `load-bearing` |
| Test files in top-level `tests/` only | Retrofit testing posture. More likely to have orphaned or fragile tests. | `conflicted` |
| `--max-warnings 0` in lint invocation | Zero-tolerance posture. Rule set is authoritative. No warning debt accumulates. | `load-bearing` |
| `eslint-suppressions.json` present (ESLint v9) | Active gradual adoption. Baseline suppression file; team is ratcheting down. Intentional migration. | `conflicted` (transitioning) |
| `ruff select = ["ALL"]` with ignore list | Aggressive posture. Everything on; ignore list reveals known force boundaries explicitly. | `load-bearing` |
| Absent CI lint gate | Advisory posture. Lint is informational; contributors choose whether to address. | `ignores` |

---

## Signal Taxonomy

### Suppression Patterns

**Spray vs Surgical**

Topology matters more than count. Ask: are suppressions concentrated at module boundaries (force boundaries) or scattered inside business logic (debt)?

| Type | Topology | Indicator |
|------|----------|-----------|
| Spray | Scattered across random lines in business logic | Accumulated debt; team gave up on rule uniformity |
| Surgical | Concentrated at a module boundary, documented with comment | Real architectural exception; high-signal force boundary |
| Blanket module-level | Top of file, covers entire module | Either module is genuinely different OR team is batch-suppressing without analysis |

**De-factoring test**: Remove the suppression. If the code still works, it's debt. If 12 modules need restructuring, it's an architectural force boundary.

### CI Gates

| Type | Pattern | Meaning |
|------|---------|---------|
| Hard gate | `continue-on-error: false` (default) | Contract enforced at merge |
| Advisory gate | `continue-on-error: true` | Signal collected, not enforced |
| Missing gate | No CI job for this check | Team hasn't decided, or decided not to gate |

**Enforcement asymmetry**: When Rust/Go is hard-gated and JS/TS is soft-enforced, this is a deliberate (or unconsidered) posture difference by language maturity or tooling confidence. Surface this explicitly.

### Coverage Thresholds

| Threshold | Team Posture |
|-----------|-------------|
| 80%+ | Quality-prioritizing. Coverage is a first-class contract. |
| 60–79% | Balanced. Team has a floor but tolerates gaps. |
| 40–59% | Pragmatic. "Some coverage better than none." Velocity trade is explicit. |
| None configured | Coverage not a team concern, or test suite is symbolic. |

### Test Placement

| Placement | Posture | Risk |
|-----------|---------|------|
| Co-located (`src/.../foo.test.ts`) | Organic, purposeful | Lower risk of orphaned tests |
| Top-level `tests/` only | Retrofit, or separation-of-concerns philosophy | Higher risk of stale/fragile tests |
| Mixed | Team is mid-transition or has inconsistent norms | Requires per-module analysis |

---

## Cross-Artifact Reinforcement Rule

A single signal is a hypothesis. Three signals converging on the same tension is a confirmed force cluster.

| Evidence Level | Threshold |
|---------------|-----------|
| Preliminary | 1 signal type (e.g., suppression concentration alone) |
| Candidate | 2 signal types pointing to same tension |
| Confirmed | 3+ signal types, different artifact types (lint + CI + tests) |

Example: Suppression cluster in module A + fragile snapshot tests in module A + no CI gate for module A = confirmed `rule-boundary tension` cluster.

---

## Real Project Examples

### Excalidraw — Stability vs Agility

- `yarn test:update` exposed as a first-class command: team resolved "tests should catch changes" vs "UI evolves rapidly" by making snapshot updates a workflow step, not an emergency.
- Translation completeness threshold enforced at build time: "partial localization ships" is explicitly rejected as a product contract.
- **Cluster**: `stability-vs-agility` (snapshot update workflow), `completeness-vs-velocity` (translation gate).

### Graphite — Enforcement Asymmetry

- Rust side: `cargo clippy -D warnings` in CI — hard gate.
- JS/TS side: "remember to run before committing" in contributor docs — convention, no hook.
- **Cluster**: `enforcement-asymmetry` — quality contracts differ by language. Either deliberate (Rust tooling is reliable, Svelte ecosystem is not) or unconsidered. Surface as explicit finding.

### Ente — Type-System Enforcement vs Test Enforcement

- Discriminated union with 8 UploadResult variants; optimistic-update guard via `pendingFavoriteUpdates: Set<number>`.
- No tests visible for UI state machines.
- **Cluster**: `type-first vs test-first` — team bet on types as the primary correctness contract. Merge-to-main IS the release gate, so CI is the last line; CI coverage quality is critical to this posture being safe.

### Neko — Intentional Suppression vs Debt Suppression

- `.stop.prevent` on every event handler — looks like suppression spray, IS architectural.
- Remote desktop use case requires intercepting all browser events. The "suppression" is a force boundary enforcement, not debt.
- Comment `// overlay must be focused` encodes a behavioral contract in source rather than in tests.
- **Cluster**: `gesture-disambiguation` (blanket event suppression is load-bearing, not lazy).

### Upwelling/withmd — Testable Determinism vs Integration Reality

- Tests cover markdown parsing and diff normalization (deterministic); multi-stage fallback chain is configuration-driven with no tests.
- `WEB2MD_CACHE_TTL_DAYS` default 30: explicit position on freshness vs consistency tradeoff.
- **Cluster**: `testable-determinism vs operational-complexity` — team tests what they can test well; complex behavior is externalized to config rather than tested.

---

## Consumer Guidance

### characterization-testing

Needs: WHERE to probe, not just WHAT was found.

Read contract signals for:
- **Untested seams at force boundaries**: suppression clusters mark structural complexity. Probe these first.
- **Conflicted contracts**: signals labeled `conflicted` are highest-value targets — behavior is likely surprising here.
- **Co-located test absence**: a source file with no adjacent test and `ignores` coverage posture = unmapped territory.

From `qa-assessment.md`, consume the `## For characterization-testing` section, which must include file paths and module names.

### writing-plans

Needs: a safety net map — which seams are protected, which are unguarded.

Read contract signals for:
- `load-bearing` = protected seam. Changes here have a net.
- `ignores` = unguarded seam. No safety net; plan must include test scaffolding step.
- `conflicted` = fragile net. Tests exist but are unreliable; plan should include stabilization step before changes.

From `qa-assessment.md`, consume the `## For writing-plans` section.

### pattern-advisor

Needs: force cluster framed as a tension (two competing forces), not a finding description.

Required schema from `qa-assessment.md`:
```
{cluster_name, force_a, force_b, evidence_files[], codebook_match_or_null}
```

- `codebook_match`: link to existing codebook pattern if the cluster is already documented.
- `codebook_match: null` → create seeds candidate with label `force-cluster,codebook-gap`.

From `qa-assessment.md`, consume the `## For pattern-advisor` section.

---

## Absence Signal Checklist

Absent signals are as informative as present ones. Explicitly check for:

- [ ] No coverage threshold despite test runner → `ignores` posture on coverage floor
- [ ] No CI lint gate → advisory posture
- [ ] Pre-commit hooks missing or empty → enforcement abandoned or never started
- [ ] No test files in high-churn module → unguarded seam regardless of global coverage
- [ ] `continue-on-error: true` on every CI check → nothing is actually enforced
