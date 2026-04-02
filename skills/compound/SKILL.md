---
name: compound
description: Capture knowledge from the current session on demand — decisions, conventions, failures, observations. User-invocable complement to the automatic close-loop extraction by record-extractor. Use when you want to explicitly document learnings mid-session without waiting for pipeline completion.
---

# Compound

Extract and record knowledge from the current session's work. This is the manual trigger for what record-extractor does automatically at pipeline close.

## When to use

- Mid-session when you've learned something worth preserving (pattern, decision, failure)
- After completing a significant piece of work but before the pipeline closes
- When the user says "capture this", "document what we learned", "compound"

## Process

1. **Scan session artifacts:** Recent git diff, design docs written this session, `[SNAG]` markers, `[NOTE]` markers
2. **Dispatch record-extractor:** Use the Agent tool to dispatch the `record-extractor` agent with the session artifacts as context. For mulch record types (convention/pattern/failure/decision/reference/guide) and classification tiers, load `mulch/references/record-types.md`.
3. **Report:** Summarize what was recorded (decisions, conventions, failures, seeds issues)

## What gets captured

Same extraction logic as record-extractor at close-loop:
- **Decisions** from brainstorming, product-design → mulch decision records
- **Conventions** from quality-linter, code-review → mulch convention records
- **References** from research-protocol, hybrid-research → mulch reference records
- **Failures** from `[SNAG]` markers, approach changes → mulch failure records
- **Observations** from `[NOTE]` markers → mulch records (type inferred from content)
- **Deferred work** → seeds issues with "deferred" label. For issue lifecycle (status flows, dependency management, blocker mechanics), load `seeds/references/issue-lifecycle.md`.
- **Completed work** → seeds close for in_progress issues

This skill dispatches record-extractor (the agent that does actual extraction). The close-loop gate fires record-extractor automatically at pipeline end — this skill is the manual complement. For failure-specific capture, use failure-capture instead.
