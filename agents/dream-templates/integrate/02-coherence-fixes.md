---
name: coherence-fixes
mode: integrate
layer: cross
trigger: always
priority: 2
---

## What This Checks

Multiple systems reference each other (CLAUDE.md → scripts, settings.json → scripts, pipelines.yaml → pipeline-stage-hook.sh). References drift as files are renamed, moved, or deleted. Unwired scripts are dead code. Broken references cause silent failures.

## Steps

1. **CLAUDE.md drift** — check if referenced scripts/hooks/patterns still exist:
   ```bash
   # Dream-added: 2026-03-24 — filter out conditional dir checks (.mulch/, .seeds/) and slash-commands (/dream, /failure-capture)
   grep -oP '`[~./][\w/.~-]+`' ~/.claude/CLAUDE.md | tr -d '`' | while read path; do
     # Skip conditional directory checks (instructions say "if .mulch/ exists")
     [[ "$path" =~ ^\.(mulch|seeds)/ ]] && continue
     # Skip slash-commands (e.g., /dream, /failure-capture)
     [[ "$path" =~ ^/[a-z] && ! "$path" =~ / *.* ]] && continue
     expanded=$(eval echo "$path" 2>/dev/null)
     [ -n "$expanded" ] && [ ! -e "$expanded" ] && echo "CLAUDE.md DRIFT: $path missing"
   done
   ```
   Fix references to point to current locations, or remove stale entries.

2. **Settings↔scripts coherence** — verify every script in scripts/ is wired to at least one hook:
   ```bash
   # Dream-added: 2026-03-24 — classify unwired as utility (called by other scripts/users) vs truly dead
   for f in ~/.claude/scripts/*.sh; do
     name=$(basename "$f")
     if ! grep -q "$name" ~/.claude/settings.json; then
       # Check if referenced by other scripts (utility, not dead)
       refs=$(grep -rl "$name" ~/.claude/scripts/ ~/.claude/CLAUDE.md 2>/dev/null | grep -v "$f" | wc -l)
       if [ "$refs" -gt 0 ]; then
         echo "UTILITY (not hook-wired, $refs refs): $name"
       else
         echo "UNWIRED (possibly dead): $name"
       fi
     fi
   done
   ```
   For unwired scripts: if they serve a purpose, wire them. If dead code, note for cleanup.

3. **Pipelines↔hook coherence** — verify pipeline stages with `skill:` fields resolve to real skills, and that the hook's dynamic cache can find them:
   ```bash
   # Dream-added: 2026-03-25 — check skill resolution, not hardcoded pipeline names.
   # pipeline-stage-hook.sh uses a dynamic yaml→cache lookup, not name grep.
   # Pipelines WITHOUT skill: fields (principle pipelines) are documentation-only — skip them.
   python3 -c "
import yaml, subprocess, os
with open(os.path.expanduser('~/.claude/pipelines.yaml')) as f:
    data = yaml.safe_load(f)
for p in data.get('pipelines', []):
    skills = [s.get('skill','') for s in p.get('stages',[]) if s.get('skill')]
    if not skills:
        print(f'PRINCIPLE (no skill stages, OK): {p[\"name\"]}')
        continue
    for s in p.get('stages', []):
        sk = s.get('skill','')
        if not sk:
            print(f'  STAGE-NO-SKILL (doc-only, OK): {p[\"name\"]}:{s[\"name\"]}')
            continue
        # Check skill exists as file
        skill_dir = os.path.expanduser(f'~/.claude/skills/{sk}')
        if not os.path.isdir(skill_dir):
            print(f'MISSING-SKILL: {p[\"name\"]}:{s[\"name\"]} → skill {sk}/ not found')
" 2>/dev/null
   ```

## Eval Checkpoints

`[eval: execution]` Drift fixes updated the actual reference (file path, function name, hook wiring), not just logged "drift detected" in the digest.

`[eval: resilience]` Missing scripts and hooks were handled gracefully — reported as drift, not errored.

`[eval: boundary]` Fixes were minimal — changed the stale reference to point to the current location, didn't refactor surrounding code or "improve" unrelated content.

## Improvement Writes

- Fix stale references in CLAUDE.md
- Wire or flag unwired scripts
- Report orphaned pipeline definitions

## Digest Section

```
### Coherence fixes
- CLAUDE.md drift fixed: N references
- Unwired scripts found: N | Wired: N
- Pipeline↔hook mismatches: N
```

## Recovery

- **On CLAUDE.md drift** (referenced paths don't exist): **escalate** — CLAUDE.md changes affect all sessions. Note the specific stale references, propose fixes in digest, but flag for user confirmation before editing.
- **On settings.json↔scripts incoherence** (hook references missing script): **escalate** — note in digest. If the script was clearly renamed (old name substring of new), suggest the fix but don't auto-apply.
- **On ambiguous drift** (unclear if path changed or was intentionally removed): **degrade** — note as "possible drift" in digest, don't fix.
