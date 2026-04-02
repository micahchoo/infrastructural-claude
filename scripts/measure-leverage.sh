#!/usr/bin/env bash
# measure-leverage.sh — Scorecard for high-leverage infrastructure metrics
# Each metric uses the most specific check possible to avoid false positives.
set +e

CLAUDE_DIR="$HOME/.claude"
RESULTS=""

log() { RESULTS="${RESULTS}\n$1"; }

# -- M1: Router recall --
# Tests prompts against the ACTUAL SKILL.md description text, not hardcoded keywords.
# For each prompt, checks if >=2 content words appear in the description.
m1_pass=0
m1_total=0
TEST_PROMPTS=(
  "how should we architect the undo system"
  "sync conflicts between collaborative editors"
  "gesture handlers are fighting for input"
  "focus keeps escaping the modal"
  "CRDT merge strategy for concurrent edits"
  "optimistic UI rollback on server rejection"
  "annotation state management across zoom levels"
  "node graph evaluation order for rendering pipeline"
  "message dispatch pattern for editor commands"
  "graph-as-document model for canvas persistence"
  "virtualize a large list of layer thumbnails"
  "schema migration for saved document format"
  "embed the editor as a component in another app"
  "spatial index for hit-testing drawn shapes"
  "platform-specific keyboard shortcuts Mac vs Linux"
  "media pipeline for image filter processing"
  "text editing cursor position in rich text"
  "constraint solver for snap-to-grid alignment"
  "hierarchical composition of grouped objects"
  "off-thread compute for expensive node operations"
)
STOP_WORDS="the|a|an|for|in|of|to|and|or|is|with|on|at|by|from|as|how|should|we|its|that|this|when|what"
CODEBOOK_DESC=$(sed -n '/^description:/,/^---/p' "$CLAUDE_DIR/skills/domain-codebooks/SKILL.md" 2>/dev/null)
for prompt in "${TEST_PROMPTS[@]}"; do
  m1_total=$((m1_total + 1))
  # Extract content words (skip stop words), check how many appear in description
  hits=0
  for word in $prompt; do
    [ ${#word} -lt 3 ] && continue
    echo "$word" | grep -qiE "^($STOP_WORDS)$" && continue
    if echo "$CODEBOOK_DESC" | grep -qiE "$word"; then
      hits=$((hits + 1))
    fi
  done
  # Require >=2 content word hits to count as a match
  [ $hits -ge 2 ] && m1_pass=$((m1_pass + 1))
done
m1_pct=$((m1_pass * 100 / m1_total))
log "M1  Router recall:              ${m1_pct}% (${m1_pass}/${m1_total})"

# -- M2: Deprecated references --
# Counts deprecated names in active SKILL.md files, excluding DEPRECATED stub files.
m2_count=$(grep -rl 'subagent-driven-development\|finishing-a-development-branch\|using-git-worktrees' \
  "$CLAUDE_DIR/plugins/cache/claude-plugins-official/superpowers"/*/skills/*/SKILL.md \
  "$CLAUDE_DIR/skills"/*/SKILL.md 2>/dev/null \
  | grep -v '/subagent-driven-development/' | grep -v '/finishing-a-development-branch/' | grep -v '/using-git-worktrees/' \
  | wc -l)
m2_occurrences=$(grep -r 'subagent-driven-development\|finishing-a-development-branch\|using-git-worktrees' \
  "$CLAUDE_DIR/plugins/cache/claude-plugins-official/superpowers"/*/skills/*/SKILL.md \
  "$CLAUDE_DIR/skills"/*/SKILL.md 2>/dev/null \
  | grep -v '/subagent-driven-development/' | grep -v '/finishing-a-development-branch/' | grep -v '/using-git-worktrees/' \
  | wc -l)
log "M2  Deprecated references:      ${m2_occurrences} occurrences in ${m2_count} files"

# -- M3: Skill resolution --
# Tests empirically: do standalone overrides contain their unique marker strings?
m3_pass=0
m3_total=0
# executing-plans standalone should have "Brownfield Gates"
m3_total=$((m3_total + 1))
if [ -f "$CLAUDE_DIR/skills/executing-plans/SKILL.md" ] && grep -q 'Brownfield Gates' "$CLAUDE_DIR/skills/executing-plans/SKILL.md" 2>/dev/null; then
  m3_pass=$((m3_pass + 1))
fi
# Check that plugin version does NOT have the marker (confirming they differ)
if [ -f "$CLAUDE_DIR/plugins/cache/claude-plugins-official/superpowers"/*/skills/executing-plans/SKILL.md ]; then
  m3_total=$((m3_total + 1))
  if ! grep -q 'Brownfield Gates' "$CLAUDE_DIR/plugins/cache/claude-plugins-official/superpowers"/*/skills/executing-plans/SKILL.md 2>/dev/null; then
    m3_pass=$((m3_pass + 1))
  fi
fi
if [ $m3_total -eq 0 ]; then
  log "M3  Skill resolution:           NO DUPLICATES FOUND"
elif [ $m3_pass -eq $m3_total ]; then
  log "M3  Skill resolution:           OVERRIDES DISTINCT (${m3_pass}/${m3_total} markers correct)"
else
  log "M3  Skill resolution:           MARKERS MISSING (${m3_pass}/${m3_total})"
fi

# -- M4: Cache atomicity --
# Positive check: finalize_cache must contain 'mv -f' (atomic rename pattern)
if grep -A2 'finalize_cache' "$CLAUDE_DIR/scripts/lib/cache-utils.sh" 2>/dev/null | grep -q 'mv -f'; then
  log "M4  Cache writes:               ATOMIC (mv)"
else
  log "M4  Cache writes:               NON-ATOMIC (no mv -f in finalize_cache)"
fi

# -- M5: jq dependency --
# Searches both scripts/*.sh AND scripts/lib/*.sh, excludes self
m5_count=0
for script in "$CLAUDE_DIR/scripts"/*.sh "$CLAUDE_DIR/scripts"/lib/*.sh; do
  [ -f "$script" ] || continue
  [ "$(basename "$script")" = "measure-leverage.sh" ] && continue
  if grep -q '\bjq\b' "$script" 2>/dev/null; then
    if ! grep -q 'command -v jq\|which jq\|type jq' "$script" 2>/dev/null; then
      m5_count=$((m5_count + 1))
    fi
  fi
done
log "M5  Scripts using jq unchecked: ${m5_count}"

# -- M6: Context pressure hook --
# Checks for specific evidence: a script named context-pressure* exists AND
# is registered as a hook in settings.json
m6_script=$(ls "$CLAUDE_DIR/scripts"/context-pressure*.sh 2>/dev/null | head -1)
if [ -n "$m6_script" ] && grep -q "context-pressure" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
  log "M6  Context pressure hook:      EXISTS ($(basename "$m6_script") + registered)"
elif [ -n "$m6_script" ]; then
  log "M6  Context pressure hook:      SCRIPT ONLY (not registered in settings.json)"
else
  log "M6  Context pressure hook:      MISSING"
fi

# -- M7: Brainstorm->plan gate --
# Checks for a specific structural section in writing-plans, not just keyword co-occurrence.
# A real gate has a section header like "Input Validation" or "Brainstorm Gate"
# AND defines eval checkpoints with [eval:] markers referencing brainstorm output.
m7_file=$(ls "$CLAUDE_DIR/plugins/cache/claude-plugins-official/superpowers"/*/skills/writing-plans/SKILL.md 2>/dev/null | head -1)
if [ -n "$m7_file" ]; then
  if grep -q '## Input Validation\|## Brainstorm Gate\|## Brainstorm.*Validation' "$m7_file" 2>/dev/null; then
    log "M7  Brainstorm->plan gate:      EXISTS (section header found)"
  elif grep -q '\[eval:.*feasibility\]\|\[eval:.*completeness\]' "$m7_file" 2>/dev/null; then
    log "M7  Brainstorm->plan gate:      PARTIAL (eval checkpoints but no gate section)"
  else
    log "M7  Brainstorm->plan gate:      MISSING"
  fi
else
  log "M7  Brainstorm->plan gate:      MISSING (writing-plans SKILL.md not found)"
fi

# -- M8: Memory TTL --
# Matches frontmatter fields specifically: ^last-verified: or ^ttl-days:
m8_total=0
m8_with_ttl=0
for mem in "$CLAUDE_DIR"/projects/*/memory/*.md; do
  [ "$(basename "$mem")" = "MEMORY.md" ] && continue
  [ -f "$mem" ] || continue
  m8_total=$((m8_total + 1))
  if grep -q '^last-verified:\|^ttl-days:' "$mem" 2>/dev/null; then
    m8_with_ttl=$((m8_with_ttl + 1))
  fi
done
log "M8  Memory TTL coverage:        ${m8_with_ttl}/${m8_total} files have TTL"

# -- M9: settings.json backup --
# Checks for specific evidence: backup-settings.sh exists + is registered as SessionStart hook
if [ -x "$CLAUDE_DIR/scripts/backup-settings.sh" ] && grep -q 'backup-settings' "$CLAUDE_DIR/settings.json" 2>/dev/null; then
  log "M9  settings.json backup:       AUTOMATED (backup-settings.sh + hook registered)"
elif [ -f "$CLAUDE_DIR/scripts/backup-settings.sh" ]; then
  log "M9  settings.json backup:       SCRIPT ONLY (not registered or not executable)"
else
  log "M9  settings.json backup:       NONE"
fi

# -- M10: Platform portability --
# Counts scripts with GNU-only stat -c that lack BSD fallback on the same line
m10_count=0
for script in "$CLAUDE_DIR/scripts"/*.sh "$CLAUDE_DIR/scripts"/lib/*.sh; do
  [ -f "$script" ] || continue
  [ "$(basename "$script")" = "measure-leverage.sh" ] && continue
  if grep -q 'stat -c' "$script" 2>/dev/null; then
    if grep 'stat -c' "$script" 2>/dev/null | grep -qv 'stat -f'; then
      m10_count=$((m10_count + 1))
    fi
  fi
done
log "M10 GNU-only stat scripts:      ${m10_count}"

# -- Output scorecard --
echo "==================================================="
echo "  HIGH-LEVERAGE SCORECARD  $(date +%Y-%m-%d\ %H:%M)"
echo "==================================================="
echo -e "$RESULTS"
echo "==================================================="
