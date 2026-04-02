#!/bin/bash
# Scan files for accidentally leaked credentials before committing
# Usage: scan-secrets.sh file1.md file2.ts ...
# Exit code: 0 = clean, 1 = secrets found
FOUND=0
for file in "$@"; do
  [ -f "$file" ] || continue
  SECRETS=$(grep -nE '(sk-[a-zA-Z0-9_-]{20,}|AKIA[A-Z0-9]{16}|xox[baprs]-[a-zA-Z0-9-]+|-----BEGIN.*(PRIVATE|RSA|EC) KEY|eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.|ghp_[a-zA-Z0-9]{36}|glpat-[a-zA-Z0-9_-]{20,}|npm_[a-zA-Z0-9]{36})' "$file" 2>/dev/null)
  if [ -n "$SECRETS" ]; then
    echo "SECRET: $file contains potential credentials:"
    echo "$SECRETS"
    FOUND=1
  fi
done
exit $FOUND
