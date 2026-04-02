---
name: failure-capture
description: Capture and triage failures, surprises, and unexpected behaviors during work sessions. Triggers on [SNAG], unexpected errors, tool failures, approach abandonment, or when a workaround was needed. Records structured failure data to mulch and creates seeds issues for unresolved failures.
---

# Failure Capture

Record failure modes as structured mulch records with cross-project memory. Invoked by the checkpoint sweep after skill completion, by cognitive guardrails when a deviation is caught, or manually when the model recognizes something went wrong.

**Triggers:** checkpoint sweep prompt after skill boundaries, `[SNAG]` self-detection, "record this failure", "what went wrong", or any cognitive guardrail that surfaces a deviation worth persisting.

**Fast path (simple failures, known root cause):** Skip to step 3. Full procedure for complex/unknown failures only.

## 1. Gather Context

Read the session's failure journal if it exists:
```bash
cat /tmp/failure-journal-*.jsonl 2>/dev/null | jq -c 'select(.severity == "error" or .severity == "critical" or .snag == true)' | tail -10
```

If the journal has entries, use them as evidence. If not, work from what the model observed directly.

## 2. Structured Triage

For each failure worth recording, answer these questions (skip ones with obvious answers):

| Question | Maps to |
|----------|---------|
| **What failed?** | `--description` |
| **What did you expect?** | Context for description |
| **What actually happened?** | `--description` (the delta) |
| **Root cause** (if known) | `--resolution` |
| **Which tool/system?** | `--tags "tool:<name>"` |
| **What category?** | `--tags "category:<cat>"` from journal |
| **Is it resolved?** | If yes: include resolution. If no: also create a seeds issue |
| **Would this help in other projects?** | If yes: write a cross-project memory |

## 3. Record to Mulch

Find the nearest `.mulch/` directory. If the failure is in a file, use the project containing that file. Otherwise use the current project.

```bash
ml record failure --type failure \
  --description "<what failed> — expected <X>, got <Y>" \
  --resolution "<fix, workaround, or 'unresolved'>" \
  --classification tactical \
  --tags "tool:<name>,category:<journal-category>,scope:<file-or-module>,prevention:<strategy>"
```

**Prevention field (required):** Every failure record needs a `prevention:` tag — a concrete, actionable strategy, not "be more careful":

| Prevention type | Example |
|----------------|---------|
| `prevention:lint-rule` | "Add a lint rule that catches X pattern" |
| `prevention:type-constraint` | "Narrow the type so invalid states are unrepresentable" |
| `prevention:test-case` | "Add a regression test for this edge case" |
| `prevention:hook-check` | "Add a PreToolUse hook that validates X before Y" |
| `prevention:doc-update` | "Document the constraint that wasn't obvious" |
| `prevention:guard-clause` | "Add runtime validation at the boundary" |

If you genuinely cannot identify a prevention strategy, use `prevention:unknown` — but most failures have a structural prevention.

**Classification guide:**
- `tactical` — one-off failure, specific to this context (default)
- `foundational` — systemic failure likely to recur (promote after 3+ occurrences)

`[eval: context-grounding]` Failure evidence is sourced from journal entries or direct observation — not reconstructed from memory.
`[eval: classification-specificity]` Category and severity are concrete (e.g., "hook-payload/critical"), not vague (e.g., "error/medium").
`[eval: mulch-actionability]` Record has actionable tags (tool, category, scope) — not just a description blob.

## 4. Cross-Project Memory (if generalizable)

If the failure would be useful in other projects (e.g., "hook payload uses `tool_input.command` not `input.command`"), write a memory file:

```bash
# In ~/.claude/projects/<current-project>/memory/
```

```markdown
---
name: failure_<brief-name>
description: <one-line — specific enough to match future queries>
type: feedback
---

<What failed and why>
**Why:** <root cause>
**How to apply:** <when this knowledge prevents a future mistake>
```

Only write cross-project memory when the failure involves Claude Code infrastructure (hooks, payloads, MCP), API contracts that span projects, or tool behavior that's version-dependent.

## 5. Unresolved Failures → Seeds

If the failure is not resolved and `.seeds/` exists:

```bash
sd create --title "Failure: <brief description>" \
  --description "mulch-ref: failure:<record-id>\nCategory: <cat>\nSeverity: <sev>" \
  --type bug \
  --labels "failure-mode,<category>"
```

`[eval: issue-evidence-link]` Seeds issue references the mulch record ID or specific evidence — not a standalone description.

## 6. Resolution Feedback

When a previously recorded failure gets resolved (you fix the root cause), close the loop:

```bash
ml outcome failure <record-id> --status success --notes "<what fixed it>"
```

Then ask: **Is this failure generalizable enough to become a detection rule?**

If yes — the same failure pattern could catch future instances automatically:

```bash
# Propose a candidate anti-pattern rule
cat >> ~/.claude/anti-pattern-rules.jsonl << 'EOF'
{"id":"<descriptive-name>","pattern":"<regex-matching-the-failure-pattern>","negative_pattern":"<regex-for-false-positives>","severity":2,"source":"failure-capture","status":"candidate","added":"<today>","mulch_ref":"<domain>:<record-id>"}
EOF
```

The `status: candidate` means it won't fire in scans until manually promoted to `active`. The `mulch_ref` links it back to the failure that inspired it.

**Promotion criteria:** A candidate rule graduates to `active` when:
- It has been proposed in 2+ separate sessions or projects
- Manual review confirms the pattern has acceptable false-positive rate
- The `source: failure-capture` tag traces its lineage

## Rumsfeld Loop Closure

This skill closes three loops from the Rumsfeld matrix:

1. **UU → KU (Discovery):** Journal entries with `category: uncategorized` or `category: unknown-error` are failures in categories nobody enumerated. Recording them as mulch failures with `category:uncategorized` tags creates a discoverable trail. Periodic review of these records surfaces "category 9" failure types.

2. **KU → KK (Resolution):** `ml outcome --status success` + candidate anti-pattern rule proposal. A resolved failure becomes a detection rule that prevents future instances. The open loop (failure record → resolution → improved detection) is now closed.

3. **UK → KK (Liberation):** Cross-project memory writes (Step 4) make project-local expertise findable via `search_memories()`. The failure discovered in autoresearch becomes visible when working in Field Studio.
