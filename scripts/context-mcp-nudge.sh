#!/usr/bin/env bash
# context-mcp-nudge.sh — PreToolUse hook that nudges toward Context MCP
# when Claude is about to Read a reference/doc file or do a web search
# that might be served faster by get_docs()
set +e
command -v jq >/dev/null 2>&1 || exit 0

# Parse the tool input from stdin
INPUT=$(cat)
TOOL_NAME="${TOOL_USE_NAME:-}"

# Only act on Read, WebSearch, WebFetch
case "$TOOL_NAME" in
  Read)
    FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
    [[ -z "$FILE_PATH" ]] && exit 0

    # Check if reading a reference file from skills/codebooks
    if [[ "$FILE_PATH" == *"/skills/"*"/references/"* ]]; then
      echo "Context MCP: This reference file is indexed in domain-codebooks or claude-skill-tree. Consider get_docs() instead of Read (unless you need to Edit)."
      exit 0
    fi

    # Check if reading library docs (node_modules, vendor, etc.)
    if [[ "$FILE_PATH" == *"/node_modules/"* || "$FILE_PATH" == *"/vendor/"* ]]; then
      PKG=$(echo "$FILE_PATH" | grep -oP 'node_modules/\K(@[^/]+/[^/]+|[^/]+)' | head -1)
      if [[ -n "$PKG" ]]; then
        echo "Context MCP: Library docs may be indexed. Try search_packages(\"$PKG\") or get_docs(\"$PKG\", \"<topic>\") first (~350ms vs reading source)."
      fi
      exit 0
    fi
    ;;

  WebSearch|WebFetch)
    # Any web search/fetch should check Context MCP first
    QUERY=$(echo "$INPUT" | jq -r '.query // .url // empty' 2>/dev/null)
    if [[ -n "$QUERY" ]]; then
      echo "Context MCP: 92+ packages indexed locally (~350ms). Try search_packages(\"<library>\") or get_docs(\"<package>\", \"<topic>\") before web fetching."
    fi
    exit 0
    ;;
esac
