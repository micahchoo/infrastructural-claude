# Skill Tree

Custom skills for Claude Code. Each skill is a directory with a `SKILL.md` file (frontmatter + workflow) and optional references, scripts, or agents.

## Architecture

```
~/.claude/
  CLAUDE.md                  # Always-on instructions
  settings.json              # Hooks, permissions, env
  pipelines.yaml             # Multi-stage workflow definitions (pipeline-stage-hook.sh)
  references/                # Shared reference material (queryable via claude-skill-tree)
  scripts/                   # Hook scripts + utilities (18 scripts)
  skills/                    # This directory
  plugins/                   # Marketplace plugins (superpowers, skill-creator, frontend-design, etc.)
```

Utility scripts (not hooks — manual or referenced by skill overrides):
- `extract-interfaces.sh` — API surface extraction for subagent prompts (writing-plans)
- `measure-leverage.sh` — infrastructure health scoring (commands-auditor)
- `content-analytics.sh` — doc/vault observability metrics (hybrid-research)
- `scan-secrets.sh` — credential leak detection (verification-before-completion)
- `override-prefilter.sh`, `update-override-version.sh` — plugin override lifecycle (plugin-override-guidebook)

**Context MCP** (library lookups) — `search_packages`, `get_docs` for version-pinned documentation

## Skills

### Implementation & Execution
| Skill | Purpose |
|-------|---------|
| `executing-plans` | Execute written plans in Subagent or Sequential mode |
| `strategic-looping` | Iterative refinement with pause-and-reflect gates |
| `portainer-deploy` | Docker Compose → Portainer stack deployment |

### Research & Analysis
| Skill | Purpose |
|-------|---------|
| `hybrid-research` | Breadth-then-depth across 3+ sources |
| `pattern-extraction-pipeline` | Extract codebooks from reference codebases |
| `pattern-advisor` | Project-specific architectural recommendations |
| `domain-codebooks` | Force-cluster pattern libraries (19 codebooks) |
| `characterization-testing` | Safety-net tests for unfamiliar code |

### Review & Quality
| Skill | Purpose |
|-------|---------|
| `interactive-pr-review` | Paced PR review with `gh` integration |
| `eval-protocol` | Expect/capture/grade for agent decision quality |
| `commands-auditor` | Audit Claude Code Bash permissions |

### Domain-Specific
| Skill | Purpose |
|-------|---------|
| `obsidian-cli` | Obsidian vault operations and OFM syntax |
| `chat-archive-ner-tuning` | NER quality tuning on chat archives |
| `userinterface-wiki` | 152 UI/UX rules across 12 categories |
| `gha` | GitHub Actions failure diagnosis |

### Session Management
| Skill | Purpose |
|-------|---------|
| `handoff` | Proactive HANDOFF.md for session continuity |
| `check-handoff` | Resume from a previous session's HANDOFF.md |

## Cross-Cutting Concerns

Every consuming skill includes two standard lines near the top of its body:

- **Library lookups**: `search_packages` -> `get_docs` for relevant library APIs. Triggered by the phrase "library lookups" in CLAUDE.md and skill bodies.
- **Mulching**: If `.mulch/` exists, prime at start for project conventions, record at end for new patterns.

## Skill Creation

All skill creation and modification is handled by the **skill-creator** plugin (Anthropic official). Local customizations (collision checks, CSO Description Trap, token efficiency, skill types, flowchart conventions) are ported into the skill-creator override. There is no separate local writing-skills skill.

## Plugin Overrides

Superpowers plugin skills are customized via the override system documented in `~/.claude/plugin-override-guidebook.md`. 15 active overrides add eval checkpoints, context MCP library lookups, mulching, merged/deprecated skill redirects, and skill-creation customizations.

## Querying This Tree

The entire `~/.claude/` directory is indexed as `claude-skill-tree@1.1`:
```
get_docs("claude-skill-tree", "<skill-name> workflow")   # Skill process
get_docs("claude-skill-tree", "<skill> trigger")          # Trigger conditions
get_docs("claude-skill-tree", "context mcp reference")    # Package mappings, CLI, query guide
```
