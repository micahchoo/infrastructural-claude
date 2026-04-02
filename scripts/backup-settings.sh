#!/usr/bin/env bash
# backup-settings.sh — SessionStart hook that backs up settings.json
# Adopts autoresearch's guard/restore pattern: snapshot on start, detect mid-session mutation
set +e
SETTINGS="$HOME/.claude/settings.json"
BACKUP_DIR="$HOME/.claude/backups"
SNAPSHOT="$BACKUP_DIR/settings.json.session-snapshot"
mkdir -p "$BACKUP_DIR"

if [ -f "$SETTINGS" ]; then
  # Rotating backup (keep last 5)
  cp "$SETTINGS" "$BACKUP_DIR/settings.json.$(date +%Y%m%d-%H%M%S)"
  ls -t "$BACKUP_DIR"/settings.json.2* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null

  # Session snapshot for contamination detection (autoresearch pattern)
  if [ -f "$SNAPSHOT" ] && ! diff -q "$SNAPSHOT" "$SETTINGS" >/dev/null 2>&1; then
    echo "WARNING: settings.json was modified since last session start."
    echo "Previous snapshot preserved at $SNAPSHOT"
    echo "Current version may have been modified by a plugin or hook."
  fi
  cp "$SETTINGS" "$SNAPSHOT"
fi
