---
name: validate-prior
mode: enrichment
layer: L1
trigger: always
priority: 1
---

## What This Checks

Before writing new improvements, validates that previous dream changes actually helped. Categories added to failure-journal-hook.sh may be dead code. Tuning conventions written to agents-record-extractor may not have improved extraction quality. Rules that never fire are a rule graveyard — this phase closes the feedback loop on the dream agent's own output.

## Steps

1. **Inventory dream-added artifacts** — find every `# Dream-added:` marker across scripts, agents, and templates:
   ```bash
   grep -rn '# Dream-added:' ~/.claude/scripts/ ~/.claude/skills/ ~/.claude/agents/ 2>/dev/null | \
     sed 's/.*# Dream-added: //' | sort | uniq -c | sort -rn
   ```
   This produces a list of dates and descriptions showing what each dream cycle added.

2. **Check category effectiveness** — find categories the dream agent previously added and count matches:
   ```bash
   # Find dream-added categories in failure-journal-hook.sh
   dream_categories=$(grep -B1 'category=' scripts/failure-journal-hook.sh 2>/dev/null | grep '# Dream-added' || echo "none")
   echo "Dream-added categories: $dream_categories"

   # Count matches per category in recent journals
   echo "=== Category hit counts ==="
   find /tmp -name 'failure-journal-*.jsonl' 2>/dev/null | \
     xargs jq -r '.category' 2>/dev/null | sort | uniq -c | sort -rn
   ```

3. **Check dream-added rule firing** — verify dream-sourced rules in anti-pattern-rules.jsonl have actually matched:
   ```bash
   # Find rules added by dream (tagged with source:dream)
   dream_rules=$(grep 'source:dream' ~/.claude/anti-pattern-rules.jsonl 2>/dev/null || echo "")
   if [ -n "$dream_rules" ]; then
     echo "=== Dream-added rules ==="
     echo "$dream_rules" | jq -r '"\(.id // .name) — matches: \(.match_count // 0)"' 2>/dev/null
   fi

   # Check mulch records from dream enrichment
   echo "=== Dream enrichment records ==="
   ml search "source:dream-enrichment" --json 2>/dev/null | \
     jq -r '.results[] | "\(.id) — \(.description[0:80])"' 2>/dev/null || echo "none"
   ```

4. **Count dream validation history** — how many prior validation cycles have occurred:
   ```bash
   validation_count=$(ml search "source:dream-validation" --json 2>/dev/null | \
     jq '.results | length' 2>/dev/null || echo 0)
   echo "Prior validation records: $validation_count"
   ```

5. **Remove dead categories** — categories with zero matches after 3+ dream cycles (tracked via validation_count) are dead code. Remove them from `scripts/failure-journal-hook.sh`.

6. **Remove unfired rules** — if a dream-added rule has `match_count: 0` and the validation_count shows 3+ prior dream cycles, the rule never proved useful. Remove it and note the removal.

7. **Check tuning convention impact** — read tuning conventions written to agents-record-extractor:
   ```bash
   ml search "source:dream-enrichment" --json 2>/dev/null | jq '.results[]'
   ```
   If a convention hasn't changed extraction behavior (no outcome_status improvements), supersede it.

8. **Compute dream ROI** and record validation results:
   ```bash
   # ROI = rules/categories that fired / total rules/categories added by dream
   # Collect these counts from steps above
   ml record agents-dream --type reference \
     --description "Validation cycle $(date +%Y-%m-%d): <added> artifacts tracked, <fired> proved useful, <removed> dead. ROI: <fired>/<added> (<pct>%)" \
     --classification observational \
     --tags "source:dream-validation,lifecycle:active"
   ```

### Effectiveness Criteria

An artifact counts as:
- **Fired**: appeared in anti-pattern-scan output, matched a failure-journal entry, or was referenced in a hook log since its creation date
- **Useful**: accessed by foxhound search, referenced in a session transcript, or cited in a mulch record since creation
- **Covering**: its detection category matched ≥1 failure-journal entry

An artifact is **dead** when: 3 consecutive validate-prior cycles find zero evidence of fired, useful, or covering. First two cycles mark it "under review" — third cycle removes with a dated archive comment.

## Eval Checkpoints

`[eval: depth]` Validation read actual artifact content (file contents, rule bodies, convention text), not just counted files or checked existence.

`[eval: idempotence]` Running validate-prior twice in succession produces the same result — no double-counting, no re-removal of already-processed artifacts.

`[eval: execution]` Dead artifacts were actually removed or archived with a dated comment, not just logged as "dead" in the digest.

## Improvement Writes

- Remove dead classify() branches from `scripts/failure-journal-hook.sh`
- Remove unfired dream-added rules from `anti-pattern-rules.jsonl`
- Supersede ineffective tuning conventions in mulch
- Record effectiveness metrics and dream ROI to `agents-dream` domain

## Digest Section

```
### Validation (prior dream changes)
- Dream artifacts tracked: N (categories: X, rules: Y, conventions: Z)
- Fired/useful: N | Dead/removed: N
- Dream ROI: N/M (pct%)
- Tuning conventions validated: N effective, M superseded
- Validation cycle: N (of 3 needed before auto-removal)
```

## Recovery

- **On conflicting evidence** (artifact appears dead by metrics but referenced in recent transcript): **escalate** — note in digest, don't remove. Flag for user review.
- **On missing source data** (anti-pattern-rules.jsonl absent, no foxhound index): **degrade** — skip the affected validation dimension, note "partial validation" in digest.
- **On corrupt mulch records**: **resume** — skip corrupt record, continue with remaining. Log skipped record IDs.
