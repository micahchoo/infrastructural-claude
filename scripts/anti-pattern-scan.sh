#!/usr/bin/env bash
# anti-pattern-scan.sh — Risk signal detection for shadow walks
# Usage: anti-pattern-scan.sh [file1 file2 ...] or pipe file list on stdin
# If no input, scans all git-tracked source files.
# Output: categorized findings + per-file risk scores (cached per git state)
set -u
command -v jq >/dev/null 2>&1 || exit 0

source "$(dirname "$0")/lib/cache-utils.sh"

SOURCE_EXTS='\.(ts|js|svelte|py|rb|go|rs|java|php|tsx|jsx|vue|mjs|cjs)$'

# --- Input contract ---
resolve_files() {
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "$@"
  elif [[ ! -t 0 ]] && read -r -t 1 first_line; then
    # Stdin has data — read it (prepend the line we already consumed)
    printf '%s\n' "$first_line"
    cat
  else
    # No args, no stdin data — scan git-tracked source files
    git ls-files 2>/dev/null | grep -E "$SOURCE_EXTS" | grep -vE "$EXCLUDES"
  fi
}

# Serve from cache if fresh (< 5 min old)
init_cache "anti-pattern-cache" 300 && exit 0

# --- Resolve file list ---
FILE_LIST=$(resolve_files "$@")
if [[ -z "$FILE_LIST" ]]; then
  exit 0
fi

# --- Rules file ---
RULES_FILE="$HOME/.claude/anti-pattern-rules.jsonl"

# --- Detector functions (each outputs JSONL to stdout) ---

UI_PATTERN='toast|alert|notify|dispatch|emit|set.*[Ee]rror|show.*[Ee]rror|throw|fail|reject'

# Generic rule-driven detector: reads active rules from RULES_FILE (excluding "special" rules)
# and applies pattern + negative-pattern window checks per file.
detect_by_rules() {
  local files
  files=$(cat)
  [[ ! -f "$RULES_FILE" ]] && return

  # Read non-special active rules
  while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    local rid rpattern rneg severity detail
    local window_after window_before window_around requires_log skip_tests
    rid=$(echo "$rule" | jq -r '.id')
    rpattern=$(echo "$rule" | jq -r '.pattern')
    rneg=$(echo "$rule" | jq -r '.negative // ""')
    severity=$(echo "$rule" | jq -r '.severity')
    detail=$(echo "$rule" | jq -r '.detail')
    window_after=$(echo "$rule" | jq -r '.window_after // 0')
    window_before=$(echo "$rule" | jq -r '.window_before // 0')
    window_around=$(echo "$rule" | jq -r '.window_around // 0')
    requires_log=$(echo "$rule" | jq -r '.requires_log // false')
    skip_tests=$(echo "$rule" | jq -r '.skip_tests // false')

    echo "$files" | while IFS= read -r f; do
      [[ -f "$f" ]] || continue

      # Skip test files if rule says so
      if [[ "$skip_tests" == "true" ]]; then
        echo "$f" | grep -qE '\.(test|spec)\.' && continue
        echo "$f" | grep -qE '__tests__/' && continue
      fi

      (grep -nE "$rpattern" "$f" 2>/dev/null || true) | while IFS=: read -r lineno _; do
        [[ -z "$lineno" ]] && continue

        # Build window based on rule's window_* fields
        local wstart wend
        if [[ $window_around -gt 0 ]]; then
          wstart=$((lineno > window_around ? lineno - window_around : 1))
          wend=$((lineno + window_around))
        elif [[ $window_after -gt 0 ]]; then
          wstart=$lineno
          wend=$((lineno + window_after))
        elif [[ $window_before -gt 0 ]]; then
          wstart=$((lineno > window_before ? lineno - window_before : 1))
          wend=$lineno
        else
          # No window — just match the line itself
          wstart=$lineno
          wend=$lineno
        fi
        local window
        window=$(sed -n "${wstart},${wend}p" "$f")

        # requires_log: only flag if console.error/warn/log IS present but no UI surface
        if [[ "$requires_log" == "true" ]]; then
          local has_log
          has_log=$(echo "$window" | grep -cE 'console\.(error|warn|log)' || true)
          [[ $has_log -eq 0 ]] && continue
          local has_return
          has_return=$(echo "$window" | grep -cE 'return.*(error|fail|null|undefined|false)' || true)
          [[ $has_return -gt 0 ]] && continue
        fi

        # Negative pattern check (if non-empty)
        if [[ -n "$rneg" ]]; then
          local has_neg
          if [[ $window_before -gt 0 && $window_after -eq 0 && $window_around -eq 0 ]]; then
            # For window_before rules, also check the match line itself for .catch
            local same_line
            same_line=$(sed -n "${lineno}p" "$f")
            has_neg=$(echo "$window" "$same_line" | grep -cE "$rneg" || true)
          else
            has_neg=$(echo "$window" | grep -cE "$rneg" || true)
          fi
          [[ $has_neg -gt 0 ]] && continue
        fi

        printf '{"file":"%s","line":%d,"signal":"%s","severity":%s,"detail":"%s"}\n' \
          "$f" "$lineno" "$rid" "$severity" "$detail"
      done
    done
  done < <(jq -c 'select(.status == "active" and (has("special") | not))' "$RULES_FILE")
}

detect_untested_churn() {
  cat >/dev/null  # consume stdin — this detector uses git log directly

  # Top 20 churn files (6 months)
  local churn
  churn=$(git log --since="6 months ago" --pretty=format: --name-only 2>/dev/null \
    | grep -vE "$EXCLUDES" | grep -E "$SOURCE_EXTS" \
    | grep -v '^$' | sort | uniq -c | sort -rn | head -20)

  # All test files
  local test_files
  test_files=$(git ls-files 2>/dev/null | grep -E '\.(test|spec)\.|__tests__/' || true)

  echo "$churn" | while read -r count filepath; do
    [[ -z "$filepath" ]] && continue
    count=$(echo "$count" | tr -dc '0-9')  # Dream-added: 2026-03-24 — digits-only to prevent arithmetic errors
    [[ -z "$count" || "$count" -eq 0 ]] && continue
    local base
    base=$(basename "$filepath" | sed 's/\.[^.]*$//')
    if ! echo "$test_files" | grep -q "$base"; then
      printf '{"file":"%s","line":0,"signal":"untested-churn","severity":2,"detail":"%s commits (6mo), no test file"}\n' "$filepath" "$count"
    fi
  done
}

detect_todo_density() {
  local files
  files=$(cat)
  echo "$files" | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    local count
    count=$(grep -cE 'TODO|FIXME|HACK|XXX' "$f" 2>/dev/null || echo 0)
    count=${count//[^0-9]/}  # Dream-added: 2026-03-24 — sanitize to digits only
    [[ -z "$count" ]] && count=0
    if [[ $count -ge 3 ]]; then
      printf '{"file":"%s","line":0,"signal":"todo-density","severity":1,"detail":"%s debt markers in single file"}\n' "$f" "$count"
    fi
  done
}

# --- Run all detectors, collect JSONL ---
run_detectors() {
  local files="$1"
  detect_by_rules        <<< "$files"
  detect_untested_churn  <<< "$files"
  detect_todo_density    <<< "$files"

  # Project-specific detectors
  local project_dir
  project_dir=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [[ -n "$project_dir" ]]; then
    for detector in "$project_dir"/.claude/scripts/detect-*.sh; do
      [[ -x "$detector" ]] && echo "$files" | "$detector"
    done
  fi
}

# --- Compositor: JSONL -> dual output ---
compositor() {
  local jsonl="$1"
  [[ -z "$jsonl" ]] && return

  echo "=== FINDINGS ==="
  echo "$jsonl" | jq -r '"[\(.signal)] \(.file):\(.line) -- \(.detail)"' | sort

  echo ""

  echo "=== RISK SCORES ==="
  echo "$jsonl" | jq -rs '
    [.[] | select(.file != null)]
    | group_by(.file)
    | map({
        file: .[0].file,
        score: (map(.severity) | add),
        signals: (group_by(.signal) | map("\(.[0].signal):\(map(.severity)|add)x\(length)") | join(" "))
      })
    | sort_by(-.score)
    | .[]
    | "\(.file)  \(.score)  \(.signals)"
  '
}

# --- Output file (stable path for reference) ---
PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
OUTPUT_FILE="${PROJECT_DIR}/.claude/anti-pattern-report.txt"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# --- Main ---
JSONL=$(run_detectors "$FILE_LIST")

if [[ -n "$JSONL" ]]; then
  compositor "$JSONL" | tee "$OUTPUT_FILE" | finalize_cache > /dev/null
  cat "$OUTPUT_FILE"
else
  echo -n | finalize_cache > /dev/null
  : > "$OUTPUT_FILE"
fi

cleanup_cache
