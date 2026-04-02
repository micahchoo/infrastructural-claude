#!/usr/bin/env bash
# post-implementation-audit.sh — Verify plan artifact manifest against disk reality.
# Usage: post-implementation-audit.sh <plan-file>
#   or:  post-implementation-audit.sh --discover
#
# Reads the PLAN_MANIFEST_START/END block from a plan file, then checks each
# claimed artifact exists and contains its marker.
#
# Exit codes: 0 = all pass, 1 = failures found, 2 = usage/parse error
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Resolve project root ---
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

# --- Find plan file ---
discover_plan() {
  # 1. Integration state
  local istate="/tmp/integration-state-${PPID}.json"
  if [[ -f "$istate" ]]; then
    local path
    path=$(jq -r '.plan_path // empty' "$istate" 2>/dev/null)
    [[ -n "$path" && -f "$path" ]] && echo "$path" && return 0
  fi

  # 2. Most recent non-archived plan
  local latest
  latest=$(find docs/superpowers/plans -maxdepth 1 -name '*.md' -not -path '*/archive/*' 2>/dev/null \
    | xargs ls -t 2>/dev/null | head -1)
  [[ -n "$latest" && -f "$latest" ]] && echo "$latest" && return 0

  # 3. Any plan in current directory
  latest=$(find . -maxdepth 2 -name '*-plan.md' -o -name '*-implementation-plan.md' 2>/dev/null \
    | xargs ls -t 2>/dev/null | head -1)
  [[ -n "$latest" && -f "$latest" ]] && echo "$latest" && return 0

  return 1
}

BASELINE=false
PLAN_FILE=""

for arg in "$@"; do
  case "$arg" in
    --baseline) BASELINE=true ;;
    --discover) PLAN_FILE="__discover__" ;;
    *) PLAN_FILE="$arg" ;;
  esac
done

if [[ "$PLAN_FILE" == "__discover__" ]]; then
  PLAN_FILE=$(discover_plan) || { echo "No plan file found." >&2; exit 2; }
elif [[ -z "$PLAN_FILE" ]]; then
  echo "Usage: post-implementation-audit.sh <plan-file> [--baseline] | --discover" >&2
  exit 2
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE" >&2
  exit 2
fi

# --- Extract manifest (last block only — plans may reference sentinels in examples) ---
MANIFEST=$(tac "$PLAN_FILE" \
  | sed -n '/<!-- PLAN_MANIFEST_END -->/,/<!-- PLAN_MANIFEST_START -->/p' \
  | tac \
  | grep '^|' | grep -v '^| *File' | grep -v '^| *[-:]' || true)

if [[ -z "$MANIFEST" ]]; then
  echo -e "${RED}AUDIT FAILED:${RESET} No artifact manifest found in $PLAN_FILE"
  echo "Plans must include a <!-- PLAN_MANIFEST_START --> / <!-- PLAN_MANIFEST_END --> block."
  exit 2
fi

# --- Audit each row ---
PASS=0
FAIL=0
TOTAL=0

echo -e "${BOLD}AUDIT:${RESET} $PLAN_FILE"
echo ""

while IFS='|' read -r _ file action marker _; do
  # Trim whitespace
  file=$(echo "$file" | sed 's/^ *//;s/ *$//;s/^`//;s/`$//')
  action=$(echo "$action" | sed 's/^ *//;s/ *$//' | tr '[:upper:]' '[:lower:]')
  marker=$(echo "$marker" | sed 's/^ *//;s/ *$//;s/^`//;s/`$//')

  [[ -z "$file" || -z "$action" ]] && continue
  TOTAL=$((TOTAL + 1))

  case "$action" in
    create)
      if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}pass${RESET}  $file  create  exists"
        PASS=$((PASS + 1))
      else
        echo -e "  ${RED}FAIL${RESET}  $file  create  ${RED}FILE MISSING${RESET}"
        FAIL=$((FAIL + 1))
      fi
      ;;

    patch)
      if [[ ! -f "$file" ]]; then
        echo -e "  ${RED}FAIL${RESET}  $file  patch  ${RED}FILE MISSING${RESET}"
        FAIL=$((FAIL + 1))
      elif [[ -z "$marker" ]]; then
        echo -e "  ${RED}FAIL${RESET}  $file  patch  ${RED}NO MARKER SPECIFIED${RESET}"
        FAIL=$((FAIL + 1))
      elif grep -qF "$marker" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}pass${RESET}  $file  patch  marker found"
        PASS=$((PASS + 1))
      else
        echo -e "  ${RED}FAIL${RESET}  $file  patch  ${RED}MARKER ABSENT${RESET}: $marker"
        FAIL=$((FAIL + 1))
      fi
      ;;

    wire)
      # Marker should be in settings.json, and the target file should exist
      if [[ -z "$marker" ]]; then
        echo -e "  ${RED}FAIL${RESET}  $file  wire  ${RED}NO MARKER SPECIFIED${RESET}"
        FAIL=$((FAIL + 1))
      elif ! grep -qF "$marker" "$file" 2>/dev/null; then
        echo -e "  ${RED}FAIL${RESET}  $file  wire  ${RED}CONFIG ENTRY MISSING${RESET}: $marker"
        FAIL=$((FAIL + 1))
      else
        # Extract script/command path from marker if it looks like a path
        target=$(echo "$marker" | grep -oE '[$~/.][a-zA-Z0-9_{}/.~-]+\.sh' | head -1 || true)
        if [[ -n "$target" ]]; then
          # Expand $HOME and ~
          target="${target/\$HOME/$HOME}"
          target="${target/\$\{HOME\}/$HOME}"
          target="${target/#\~/$HOME}"
          if [[ -f "$target" ]]; then
            echo -e "  ${GREEN}pass${RESET}  $file  wire  entry + target exist"
            PASS=$((PASS + 1))
          else
            echo -e "  ${RED}FAIL${RESET}  $file  wire  ${RED}TARGET MISSING${RESET}: $target"
            FAIL=$((FAIL + 1))
          fi
        else
          # No extractable target — just check config entry exists
          echo -e "  ${GREEN}pass${RESET}  $file  wire  entry found (no target to verify)"
          PASS=$((PASS + 1))
        fi
      fi
      ;;

    delete)
      if [[ ! -f "$file" ]]; then
        echo -e "  ${GREEN}pass${RESET}  $file  delete  absent"
        PASS=$((PASS + 1))
      else
        echo -e "  ${RED}FAIL${RESET}  $file  delete  ${RED}STILL EXISTS${RESET}"
        FAIL=$((FAIL + 1))
      fi
      ;;

    *)
      echo -e "  ${YELLOW}SKIP${RESET}  $file  ${YELLOW}unknown action: $action${RESET}"
      ;;
  esac
done <<< "$MANIFEST"

echo ""
echo -e "${BOLD}RESULT:${RESET} $PASS/$TOTAL passed, $FAIL failed"

if [[ "$BASELINE" == "true" ]]; then
  echo -e "${BOLD}BASELINE:${RESET} $PASS/$TOTAL already passing — $FAIL items to implement"
  exit 0
elif [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}AUDIT FAILED — do not proceed to land${RESET}"
  exit 1
else
  echo -e "${GREEN}AUDIT PASSED${RESET}"
  exit 0
fi
