---
name: seeds-bridge
mode: enrichment
layer: L1
trigger: closed_seeds > 0
priority: 4
---

## What This Checks

Closed seeds often contain decision-bearing reasons that never get recorded to mulch. This means knowledge is lost at every `sd close`. The seeds→mulch bridge mines closed issues for decisions worth preserving.

## Steps

1. **Read closed seeds** with reasons:
   ```bash
   grep '"status":"closed"' ~/.claude/.seeds/issues.jsonl | \
     jq -r 'select(.reason != null) | "\(.id): \(.title) — \(.reason)"'
   ```

2. **Filter** for decision-bearing reasons — skip simple "done" or "completed" reasons. Look for reasons containing: outcome, decision, approach, because, instead, switched, rejected, chose.

3. **Check** if a mulch record already exists for each decision:
   ```bash
   ml search "<key phrase from reason>" 2>/dev/null
   ```

4. **Create mulch records** for unrecorded decisions:
   ```bash
   ml record infrastructure --type decision \
     --description "<decision from seed close reason>" \
     --classification tactical \
     --tags "source:dream-seeds-bridge,lifecycle:active" \
     --evidence-commit "$(git log -1 --format='%H')"
   ```

## Eval Checkpoints

`[eval: target]` Mined decision-bearing closed seeds (those with outcome reasons), not routine task closures.

`[eval: boundary]` Decision records written to the correct mulch domain for the project, not the global agents-dream domain.

## Improvement Writes

- Create mulch decision records from closed seeds
- Bridge the knowledge gap between issue tracking and expertise system

## Digest Section

```
### Seeds→mulch bridge
- Closed seeds mined: N | Decision records created: N
```

## Recovery

- **On seeds not found** (.seeds/issues.jsonl missing): **degrade** — skip, note "no seeds" in digest.
- **On ambiguous outcome reasons**: **degrade** — skip seeds without clear decision signal. Don't invent decisions.
