#!/usr/bin/env bash
# anti-pattern-query.sh — unified query interface for anti-pattern data
# Modes: scan (full scan), summary (count), inject (context slice for skills)
set -u

MODE=""
SKILL_NAME=""
shift_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --skill) SKILL_NAME="$2"; shift 2 ;;
    *) shift_args+=("$1"); shift ;;
  esac
done

PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
REPORT_FILE="${PROJECT_DIR}/.claude/anti-pattern-report.txt"

case "$MODE" in
  scan)
    # Delegate to scan script with remaining args
    exec bash "$(dirname "$0")/anti-pattern-scan.sh" "${shift_args[@]}"
    ;;

  summary)
    [[ ! -f "$REPORT_FILE" ]] && exit 0
    TOTAL=$(grep -c '^\[' "$REPORT_FILE" 2>/dev/null) || TOTAL=0
    [[ "$TOTAL" -eq 0 ]] && exit 0
    CRITICAL=$(grep -c '^\[critical\]' "$REPORT_FILE" 2>/dev/null) || CRITICAL=0
    HIGH=$(grep -c '^\[catch-all\]' "$REPORT_FILE" 2>/dev/null) || HIGH=0
    MODERATE=$(( TOTAL - CRITICAL - HIGH ))
    [[ "$MODERATE" -lt 0 ]] && MODERATE=0
    echo "Anti-patterns: ${TOTAL} findings (${CRITICAL} critical, ${HIGH} high, ${MODERATE} moderate)"
    ;;

  inject)
    [[ ! -f "$REPORT_FILE" ]] && exit 0
    SCAN_OUTPUT=$(cat "$REPORT_FILE")
    [[ -z "$SCAN_OUTPUT" ]] && exit 0

    FINDING_COUNT=$(echo "$SCAN_OUTPUT" | grep -c '^\[' || true)
    SIGNAL_SUMMARY=$(echo "$SCAN_OUTPUT" | grep -oP '^\[\K[^\]]+' | sort | uniq -c | sort -rn | head -7 | awk '{printf "%s:%s ", $2, $1}')
    RISK_SCORES=$(echo "$SCAN_OUTPUT" | grep -A1000 '=== RISK SCORES ===' | head -16)
    SILENT_FINDINGS=$(echo "$SCAN_OUTPUT" | grep -E '^\[(silent-catch|console-only-error)\]' | head -10)

    echo "Anti-pattern scan: ${FINDING_COUNT} findings (${SIGNAL_SUMMARY})"
    echo ""
    echo "${RISK_SCORES}"
    echo ""
    echo "Top silent-catch/console-only findings:"
    echo "${SILENT_FINDINGS:-  (none detected)}"
    echo ""
    echo "Full report: ${REPORT_FILE}"
    ;;

  *)
    echo "Usage: anti-pattern-query.sh --mode {scan|summary|inject} [--skill NAME]" >&2
    exit 1
    ;;
esac
