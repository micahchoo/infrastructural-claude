#!/usr/bin/env bash
# claude-md-nudge.sh — SessionStart hook
# Detects missing or stale project-level CLAUDE.md and emits guidelines.

PROJ_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Skip if we're in the home claude dir (global CLAUDE.md collision handled separately)
[[ "$PROJ_ROOT" == "$HOME/.claude" ]] && {
  # For ~/.claude/, check .claude/CLAUDE.md (project-level slot)
  CLAUDE_MD="$PROJ_ROOT/.claude/CLAUDE.md"
  STALE_DAYS=30
  if [[ -f "$CLAUDE_MD" ]]; then
    age_days=$(( ( $(date +%s) - $(stat -c %Y "$CLAUDE_MD" 2>/dev/null || stat -f %m "$CLAUDE_MD" 2>/dev/null) ) / 86400 ))
    [[ $age_days -lt $STALE_DAYS ]] && exit 0
    echo "Project CLAUDE.md is ${age_days}d old. Consider running /claude-md-improver to refresh."
    exit 0
  fi
  # Fall through to full nudge if missing
  :
}

# Check standard locations
for candidate in "$PROJ_ROOT/CLAUDE.md" "$PROJ_ROOT/.claude/CLAUDE.md"; do
  if [[ -f "$candidate" ]]; then
    age_days=$(( ( $(date +%s) - $(stat -c %Y "$candidate" 2>/dev/null || stat -f %m "$candidate" 2>/dev/null) ) / 86400 ))
    if [[ $age_days -ge 30 ]]; then
      echo "Project CLAUDE.md is ${age_days}d old. Consider running /claude-md-improver to refresh."
    fi
    exit 0
  fi
done

# --- No project CLAUDE.md found — emit full nudge ---
cat <<'NUDGE'
This project has no project-level CLAUDE.md. Consider creating one with /claude-md-improver.

## What project-level CLAUDE.md is for

SessionStart hooks inject fresh analytical data (structure, stats, churn, debt).
The prompt-enhancer maps each prompt to relevant files.
CLAUDE.md provides the INTERPRETIVE layer — durable context that makes ephemeral data useful.

## Content guidelines

Four sections, each earns its place or gets cut:

1. **Narrative**: What this project IS and WHY it's structured this way (1-3 sentences)
2. **Commands**: Curated build/test/lint/validate workflows (copy-paste ready)
3. **Conventions**: Decisions that shape work here, not inferable from code
4. **Gotchas**: Things that will surprise an agent if not warned

## How to source information

- `codebase-analytics.sh` for structure/stats → INTERPRET, don't copy
- `anti-pattern-scan.sh` for known issues → summarize recurring themes
- HANDOFF.md for in-flight context and key decisions
- `.mulch/` for accumulated decisions: `ml search "convention"`
- `.seeds/` for project priorities and blocked work
- package.json / Cargo.toml / pyproject.toml for commands and deps
- git log for commit conventions and workflow patterns

## Summarization rules

Summarize for ACTION, not understanding. Every line should change what the agent does.

- **Name names**: "autoresearch/ runs A/B skill experiments" not "there's a testing subsystem"
- **Counts anchor context**: "43 skills, 40 scripts" not "many components"
- **Decisions over facts**: "low test-ratio is intentional — testing uses A/B" not "test ratio is 1/496"
- **Commands over descriptions**: list the command, not what it does
- **Gotchas are specific**: "writing-skills stub suppresses plugin version — don't delete" not "be careful with overrides"
- **One sentence per concept**: if it needs a paragraph, it belongs in README
- **Cut anything one tool call reveals**: don't document what `ls` would show
- **Seams as extension points**: name WHERE to make changes — "settings.json wires hooks to scripts" not "the system is configurable"
- **Subsystem boundaries**: what touches what and what's off-limits — "autoresearch reads skills/ but never modifies them"
- **Data flow in one line**: "hooks → scripts → .mulch/ records → ml search" — the pipeline, not the implementation
- **Coupling warnings**: where surprising coupling exists — "local SKILL.md overrides plugin version — deleting resurfaces the plugin"

## CLAUDE.md vs README.md

| | README.md | CLAUDE.md |
|-|-----------|-----------|
| Audience | Humans browsing the repo | Agent working in the repo |
| Tone | Welcoming, explanatory | Dense, directive |
| Build commands | Explains prerequisites | Just lists them |
| Architecture | Describes for understanding | Interprets for decision-making |
| API/usage docs | Yes | No — agent reads the code |
| Gotchas | If user-facing | If they affect agent work |
| "Don't do X" | Rarely | Core purpose |

Test: would a human contributor need this → README. Would an agent session need this → CLAUDE.md.

readme-seam-check.sh (SessionStart) verifies README claims against ground truth.
If it reports stale or broken README content, that's signal for what needs updating — but fix the README, don't move it to CLAUDE.md.

## Interaction with global CLAUDE.md

The user's global ~/.claude/CLAUDE.md establishes knowledge infrastructure: mulch, seeds, foxhound, context MCP, cognitive guardrails. Project-level CLAUDE.md does NOT re-explain these systems. Instead:

- **Project-specific routing**: which foxhound tiers matter here, which mulch domains exist
- **Infrastructure instances**: "this project uses .mulch/ domains: X, Y" or ".seeds/ templates: pattern-enrichment"
- **Guardrail emphasis**: which cognitive guardrails fire most often in this codebase and why
- **Tool relevance**: which knowledge infra tools are primary vs rarely needed here

Rule: global says HOW to use the tools. Project says WHICH tools matter here and WHEN.

## Eval checkpoints

After generating or updating a project CLAUDE.md, verify:

1. **Action test**: Does every line change what the agent does? Remove lines that only inform.
2. **Redundancy test**: Is anything already in SessionStart output? Cut it.
3. **One-tool-call test**: Would `ls`, `grep`, or `git log` reveal this? Cut it.
4. **Audience test**: Would a human contributor need this more than an agent? Move to README.
5. **Seam test**: Are extension points and modification boundaries documented?
6. **Boundary test**: Are subsystem relationships and off-limits zones clear?
7. **Global overlap test**: Does anything duplicate the global CLAUDE.md? Reference, don't repeat.
8. **Staleness test**: Is every command still valid? Run them.
NUDGE