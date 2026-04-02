#!/usr/bin/env bash
# dream-trigger-hook.sh — SessionStart hook
# Counts accumulated signal and offers /dream when thresholds met.
# Thresholds are self-tuning via mulch conventions in agents-dream domain.
set +e
command -v jq >/dev/null 2>&1 || exit 0
command -v ml >/dev/null 2>&1 || exit 0

# --- Load thresholds (defaults, overridden by mulch conventions) ---
ENRICH_RECORDS_THRESHOLD=10
ENRICH_STALE_THRESHOLD=3
GAPS_UNCAT_THRESHOLD=5
GAPS_CANDIDATE_THRESHOLD=2
INTEGRATE_MEMORY_THRESHOLD=3

# Check for tuned thresholds in mulch (self-tuning)
# Convention format in description: "key=value key=value ..."
# e.g. "ENRICH_RECORDS_THRESHOLD=15 GAPS_UNCAT_THRESHOLD=8"
tuning=$(ml search "ENRICH_RECORDS_THRESHOLD" --domain agents-dream --json 2>/dev/null | jq -r '.results[0].description // empty' 2>/dev/null)
if [[ -n "$tuning" ]]; then
  for pair in $tuning; do
    key="${pair%%=*}"
    val="${pair#*=}"
    # Only override known threshold variables, ignore malformed entries
    case "$key" in
      ENRICH_RECORDS_THRESHOLD|ENRICH_STALE_THRESHOLD|GAPS_UNCAT_THRESHOLD|GAPS_CANDIDATE_THRESHOLD|INTEGRATE_MEMORY_THRESHOLD)
        # Validate value is a positive integer
        if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -gt 0 ]]; then
          eval "$key=$val"
        fi
        ;;
    esac
  done
fi

# --- Count signals ---
offers=""

# Enrichment: records without outcomes
no_outcome=$(ml search "lifecycle:active" --json 2>/dev/null | \
  jq '[.results[] | select(.outcome_status == null)] | length' 2>/dev/null || echo 0)
if [[ "$no_outcome" -ge "$ENRICH_RECORDS_THRESHOLD" ]]; then
  offers="${offers}enrichment (${no_outcome} records without outcomes)\n"
fi

# Detect-gaps: uncategorized failures in recent journals
uncat=0
for j in /tmp/failure-journal-*.jsonl; do
  [[ -f "$j" ]] || continue
  n=$(jq -r 'select(.category == "uncategorized")' "$j" 2>/dev/null | wc -l)
  uncat=$((uncat + n))
done
if [[ "$uncat" -ge "$GAPS_UNCAT_THRESHOLD" ]]; then
  offers="${offers}detect-gaps (${uncat} uncategorized failures)\n"
fi

# Detect-gaps: candidate rules pending
candidates=0
rules_file="$HOME/.claude/anti-pattern-rules.jsonl"
if [[ -f "$rules_file" ]]; then
  candidates=$(grep -c '"status":"candidate"' "$rules_file" 2>/dev/null)
  candidates=${candidates:-0}
fi
if [[ "$candidates" -ge "$GAPS_CANDIDATE_THRESHOLD" ]]; then
  offers="${offers}detect-gaps (${candidates} candidate rules pending graduation)\n"
fi

# Integration: cross-project memory files
xproject=$(find ~/.claude/projects/*/memory -name '*.md' 2>/dev/null | wc -l)
if [[ "$xproject" -ge "$INTEGRATE_MEMORY_THRESHOLD" ]]; then
  offers="${offers}integrate (${xproject} cross-project memory files)\n"
fi

# --- Write orient cache for dream-agent ---
cat > /tmp/dream-orient-cache.json <<ORIENT_EOF
{"no_outcome":${no_outcome:-0},"uncategorized":${uncat:-0},"candidates":${candidates:-0},"cross_project":${xproject:-0}}
ORIENT_EOF

# --- Output offers ---
if [[ -n "$offers" ]]; then
  echo "Dream pipelines available:"
  echo -e "$offers" | while read -r line; do
    [[ -n "$line" ]] && echo "  /dream $line"
  done
fi

exit 0
