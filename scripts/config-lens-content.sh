#!/usr/bin/env bash
# config-lens-content.sh — Content lens: topics, heading frequency, frontmatter, keywords
# Analyzes what a Claude Code config directory is about by its prose
set +e

TARGET="${1:-$HOME/.claude}"
[[ -d "$TARGET" ]] || { echo "Usage: config-lens-content.sh [claude-config-dir]"; exit 1; }
cd "$TARGET" || exit 1
ABS_TARGET=$(pwd)

echo "=== CONTENT LENS: $(basename "$ABS_TARGET") ==="
echo ""

MD_COUNT=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l)

# --- Heading frequency ---
echo "=== HEADING FREQUENCY (H1/H2, top 20) ==="
if [[ "$MD_COUNT" -gt 0 ]]; then
  find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -exec grep -h '^##\? ' {} + 2>/dev/null \
    | sed 's/^#* //' \
    | awk '{$1=$1; print tolower($0)}' \
    | sort | uniq -c | sort -rn | head -20
fi
echo ""

# --- Topic density by directory ---
echo "=== TOPIC DENSITY (words by top-level dir) ==="
for dir in */; do
  [[ -d "$dir" ]] || continue
  dir_name="${dir%/}"
  word_count=$(find "$dir" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -exec cat {} + 2>/dev/null | wc -w)
  [[ "$word_count" -gt 0 ]] && printf "  %8d  %s\n" "$word_count" "$dir_name"
done | sort -rn
echo "  --------"
total_words=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -exec cat {} + 2>/dev/null | wc -w)
printf "  %8d  total (%d files)\n" "$total_words" "$MD_COUNT"
echo ""

# --- Frontmatter survey ---
echo "=== FRONTMATTER ==="
if [[ "$MD_COUNT" -gt 0 ]]; then
  FM_COUNT=$(find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -exec grep -l '^---$' {} + 2>/dev/null | wc -l)
  echo "files with frontmatter: $FM_COUNT / $MD_COUNT"
  if [[ "$FM_COUNT" -gt 0 ]]; then
    echo "top keys:"
    find . -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null \
      | xargs -0 awk 'FNR==1{c=0} /^---$/{if(++c==1){next}else{c=3;next}} c==1 && /^[a-zA-Z_-]+:/{split($0,a,":"); print a[1]}' 2>/dev/null \
      | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
  fi
fi
echo ""

# --- Skill keyword extraction ---
echo "=== SKILL KEYWORDS ==="
if [[ -d "skills" ]]; then
  # Extract description fields from SKILL.md frontmatter, tokenize, count
  find skills -name 'SKILL.md' -print0 2>/dev/null \
    | xargs -0 awk 'FNR==1{c=0} /^---$/{if(++c==1){next}else{c=3;next}} c==1 && /^description:/{sub(/^description: */, ""); print}' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alpha:]' '\n' \
    | grep -vE '^(the|a|an|and|or|for|to|of|in|is|it|on|at|by|with|from|as|use|when|this|that|not|do|are|be|has|have|will|can|may|its|you|your)$' \
    | sort | uniq -c | sort -rn | head -20 | sed 's/^/  /'
fi
echo ""

# --- Unique H1 topics per directory (structural topic map) ---
echo "=== DIRECTORY TOPICS (unique H1s) ==="
for dir in */; do
  [[ -d "$dir" ]] || continue
  dir_name="${dir%/}"
  topics=$(find "$dir" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -exec grep -h '^# [A-Z]' {} + 2>/dev/null \
    | sed 's/^# //' | cut -c1-60 | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')
  [[ -n "$topics" ]] && echo "  $dir_name: $topics"
done
echo ""
