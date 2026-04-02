#!/usr/bin/env bash
# Claude Code status line — compact Catppuccin Mocha-inspired prompt

input=$(cat)

# ── Parse JSON ────────────────────────────────────────────────────────────────
cwd=$(echo "$input"   | jq -r '.workspace.current_dir // .cwd // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
used=$(echo "$input"  | jq -r '.context_window.used_percentage // empty')

# ── Try ccstatusline first (fall through to bash rendering if unavailable) ────
if command -v bunx >/dev/null 2>&1; then
  output=$(echo "$input" | bunx -y ccstatusline@latest 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$output" ]; then
    # Write signal file before exiting
    used_raw=${used%.*}
    [ -n "$used_raw" ] && [ "$used_raw" != "null" ] && echo "$used_raw" > /tmp/cc-ctx-usable
    printf "%s\n" "$output"
    exit 0
  fi
fi

# ── Colors (256-color Catppuccin Mocha approximations) ───────────────────────
reset="\033[0m"
peach="\033[38;5;215m"    # directory
green="\033[38;5;150m"    # git branch
red="\033[38;5;210m"      # git dirty / high ctx
overlay0="\033[38;5;242m" # model / low ctx
mauve="\033[38;5;183m"    # peach/mauve for medium ctx

# ── Directory (basename only) ─────────────────────────────────────────────────
dir="${cwd:-$(pwd)}"
dirname="${peach}$(basename "$dir")${reset}"

# ── Git branch + compact status flags (skip optional locks) ──────────────────
git_part=""
if git -c core.fsync=none rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -c core.fsync=none symbolic-ref --short HEAD 2>/dev/null \
           || git -c core.fsync=none rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    git_status=$(git -c core.fsync=none status --porcelain 2>/dev/null)
    flags=""
    echo "$git_status" | grep -q '^[MADRC]'  && flags="${flags}+"
    echo "$git_status" | grep -q '^.[MD]'    && flags="${flags}!"
    echo "$git_status" | grep -q '^??'       && flags="${flags}?"
    git -c core.fsync=none rev-list --count @{u}..HEAD 2>/dev/null | grep -qv '^0$' && flags="${flags}↑"
    git -c core.fsync=none rev-list --count HEAD..@{u} 2>/dev/null | grep -qv '^0$' && flags="${flags}↓"

    git_part="${green}${branch}${reset}"
    [ -n "$flags" ] && git_part="${git_part}${red}${flags}${reset}"
  fi
fi

# ── Model (short: last component of model ID, strip date suffix) ──────────────
model_part=""
if [ -n "$model_id" ]; then
  # e.g. "claude-sonnet-4-6" → strip leading "claude-"
  short=$(echo "$model_id" | sed 's/^claude-//')
  model_part="${overlay0}${short}${reset}"
fi

# ── Context usage ─────────────────────────────────────────────────────────────
ctx_part=""
if [ -n "$used" ] && [ "$used" != "null" ]; then
  used_int=${used%.*}
  echo "$used_int" > /tmp/cc-ctx-usable
  if   [ "$used_int" -ge 80 ]; then ctx_color="$red"
  elif [ "$used_int" -ge 50 ]; then ctx_color="$mauve"
  else                               ctx_color="$overlay0"
  fi
  ctx_part="${ctx_color}${used_int}%${reset}"
fi

# ── Pipeline carousel ────────────────────────────────────────────────────────
teal="\033[38;5;116m"     # pipeline name
yellow="\033[38;5;223m"   # current stage (highlighted)
dim="\033[38;5;239m"      # other stages

pipe_part=""
STATE_FILE="/tmp/pipeline-state.json"
if [ -f "$STATE_FILE" ]; then
  # Only show if state is recent (< 30 min)
  state_ts=$(jq -r '.ts // 0' "$STATE_FILE" 2>/dev/null)
  now_ts=$(date +%s)
  age=$(( now_ts - state_ts ))
  if [ "$age" -lt 1800 ]; then
    pipe_name=$(jq -r '.pipeline // empty' "$STATE_FILE" 2>/dev/null)
    current=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
    stages_str=$(jq -r '.stages // empty' "$STATE_FILE" 2>/dev/null)
    if [ -n "$pipe_name" ] && [ -n "$stages_str" ]; then
      carousel=""
      IFS='|' read -ra STAGES <<< "$stages_str"
      for s in "${STAGES[@]}"; do
        if [ "$s" = "$current" ]; then
          carousel="${carousel}${yellow}●${s}${reset} "
        else
          carousel="${carousel}${dim}○${s}${reset} "
        fi
      done
      pipe_part="${teal}${pipe_name}${reset} ${carousel}"
    fi
  fi
fi

# ── Assemble ──────────────────────────────────────────────────────────────────
line="$dirname"
[ -n "$git_part"   ] && line="${line} ${git_part}"
[ -n "$model_part" ] && line="${line} ${overlay0}|${reset} ${model_part}"
[ -n "$ctx_part"   ] && line="${line} ${ctx_part}"
[ -n "$pipe_part"  ] && line="${line} ${overlay0}|${reset} ${pipe_part}"

printf "%b\n" "$line"
