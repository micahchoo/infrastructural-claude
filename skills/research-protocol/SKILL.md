---
name: research-protocol
description: >-
  Structured multi-track research orchestration for 3+ independent investigation
  tracks. Adds formal machinery on top of hybrid-research: prerequisite gates,
  numbered research plans, journal templates, orthogonality checks, and
  multi-agent dispatch with structured composition. Use when hybrid-research's
  Fan Out step would produce 3+ independent agent dispatches. Do NOT use for:
  single-source lookups (use get_docs), 1-2 track investigations (use
  hybrid-research), codebase exploration (use hybrid-research onboarding mode),
  pattern extraction (use pattern-extraction-pipeline), or implementation
  planning (use writing-plans).
---

# Research Protocol

Structured orchestration layer on top of hybrid-research. Use this when you have 3+ independent research tracks — it adds the machinery that prevents agents from duplicating work, proposing solutions instead of reporting findings, or missing cross-track connections.

hybrid-research owns the core workflow (Frame → Scavenge → Fan Out → Synthesize → Cut). This skill owns the **orchestration structure** for the multi-agent case.

## Prerequisite Gates

These extend hybrid-research's Frame and Scavenge steps. Each gate is a one-line test — if it fails, do the thing in the right column.

| Gate | Done test | If missing |
|------|-----------|------------|
| **Requirements** | File exists with numbered, testable requirements (no solution-shaping) | Invoke brainstorming → /simplify (recs only) → /eval-protocol to grade |
| **Existing capabilities audited** | Requirements doc has "Existing Capabilities" section referencing what's already built | Run hybrid-research Step 2 (Scavenge). Catalog what exists. |
| **Research plan with tracks** | Questions have Q-numbers, grouped into tracks with goal statements, each question has an output statement | Write from requirements: "what must I learn from external systems to satisfy this?" Group by domain. |
| **Queries assigned** | Each question has a queries block (2-4 keyword FTS5, 3+ source types per track) | Follow hybrid-research query design (Step 1 output statements) |
| **Libraries indexed** | `get_docs("<lib>", "<keyword>")` returns results for each referenced library | Index missing ones via `search_packages` → `download_package` |

`[eval: criteria-precommit]` Before dispatching agents, define what a complete research output looks like per track — outcome conditions ("Q1 is answered when I can cite a specific API method and version"), not procedural stop conditions ("queries exhausted").

## Pipeline

### 1. Partition into orthogonal agents

Split tracks into agents with no shared state. Orthogonality test: can agent A complete without agent B's output? If not, merge or sequence.

- Group by source overlap (3+ shared libraries → merge)
- Group by question dependency
- Cap: 4-5 agents, 3-10 questions each
- Move the orthogonality test upstream into your research plan — catching it here is late

### 2. Dispatch with journal template

Use dispatching-parallel-agents. Each agent receives the journal template from `references/journal-template.md` as its prompt structure. Each agent runs hybrid-research Steps 3-4 (Fan Out + Synthesize) on its assigned track. Agent instructions:

- Execute every query. Null results are findings.
- When a query surfaces unexpected vocabulary, re-search with that vocabulary.
- When sources contradict, record both positions.
- Free exploration: max 3 threads per agent, 8 threads total across all agents.
- **Record what you found, not what you'd build.** The composition layer makes decisions.
- **Stop condition**: Exhausted queries, or 2 consecutive null results on refined queries.

### 3. Compose journals into synthesis

After all agents return, the **orchestrator** (you) merges findings — this is hybrid-research Step 4 (Synthesize) applied across agents. Two sections:

**Requirement-Fit:** For each requirement — what did research find that supports, challenges, or refines it? Which agents contributed? The orchestrator decides whether requirements need revision.

**Open Questions:** What couldn't be answered, what emerged from free exploration, what contradictions need resolution, where to look next.

**Cycles 2+:** Delta-only findings — report what changed since last cycle, not full findings.

**Stop condition checkpoint:** All requirement Qs answered? ✓/✗ | 2+ sources per finding? ✓/✗ | No new contradictions? ✓/✗ | Confidence > threshold? ✓/✗ → All ✓ = stop. Any ✗ = one more cycle. Cap: 3 cycles with ✗ → stop, record gaps.

`[eval: operationalize]` Synthesis claims must cite specific findings — agent ID, question number, source path/URL. "Research suggests" without a source reference is not a finding.

**Claim verification** (recommended for synthesis with specific factual claims):
Before grading, dispatch the gate-enforcer agent in `claim-verification` mode to verify factual claims from research agents — file paths, API behaviors, version numbers:
- Agent: `gate-enforcer`
- Prompt: `"Gate mode: claim-verification. Claims: <key factual claims from synthesis>. Verify each by reading actual source. Return: verification table."`

### 4. Quality pipeline

Run hybrid-research Step 5 (Cut) on the synthesis, then `/simplify` (recommendations only), then `/eval-protocol` to grade each recommendation. Surface A/B-grade findings.

`[eval: track-orthogonality]` Research tracks are actually independent — agent A can complete without agent B's output. If not, tracks were merged or sequenced.
`[eval: claims-grounded]` Synthesis claims cite specific track findings (agent, question number, source), not abstract summaries.
