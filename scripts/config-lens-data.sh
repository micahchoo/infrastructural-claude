#!/usr/bin/env bash
# config-lens-data.sh — Data lens: file types, sizes, lifecycle classification, freshness
# Analyzes the mass and lifecycle of data in a Claude Code config directory
set +e

TARGET="${1:-$HOME/.claude}"
[[ -d "$TARGET" ]] || { echo "Usage: config-lens-data.sh [claude-config-dir]"; exit 1; }
cd "$TARGET" || exit 1
ABS_TARGET=$(pwd)

echo "=== DATA LENS: $(basename "$ABS_TARGET") ==="
echo ""

# --- Directory sizes ---
echo "=== DIRECTORY SIZES ==="
du -sh */ 2>/dev/null | sort -rh | head -20
# Top-level files
top_file_size=$(find . -maxdepth 1 -type f -exec du -ch {} + 2>/dev/null | tail -1 | awk '{print $1}')
echo "${top_file_size:-0}	(top-level files)"
echo ""

# --- File type distribution ---
echo "=== FILE TYPES (by count) ==="
find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' \
  | grep -oE '\.[^./]+$' | sort | uniq -c | sort -rn | head -15
echo ""

# --- File type distribution by size ---
echo "=== FILE TYPES (by size) ==="
find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -printf '%s %f\n' 2>/dev/null \
  | awk '{
      ext = $2; sub(/.*\./, ".", ext);
      if (ext == $2) ext = "(no ext)";
      sizes[ext] += $1; counts[ext]++
    }
    END {
      for (e in sizes) printf "%10.1fM  %s (%d files)\n", sizes[e]/1048576, e, counts[e]
    }' \
  | sort -rn | head -15
echo ""

# --- Lifecycle classification ---
echo "=== LIFECYCLE CLASSIFICATION ==="

classify_dir() {
  local dir="$1" category="$2" desc="$3"
  if [[ -d "$dir" ]]; then
    local size
    size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    printf "  %-22s %-6s  %s\n" "$dir" "$size" "$desc"
  fi
}

echo "Session state (per-session, ephemeral):"
classify_dir "projects"       "" "conversation transcripts (JSONL by UUID)"
classify_dir "tasks"          "" "subagent task data + highwatermarks"
classify_dir "session-env"    "" "environment snapshots"
classify_dir "shell-snapshots" "" "shell state captures"
echo ""

echo "Versioned snapshots (immutable copies, accumulate):"
classify_dir "plugins/cache"        "" "installed plugin versions"
classify_dir "plugins/marketplaces" "" "marketplace clones"
classify_dir "autoresearch/variants" "" "A/B test config clones"
classify_dir "mcp-servers"          "" "MCP server code + deps"
echo ""

echo "Append-only logs (accumulate across sessions):"
if [[ -f "history.jsonl" ]]; then
  lines=$(wc -l < history.jsonl 2>/dev/null)
  size=$(du -sh history.jsonl 2>/dev/null | awk '{print $1}')
  echo "  history.jsonl          $size   global history ($lines lines)"
fi
classify_dir "debug"          "" "trace files by UUID"
classify_dir "logs"           "" "hook/scan logs"
if [[ -f "autoresearch/results.jsonl" ]]; then
  lines=$(wc -l < autoresearch/results.jsonl 2>/dev/null)
  echo "  autoresearch/results   -      eval results ($lines entries)"
fi
echo ""

echo "Safety nets (recovery/undo):"
classify_dir "file-history"   "" "file edit history for rollback"
classify_dir "backups"        "" "rotating settings.json snapshots"
echo ""

echo "Caches (disposable, rebuildable):"
classify_dir "paste-cache"    "" "clipboard buffers"
classify_dir "cache"          "" "general cache"
for f in *-cache.json; do
  [[ -f "$f" ]] || continue
  size=$(du -sh "$f" 2>/dev/null | awk '{print $1}')
  echo "  $f  $size"
done
echo ""

echo "Other:"
classify_dir "teams"          "" "agent team configs"
classify_dir "plans"          "" "implementation plans"
classify_dir "context-mode"   "" "context-mode plugin state"
classify_dir "memory"         "" "auto-memory records"
echo ""

# --- Freshness ---
echo "=== FRESHNESS ==="
total_files=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l)
recent_1d=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -mtime -1 2>/dev/null | wc -l)
recent_7d=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -mtime -7 2>/dev/null | wc -l)
recent_30d=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -mtime -30 2>/dev/null | wc -l)
stale_90d=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -mtime +90 2>/dev/null | wc -l)
echo "total files: $total_files"
echo "modified <1d:  $recent_1d"
echo "modified <7d:  $recent_7d"
echo "modified <30d: $recent_30d"
echo "stale >90d:    $stale_90d"
echo ""

# --- Largest files ---
echo "=== LARGEST FILES (top 10) ==="
find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -printf '%s %p\n' 2>/dev/null \
  | sort -rn 2>/dev/null | head -10 \
  | awk '{printf "%8.1fM  %s\n", $1/1048576, $2}'
echo ""
