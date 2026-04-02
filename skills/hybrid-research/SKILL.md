---
name: hybrid-research
description: >-
  General-purpose research workflow: frame testable questions, scavenge existing
  knowledge, fan out independent threads, synthesize against original questions,
  cut noise. Use for: tracing systems across files, comparing approaches, codebase
  onboarding, cross-referencing docs, evidence gathering before hypothesis, or
  any investigation requiring 2+ sources. Distinguishing test: if one tool call
  answers it, skip this. If correlating multiple sources is needed, use this.
  If you have 3+ independent research tracks needing structured agent dispatch,
  escalate to research-protocol.
---

# Hybrid Research

**Init**: `mulch prime` if `.mulch/` exists. `sd ready` if `.seeds/` exists. `sync_deps(root)` if a package manifest exists. If HANDOFF.md has a Knowledge State section, use its productive tiers and address gaps before framing questions.

## 1. Frame

For questioning techniques (divergent thinking, constraint surfacing, gray-area classification), load `eval-protocol/references/questioning-techniques.md`.

Write your research questions as testable statements. "Can I identify which library handles X and its API surface?" not "understand X." If you can't tell whether a question is answered, rewrite it.

Each question gets:
- 2-4 FTS5 keyword queries (not natural language)
- An output statement: "I'll know this is answered when..."

`bias:substitution` — Are you researching the actual question, or a related question that's easier to search for?

`[eval: criteria-precommit]` Output statements are outcome-based ("I can name the specific function and its signature"), not procedural ("I searched 3 sources").

## 2. Scavenge

Before searching anywhere external, check what you already have. This is the step people skip and then waste half their research re-discovering what's in front of them.

**Sources to check (in order):**
1. **Foxhound** `search("<topic>", project_root=root)` — broadest net, start here.
2. **Context MCP** `search_packages` → `get_docs` — pre-indexed library docs (~350ms).
3. **Local files** — Glob + Grep for touchpoints in the codebase.
4. **Mulch** — prior decisions and expertise already recorded.

Cross off anything already answered. Index any libraries you'll need but haven't indexed (`search_packages` → `download_package` or `context add <url>`).

**Codebook gap**: If foxhound returns thin results for a domain with competing forces: `~/.claude/scripts/codebook-gap.sh record "Force: X vs Y vs Z" "Leads: [repos/files seen]. Context: [what you were doing]"`

`bias:availability` — Are your sources from 3+ distinct types (local code, indexed docs, web, mulch, reference projects)? If they cluster in one type, you're searching where it's easy, not where the answer lives.

`[eval: target]` Sources from 3+ domains identified.
`[eval: no-rediscovery]` If handoff Knowledge State existed, productive tiers and gaps informed the search cascade — didn't re-discover what the prior session already mapped.

## 3. Fan Out

For convergence discipline (quality ratchet, 3-iteration cap, runaway detection), load `strategic-looping/references/convergence.md`.

Group remaining questions by independence: can they be answered without each other's results? If yes, research them in parallel. If no, sequence them.

Each thread's job is to **record findings, not propose solutions.** Null results and contradictions both count as findings.

**Thread execution:**
- Execute your queries through the search cascade: foxhound → indexed docs → local files → web.
- When a query surfaces unexpected vocabulary, re-search with that vocabulary.
- When sources contradict, record both positions with dates/versions.
- **Web sources**: Use WebFetch on 3+ sources in parallel when local/indexed sources are insufficient.

**Stop condition for each thread:** Stop when you've exhausted your queries, hit 2 consecutive null results on refined queries, or the same results keep appearing from different search terms — you've converged.

**Escalation trigger:** If you have 3+ independent tracks that each need their own agent dispatch, switch to `/research-protocol` which adds journal templates, orthogonality checks, and structured multi-agent orchestration.

`[eval: depth]` At least one source read beyond its summary/abstract.
`[eval: sequence]` Same query not repeated with minor rewording >2 times.

## 4. Synthesize

Merge everything back against your original questions. For each one: **answered**, **partially answered**, or **still open**? Flag contradictions rather than resolving them prematurely.

**Cross-reference rule**: Before acting on a pattern you found, confirm it appears in 2+ sources. One source can be wrong, outdated, or context-specific.

`bias:wysiati` — What evidence is missing? What would someone who disagrees with your emerging conclusion point to?

**Partial results record:** `## Found: ___ | Confidence: high/medium/low | Gaps: ___ | Next steps: ___`

`[eval: completeness]` Every original question has an explicit status (answered/partial/open).

## 5. Cut

Drop low-confidence findings. If a finding wouldn't change a decision you're about to make, it's noise. Anchor this to the downstream consumer: if this feeds a plan, cut findings that don't map to a requirement. If this feeds a debug session, cut findings that don't narrow the hypothesis space.

**Produce**: Novel findings not already in mulch: `ml record --type reference --tags "discovery,<domain>" --classification observational --evidence-file <source>`.

## Research Termination

| Signal | Action |
|--------|--------|
| Same results from refined queries | Converged — move to acting. |
| Core question answered + cross-validated | Done. State what you found and the sources. |
| 3 depth reads without progress | Wrong thread. Fresh breadth sweep with new terms. |
| Sources contradict each other | Flag it, check dates/versions, investigate discrepancy. |
| New concept discovered during depth | Surface to breadth — search for this term across all indexed sources. |
| Architecture patterns recurring across 3+ sources | Route to `/pattern-extraction-pipeline` to formalize as a codebook. |
| Existing codebook covers this domain | `get_docs("domain-codebooks", "<force-cluster>")` — synthesize from indexed content. |

## Codebase Onboarding Mode

When the trigger is "onboard to codebase", "map this codebase", or "understand this project":

**Step 0: Content survey and auto-index.** Run `~/.claude/scripts/content-analytics.sh .` to get a 0-shot content profile. If the output shows `RECOMMENDED` for Context MCP indexing (50+ markdown files), build a project-level index:
```bash
context add . --name "$(basename $PWD)" --pkg-version 1.0
```
This index feeds query refinement — prose-heavy projects (ADRs, design docs, wikis) become searchable via `get_docs("<project-name>", "<topic>")` instead of multi-Grep discovery.

**Step 1: Structured mapping.** Use the 7-document schema from `~/.claude/skills/codebase-diagnostics/references/codebase-mapping-schema.md`.

Dispatch 4 parallel Explore agents (tech/arch/quality/concerns), each writing documents directly. Orchestrator collects only confirmations + line counts.

Run `~/.claude/scripts/scan-secrets.sh` on all generated documents before any commit.

`[eval: shape]` Output follows 7-document schema when trigger is codebase onboarding.
`[eval: completeness]` Each document contains 3+ specific file paths with backtick formatting.
`[eval: efficiency]` Orchestrator context contains only confirmations, not document contents.
