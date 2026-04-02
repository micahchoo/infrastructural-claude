#!/usr/bin/env bash
# Surface anti-pattern-report.txt findings as a SessionStart summary line.
# Check project-local (.claude/) then global (~/.claude/) locations
exec bash "$(dirname "$0")/anti-pattern-query.sh" --mode summary
