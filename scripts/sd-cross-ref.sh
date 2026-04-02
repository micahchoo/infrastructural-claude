#!/usr/bin/env bash
# Cross-reference query across both seeds instances.
# Usage: sd-cross-ref.sh [list|ready|show] [args...]
#
# Queries both:
#   ~/.claude/.seeds/ (global)
#   ~/.claude/autoresearch/.seeds/ (autoresearch-scoped)
set -euo pipefail

CMD="${1:-list}"
shift || true

echo "=== Global seeds ==="
(cd ~/.claude && sd "$CMD" "$@" 2>/dev/null) || echo "(no global .seeds/)"

echo ""
echo "=== Autoresearch seeds ==="
(cd ~/.claude/autoresearch && sd "$CMD" "$@" 2>/dev/null) || echo "(no autoresearch .seeds/)"
