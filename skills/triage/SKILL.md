---
name: triage
description: Interactive review of seeds issues labeled needs-triage — approve, defer, or discard issues created by automated systems before they enter the ready queue. Use when sd-next reports triageable items, or when you want to review pending automated findings.
---

# Triage

Review seeds issues that were created by automated systems (record-extractor, anti-pattern-scan, architecture-staleness) and haven't been human-approved yet. These issues carry the `needs-triage` label and are filtered from `sd ready` / `sd-next` until triaged.

## When to use

- `sd-next` reports "some may need triage"
- After a pipeline run that created automated seeds issues
- Periodic cleanup of the issue backlog

## Process

1. **List triageable items:**
   ```bash
   sd list --label needs-triage --json
   ```

2. **Present each item** to the user with context:
   - Title, description, source (which system created it)
   - Priority and any dependency links
   - Your assessment: is this actionable work or noise?

3. **For each item, get user decision:**
   - **Approve** → remove `needs-triage` label: `sd label remove <id> needs-triage`
     Item becomes visible to `sd ready` and `sd-next`
   - **Defer** → keep `needs-triage`, optionally add context to description
   - **Discard** → close with reason: `sd close <id> --reason "outcome:rework — triaged as not actionable"`

4. **Summary:** Report approved/deferred/discarded counts.

## Label convention

Systems that auto-create seeds issues add `needs-triage` (keeps unvetted items out of `sd ready`):
- `record-extractor` agent: deferred work items from close-loop
- `anti-pattern-scan`: findings promoted to issues
- `architecture-staleness.sh`: stale doc findings

Issues created by the user directly or through `sd create` do NOT get `needs-triage` — they're pre-approved by the act of manual creation.

