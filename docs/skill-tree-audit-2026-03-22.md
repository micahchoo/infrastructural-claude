# Skill-Tree Infrastructure Audit

**Date**: 2026-03-22
**Scope**: Skill check, creation, override, and indexing infrastructure in `~/.claude/`

## Infrastructure Map

| Component | Path | Role |
|-----------|------|------|
| Skill README | `skills/README.md` | Tree architecture, skill catalog, querying guide |
| writing-skills | `skills/writing-skills/SKILL.md` | TDD-based skill authoring (local override of plugin) |
| skill-creator plugin | `plugins/cache/.../skill-creator/` | Interview-based skill authoring (Anthropic official) |
| config-lens-structural.sh | `scripts/config-lens-structural.sh` | Pre-creation collision check (name, pipeline, trigger overlap) |
| check-plugin-overrides.sh | `scripts/check-plugin-overrides.sh` | SessionStart hook: detects plugin version drift |
| override-prefilter.sh | `scripts/override-prefilter.sh` | Marker-based triage: SKIP vs EVALUATE per override |
| plugin-override-guidebook.md | `plugin-override-guidebook.md` | 15 active overrides, evaluation procedure, test cases |
| pipelines.yaml | `pipelines.yaml` | `skill-creation` pipeline (6 stages) + `atlas-health` pipeline |
| Context MCP index | `claude-skill-tree@1.1` | FTS5 queryable via `get_docs("claude-skill-tree", ...)` |
| tests/ | `tests/` | Only foxhound smoke tests; no skill-specific tests |

## Findings

### 1. CRITICAL: 3 skills exceed the 1024-char frontmatter max

The `writing-skills` skill specifies "Max 1024 characters total" for frontmatter. Three skills exceed this:

| Skill | Description Length |
|-------|-------------------|
| `domain-codebooks` | 1989 chars (nearly 2x max) |
| `system-design` | 1136 chars |
| `obsidian-cli` | 1127 chars |

**Risk**: Claude Code may silently truncate these descriptions, losing trigger keywords. If the platform enforces the 1024 limit, the tail content (often negative triggers / disambiguation) gets clipped.

### 2. HIGH: 20 of 25 skills violate the "Use when..." description prefix

The `writing-skills` skill states: *"Start with 'Use when...' to focus on triggering conditions."* Only 5 skills comply:

- `adversarial-api-testing`, `product-design`, `shadow-walk`, `userinterface-wiki`, `writing-skills`

The other 20 start with noun phrases ("Architectural...", "Project expertise..."), verb phrases ("Extract...", "Diagnose...", "Deploy..."), or descriptive summaries. This is inconsistent with the stated convention, though it's worth noting the `skill-creator` plugin (Anthropic official) does NOT require "Use when..." — it says descriptions should include "what it does AND specific contexts."

**Tension**: The local `writing-skills` and the plugin `skill-creator` give contradictory CSO guidance. This likely explains why most skills don't follow the local convention.

### 3. MEDIUM: 8 skills leak workflow summaries into descriptions (CSO violation)

The `writing-skills` skill warns: *"Descriptions that summarize workflow create a shortcut Claude will take."* These skills include process details:

| Skill | Leaked Phrase |
|-------|---------------|
| `executing-plans` | "two-stage review" |
| `hybrid-research` | "breadth-then-depth" |
| `eval-protocol` | "expect/capture/grade" |
| `mulch` | "structured JSONL records" |
| `product-design` | "vision, design tokens, section specs, data shapes" |
| `characterization-testing` | "pipeline" (in context of extraction pipeline routing) |
| `pattern-extraction-pipeline` | "pipeline" (in name, hard to avoid) |
| `seam-identification` | "pipeline" (cross-reference to extraction pipeline) |

The `product-design` description is the clearest violation — it describes the full pipeline shape. `executing-plans` mentioning "two-stage review" is exactly the anti-pattern the CSO section was written to prevent.

### 4. MEDIUM: 10 additional skills exceed the 500-char recommendation

Beyond the 3 over-1024, these are over 500 chars:

`characterization-testing` (542), `chat-archive-ner-tuning` (579), `executing-plans` (597), `handoff` (530), `interactive-pr-review` (596), `mulch` (757), `pattern-advisor` (783), `pattern-extraction-pipeline` (1022), `seam-identification` (596), `seeds` (713)

13 of 25 skills exceed the 500-char target. These descriptions are loaded into every conversation's system prompt — each extra char is multiplied across all sessions.

### 5. MEDIUM: No skill-specific tests exist

The `tests/` directory contains only foxhound smoke tests. Despite the `writing-skills` "Iron Law" — *"NO SKILL WITHOUT A FAILING TEST FIRST"* — there are zero:
- Pressure scenario baselines
- With-skill vs without-skill comparison runs
- Rationalization capture artifacts

The `skill-creation` pipeline in `pipelines.yaml` defines test stages (baseline-test, iterate), but no artifacts from these stages exist in the repo.

### 6. LOW: Local `writing-skills` shadows plugin `writing-skills` identically

`diff` of the first 30 lines shows no difference. The local `skills/writing-skills/SKILL.md` is byte-identical to the plugin version at `plugins/cache/claude-plugins-official/superpowers/5.0.5/skills/writing-skills/SKILL.md`.

This shadow currently does nothing. When the superpowers plugin updates, the local copy will silently win with stale content — but since there's no actual override, this is just dead weight. Either:
- Remove the local copy (let plugin provide it), or
- Intentionally diverge it (make it a real override and add to the guidebook)

### 7. LOW: Collision check is advisory, not enforced

`config-lens-structural.sh` provides the collision detection referenced by `writing-skills` Pre-creation Collision Check, but:
- No hook runs it before skill creation
- It's a manual `run this script` instruction
- The `skill-creation` pipeline's "intent-capture" stage doesn't reference it

### 8. INFO: Override infrastructure is well-designed

The three-layer override system works well:
1. **Detection**: `check-plugin-overrides.sh` (SessionStart hook) catches version drift
2. **Triage**: `override-prefilter.sh` uses marker strings to separate SKIP from EVALUATE
3. **Procedure**: `plugin-override-guidebook.md` has clear verdicts (keep/adopt/hybrid), diff workflow, and test protocol

15 overrides across 3 plugins (superpowers, skill-creator, frontend-design) are tracked with applied-version metadata.

## Recommendations

1. **Trim the 3 over-1024 descriptions** — `domain-codebooks`, `system-design`, `obsidian-cli`. Move disambiguation content (negative triggers, cross-references) into the skill body's "When to Use" section.

2. **Resolve the CSO guidance conflict** — Decide whether descriptions should start with "Use when..." (writing-skills) or describe "what it does AND when" (skill-creator). Update the losing convention. The skill-creator's "pushy" approach may win on triggering accuracy.

3. **Audit the 8 workflow-leak descriptions** — At minimum fix `executing-plans` ("two-stage review") and `product-design` (full pipeline summary), which are textbook examples of the CSO anti-pattern.

4. **Compress descriptions toward 500 chars** — 13/25 exceed the target. Each conversation pays the token cost. Prioritize the 10 in the 500-1024 range.

5. **Remove or diverge the local `writing-skills` shadow** — It's currently dead weight. If it should diverge, add it to the override guidebook.

6. **Consider a PreToolUse hook for skill creation** — When `Write` targets `skills/*/SKILL.md`, auto-run collision check. Low-cost guardrail.
