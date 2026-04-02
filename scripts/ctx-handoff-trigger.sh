#!/usr/bin/env bash
# Inject handoff reminder based on accurate context % from statusline signal file.
# Falls back to nothing if signal file is absent or stale — no ccstatusline dependency.

CTX_FILE="/tmp/cc-ctx-usable"
STALE_SECS=300  # ignore signal file older than 5 min

[ -f "$CTX_FILE" ] || exit 0

# Freshness check
file_ts=$(stat -c %Y "$CTX_FILE" 2>/dev/null || stat -f %m "$CTX_FILE" 2>/dev/null)
now_ts=$(date +%s)
age=$(( now_ts - file_ts ))
[ "$age" -gt "$STALE_SECS" ] && exit 0

used=$(cat "$CTX_FILE")
[[ "$used" =~ ^[0-9]+$ ]] || exit 0

if   [ "$used" -ge 85 ]; then
  echo "[CONTEXT ${used}%: write HANDOFF.md immediately and recommend fresh session — do not defer]"
elif [ "$used" -ge 75 ]; then
  echo "[CONTEXT ${used}%: proactively write HANDOFF.md and recommend starting fresh soon]"
elif [ "$used" -ge 60 ]; then
  echo "[CONTEXT ${used}%: if substantial work remains, write HANDOFF.md and recommend fresh session]"
fi
