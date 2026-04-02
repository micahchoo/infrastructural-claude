#!/usr/bin/env bash
# Brownfield flow context prerequisite check.
# Fires PreToolUse on Edit/Write. Checks if flow context has been established
# this session via a temp-file flag. If not, injects a blocking reminder.
#
# The agent touches /tmp/flow-context-established-<ppid> after establishing
# flow context at any tier. This script checks for that flag.

set -euo pipefail

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"
FLAG_FILE="/tmp/flow-context-established-${PPID}"

# Only check Edit and Write tools
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# Skip if no file path (shouldn't happen for Edit/Write)
[[ -z "$FILE_PATH" ]] && exit 0

# Skip new file creation (Write to non-existent path)
if [[ "$TOOL_NAME" == "Write" && ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Skip if flow context already established
[[ -f "$FLAG_FILE" ]] && exit 0

# Check if this is a file in the current project (not a temp file, not in ~/.claude itself)
case "$FILE_PATH" in
  /tmp/*|*/.claude/*) exit 0 ;;
esac

# Flow context not established — inject reminder
cat <<'REMINDER'
[FLOW CONTEXT REQUIRED] You are editing an existing file without establishing flow context.

Before proceeding:
1. Check if docs/architecture/ exists in the project
2. Apply the tier calibration tree from CLAUDE.md's Brownfield Flow Protocol
3. Establish flow context at the appropriate tier (Micro: state inline, Standard: produce flow map, Deep: run codebase-diagnostics)
4. Then proceed with the edit

After establishing flow context, the agent should run:
  touch /tmp/flow-context-established-$PPID
REMINDER
