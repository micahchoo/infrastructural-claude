---
name: interactive-pr-review
description: >-
  Perform an interactive, paced code review of a pull request — reading diffs,
  flagging issues, and optionally posting feedback via gh.

  TRIGGER when: user wants to review, audit, or inspect a PR's changes as the
  reviewer (e.g., "review PR #123", a GitHub PR URL, examining someone else's
  code before approving).

  DO NOT trigger for: creating a PR; requesting review of your own PR (use
  requesting-code-review); addressing received feedback on your own PR (use
  receiving-code-review). Key distinction: reviewer examining others' code =
  this skill; author seeking or handling feedback = the other two.
---

# Interactive PR Review

Review PRs at the pace the reviewer controls — not a one-shot dump of comments.

**Library lookups**: `search_packages` → `get_docs` for libraries in the diff — verify flagged patterns against current API docs. 2-4 keyword queries.
**Mulching**: If `.mulch/` exists: `mulch prime` for project conventions before reviewing. `mulch record --tags <situation>` conventions discovered during review.
**Foxhound**: Before reviewing, `search("<pr-topic>")` to check for known patterns, conventions, or prior decisions relevant to this PR's domain. Use `search_patterns("<area>")` if the PR touches an area with known architectural forces.

## Start

1. Fetch PR metadata and diff via `gh`
2. Present: title, base/head, commit count, files categorized by risk (core changes vs tests vs config)
4. Ask where to start

`[eval: pr-overview]` PR metadata has been fetched and a categorized file list (risk-ranked) has been presented to the user.

## Pacing

- **<15 files**: file-by-file by default
- **15+ files**: highlight high-risk files first (new files, complex logic, security-sensitive, high churn)
- Let user override: "just the summary", "focus on [area]", "file by file"

`[eval: pacing-plan]` A pacing strategy has been selected (file-by-file or risk-ranked) and the first review target has been identified.

Wait for user input between files. They might dig deeper, ask questions, or move on.

## What to flag (and what to skip)

Flag: logic errors, edge cases, security concerns, missing error handling at boundaries, breaking API changes, test coverage gaps for new behavior.

Skip: style, formatting, naming, missing docstrings — unless user specifically asks.

When something looks off, verify before commenting — read the full file, check callers, check tests. Don't speculate. **Context MCP**: When reviewing code that uses specific libraries, `get_docs("<lib>", "<api>")` to verify whether flagged patterns are correct usage or actual issues — avoids false positives from outdated training data. Query style: 2-4 keywords.

`bias:substitution` — When flagging issues, check: are you reviewing what was actually asked, or substituting an easier review (e.g., nitpicking style instead of evaluating logic correctness)?

`[eval: issue-verification]` Each flagged issue has been verified against the full file, callers, or tests — no speculative flags remain.

`[eval: finding-quality]` Comments reference specific lines and explain *why* something is a problem, not just *what* it is. Review covers the actual change, not surrounding unchanged code.

## Posting feedback

`bias:wysiati` — Before concluding the review, ask: what code paths weren't examined? What callers, error paths, or edge cases might be affected by this change but weren't in the diff?

Gaps found: examine them now, OR `[DEFERRED: specific paths]` as .seeds/ issue.

`[eval: coverage-gap-check]` Unexamined code paths, callers, and edge cases affected by the change have been explicitly identified before concluding.

Confirm with the user before posting — review comments are visible to others. Use `gh pr review` and `gh api` for inline comments.

`[eval: feedback-posted]` User confirmed the review summary before any comments were posted via `gh`.
