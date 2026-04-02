---
name: ctx-usage-patterns
mode: enrichment
layer: L1
trigger: always
priority: 8
---

## What This Checks

Reads `~/.claude/logs/ctx-usage.jsonl` — per-turn context usage log written by `ctx-usage-logger.sh` — and identifies which tool buckets, projects, and session patterns consume the most context. Uses this to calibrate handoff thresholds, flag expensive tool patterns, and surface projects that reliably burn context fast. Exits early if the log has fewer than 20 entries (insufficient signal).

## Steps

1. **Check log exists and has signal:**
   ```bash
   LOG="$HOME/.claude/logs/ctx-usage.jsonl"
   [ -f "$LOG" ] || { echo "No ctx-usage log yet — skipping"; exit 0; }
   entry_count=$(wc -l < "$LOG")
   echo "Log entries: $entry_count"
   [ "$entry_count" -lt 20 ] && { echo "Insufficient data (<20 turns) — skipping"; exit 0; }
   ```

2. **Per-bucket context cost** — which tool types eat the most context per turn:
   ```bash
   echo "=== Avg delta_pct per tool bucket ==="
   jq -r '.tools[] as $t | {bucket: $t, delta: .delta_pct}' "$LOG" 2>/dev/null | \
     jq -rs 'group_by(.bucket) | map({
       bucket: .[0].bucket,
       count: length,
       avg_delta: (map(.delta) | add / length | floor),
       max_delta: (map(.delta) | max)
     }) | sort_by(-.avg_delta) | .[] |
     "\(.avg_delta)% avg, \(.max_delta)% max, \(.count) turns — \(.bucket)"'
   ```

3. **Per-project burn rate** — projects that eat context fastest:
   ```bash
   echo "=== Avg delta_pct per project ==="
   jq -r '{cwd: (.cwd | split("/") | last), delta: .delta_pct}' "$LOG" 2>/dev/null | \
     jq -rs 'group_by(.cwd) | map({
       project: .[0].cwd,
       turns: length,
       avg_delta: (map(.delta) | add / length | floor),
       total_pct: (map(.delta) | add)
     }) | sort_by(-.avg_delta) | .[] |
     "\(.avg_delta)% avg/turn, \(.turns) turns, \(.total_pct)% total — \(.project)"'
   ```

4. **Multi-tool turn cost** — do turns with more tool calls cost more?
   ```bash
   echo "=== Delta by turn tool count ==="
   jq -r '{n: (.tools | length), delta: .delta_pct}' "$LOG" 2>/dev/null | \
     jq -rs 'group_by(.n) | map({
       tool_count: .[0].n,
       avg_delta: (map(.delta) | add / length | floor),
       samples: length
     }) | sort_by(.tool_count) | .[] |
     "\(.tool_count) tools/turn → \(.avg_delta)% avg delta (\(.samples) samples)"'
   ```

5. **High-spike turns** — turns with delta > 10% (outliers worth investigating):
   ```bash
   echo "=== Turns with delta > 10% ==="
   jq -r 'select(.delta_pct > 10) | "\(.delta_pct)% — \(.tools | join(", ")) — \(.cwd | split("/") | last)"' "$LOG" 2>/dev/null | \
     sort -rn | head -15
   ```

6. **Handoff threshold calibration** — what % of turns are still under the 60% threshold?
   ```bash
   echo "=== Context pressure distribution ==="
   total=$(wc -l < "$LOG")
   under60=$(jq 'select(.used_pct < 60)' "$LOG" 2>/dev/null | wc -l)
   over60=$(jq 'select(.used_pct >= 60 and .used_pct < 75)' "$LOG" 2>/dev/null | wc -l)
   over75=$(jq 'select(.used_pct >= 75)' "$LOG" 2>/dev/null | wc -l)
   echo "Under 60%: $under60/$total turns ($(( under60 * 100 / total ))%)"
   echo "60–75%: $over60/$total turns"
   echo "75%+: $over75/$total turns"
   ```

7. **Write findings as mulch pattern record** — if a clear expensive bucket emerges:
   ```bash
   # Only if avg delta for any bucket > 8%
   top_bucket=$(jq -r '.tools[] as $t | {bucket: $t, delta: .delta_pct}' "$LOG" 2>/dev/null | \
     jq -rs 'group_by(.bucket) | map({bucket: .[0].bucket, avg: (map(.delta) | add / length)}) |
     sort_by(-.avg) | .[0] | "\(.bucket)=\(.avg | floor)"')
   bucket_name="${top_bucket%%=*}"
   bucket_avg="${top_bucket##*=}"
   if [ "${bucket_avg:-0}" -gt 8 ] 2>/dev/null; then
     ml record context-usage --type pattern \
       --description "High context burn bucket: ${bucket_name} averages ${bucket_avg}% per turn — consider batching or deferring" \
       --classification observational \
       --tags "source:dream-ctx-usage,bucket:${bucket_name}" 2>/dev/null || true
   fi
   ```

`[eval: signal]` Log has ≥20 entries before any analysis runs — template exits cleanly otherwise.
`[eval: buckets]` Per-bucket delta table is produced and sorted by avg cost.
`[eval: actionable]` At least one finding is written to mulch if a bucket exceeds 8% avg delta.

## Improvement Writes

- Mulch `pattern` record when a consistently expensive tool bucket is identified
- No changes to scripts or hooks — read-only analysis

## Digest Section

```
## Context Usage Patterns (ctx-usage-patterns)
- Log entries analyzed: <N>
- Top burn bucket: <bucket> at <X>% avg delta/turn
- Hottest project: <project> at <X>% avg delta/turn
- Handoff calibration: <X>% of turns reached 60%+ pressure
- Mulch record written: yes/no
```

## Recovery

- **Log absent**: exits cleanly — template becomes active once ctx-usage-logger.sh accumulates 20+ entries
- **jq unavailable**: exits cleanly at startup guard
- **mlrecord fails**: logged via `|| true` — non-fatal
