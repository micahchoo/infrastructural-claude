---
name: handoff
description: >-
  Proactive session continuity — writes HANDOFF.md so a fresh agent can resume.
  PROACTIVE: When context usage exceeds 60% with substantial remaining work, or
  75% regardless, write HANDOFF.md and recommend a fresh session. EXPLICIT:
  "hand off", "save progress", "start fresh", "pick this up later", "wrap up".
  Also when strategic-looping routes here or message compression is detected.
  NOT for: git commit/push, READMEs, human-to-human knowledge transfer, or
  saving conversation history. "Handoff" = agent-to-agent, not team process.
---

# Session Continuity Protocol

Two modes: **proactive** (you initiate based on context pressure) and **explicit** (user requests).

## Context Pressure Assessment

Run `ctx stats` at natural pause points — if >60%, recommend handoff. The goal is to hand off *before* quality degrades, not after.

### Estimating % used

You can't read a token counter directly, but you can estimate from conversation characteristics:

1. **Know your window** from the model ID in your system prompt:
   - `claude-opus-4-*[1m]` → 1,000,000 tokens
   - `claude-sonnet-4-*` → 200,000 tokens
   - `claude-haiku-4-*` → 200,000 tokens

2. **Estimate consumption** (rough tokens per interaction type):
   - System prompt + loaded skills: ~20,000
   - Each user message + your response: ~1,500
   - Each tool call + result: ~3,000 (small grep/glob) to ~15,000 (large file read)
   - Each subagent dispatch + result: ~3,000
   - Each loaded skill body: ~3,000–8,000

   Tally these up against your window size to get approximate % used.

3. **Hard signals** that override heuristic estimates:
   - **System compression message** ("prior messages compressed") → past ~80%, act immediately
   - **Repeated tool failures or degraded reasoning** → context pressure symptom, act on it

### Decision table

| Estimated usage | Remaining work | Action |
|---|---|---|
| <60% | Any | Continue normally |
| 60–75% | Substantial (5+ tasks, open-ended research, multi-file changes) | **Advisory**: Write HANDOFF.md. Tell user context is filling up, recommend starting fresh soon. Continue if they want. |
| 60–75% | Light (1–2 small tasks) | Continue — you'll likely finish in time |
| 75–85% | Any remaining work | **Proactive**: Write HANDOFF.md. Recommend fresh session now. |
| >85% or compression detected | Any | **Urgent**: Write HANDOFF.md immediately. Tell user to start fresh. |

### Estimating remaining work

Look at these sources:
- **Task list**: Count incomplete tasks (if using TaskList)
- **Plan**: Count remaining steps (if executing a plan)
- **Conversation goal**: What did the user ask for? What fraction is done?
- **Complexity signals**: Are remaining items simple (rename, format) or complex (architecture, debugging)?

The key question: "If I started fresh right now with HANDOFF.md, would total work be less than pushing through with degraded context?" Past 60% with substantial work remaining, the answer is usually yes — a fresh agent with a good handoff is faster than a fatigued one.

## Writing HANDOFF.md

1. Check if HANDOFF.md exists in the project root — read it first if so
2. If the project uses mulch: run `mulch learn` → `mulch record --tags <situation>` to capture conventions discovered this session. Check `mulch query --classification foundational --sort-by-score` for records worth promoting to CLAUDE.md or domain-codebooks.
3. If `.seeds/` exists: `sd list --status in_progress` — include all open issues in the handoff's Progress section. Run `sd update` on each with current session-end state. Close completed issues with `sd close <id> --reason "..."`.
4. Note which `[eval: ...]` checkpoints passed/failed this session — include in "What Worked / What Didn't Work" sections.
5. **Doc freshness checks before handoff:**

   1. **Assumption check:** `ml search "assumption source:brainstorming"` — did any assumptions prove wrong? If so, record the outcome via `ml outcome`.

   2. **README seam check:** If `readme-seam-check.sh` exists: `bash ~/.claude/scripts/readme-seam-check.sh` — include warnings in "Next Steps".

   3. **Stale plan check:** Plans in `plans/` or `docs/superpowers/plans/` that appear fully executed — note "consider archiving" in Next Steps.

   4. **Post-`sd prime` cross-reference:** If `.seeds/` exists, scan blocked issue descriptions for `mulch-ref:` lines. Check referenced decisions via `ml search` — if outcome is `failure`, note it in HANDOFF.md.

6. **Knowledge state capture** (so the next agent doesn't re-discover sources):

   1. **Indexed packages:** Run foxhound `sync_deps` to snapshot indexed state. Note any packages manually added via `context add` this session.
   2. **Productive search tiers:** Which foxhound tiers returned useful results? Only note non-obvious ones — skip if default `search` routing was sufficient.
   3. **Knowledge gaps:** Queries that returned no useful results, or libraries that needed `context add` but weren't indexed.

7. Create or update with these sections:

```markdown
# Handoff

## Goal
[The user's original request in their words, not your interpretation]

## Progress
- ✅ Completed item (path/to/file:L10-L50)
- 🔄 In progress item — state reached, what remains
- ⬚ Not started item
[If feature_list.json exists: "Acceptance: X/Y passing (Z%)"]

## What Worked
[Approaches, tools, patterns that succeeded — so the next agent reuses them]

## What Didn't Work
[Failed approaches with brief reason — so the next agent doesn't repeat them]

## Key Decisions
[Decisions made and rationale — so the next agent doesn't re-debate them]

## Trajectory
[The story of how we got here — what artifacts alone don't convey]

**How we got here** (1 paragraph): Narrative arc from starting state to current state.
Cover the pivots, not the routine steps. A fresh agent reading this should
understand *why* the codebase looks the way it does now, not just *what* it contains.

**Hard calls**: Decisions where alternatives were seriously considered or the
choice felt uncertain. What was the tension? What tipped it?

**Shaky ground**: Assumptions that haven't been validated, or were validated
weakly. Things that worked but you're not sure *why* they worked.

**Invisible context**: What you learned that isn't in any file — runtime
behavior observed, undocumented API quirks, performance characteristics,
user intent that shaped choices but isn't written down anywhere.

## Active Skills & Routing
[Which skills were invoked and why — so the next agent doesn't re-discover workflow]
- skill-name: why it was active, what phase/state it reached
- Checkpoint results: any eval-protocol grades or verification outcomes
- Pending routing: skills the next task needs (per strategic-looping forward-look)

## Infrastructure Delta
[What changed in .claude/ this session — so the next agent knows what's new vs inherited]
- Plugins: [versions that changed, or "unchanged"]
- Hooks: [added/removed/modified, or "unchanged"]
- Skills: [created/modified, or "unchanged"]
- Pipelines: [stages added, or "unchanged"]
- Overrides: [reapplied/dropped, or "unchanged"]

To populate: run `~/.claude/scripts/config-lens-structural.sh` and diff against
the SessionStart codebase-analytics output. Only note what CHANGED — skip unchanged sections.
If nothing changed, write "No infrastructure changes this session."

## Knowledge State
[What the next agent needs to find information — so they don't re-discover sources]
- Indexed: [packages added via `context add` this session, or "none"]
- Productive tiers: [foxhound tiers that returned useful results, or "default routing sufficient"]
- Gaps: [queries/libraries with no indexed docs, or "none encountered"]

## Next Steps
1. First thing to do (with expected approach)
2. Second thing (note any dependencies or blockers)

## Context Files
- path/to/file — why it matters (3-5 files the next agent should read first)
```

8. Save as HANDOFF.md in the project root
9. Tell the user the file path and recommend: *"Start a fresh conversation and point it at HANDOFF.md to continue."*

`[eval: approach]` HANDOFF.md captures goal in user's words, not agent interpretation.
`[eval: depth]` Progress section includes file paths with line references for completed items.
`[eval: completeness]` Next Steps section covers all remaining work with expected approach for each.
`[eval: knowledge-state]` Knowledge State section captures indexed packages, productive tiers, and gaps — or explicitly states none.
