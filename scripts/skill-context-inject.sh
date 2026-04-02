#!/usr/bin/env bash
# skill-context-inject.sh — PreToolUse hook for Skill invocations
# Injects skill catalog + pipeline catalog before planning/brainstorming skills
set +e

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
skill_name=$(echo "$input" | jq -r '.tool_input.skill // .input.skill // empty' 2>/dev/null)
[ -z "$skill_name" ] && exit 0
skill_name="${skill_name##*:}"

# Only fire for planning-adjacent skills
case "$skill_name" in
  brainstorming|writing-plans|executing-plans) ;;
  *) exit 0 ;;
esac

SKILL_DIR="$HOME/.claude/skills"
PIPELINES="$HOME/.claude/pipelines.yaml"
SKILL_CACHE="/tmp/skill-catalog-cache"
PIPELINE_CACHE="/tmp/pipeline-catalog-cache"

# --- Skill catalog (cached) ---
if [ ! -f "$SKILL_CACHE" ] || [ "$SKILL_DIR" -nt "$SKILL_CACHE" ]; then
  catalog=""
  for skill_file in "$SKILL_DIR"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    sname=$(sed -n 's/^name: *//p' "$skill_file" | head -1)
    [ -z "$sname" ] && continue
    catalog="${catalog}  ${sname}\n"
  done
  # Also include marketplace skills not locally overridden
  for skill_file in "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/"*/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    sname=$(sed -n 's/^name: *//p' "$skill_file" | head -1)
    [ -z "$sname" ] && continue
    # Skip if local override exists
    [ -f "$SKILL_DIR/$sname/SKILL.md" ] && continue
    catalog="${catalog}  ${sname}\n"
  done
  echo -e "$catalog" | sort -u > "$SKILL_CACHE"
fi

# --- Pipeline catalog (cached) ---
if [ ! -f "$PIPELINE_CACHE" ] || [ "$PIPELINES" -nt "$PIPELINE_CACHE" ]; then
  python3 -c "
import yaml, sys
with open('$PIPELINES') as f:
    data = yaml.safe_load(f)
groups = {}
for p in data.get('pipelines', []):
    s = p.get('status', 'active')
    groups.setdefault(s, []).append(p['name'])
for status in ['active', 'forming', 'planned']:
    names = groups.get(status, [])
    if names:
        print(f'{status}: {\", \".join(names)}')
" > "$PIPELINE_CACHE" 2>/dev/null
fi

# --- Emit ---
echo "<skill-catalog>"
echo "Available skills:"
cat "$SKILL_CACHE"
echo ""
cat "$PIPELINE_CACHE"
echo ""
echo "Decision gate: Which skills and pipelines apply to this work?"
echo "Annotate each plan task with its execution skill."
echo "</skill-catalog>"

exit 0
