---
name: log-hygiene
mode: enrichment
layer: L2
trigger: always
priority: 6
---

## What This Checks

Hook scripts write to `~/.claude/logs/` but nothing rotates these logs. Over time they grow unbounded, wasting disk and making grep slower. This template enforces a size cap.

## Steps

1. **Check log sizes**:
   ```bash
   for log in ~/.claude/logs/*.log; do
     [ -f "$log" ] && echo "$(wc -c < "$log") $log"
   done
   ```

2. **Rotate oversized logs** — if any log exceeds 100KB, keep last 500 lines:
   ```bash
   for log in ~/.claude/logs/*.log; do
     size=$(wc -c < "$log" 2>/dev/null || echo 0)
     if [ "$size" -gt 102400 ]; then
       tail -500 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
       echo "Rotated: $log ($size → $(wc -c < "$log") bytes)"
     fi
   done
   ```

## Eval Checkpoints

`[eval: resilience]` Handles missing or empty log directories gracefully — no errors on zero logs.

`[eval: boundary]` Only rotated/cleaned old logs — active logs (modified within 24h) were not touched.

## Improvement Writes

- Rotate logs exceeding 100KB (keep last 500 lines)

## Digest Section

```
### Log hygiene
- Logs rotated: N | Bytes freed: N
```

## Recovery

- **On locked log files**: **degrade** — skip locked files, note in digest.
- **On missing log directory**: **degrade** — skip, note "no logs dir" in digest.
