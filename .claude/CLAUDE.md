# Skill Tree & Agent Infrastructure

Claude Code configuration repo: 43 skills, 40 hook/utility scripts, an A/B testing framework, and plugin infrastructure. Everything here shapes how Claude Code sessions behave across all projects.

## Commands

- `bash autoresearch/skill-tree-audit.sh` — full skill tree health scan
- `python autoresearch/run_ab.py` — run A/B experiments on skill variants
- `python autoresearch/grade.py` — grade experiment results
- `bash scripts/anti-pattern-scan.sh` — scan for anti-patterns across skill tree
- `bash scripts/codebase-analytics.sh` — generate cached codebase snapshot

## Seams & Extension Points

- **settings.json** wires hooks to scripts — add new automation here, not in CLAUDE.md
- **skills/<name>/SKILL.md** — each skill is a self-contained file with YAML frontmatter (name + description). Without frontmatter, the skill is invisible to triggering
- **scripts/** — stateless hook scripts. State lives in `.mulch/` and `.seeds/`, not in scripts
- **pipelines.yaml** — pipeline stage definitions consumed by `pipeline-stage-hook.sh`
- **plugins/** — plugin metadata and marketplace configs. `installed_plugins.json` controls what's active

## Subsystem Boundaries

- **autoresearch/** reads `skills/` for evaluation but never modifies them. Has its own `.seeds/`, `.mulch/`, `HANDOFF.md`
- **scripts/** are invoked by settings.json hooks — they don't call each other except through shared cache (`/tmp/codebase-analytics-*`)
- **mcp-servers/foxhound** is an external process — config lives here, runtime is separate
- Data flow: hooks → scripts → `.mulch/` records → `ml search`; `.seeds/` issues → `sd ready` → agent dispatch

## Conventions

- Local `skills/<name>/SKILL.md` overrides the plugin version from `plugins/cache/`. Stubs intentionally suppress unwanted plugin skills (e.g., `writing-skills` is a 5-line stub suppressing the superpowers plugin version)
- `~/.claude/CLAUDE.md` is the GLOBAL file loaded in ALL projects — never put project-specific content there. This file is the project-level slot
- Hook scripts must be idempotent and respect timeouts in settings.json
- Autoresearch `eval-set.json` defines the test corpus, `hypotheses.jsonl` the experiment queue, `baselines.jsonl` the control measurements

## Emergent Multiplexers

Systems that grew into real infrastructure without being designed as one:

- **PostToolUse:Skill is the skill lifecycle bus** — eval-capture, skill-closeloop, hookify rule check, and update-config detection all fire on every skill completion. New "after skill finishes" behavior goes here
- **Anti-pattern pipeline** — `anti-pattern-scan.sh` → `/tmp/` cache → `anti-pattern-query.sh` (3 modes: scan/summary/inject) → `anti-pattern-summary.sh` (SessionStart). Four scripts, one pipeline
- **Override management** — `plugin-override-guidebook.md` + `override-audit.sh` + `override-prefilter.sh` + `.marketplace-base.md` snapshots + three-verdict protocol (Keep/Adopt/Hybrid). Versioned override system with 3-way diff

## Caching Topology

Scripts share state through `/tmp/` caches keyed by git state. Producer must run before consumers.

| Cache | Producer | Consumers |
|-------|----------|-----------|
| `/tmp/codebase-analytics-*` | `codebase-analytics.sh` (sync) | `anti-pattern-summary.sh`, `readme-seam-check.sh` |
| `/tmp/anti-pattern-*` | `anti-pattern-scan.sh` (async) | `anti-pattern-query.sh`, `anti-pattern-summary.sh` |
| `/tmp/enhancer-*` | `prompt-enhancer.sh` | (don't duplicate its file-relevance work) |

## Gotchas

- Deleting a local skill stub resurfaces the plugin version — always check `plugins/cache/` before removing
- `$$` PID scoping: each `bash script.sh` invocation gets its own PID. Hook scripts sharing temp files must use consistent naming, not `$$`
  Format: `/tmp/hook-<scriptname>-<semanticid>` with `.lock` guards for concurrent hooks.
- SessionStart hook order matters — `codebase-analytics.sh` (sync) must run before async consumers. 6 of 14 SessionStart hooks are async and can race
- `prompt-enhancer.sh` is a UserPromptSubmit hook using Haiku — it has a cooldown and gates. Don't duplicate its file-relevance work
  Check `/tmp/enhancer-*` cache before building your own relevance scoring.

## Knowledge Infra (project-specific)

- **Seeds**: `.seeds/issues.jsonl` tracks skill tree work. `sd ready` for unblocked tasks.
- **Foxhound**: patterns tier most relevant for skill/codebook work. Projects tier for reference implementations.
- **Overconfidence fires most here** — training data about Claude Code internals goes stale fast, always verify against current code.
