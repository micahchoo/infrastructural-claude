#!/usr/bin/env bash
# context-mcp-post-fetch.sh — PostToolUse hook after WebFetch/WebSearch
# Evaluates whether fetched content is worth indexing in Context MCP
set +e
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME="${TOOL_USE_NAME:-}"
INPUT=$(cat)

case "$TOOL_NAME" in
  WebFetch)
    URL=$(echo "$INPUT" | jq -r '.url // empty' 2>/dev/null)
    [[ -z "$URL" ]] && exit 0

    # Only trigger on library/API doc URLs
    echo "$URL" | grep -qiE '(docs\.|/docs/|/api/|/reference/|/guide/|readme|npmjs\.com/package/|pypi\.org/project/)' || exit 0

    # Extract package name
    PKG=""
    if echo "$URL" | grep -qE 'npmjs\.com/package/'; then
      PKG=$(echo "$URL" | grep -oP 'npmjs\.com/package/\K(@[^/]+/[^/]+|[^/]+)')
    elif echo "$URL" | grep -qE 'pypi\.org/project/'; then
      PKG=$(echo "$URL" | grep -oP 'pypi\.org/project/\K[^/]+')
    elif echo "$URL" | grep -qE 'github\.com/'; then
      PKG=$(echo "$URL" | grep -oP 'github\.com/\K[^/]+/[^/]+' | head -1)
    fi

    # Already indexed?
    if [[ -n "$PKG" ]] && context list 2>/dev/null | grep -qi "$PKG"; then
      echo "Context MCP: $PKG is already indexed. Use get_docs() instead of fetching."
      exit 0
    fi

    # Eval gate: only suggest indexing if worth it
    cat <<'EVAL'
Context MCP index eval — before indexing, check:
  1. Will this library be referenced again this session or in future sessions?
  2. Does the source have 50+ doc sections (not just a single README)?
  3. Is it a project dependency (package.json/Cargo.toml/pyproject.toml)?
If all three: index it. If only #1: bookmark for later. If none: skip.
EVAL

    if [[ -n "$PKG" ]]; then
      echo "Commands if indexing:"
      echo "  context browse $PKG                    # check registry first"
      echo "  context install npm/$PKG               # from registry"
      echo "  context add <repo-url> --name $PKG     # from git"
    fi
    ;;

  WebSearch)
    # Only fire if search query looks library-related
    QUERY=$(echo "$INPUT" | jq -r '.query // empty' 2>/dev/null)
    [[ -z "$QUERY" ]] && exit 0
    echo "$QUERY" | grep -qiE '(library|framework|api|sdk|docs|package|module|plugin|npm|pip|crate|gem)' || exit 0

    echo "Context MCP: search_packages(\"<library>\") checks 92+ indexed packages (~350ms). context browse <name> searches the registry."
    ;;
esac
