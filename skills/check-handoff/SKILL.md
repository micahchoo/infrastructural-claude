---
name: check-handoff
description: >-
  Resume work from a previous session's HANDOFF.md. Reads it, validates
  referenced files exist, summarizes state, proposes a session plan.

  Triggers: "check handoff", "resume", "pick up where we left off",
  "continue from last session", "/check-handoff", or starting in a
  directory with HANDOFF.md.

  NOT for: writing handoffs (use handoff skill), general onboarding,
  or resuming from git history alone.
---

# Check Handoff

1. **Find & read** HANDOFF.md in project root or parent dirs
2. **Validate** — spot-check that referenced files/scripts/artifacts still exist. Flag missing items.
3. **Seeds context** — if `.seeds/` exists: `sd prime` then `sd ready` to find unblocked work. Claim issues you'll work on with `sd update --assignee "agent"`.
3b. **App dev bootstrap** — if `init.sh` exists: run `chmod +x init.sh && ./init.sh` to bootstrap the dev environment. If `feature_list.json` exists: count passing/total and report progress. Then regression-test 2-3 existing `passes:true` features (using Playwright if available, else curl) to verify no silent breakage. Fix regressions before new work.
4. **Freshness** — check if "in progress" items were completed since (file mtimes, git log). Flag stale decisions.
5. **Summarize** — synthesize (don't regurgitate): what was done, what remains, blockers resolved, stale items
6. **Open questions** — if HANDOFF.md references a plan, check its `## Open Questions` section. Surface any unresolved questions from the prior session — they need hybrid-research before resuming execution.
7. **Plan this session** — scope what fits in context budget, sequence by dependencies, define "done" criteria, flag if another handoff will be needed
8. **Restore knowledge context:**
   a. **Skills & libraries:** If handoff mentions active skills, refresh via `get_docs("claude-skill-tree", "<skill-name>")`. For library-specific work, check `search_packages` for pre-indexed docs.
   b. **Knowledge state:** If HANDOFF.md has a `## Knowledge State` section:
      - Run foxhound `sync_deps` for the project root to ensure dependencies are indexed.
      - If "Gaps" lists missing packages, attempt `context add` for critical ones before starting work.
      - If "Productive tiers" lists specific foxhound tiers, note them for search routing this session.
      - Run foxhound `health` to verify the search layer is operational.
      If no Knowledge State section exists, run `sync_deps` anyway — it's cheap and prevents re-discovery.

9. **Infrastructure drift** — if HANDOFF.md has an `## Infrastructure Delta` section listing what changed last session, run `~/.claude/scripts/config-lens-structural.sh` and compare:
   - Plugin versions: did any update since the handoff? Override status may be stale.
   - Hooks: were any added/removed? The handoff's routing assumptions may not hold.
   - Skills: were any created/modified? The handoff's skill references may be outdated.
   - Report drift to the user before proceeding. If no Infrastructure Delta section exists, skip this step.

Trust prior findings unless validation shows staleness. Honor prior decisions unless new info invalidates the rationale. Be strategic about which context files to load now vs later.

`[eval: knowledge-restored]` Knowledge infrastructure verified: sync_deps ran, gaps addressed or noted, foxhound operational.
`[eval: no-rediscovery]` Session plan accounts for knowledge state from handoff — doesn't re-investigate what prior session already mapped.
`[eval: regression-clean]` When feature_list.json exists, existing `passes:true` features were regression-tested before new work began — regressions fixed or flagged.

## Validation Checklist

Run these checks before proposing a session plan. Each catch prevents wasted work on stale assumptions.

- **Referenced files exist**: For every file path in HANDOFF.md, verify it exists on disk. Flag deletions, renames, or moves since the handoff was written. Use `git log --diff-filter=D --name-only` to check for recently deleted files.
- **Git state matches expectations**: Confirm the current branch, last commit, and working tree state align with what the handoff describes. Surface discrepancies before proceeding.
- **Seeds/mulch state if mentioned**: If the handoff references specific issue IDs, verify they still exist and have the expected status (`sd show <id>`). If it mentions mulch decisions, run `ml prime` and confirm the referenced records are present — compaction or pruning may have removed them.
- **Commands still work**: If the handoff includes shell commands (build, test, serve), dry-run or `--help` check at least the critical ones. Dependency updates, removed scripts, or changed env vars can silently break them.
- **Artifact integrity**: If the handoff mentions generated outputs (built artifacts, coverage reports, eval results), check timestamps. Stale artifacts from a prior session can mislead — regenerate if older than the latest relevant commit.
- **Environment assumptions**: If the handoff assumes specific env vars, running services, or tool versions, verify them. `which <tool>`, `<tool> --version`, and `env | grep <VAR>` are fast sanity checks.

**Same-session resume:** Did plan change? Context OK? Full checklist only on fresh session.
