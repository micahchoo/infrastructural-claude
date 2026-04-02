---
name: plugin-state
mode: enrichment
layer: L0
trigger: always
priority: 7
---

<!-- Note: This template is infrastructure housekeeping, not baseline-enrichment.
     It lives in enrichment as the least-wrong home. Future: consider a standalone
     periodic check or a fourth "maintenance" mode. -->

## What This Checks

Plugin cache accumulates old versions (400MB+). Blocklist entries may be stale. Installed plugin versions drift from marketplace latest. Nobody tracks this, so cache grows unbounded and stale entries persist.

## Steps

1. **Check plugin cache freshness**:
   ```bash
   ls -d ~/.claude/plugins/cache/*/*/ 2>/dev/null | while read dir; do
     plugin=$(basename "$(dirname "$dir")")
     version=$(basename "$dir")
     age_days=$(( ($(date +%s) - $(stat -c %Y "$dir" 2>/dev/null || echo 0)) / 86400 ))
     echo "$plugin@$version — ${age_days}d old"
   done
   ```

2. **Flag stale blocklist entries** — entries older than 90 days may need review:
   ```bash
   jq -r '.[] | "\(.name) — fetched \(.fetchedAt)"' ~/.claude/plugins/blocklist.json 2>/dev/null
   ```

3. **Note findings** as mulch references:
   ```bash
   ml record agents-dream --type reference \
     --description "Plugin state: <N> plugins checked, <M> stale versions, <K> blocklist entries." \
     --classification observational \
     --tags "source:dream-plugin-state,lifecycle:active"
   ```

## Eval Checkpoints

`[eval: target]` Checked freshness of installed/active plugins, not just everything in the cache directory.

`[eval: resilience]` Handles missing plugin cache directory and empty blocklist gracefully.

## Improvement Writes

- Record plugin state to mulch
- Flag stale cache versions for cleanup

## Digest Section

```
### Plugin state
- Plugins checked: N | Stale versions: N
- Blocklist entries reviewed: N
```

## Recovery

- **On missing plugin cache**: **degrade** — skip freshness check, note in digest.
- **On blocklist parse error**: **degrade** — skip blocklist review, note in digest.
