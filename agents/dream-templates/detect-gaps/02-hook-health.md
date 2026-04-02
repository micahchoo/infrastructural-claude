---
name: hook-health
mode: detect-gaps
layer: L2
trigger: always
priority: 2
---

## What This Checks

30+ hook scripts across 6 event types can break silently — timeouts, missing scripts, permission errors. Log files capture these failures but nobody reviews them. Dead hooks waste startup time and can cause subtle behavior gaps.

## Steps

1. **Scan hook logs** for error patterns:
   ```bash
   # Timeout patterns
   grep -i 'timeout\|timed out\|killed' ~/.claude/logs/*.log 2>/dev/null | tail -20
   # Permission/path errors
   grep -i 'permission denied\|not found\|no such file' ~/.claude/logs/*.log 2>/dev/null | tail -20
   ```

2. **Check for dead hooks** — hooks in settings.json whose scripts don't exist:
   ```bash
   # Dream-added: 2026-03-25 — fixed: capture $HOME/~ prefixed paths, not just /path
   jq -r '.. | .command? // empty' ~/.claude/settings.json 2>/dev/null | \
     grep '\.sh' | while IFS= read -r script; do
       # Extract .sh paths including $HOME, $VAR, and ~ prefixes
       echo "$script" | grep -oP '(?:\$\w+|~)?/[\w/.~-]+\.sh' | while read -r sh_path; do
         expanded=$(eval echo "$sh_path" 2>/dev/null)
         [ -n "$expanded" ] && [ ! -f "$expanded" ] && echo "DEAD HOOK: $sh_path → $expanded"
       done
     done
   ```

3. **Fix or report**:
   - Fixable issues (wrong path, missing directory) → fix directly
   - Structural issues → create a seeds issue:
     ```bash
     sd create --title "Dead hook: <script>" --type bug --priority P2 --labels hook-health
     ```

## Eval Checkpoints

`[eval: target]` Focused analysis on hooks with errors, timeouts, or unexpected exit codes — not a broad survey of all hooks.

`[eval: execution]` Fixes for broken hooks were applied (script edits, settings.json updates), not just logged as recommendations.

## Improvement Writes

- Fix broken hook script paths in settings.json
- Create seeds issues for structural hook problems
- Report timeout patterns for investigation

## Digest Section

```
### Hook health
- Logs scanned: N | Errors found: N
- Dead hooks found: N | Fixed: N | Issues created: N
```

## Recovery

- **On settings.json parse error**: **escalate** — settings.json is load-bearing for all sessions. Note error, don't attempt repair without user confirmation.
- **On no error signals in logs**: **degrade** — skip template, note "hooks healthy" in digest.
- **On ambiguous error** (unclear if hook failure or expected behavior): **degrade** — log the ambiguity, don't "fix" what might be intentional.
