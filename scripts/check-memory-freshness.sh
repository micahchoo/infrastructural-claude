#!/usr/bin/env bash
# check-memory-freshness.sh — SessionStart hook that warns about stale memories
set +e
now=$(date +%s)
stale=0

for mem in "$HOME"/.claude/projects/*/memory/*.md; do
  [ "$(basename "$mem")" = "MEMORY.md" ] && continue
  [ -f "$mem" ] || continue

  last_verified=$(grep -m1 '^last-verified:' "$mem" 2>/dev/null | sed 's/.*: *//')
  ttl_days=$(grep -m1 '^ttl-days:' "$mem" 2>/dev/null | sed 's/.*: *//')

  [ -z "$last_verified" ] && continue
  [ -z "$ttl_days" ] && ttl_days=30

  verified_ts=$(date -d "$last_verified" +%s 2>/dev/null || echo 0)
  [ "$verified_ts" -eq 0 ] && continue
  age_days=$(( (now - verified_ts) / 86400 ))

  if [ "$age_days" -gt "$ttl_days" ]; then
    echo "STALE MEMORY: $(basename "$mem") — last verified $last_verified ($age_days days ago, TTL ${ttl_days}d)"
    stale=$((stale + 1))
  fi
done

[ $stale -gt 0 ] && echo "($stale stale memories — consider reviewing or updating them)"
exit 0
