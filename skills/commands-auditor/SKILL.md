---
name: commands-auditor
description: >-
  Audit Claude Code's approved Bash commands (permissions.allow) for security risks.
  Scans settings.json for dangerous patterns like Bash(*), sudo, rm -rf, curl|sh.
  Triggers: "audit permissions", "cc-safe", "permission audit", reviewing permissions.allow,
  or after update-config modifies Bash permissions. ONLY for Claude Code's own
  permissions.allow — not npm/pip audit, chmod, IAM, or general security review.
---

# Commands Auditor

Scan Claude Code settings for risky approved Bash permissions.

**Risk assessment:** severity x frequency x hook_count (see Blast Radius below).

## What to scan

All settings files that can contain `permissions.allow`:
- `~/.claude/settings.json` and `settings.local.json` (global)
- `./.claude/settings.json` and `settings.local.json` (project)

Extract every `Bash(...)` entry and match against risk patterns.

## Risk tiers

**Critical** (recommend removal): `rm -rf`, `sudo`, `chmod 777`, `curl|sh`/`wget|bash`, `Bash(*)` (blanket), disk-destructive (`dd`, `mkfs`), publishing (`npm publish`, `cargo publish`), `docker run --privileged`

**Warning** (recommend scoping): `git reset --hard`, `git push --force`, `git clean -f`, `kill`/`pkill`, system-wide installs (`pip install`, `npm install -g`), overly broad globs

**Context-dependent** (note but don't alarm): `docker exec` in container workflows, `rm -rf` scoped to temp dirs, force-push to personal branches

## Output format

Group by severity. For each finding: file path, the pattern, why it's risky, and a tighter alternative. End with clean files.

Verify unfamiliar command flags via `get_docs("tldr", "<command>")` before classifying risk — avoids false positives.

## Blast radius tracing

After scanning permissions, run `~/.claude/scripts/config-lens-structural.sh` and cross-reference
flagged permissions against hook wiring to assess actual exposure:

1. **Hook frequency**: Which hooks could exercise each flagged permission?
   - SessionStart: runs once per session (low)
   - PreToolUse: runs per matching tool call — Skill matcher fires ~10x/session (high)
   - UserPromptSubmit: runs per user message (highest)
   - PostToolUse/PreCompact: low frequency
2. **Blast radius**: `severity x frequency x hook_count`. A destructive permission exercised
   by a high-frequency hook is critical. A permission with no hook path is informational only.
3. **Unreachable permissions**: Entries in permissions.allow that no hook script, CLAUDE.md
   instruction, or skill references — candidates for removal.

Output after the risk tier table:

```
=== BLAST RADIUS ===
  Bash(rm -rf):
    exercised by: anti-pattern-scan.sh (PreToolUse:Skill, ~10x/session)
    risk: HIGH (destructive + high frequency)
  Bash(curl):
    exercised by: (no hook path found)
    risk: LOW (exists but unused)

=== UNREACHABLE PERMISSIONS ===
  Bash(docker): no hook or instruction references this
```

`[eval: completeness]` All `Bash(...)` entries checked, including broad globs and context-dependent patterns.
`[eval: idempotence]` Re-running produces same risk classifications.
`[eval: depth]` Blast radius traced through hooks, not just permission pattern matched.

## Suggest fixes, don't just flag

- `Bash(rm -rf *)` → remove, or scope: `Bash(rm -rf /tmp/build-*)`
- `Bash(sudo *)` → remove, or scope: `Bash(sudo systemctl restart myapp)`
- `Bash(*)` → remove, enumerate specific commands needed
