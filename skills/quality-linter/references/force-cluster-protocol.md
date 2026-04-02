# Force Cluster Protocol (QA Artifacts)

Adapted from pattern-extraction-pipeline. A force cluster is a confirmed architectural tension that explains multiple QA signals — not a quality metric, but a team decision made visible.

---

## Identification Protocol (6 Steps)

**Step 1 — Find QA seams** (points where team intent is externalized)

| Seam Type | What to Look For |
|-----------|-----------------|
| Suppression sites | `eslint-disable`, `noqa`, `@ts-ignore` — exact location + density + pattern |
| CI gate boundaries | `continue-on-error: true/false` — enforcement threshold |
| Snapshot test density | Which modules, how concentrated |
| Coverage threshold | Numeric floor in config, or absence |
| Test file placement | Co-located vs top-level `tests/` |
| Absent signals | No pre-commit hook, no coverage floor, no CI lint gate |

**Step 2 — Label each signal with competing forces**

For each signal: what two forces is this team navigating?

| QA Signal | Force A | Force B | Candidate Cluster |
|-----------|---------|---------|-------------------|
| Suppression spray (scattered, no pattern) | rule is correct | rule doesn't fit this module | rule-boundary (debt vs architecture — unresolved) |
| Surgical suppression (scoped + documented) | rule is correct generally | this module is structurally different | rule-boundary (confirmed force) |
| High snapshot density in one module | API must not change | internal code can evolve | stability vs agility |
| Snapshot spray (everywhere) | catch all regressions | enable change without breaking | over-stabilization |
| Coverage threshold at 40–60% | some coverage > none | can't afford 80% here | quality floor vs velocity |
| CI gate `continue-on-error: true` | want visibility | can't block on this yet | signal vs enforcement |
| Pre-commit hook commented out | tried enforcement | tooling was too slow/noisy | quality ratchet abandoned |
| Tests co-located | testing is organic | — | healthy signal, not a tension |
| Tests top-level only | testing is separate concern | — | retrofit posture |
| Enforcement asymmetry by language | enforce uniformly | enforce where tooling is reliable | cross-language consistency |

**Step 3 — Group by tension, not by artifact type**

Do NOT produce "test audit + lint audit + formatter audit." Group by force cluster:

- `stability vs agility` — snapshots + frozen APIs + suppressed mutation rules
- `quality floor vs velocity` — low threshold + no pre-commit + suppression spray
- `enforcement vs advisory` — `continue-on-error: true` + warn-not-error lint + no ratchet
- `type enforcement vs test enforcement` — discriminated unions as contracts, no tests for state machines
- `cross-language enforcement asymmetry` — Rust hard-gated, JS soft/convention-only

**Step 4 — Validate by cross-artifact reinforcement**

A force cluster is confirmed only when multiple artifact types point to the same tension.

| Evidence Count | Status |
|---------------|--------|
| 1 artifact type | Preliminary candidate only |
| 2 artifact types, same module | Probable — flag for de-factoring |
| 3+ artifact types, converging | Confirmed force cluster |

Example: suppressions in module A + fragile tests in module A + no CI gate for module A = confirmed cluster.

**Step 5 — De-factor to confirm**

Ask: "If this suppression/gate/snapshot were removed, what breaks?"

- Suppression removed → code still works = debt (not a force boundary)
- Suppression removed → 12 modules need restructuring = architectural force boundary

For QA artifacts: run linter without the suppression (automatable). Count cascade. Cascade > 3 modules = structural.

**Step 6 — Record**

```
# Confirmed cluster:
ml record <domain> --type convention \
  --tags "source:quality-linter,mode:evaluate,lifecycle:discovered"

# Undocumented cluster (codebook gap):
sd create --labels "force-cluster,codebook-gap"
```

Domain names mirror codebooks (`state-management`, `error-handling`), not a generic `testing` domain.

---

## Signal-to-Cluster Quick Reference

| Signal Combination | Likely Cluster |
|--------------------|----------------|
| Suppression spray + no CI lint gate + low coverage threshold | quality floor vs velocity |
| Dense snapshots in one module + suppressed mutation rules | stability vs agility |
| `continue-on-error: true` + warn-not-error lint config | enforcement vs advisory |
| Discriminated unions as state contracts + no tests for state machines | type-enforcement vs test-enforcement |
| Rust CI blocks + JS relies on contributor discipline | cross-language enforcement asymmetry |
| Pre-commit hook commented out + coverage regressing across PRs | ratchet abandoned |
| Co-located tests + coverage threshold 70%+ + `--max-warnings 0` | quality-first posture (no tension — healthy) |

---

## Suppression Topology (Spray vs Surgical)

Count alone is not sufficient. Ask WHERE suppressions appear:

| Topology | Interpretation |
|----------|---------------|
| Scattered within business logic | Debt — rule uniformly applies, team gave up |
| Concentrated at module boundary | Architectural — this module is genuinely different |
| With inline explanation comments | Surgical — intentional force boundary, documented |
| Shrinking across PRs (ratchet file present) | Active migration — not debt, not force boundary |

---

## Validation Criteria Summary

A candidate cluster is real (not noise) when:
1. Two or more artifact types point to the same tension
2. De-factoring confirms structural necessity (not debt)
3. The tension has a name expressible as Force A vs Force B
4. The cluster location is specific (module/file, not "the codebase")

---

## Recording Format

**Mulch record** (confirmed cluster):
```
domain: <codebook-domain>
type: convention
content: "Team resolves [Force A] vs [Force B] by [mechanism]. Evidence: [artifact1], [artifact2]."
tags: source:quality-linter, mode:evaluate, lifecycle:discovered
```

**Seeds issue** (codebook gap — cluster has no matching codebook entry):
```
sd create \
  --title "Force cluster undocumented: <cluster-name>" \
  --labels "force-cluster,codebook-gap" \
  --body "Force A: X. Force B: Y. Evidence files: [...]. Suggested domain: <name>."
```

---

## Cross-Skill Export Format

The `qa-assessment.md` file MUST include named `## For <skill>` sections. These are consumption contracts.

### `## For characterization-testing`

```
- [path/to/module]: untested seam, adjacent to hotspot (churn rank N)
- [path/to/module]: suppression cluster — N eslint-disable in M files, force boundary
- [Contract]: team treats X as load-bearing but tests are fragile (trivial assertions)
```

Characterization-testing needs WHERE to probe (file paths), not abstract descriptions.

### `## For writing-plans`

```
- Protected: [module] — purposeful tests + CI gate + no suppressions
- Unguarded: [module] — no tests, no lint gate, high churn
- Conflicted: [module] — tests exist but fragile, suppression spray
```

### `## For pattern-advisor`

```
- Force cluster: [name], codebook match: [yes/no, codebook-name if yes]
  Force A: [description]. Force B: [description].
  Evidence: [file1, file2]. Suggested domain: [name].
- Codebook gap: [description] → seeds candidate
```

Pattern-advisor needs the cluster framed as two competing forces with evidence files. Schema:
`{cluster_name, force_a, force_b, evidence_files[], codebook_match_or_null}`

### Export invariants

- File title: `# QA Assessment: <project>`
- Location: `.mulch/assessments/qa-assessment.md` or project root
- Contract language: use exactly `load-bearing`, `conflicted`, `ignores` — downstream skills key on these strings
- Every `## For <skill>` section must include file paths, not just descriptions
