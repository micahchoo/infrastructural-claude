#!/usr/bin/env bash
# edit-quality-check.sh — PostToolUse: lint/typecheck on Write/Edit
# Reads stdin JSON, extracts file path, runs language-appropriate checks.
# On findings: emit <system-reminder> to stdout + append to failure journal.
# On clean: emit nothing (no context pollution).
set +e
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

# Change to git root for consistent tool invocation
git_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)
[ -n "$git_root" ] && cd "$git_root"

ext="${file_path##*.}"
findings=""

case "$ext" in
  py)
    command -v ruff >/dev/null 2>&1 || exit 0
    # Require ruff config in project tree — don't run globally
    dir=$(dirname "$(realpath "$file_path")")
    has_config=false
    while [ "$dir" != "/" ] && [ "$dir" != "$HOME" ]; do
      if [ -f "$dir/ruff.toml" ] || [ -f "$dir/.ruff.toml" ]; then
        has_config=true; break
      fi
      if [ -f "$dir/pyproject.toml" ] && grep -q '\[tool\.ruff\]' "$dir/pyproject.toml" 2>/dev/null; then
        has_config=true; break
      fi
      dir=$(dirname "$dir")
    done
    $has_config || exit 0
    findings=$(ruff check --output-format=concise "$file_path" 2>&1)
    ;;
  ts|tsx|js|jsx|mjs|mts)
    # Find tsconfig walking up from file
    dir=$(dirname "$(realpath "$file_path")")
    project_dir=""
    while [ "$dir" != "/" ]; do
      if [ -f "$dir/tsconfig.json" ]; then
        project_dir="$dir"; break
      fi
      dir=$(dirname "$dir")
    done
    [ -z "$project_dir" ] && exit 0
    tsc_bin="$project_dir/node_modules/.bin/tsc"
    [ ! -x "$tsc_bin" ] && tsc_bin=$(command -v tsc 2>/dev/null)
    [ -z "$tsc_bin" ] && exit 0
    findings=$(cd "$project_dir" && "$tsc_bin" --noEmit 2>&1 | head -50)
    ;;
  go)
    command -v go >/dev/null 2>&1 || exit 0
    dir=$(dirname "$(realpath "$file_path")")
    while [ "$dir" != "/" ]; do
      [ -f "$dir/go.mod" ] && break
      dir=$(dirname "$dir")
    done
    [ ! -f "$dir/go.mod" ] && exit 0
    findings=$(cd "$dir" && go vet ./... 2>&1)
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$findings" ] && exit 0

filename="${file_path##*/}"
echo "<system-reminder>edit-quality-check [${filename}]: fix before continuing.
${findings}</system-reminder>"

# Cross-infra: append to failure journal (same PPID as other hooks)
JOURNAL="/tmp/failure-journal-${PPID}.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
  --arg ts "$TS" \
  --arg file "$file_path" \
  --arg findings "$findings" \
  '{ts:$ts,source:"edit-quality-check",category:"lint",file:$file,findings:$findings,is_error:true}' \
  >> "$JOURNAL" 2>/dev/null

exit 0
