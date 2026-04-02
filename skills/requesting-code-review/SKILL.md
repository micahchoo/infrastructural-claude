---
name: requesting-code-review
description: >-
  Use when completing tasks, implementing major features, before merging to
  verify work meets requirements, finishing a branch, or landing work. Triggers
  on: "request review", "finish branch", "land this", "merge this", "done with
  implementation", "ship it". Do NOT trigger for: brainstorming features or
  exploring requirements before implementation (use brainstorming); writing
  implementation plans (use writing-plans); reviewing pull requests you didn't
  author (use interactive-pr-review); routine git operations without landing
  intent (use git commands directly).
---

# Requesting Code Review

**Init**: `mulch learn` if `.mulch/` exists — record new conventions/failures at end, close the loop on any applied `ml search` advice.

Dispatch a code-reviewer subagent with precisely crafted context for evaluation — not your session history. This keeps the reviewer focused on the work product and preserves your context for coordination.

## Landing Decision

Before diving into review mechanics, determine how this work should land.

**Ask:** "How do you want to land this work?"

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed until tests pass.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Present Options

```
Implementation complete. What would you like to do?

1. PR for review → code review then merge (continues below)
2. Merge directly → merge to <base-branch> locally
3. Cleanup/defer → keep branch, stash, or discard

Which option?
```

### Option 1: PR for Review

Flows into the **Requesting Code Review** process below.

After review is approved:
```bash
git push -u origin <feature-branch>
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree if applicable (see Worktree Cleanup below).

### Option 2: Merge Directly

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch (squash decision: ask user)
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree if applicable (see Worktree Cleanup below).

### Option 3: Cleanup/Defer

Present sub-options:
- **Keep as-is:** "Keeping branch <name>. Worktree preserved at <path>." Don't cleanup worktree.
- **Discard:** Confirm first:
  ```
  This will permanently delete:
  - Branch <name>
  - All commits: <commit-list>
  - Worktree at <path>

  Type 'discard' to confirm.
  ```
  Wait for exact confirmation. If confirmed:
  ```bash
  git checkout <base-branch>
  git branch -D <feature-branch>
  ```
  Then: Cleanup worktree.

**Outcome tracking — validate decisions and conventions:**

After work passes review and before/after landing:

1. Search for decisions and conventions that scoped this work:
   ```bash
   ml search "source:brainstorming scope:<module>"
   ml search "source:writing-plans scope:<module>"
   ```

2. For each found record, evaluate: did this decision/convention hold up during implementation?
   ```bash
   # If it held up:
   ml outcome <domain> <id> --status success --notes "Applied in this PR, held up during implementation"

   # If it didn't:
   ml outcome <domain> <id> --status failure --notes "<what went wrong>"
   ```

3. Check if a spec file was referenced by the plan. If the feature passes review:
   - Flag: "Spec at `<path>` covers shipped feature — recommend updating frontmatter to `status: implemented`."

`[eval: outcomes]` At least one ml outcome recorded for decisions/conventions that scoped this work.

### Worktree Cleanup

**For Options 1 (after merge), 2, and Discard:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

### Quick Reference

| Option | Review | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|--------|-------|------|---------------|----------------|
| 1. PR for review | ✓ | - | ✓ | ✓ | - |
| 2. Merge directly | - | ✓ | - | - | ✓ |
| 3a. Keep as-is | - | - | - | ✓ | - |
| 3b. Discard | - | - | - | - | ✓ (force) |

---

## Pre-Review Quality Pass

Before requesting review, run `/simplify` to review changed code for reuse, quality, and efficiency. This catches low-hanging issues before the reviewer sees them.

## UI Quality Audit

When changed files include UI code (files matching `*.svelte|*.tsx|*.jsx|*.vue|*.css|**/components/**`),
add two review steps before the landing decision:

If changes affect user-facing rendering but filename doesn't match the glob, run UI audit anyway.

**Step A: userinterface-wiki rule audit**

Load `userinterface-wiki` skill and audit changed files against applicable rule categories:

| Changed code contains | Audit against |
|---|---|
| Animation, transition, keyframe | Animation Principles (CRITICAL) + Timing Functions (HIGH) |
| CSS properties, pseudo-elements | Visual Design (HIGH) + CSS Pseudo Elements (MEDIUM) |
| Interactive elements, buttons, links | Laws of UX (HIGH) |
| Font, text styling, typography | Typography (MEDIUM) |
| Audio, sound | Audio Feedback + Sound Synthesis (MEDIUM) |

Report findings as `file:line violates <rule-id>` (e.g., `src/Button.svelte:42 violates timing-under-300ms`).

**Step B: shadow-walk regression**

Run a targeted shadow-walk (regression scope) on user flows touching the changed files.
This catches UX-level issues (dead ends, silent failures, nav traps) that rule-by-rule
auditing misses.

**NOT triggered for**: Backend-only changes, docs, config files, test files.

`[eval: ui-audit]` UI changes were audited against userinterface-wiki rules before landing decision.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

```bash
# --- PR scaffold (fill in blanks) ---
BASE_SHA=$(git merge-base HEAD main)
HEAD_SHA=$(git rev-parse HEAD)
TITLE="$(git log --oneline $BASE_SHA..HEAD | head -1 | cut -d' ' -f2-)"
git diff $BASE_SHA..HEAD --stat
git log --oneline $BASE_SHA..HEAD
```

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer subagent:**

Use Task tool with superpowers:code-reviewer type, fill template at `code-reviewer.md`

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch superpowers:code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Guardrails

- "Simple" changes still break things — review catches what familiarity obscures
- Critical issues get fixed now; Important issues before proceeding; Minor issues noted for later
- Tests pass before offering landing options — merging broken code wastes everyone's time
- Typed "discard" confirmation before deleting work — accidental deletion is irreversible
- Worktree cleanup only on merge and discard paths — keep-as-is preserves the escape hatch
- If the reviewer is wrong, push back with technical reasoning and evidence, not deference
- For self-reviewing your own diff before requesting external review, consider `/interactive-pr-review` first

See template at: `requesting-code-review/code-reviewer.md`
