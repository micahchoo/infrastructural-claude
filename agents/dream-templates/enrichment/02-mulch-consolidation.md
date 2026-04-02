---
name: mulch-consolidation
mode: enrichment
layer: L1
trigger: always
priority: 2
---

## What This Checks

Mulch records accumulate across sessions without consolidation. Redundant records inflate search results. Contradictory records confuse future agents. Records without outcomes represent uninspected work.

## Steps

1. **Read** all mulch records without outcomes across all domains:
   ```bash
   ml search "lifecycle:active" --json 2>/dev/null | \
     jq '.results[] | select(.outcome_status == null)'
   ```

2. **Identify** redundant records — same description from different sessions.

3. **Merge** redundant records: keep the most detailed, supersede others:
   ```bash
   ml edit <domain> <id> --tags "lifecycle:superseded"
   ```

4. **Resolve** contradictions: if two records disagree, flag for human review.

5. **Enrich agent tuning**: compute outcome ratios per source skill, write tuning conventions:
   ```bash
   ml record agents-record-extractor --type convention \
     --description "<extraction pattern X> produces <ratio>% useful records — <adjust/maintain>" \
     --classification tactical \
     --tags "source:dream-enrichment,lifecycle:active"
   ```

## Eval Checkpoints

`[eval: completeness]` All active-lifecycle records in the target domain were reviewed, not just a sample.

`[eval: boundary]` Only modified records in the target mulch domain — didn't touch other domains' records.

## Improvement Writes

- Supersede redundant mulch records
- Flag contradictions for human review
- Write tuning conventions to `agents-record-extractor` domain

## Digest Section

```
### Mulch
- Records reviewed: N | Merged: N | Contradictions: N
- Tuning conventions written: N
```

## Recovery

- **On corrupt JSONL records**: **resume** — skip corrupt lines, continue. Note count in digest.
- **On domain not found**: **degrade** — skip domain, list as "not found" in digest.
