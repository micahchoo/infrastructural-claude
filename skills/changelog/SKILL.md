---
name: changelog
description: >-
  Generate user-facing changelogs from git history. Transforms technical commits
  into clear, customer-friendly release notes. Categorizes changes, filters noise,
  and formats professionally. Triggers: "create changelog", "release notes",
  "what changed since", "generate changelog", "update CHANGELOG.md", or as an
  optional step in finishing-a-development-branch when the branch contains
  user-facing changes.
---

# Changelog Generator

Transform technical git commits into polished, user-friendly changelogs.

## When to Use

- Preparing release notes for a new version
- Creating weekly/monthly product update summaries
- Documenting changes for customers
- Writing changelog entries for app store submissions
- As part of `finishing-a-development-branch` for user-facing branches

## Process

### 1. Determine Scope

Identify the commit range:
```bash
# Since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# Between versions
git log v1.0.0..v2.0.0 --oneline

# Date range
git log --since="2026-03-01" --until="2026-03-15" --oneline
```

### 2. Categorize Changes

Read each commit and classify:

| Category | Commits that... | Emoji |
|----------|----------------|-------|
| **New Features** | Add wholly new user-facing functionality | (none by default) |
| **Improvements** | Enhance existing user-facing functionality | (none by default) |
| **Bug Fixes** | Fix user-visible broken behavior | (none by default) |
| **Breaking Changes** | Require user action on upgrade | (none by default) |
| **Security** | Fix vulnerabilities or improve security posture | (none by default) |

### 3. Filter Noise

**Exclude** (do not include in user-facing changelog):
- Refactoring (no behavior change)
- Test additions/fixes
- CI/CD changes
- Documentation-only changes
- Dependency bumps (unless security-relevant)
- Internal tooling changes

**Include selectively:**
- Dependency bumps that fix CVEs → Security category
- Docs changes that affect user-facing help text → Improvements

### 4. Translate Technical to User Language

| Technical commit | User-facing entry |
|-----------------|-------------------|
| `fix: null check in auth middleware` | Fixed issue where some users couldn't log in |
| `feat: add WebSocket support to sync engine` | Real-time sync — changes now appear instantly across devices |
| `perf: batch DB queries in feed endpoint` | Feed loads 2x faster |

**Rules:**
- Lead with what the user gains, not what you changed
- Use active voice ("Added", "Fixed", "Improved")
- Include context when the change isn't self-explanatory
- Quantify improvements when possible ("2x faster", "50% less memory")

### 5. Format

```markdown
# <Project Name> — <Version or Date>

## New Features
- **<Feature name>**: <1-2 sentence description of what users can now do>

## Improvements
- **<Area>**: <What's better and by how much>

## Bug Fixes
- Fixed <user-visible symptom>
- Resolved <user-visible symptom>

## Breaking Changes
- **<What changed>**: <What users need to do>
```

**Omit empty categories.** If there are no breaking changes, don't include the heading.

### 6. Output

Write to the project's changelog file (usually `CHANGELOG.md`) or output for review.

If the project already has a CHANGELOG.md, prepend the new entry — don't overwrite history.

## Tips

- Run from git repository root
- Specify date/version ranges for focused changelogs
- Review and adjust before publishing — generated changelogs are a starting point
- For multi-contributor projects, `git shortlog` helps attribute changes
- When triggered from finishing-a-development-branch, skip for infra/tooling branches (all commits match the noise filter)

