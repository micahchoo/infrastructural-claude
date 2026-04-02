#!/usr/bin/env bash
# content-analytics.sh — 0-shot observability for non-code / prose-heavy directories
# Produces a compact summary (~60-80 lines, ~800 tokens)
# Complements codebase-analytics.sh for docs, vaults, knowledge bases, wikis
# Caches by directory content hash to avoid redundant work
set +e

TARGET="${1:-.}"
[[ -d "$TARGET" ]] || { echo "Usage: content-analytics.sh [directory]"; exit 1; }
cd "$TARGET"
ABS_TARGET=$(pwd)

# --- Cache logic ---
CACHE_DIR="/tmp/content-analytics-cache"
mkdir -p "$CACHE_DIR"
DIR_HASH=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -exec sh -c 'stat -c "%Y" "$1" 2>/dev/null || stat -f "%m" "$1" 2>/dev/null || echo 0' _ {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
CACHE_KEY=$(echo "${ABS_TARGET}_${DIR_HASH}" | sha256sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

if [[ -f "$CACHE_FILE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -lt 300 ]]; then
  cat "$CACHE_FILE"
  exit 0
fi

# --- Gather analytics ---
{
  echo "=== CONTENT SURVEY: $(basename "$ABS_TARGET") ==="
  echo ""

  # 1. File type breakdown
  echo "=== FILE TYPES ==="
  find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' \
    | grep -oE '\.[^./]+$' | sort | uniq -c | sort -rn | head -12
  echo ""

  # 2. Markdown stats
  MD_COUNT=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' | wc -l)
  MD_WORDS=0
  MD_LINES=0
  if [[ $MD_COUNT -gt 0 ]]; then
    MD_WORDS=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec cat {} + 2>/dev/null | wc -w)
    MD_LINES=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec cat {} + 2>/dev/null | wc -l)
  fi
  echo "=== MARKDOWN ==="
  echo "files: $MD_COUNT"
  echo "words: $MD_WORDS"
  echo "lines: $MD_LINES"
  if [[ $MD_COUNT -gt 0 ]]; then
    echo "avg words/file: $((MD_WORDS / MD_COUNT))"
  fi
  echo ""

  # 3. Indexing recommendation
  echo "=== CONTEXT MCP INDEXING ==="
  if [[ $MD_COUNT -ge 50 ]]; then
    echo "RECOMMENDED: $MD_COUNT markdown files (threshold: 50)"
    echo "  context add \"$ABS_TARGET\" --name \"$(basename "$ABS_TARGET")\" --pkg-version 1.0"
  elif [[ $MD_COUNT -ge 20 ]]; then
    echo "MARGINAL: $MD_COUNT markdown files (threshold: 50, consider if heavily cross-referenced)"
  else
    echo "NOT NEEDED: $MD_COUNT markdown files (use Grep for search)"
  fi
  echo ""

  # 4. Directory structure
  echo "=== STRUCTURE ==="
  if command -v tree &>/dev/null; then
    tree -L 2 --dirsfirst -I 'node_modules|.git|vendor|dist|build|__pycache__|.next|.cache' \
      --noreport 2>/dev/null | head -30
  else
    find . -maxdepth 2 -type d \
      -not -path '*/.git*' -not -path '*/node_modules*' \
      | sort | head -25
  fi
  echo ""

  # 5. Heading topics — most common H1/H2 across all markdown
  if [[ $MD_COUNT -gt 0 ]]; then
    echo "=== TOPICS (heading frequency) ==="
    find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec grep -h '^##\? ' {} + 2>/dev/null \
      | sed 's/^#* //' \
      | awk '{$1=$1; print tolower($0)}' \
      | sort | uniq -c | sort -rn | head -15
    echo ""
  fi

  # 6. Frontmatter property survey — what YAML keys appear
  if [[ $MD_COUNT -gt 0 ]]; then
    FM_FILES=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec grep -l '^---$' {} + 2>/dev/null | wc -l)
    if [[ $FM_FILES -gt 0 ]]; then
      echo "=== FRONTMATTER ==="
      echo "files with frontmatter: $FM_FILES / $MD_COUNT"
      # Extract top-level YAML keys between --- fences
      find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
        -exec awk '/^---$/{if(++c==1){next}else{exit}} c==1 && /^[a-zA-Z_-]+:/{split($0,a,":"); print a[1]}' {} + 2>/dev/null \
        | sort | uniq -c | sort -rn | head -12
      echo ""
    fi
  fi

  # 7. Internal link density (wikilinks and markdown links)
  if [[ $MD_COUNT -gt 0 ]]; then
    WIKILINKS=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec grep -ohE '\[\[[^\]]+\]\]' {} + 2>/dev/null | wc -l)
    MD_LINKS=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -exec grep -ohE '\[([^\]]+)\]\([^\)]+\)' {} + 2>/dev/null | wc -l)
    echo "=== LINKS ==="
    echo "wikilinks: $WIKILINKS"
    echo "markdown links: $MD_LINKS"
    if [[ $MD_COUNT -gt 0 ]]; then
      echo "links/file: $(( (WIKILINKS + MD_LINKS) / MD_COUNT ))"
    fi
    echo ""
  fi

  # 8. Staleness — file age distribution
  echo "=== FRESHNESS ==="
  RECENT_7D=$(find . -name '*.md' -not -path '*/.git/*' -mtime -7 2>/dev/null | wc -l)
  RECENT_30D=$(find . -name '*.md' -not -path '*/.git/*' -mtime -30 2>/dev/null | wc -l)
  STALE_90D=$(find . -name '*.md' -not -path '*/.git/*' -mtime +90 2>/dev/null | wc -l)
  echo "modified <7d: $RECENT_7D"
  echo "modified <30d: $RECENT_30D"
  echo "stale >90d: $STALE_90D"
  if [[ $MD_COUNT -gt 0 && $STALE_90D -gt 0 ]]; then
    echo "staleness: $((STALE_90D * 100 / MD_COUNT))%"
  fi
  echo ""

  # 9. Largest markdown files
  echo "=== LARGEST FILES ==="
  find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -exec wc -w {} + 2>/dev/null \
    | grep -v ' total$' | sort -rn | head -8
  echo ""

  # 10. Non-markdown content signals
  YAML_COUNT=$(find . -name '*.yaml' -o -name '*.yml' -not -path '*/.git/*' 2>/dev/null | wc -l)
  JSON_COUNT=$(find . -name '*.json' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l)
  CSV_COUNT=$(find . -name '*.csv' -not -path '*/.git/*' 2>/dev/null | wc -l)
  IMG_COUNT=$(find . \( -name '*.png' -o -name '*.jpg' -o -name '*.svg' -o -name '*.gif' \) -not -path '*/.git/*' 2>/dev/null | wc -l)
  if [[ $((YAML_COUNT + JSON_COUNT + CSV_COUNT + IMG_COUNT)) -gt 0 ]]; then
    echo "=== NON-MARKDOWN CONTENT ==="
    [[ $YAML_COUNT -gt 0 ]] && echo "yaml/yml: $YAML_COUNT"
    [[ $JSON_COUNT -gt 0 ]] && echo "json: $JSON_COUNT"
    [[ $CSV_COUNT -gt 0 ]] && echo "csv: $CSV_COUNT"
    [[ $IMG_COUNT -gt 0 ]] && echo "images: $IMG_COUNT"
    echo ""
  fi

  # 11. Obsidian vault detection
  if [[ -d ".obsidian" ]]; then
    echo "=== OBSIDIAN VAULT ==="
    echo "detected: yes"
    BASE_COUNT=$(find . -name '*.base' 2>/dev/null | wc -l)
    CANVAS_COUNT=$(find . -name '*.canvas' 2>/dev/null | wc -l)
    [[ $BASE_COUNT -gt 0 ]] && echo "bases: $BASE_COUNT"
    [[ $CANVAS_COUNT -gt 0 ]] && echo "canvases: $CANVAS_COUNT"
    [[ -f ".obsidian/plugins/extended-graph/data.json" ]] && echo "extended-graph: yes"
    echo ""
  fi

} > "$CACHE_FILE" 2>/dev/null

find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null || true

cat "$CACHE_FILE"
