#!/usr/bin/env bash
# Deterministic Context MCP index freshness checker
#
# Modes:
#   --local    Check local sources only (fast, <1s)
#   --full     Check all sources including remote git (needs network, ~7s)
#   --auto     Local always + full if last full run was > --full-ttl days ago (default: 21d)
#   --update   Check + rebuild stale packages (default: report only)
#   --dry-run  Show what would be rebuilt without doing it
#   --failed-only   Only attempt packages that failed in the last run
#   --parallel=N   Concurrent remote checks/rebuilds (default: 10)
#   --full-ttl=N   Days between full checks in --auto mode (default: 49)
#
# Exit codes: 0 = all fresh, >0 = number of stale packages
set -u

PACKAGES_DIR="${CONTEXT_PACKAGES_DIR:-$HOME/.context/packages}"
STATE_DIR="$HOME/.claude/.context-freshness"
MODE="local"
UPDATE=false
DRY_RUN=false
PARALLEL=10
FAILED_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local" ;;
    --full)  MODE="full" ;;
    --auto)  MODE="auto" ;;
    --update) UPDATE=true ;;
    --dry-run) DRY_RUN=true; UPDATE=false ;;
    --parallel=*) PARALLEL="${1#*=}" ;;
    --full-ttl=*) FULL_TTL_DAYS="${1#*=}" ;;
    --failed-only) FAILED_ONLY=true ;;
    *) echo "Unknown option: $1" >&2; exit 255 ;;
  esac
  shift
done

FULL_TTL_DAYS="${FULL_TTL_DAYS:-49}"

mkdir -p "$STATE_DIR"

# --auto: always run local, promote to full if last full run was > FULL_TTL_DAYS ago
if [[ "$MODE" == "auto" ]]; then
  FULL_STAMP="$STATE_DIR/.last-full-run"
  if [[ -f "$FULL_STAMP" ]]; then
    last_full=$(stat -c %Y "$FULL_STAMP" 2>/dev/null || echo 0)
    age_days=$(( ($(date +%s) - last_full) / 86400 ))
    if [[ $age_days -ge $FULL_TTL_DAYS ]]; then
      MODE="full"
      echo "context-index-freshness: full check triggered (${age_days}d since last, TTL ${FULL_TTL_DAYS}d)"
    else
      MODE="local"
    fi
  else
    # Never run full before — trigger it
    MODE="full"
    echo "context-index-freshness: first full check"
  fi
fi

# --- Helpers ---

meta_get() {
  sqlite3 "$1" "SELECT value FROM meta WHERE key='$2'" 2>/dev/null
}

# --- Check: Local source (dir) ---
# Uses mtime hash — catches both committed and uncommitted changes.

check_local() {
  local db="$1" name="$2" source_url="$3"
  local hash_file="$STATE_DIR/${name}.hash"

  local content_hash
  content_hash=$(find "$source_url" -name "*.md" \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/cache/*" \
    -not -path "*/backups/*" \
    -exec stat -c '%Y %n' {} + 2>/dev/null | sort | md5sum | cut -d' ' -f1)

  local stored_hash
  stored_hash=$(cat "$hash_file" 2>/dev/null)

  if [[ "$content_hash" == "$stored_hash" ]]; then
    return
  fi

  echo "STALE  $name  (local content changed)"

  if $DRY_RUN; then
    echo "  [dry-run] would rebuild $name from $source_url"
  elif $UPDATE; then
    local version
    if [[ -d "$source_url/.git" ]]; then
      version=$(git -C "$source_url" rev-parse --short HEAD 2>/dev/null || echo "local")
    else
      version="${content_hash:0:12}"
    fi
    context add "$source_url" --name "$name" --pkg-version "$version" >/dev/null 2>&1 \
      && echo "  rebuilt $name ($version)" \
      || echo "  FAILED $name" >&2
    echo "$content_hash" > "$hash_file"
  fi
}

# --- Check + Rebuild: Remote git ---
# Called per-package. Designed to be run in parallel via xargs.

check_remote() {
  local db="$1"

  local name source_url source_commit version
  name=$(meta_get "$db" "name")
  source_url=$(meta_get "$db" "source_url")
  source_commit=$(meta_get "$db" "source_commit")
  version=$(meta_get "$db" "version")

  # Determine what to compare against based on version type
  local is_pinned=false
  local ref="HEAD"
  case "$version" in
    main|master|develop|dev) ref="refs/heads/$version" ;;
    ""|latest) ref="HEAD" ;;
    *)
      # Semver or tag-pinned — compare against the tag, not HEAD
      is_pinned=true
      ;;
  esac

  if $is_pinned; then
    # Tag-pinned: only stale if indexed commit doesn't match the tag's commit
    local tag_commit=""
    for tag_try in "$version" "v$version"; do
      tag_commit=$(git ls-remote --tags --quiet "$source_url" "refs/tags/$tag_try" 2>/dev/null | head -1 | cut -f1)
      [[ -n "$tag_commit" ]] && break
    done

    if [[ -z "$tag_commit" ]]; then
      echo "SKIP   $name  (tag $version not found at $source_url)"
      return
    fi

    if [[ "$tag_commit" == "$source_commit" ]]; then
      [[ "$MODE" == "full" ]] && echo "FRESH  $name  (pinned $version)"
      return
    fi

    echo "STALE  $name  (tag $version: ${tag_commit:0:8} != indexed ${source_commit:0:8})"
  else
    # Branch-tracking: stale if HEAD has moved
    local remote_head
    remote_head=$(git ls-remote --quiet "$source_url" "$ref" 2>/dev/null | head -1 | cut -f1)

    if [[ -z "$remote_head" ]]; then
      echo "SKIP   $name  (ls-remote failed for $source_url)"
      return
    fi

    if [[ "$remote_head" == "$source_commit" ]]; then
      [[ "$MODE" == "full" ]] && echo "FRESH  $name"
      return
    fi

    echo "STALE  $name  (remote ${remote_head:0:8} != indexed ${source_commit:0:8})"
  fi

  if $DRY_RUN; then
    echo "  [dry-run] would rebuild $name"
    return
  fi

  if ! $UPDATE; then
    return
  fi

  # Smart rebuild: try registry first (pre-built, ~1.5s), fall back to source (~30s)
  local failed_file="$STATE_DIR/${name}.failed"
  if $FAILED_ONLY && [[ ! -f "$failed_file" ]]; then
    return
  fi

  if context install "npm/$name" >/dev/null 2>&1; then
    echo "  rebuilt $name (registry)"
    rm -f "$failed_file"
  else
    # Try source rebuild — for semver versions, try both "version" and "v{version}" tags
    local tag="${version:-main}"
    local rebuilt=false
    for tag_try in "$tag" "v$tag"; do
      if context add "$source_url" --name "$name" --tag "$tag_try" >/dev/null 2>&1; then
        echo "  rebuilt $name (source, $tag_try)"
        rm -f "$failed_file"
        rebuilt=true
        break
      fi
    done
    if ! $rebuilt; then
      echo "  FAILED $name" >&2
      touch "$failed_file"
    fi
  fi
}
export -f check_remote meta_get
export MODE UPDATE DRY_RUN PACKAGES_DIR FAILED_ONLY STATE_DIR

# --- Main ---

main() {
  local stale_count=0
  local db name source_url
  declare -A seen

  # Collect remote dbs for parallel processing
  local remote_dbs=()

  for db in $(ls -t "$PACKAGES_DIR"/*.db 2>/dev/null); do
    [[ -f "$db" ]] || continue

    name=$(meta_get "$db" "name")
    [[ -z "$name" ]] && continue
    [[ -n "${seen[$name]:-}" ]] && continue
    seen[$name]=1

    source_url=$(meta_get "$db" "source_url")

    if [[ -z "$source_url" ]]; then
      # Registry-only package (no source URL) — skip, use sync_deps per-project
      continue

    elif [[ "$source_url" == http* ]]; then
      # Remote git — collect for parallel processing
      [[ "$MODE" == "full" ]] && remote_dbs+=("$db")

    elif [[ -d "$source_url" ]]; then
      # Local source
      check_local "$db" "$name" "$source_url"

    else
      echo "STALE  $name  (source path missing: $source_url)"
      stale_count=$((stale_count + 1))
    fi
  done

  # Run remote checks in parallel
  if [[ ${#remote_dbs[@]} -gt 0 ]]; then
    printf '%s\n' "${remote_dbs[@]}" | xargs -P "$PARALLEL" -I{} bash -c 'check_remote "$@"' _ {}
  fi
}

output=$(main 2>&1)
echo "$output"

# Stamp full-run timestamp on successful full check
if [[ "$MODE" == "full" ]]; then
  touch "$STATE_DIR/.last-full-run"
fi

stale_count=$(echo "$output" | grep -c "^STALE" || true)
if [[ $stale_count -gt 0 ]]; then
  echo "---"
  echo "$stale_count stale package(s) found"
fi

exit "$stale_count"
