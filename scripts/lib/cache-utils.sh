#!/usr/bin/env bash
# cache-utils.sh — Shared git-state caching for ~/.claude scripts
# Source this, then call: init_cache <cache-name> [ttl-seconds]
# Returns 0 (cache hit, already printed) or 1 (cache miss, caller should generate).
# After generating output, pipe it through: finalize_cache

# Regex pattern for grep -vE exclusions
EXCLUDES="node_modules|\.git|vendor|dist|build|__pycache__|\.next|\.cache|\.venv|target|\.worktrees"
# Glob pattern for tree -I exclusions (no regex escapes)
TREE_EXCLUDES="node_modules|.git|vendor|dist|build|__pycache__|.next|.cache|.venv|target|.worktrees"

_CACHE_FILE=""
_CACHE_DIR=""
_GIT_FILES_CACHE=""

init_cache() {
  local cache_name="${1:?usage: init_cache <name> [ttl]}"
  local ttl="${2:-300}"
  _CACHE_DIR="/tmp/${CACHE_NAMESPACE:-}${cache_name}"
  mkdir -p "$_CACHE_DIR"

  local git_head git_dirty cache_key
  git_head=$(git rev-parse HEAD 2>/dev/null || echo "nogit")
  # Include both tracked changes and untracked files in dirty hash
  git_dirty=$({ git diff --raw 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sha256sum | cut -c1-16)
  cache_key=$(echo "${PWD}_${git_head}_${git_dirty}" | sha256sum | cut -c1-16)
  _CACHE_FILE="$_CACHE_DIR/$cache_key"

  if [[ -f "$_CACHE_FILE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$_CACHE_FILE" 2>/dev/null || stat -f %m "$_CACHE_FILE" 2>/dev/null || echo 0))) -lt $ttl ]]; then
    cat "$_CACHE_FILE"
    cleanup_cache
    return 0
  fi
  return 1
}

# init_sub_cache — separate cache with custom key (e.g., for GH API with longer TTL)
# Usage: init_sub_cache <name> <ttl> <custom-key>
# Returns 0 (hit, already printed) or 1 (miss, caller generates and pipes through finalize_sub_cache)
_SUB_CACHE_FILE=""
init_sub_cache() {
  local name="${1:?}" ttl="${2:-900}" key="$3"
  local sub_dir="/tmp/${CACHE_NAMESPACE:-}${name}"
  mkdir -p "$sub_dir"
  _SUB_CACHE_FILE="$sub_dir/$(echo "$key" | sha256sum | cut -c1-16)"
  if [[ -f "$_SUB_CACHE_FILE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$_SUB_CACHE_FILE" 2>/dev/null || stat -f %m "$_SUB_CACHE_FILE" 2>/dev/null || echo 0))) -lt $ttl ]]; then
    cat "$_SUB_CACHE_FILE"
    return 0
  fi
  return 1
}

finalize_sub_cache() {
  local tmp="${_SUB_CACHE_FILE}.$$"
  if tee "$tmp" && [[ -s "$tmp" ]]; then
    mv -f "$tmp" "$_SUB_CACHE_FILE"
  else
    rm -f "$tmp"
  fi
}

finalize_cache() {
  local tmp="${_CACHE_FILE}.$$"
  if tee "$tmp" && [[ -s "$tmp" ]]; then
    mv -f "$tmp" "$_CACHE_FILE"
  else
    rm -f "$tmp"
  fi
}

cleanup_cache() {
  find "$_CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null || true
}

# tracked_files — cached git ls-files with optional extension filter and EXCLUDES applied
# Usage: tracked_files [ext-regex]
# Example: tracked_files '\.(ts|js)$'
tracked_files() {
  if [[ -z "$_GIT_FILES_CACHE" || ! -f "$_GIT_FILES_CACHE" ]]; then
    _GIT_FILES_CACHE=$(mktemp)
    git ls-files 2>/dev/null > "$_GIT_FILES_CACHE"
  fi
  if [[ -n "$1" ]]; then
    grep -E "$1" "$_GIT_FILES_CACHE" | grep -vE "$EXCLUDES"
  else
    grep -vE "$EXCLUDES" "$_GIT_FILES_CACHE"
  fi
}
