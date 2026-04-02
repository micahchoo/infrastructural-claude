#!/usr/bin/env bash
# failure-journal-hook.sh — PostToolUse:Bash silent failure observer
# Zero context injection. Logs all meaningful Bash signals to session-scoped JSONL.
# Captures: errors, warnings, retries, silent degradation, deprecations.
# Designed for maximum observability at zero context window cost.
#
# Downstream consumers:
#   - Checkpoint hook (Component 2): reads journal at skill boundaries
#   - Introspection skill (Component 3): queries journal for failure context
#   - Session-end summary: flags unrecorded failures
set +e

command -v jq >/dev/null 2>&1 || exit 0

JOURNAL="/tmp/failure-journal-${PPID}.jsonl"
MAX_JOURNAL_BYTES=102400  # 100KB cap
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─── Read payload ───────────────────────────────────────────────────────
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
desc=$(echo "$input" | jq -r '.tool_input.description // empty' 2>/dev/null)
is_error=$(echo "$input" | jq -r '.is_error // false' 2>/dev/null)
output_len=$(echo "$input" | jq '.tool_output | length' 2>/dev/null || echo 0)
# First 2000 chars for pattern matching (keeps hook fast on large outputs)
snippet=$(echo "$input" | jq -r '.tool_output // empty' 2>/dev/null | head -c 2000)

# ─── Extract first command word (handles pipes, paths, bash -c) ─────────
cmd_first="${cmd%% *}"
cmd_first="${cmd_first%%|*}"
cmd_first="${cmd_first##*/}"

# ─── Benign filter: commands with expected non-zero exits ───────────────
if [[ "$is_error" == "true" ]]; then
  case "$cmd_first" in
    grep|rg|egrep|fgrep|ag)
      [[ ${#snippet} -lt 5 ]] && exit 0 ;;
    test|\[)
      exit 0 ;;
    diff|cmp)
      [[ "${output_len:-0}" -lt 100 ]] && exit 0 ;;
    which|command|type|hash)
      exit 0 ;;
    false)
      exit 0 ;;
  esac
fi

# ─── Skip trivial successes (no warning signals) ───────────────────────
if [[ "$is_error" != "true" ]]; then
  case "$cmd_first" in
    ls|cat|echo|printf|head|tail|wc|sort|uniq|cut|tr|tee|touch|mkdir| \
    mv|cp|chmod|chown|cd|pwd|pushd|popd|date|sleep|seq|xargs|find| \
    basename|dirname|realpath|readlink|stat|file|xxd|base64|env|set| \
    export|source|eval|read|mapfile|declare|local|shift|getopts|wait| \
    grep|rg|egrep|fgrep|ag|ack|du|df|rm|rmdir|ln|id|whoami|which|type)
      if ! echo "$snippet" | grep -qiE 'warn|deprecat|WARN|WARNING|obsolete|⚠'; then
        exit 0
      fi
      ;;
  esac
fi

# ─── Classify error/signal category ────────────────────────────────────
category="uncategorized"
subcategory=""
severity="info"

classify() {
  local s="$snippet"

  # --- File system ---
  if echo "$s" | grep -qiE 'ENOENT|No such file|not found|does not exist|missing file'; then
    category="filesystem"; subcategory="not-found"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'EACCES|Permission denied|EPERM|access denied'; then
    category="filesystem"; subcategory="permission"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'EISDIR|Is a directory|not a directory|ENOTDIR'; then
    category="filesystem"; subcategory="path-type"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'ENOSPC|No space left|disk full'; then
    category="resource"; subcategory="disk"; severity="critical"; return
  fi

  # --- Module/import resolution ---
  if echo "$s" | grep -qiE 'Cannot find module|MODULE_NOT_FOUND|ModuleNotFoundError|No module named|ImportError'; then
    category="module"; subcategory="not-found"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'Cannot resolve|Could not resolve|unresolved import'; then
    category="module"; subcategory="resolve"; severity="error"; return
  fi

  # --- Python tracebacks (rich sub-classification) ---
  if echo "$s" | grep -qE 'Traceback \(most recent call last\)'; then
    category="python"; severity="error"
    if echo "$s" | grep -qE 'NameError'; then subcategory="name"
    elif echo "$s" | grep -qE 'ValueError'; then subcategory="value"
    elif echo "$s" | grep -qE 'KeyError'; then subcategory="key"
    elif echo "$s" | grep -qE 'AttributeError'; then subcategory="attribute"
    elif echo "$s" | grep -qE 'IndexError'; then subcategory="index"
    elif echo "$s" | grep -qE 'RuntimeError'; then subcategory="runtime"
    elif echo "$s" | grep -qE 'OSError|IOError'; then subcategory="io"
    elif echo "$s" | grep -qE 'FileNotFoundError'; then subcategory="file-not-found"
    elif echo "$s" | grep -qE 'ConnectionError|requests\.exceptions'; then subcategory="network"
    elif echo "$s" | grep -qE 'json\.decoder\.JSONDecodeError'; then subcategory="json-decode"
    elif echo "$s" | grep -qE 'AssertionError'; then subcategory="assertion"
    elif echo "$s" | grep -qE 'TimeoutError'; then subcategory="timeout"
    else subcategory="other"
    fi
    return
  fi

  # --- Node.js runtime errors ---
  if echo "$s" | grep -qE 'ReferenceError|RangeError|EvalError|URIError'; then
    category="node"; subcategory="runtime"; severity="error"; return
  fi
  if echo "$s" | grep -qE 'UnhandledPromiseRejection|unhandled rejection'; then
    category="node"; subcategory="promise"; severity="error"; return
  fi
  if echo "$s" | grep -qE 'ERR_REQUIRE_ESM|ERR_MODULE_NOT_FOUND|ERR_PACKAGE'; then
    category="node"; subcategory="module-system"; severity="error"; return
  fi

  # --- Syntax errors (cross-language) ---
  if echo "$s" | grep -qiE 'SyntaxError|syntax error|unexpected token|parse error|parsing error'; then
    category="syntax"; subcategory="parse"; severity="error"; return
  fi

  # --- Type errors (cross-language) ---
  if echo "$s" | grep -qiE 'TypeError|type error|is not a function|is not defined|is not assignable'; then
    category="type"; subcategory="mismatch"; severity="error"; return
  fi

  # --- TypeScript compilation ---
  if echo "$s" | grep -qE 'error TS[0-9]+|TS[0-9]+:'; then
    category="typescript"; subcategory="compile"; severity="error"; return
  fi

  # --- Rust compilation ---
  if echo "$s" | grep -qE 'error\[E[0-9]+\]|cannot find.*in this scope'; then
    category="rust"; subcategory="compile"; severity="error"; return
  fi

  # --- Test failures (before build — "FAILED" appears in both) ---
  if echo "$s" | grep -qiE 'FAIL[^A-Za-z]|Tests:.*failed|test.*failed|AssertionError|assert.*failed'; then
    category="test"; subcategory="assertion"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'Expected.*Received|Expected.*but got|expected.*actual'; then
    category="test"; subcategory="mismatch"; severity="error"; return
  fi
  if echo "$s" | grep -qE '✗|✕|✘|FAILURES'; then
    category="test"; subcategory="failed"; severity="error"; return
  fi

  # --- Build/compilation (generic, after test) ---
  if echo "$s" | grep -qE 'Build failed|build error|compilation failed|make:.*Error'; then
    category="build"; subcategory="failed"; severity="error"; return
  fi
  if echo "$s" | grep -qE 'FAILED' && ! echo "$s" | grep -qiE 'test|spec|assert'; then
    category="build"; subcategory="failed"; severity="error"; return
  fi

  # --- Git errors ---
  if echo "$s" | grep -qiE 'CONFLICT|merge conflict'; then
    category="git"; subcategory="conflict"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'not a git repository|fatal:.*git'; then
    category="git"; subcategory="not-repo"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'detached HEAD|not currently on a branch'; then
    category="git"; subcategory="detached"; severity="warning"; return
  fi
  if echo "$s" | grep -qiE 'Your branch is behind|have diverged'; then
    category="git"; subcategory="diverged"; severity="warning"; return
  fi
  if echo "$s" | grep -qiE 'nothing to commit|Already up to date|already exists'; then
    category="git"; subcategory="noop"; severity="info"; return
  fi

  # --- Network/HTTP errors ---
  if echo "$s" | grep -qiE 'ECONNREFUSED|ECONNRESET|ETIMEDOUT|EHOSTUNREACH|connection refused'; then
    category="network"; subcategory="connection"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'fetch failed|network error|DNS resolution|getaddrinfo|ENOTFOUND'; then
    category="network"; subcategory="dns-or-fetch"; severity="error"; return
  fi
  if echo "$s" | grep -qiE '50[0-9] [A-Z]|502 Bad|503 Service|504 Gateway|500 Internal'; then
    category="network"; subcategory="http-5xx"; severity="error"; return
  fi
  if echo "$s" | grep -qiE '401 Unauthorized|403 Forbidden|authentication.*failed|auth.*error'; then
    category="auth"; subcategory="http-auth"; severity="error"; return
  fi
  if echo "$s" | grep -qiE '404 Not Found|404:.*not found'; then
    category="network"; subcategory="http-404"; severity="warning"; return
  fi
  if echo "$s" | grep -qiE '429 Too Many|rate limit|throttl'; then
    category="network"; subcategory="rate-limit"; severity="warning"; return
  fi

  # --- Resource exhaustion ---
  if echo "$s" | grep -qiE 'ENOMEM|out of memory|heap out of memory|JavaScript heap'; then
    category="resource"; subcategory="memory"; severity="critical"; return
  fi
  if echo "$s" | grep -qiE 'EMFILE|Too many open files'; then
    category="resource"; subcategory="file-descriptors"; severity="critical"; return
  fi
  if echo "$s" | grep -qiE 'killed|signal 9|SIGKILL|OOMKilled'; then
    category="resource"; subcategory="oom-killed"; severity="critical"; return
  fi

  # --- Lock/concurrency ---
  if echo "$s" | grep -qiE 'Lock acquisition|resource busy|EBUSY|lock file|deadlock'; then
    category="lock"; subcategory="contention"; severity="warning"; return
  fi

  # --- Package manager errors ---
  if echo "$s" | grep -qiE 'npm ERR!|npm error|ERESOLVE|peer dep.*conflict'; then
    category="package"; subcategory="npm"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'pnpm.*ERR|ERR_PNPM'; then
    category="package"; subcategory="pnpm"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'pip.*error|Could not find a version|No matching distribution'; then
    category="package"; subcategory="pip"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'cargo.*error|could not compile'; then
    category="package"; subcategory="cargo"; severity="error"; return
  fi

  # --- Docker/container ---
  if echo "$s" | grep -qiE 'docker.*error|cannot connect to.*Docker|No such container|No such image'; then
    category="docker"; subcategory="runtime"; severity="error"; return
  fi
  if echo "$s" | grep -qiE 'container.*exited|unhealthy|health.*fail'; then
    category="docker"; subcategory="health"; severity="warning"; return
  fi

  # --- MCP/infrastructure ---
  if echo "$s" | grep -qiE 'MCP.*error|Connection closed|MCP.*timeout|MCP.*failed'; then
    category="mcp"; subcategory="connection"; severity="error"; return
  fi

  # --- Timeout ---
  if echo "$s" | grep -qiE 'timed out|timeout|ETIMEDOUT|deadline exceeded'; then
    category="timeout"; subcategory="execution"; severity="error"; return
  fi

  # --- Deprecation warnings (even in success) ---
  if echo "$s" | grep -qiE 'DeprecationWarning|deprecated|will be removed|will stop working'; then
    category="deprecation"; severity="warning"; return
  fi

  # --- General warnings (even in success) ---
  if echo "$s" | grep -qiE 'Warning:|WARN[^I]|warning:|⚠'; then
    category="warning"; severity="warning"; return
  fi

  # --- File modification conflict (Claude-specific) ---
  if echo "$s" | grep -qiE 'unexpectedly modified|Read it again before'; then
    category="stale-read"; subcategory="file-modified"; severity="error"; return
  fi

  # --- Silent failures (exit 0 but wrong) ---
  # Skip if command is piped through grep/tail/head — empty output means
  # the filter matched nothing, not that the tool failed silently.
  if [[ "$is_error" != "true" ]] && [[ "${output_len:-0}" -eq 0 ]]; then
    if ! echo "$cmd" | grep -qE '\|\s*(grep|tail|head|wc|cut|sort|awk|sed)\b'; then
      case "$cmd_first" in
        make|cargo|npm|npx|pnpm|yarn|bun|docker|python*|pytest|vitest|jest|tsc)
          category="silent"; subcategory="empty-output"; severity="warning"
          return ;;
      esac
    fi
  fi

  # --- Framework: Svelte/SvelteKit/Vite ---
  if echo "$s" | grep -qiE 'svelte.*error|SvelteKit|vite.*error|HMR.*error'; then
    category="framework"; subcategory="svelte"; severity="error"; return
  fi

  # --- Framework: React/Next.js ---
  if echo "$s" | grep -qiE 'react.*error|Invalid hook call|hydration.*mismatch|next.*error|NEXT_NOT_FOUND'; then
    category="framework"; subcategory="react"; severity="error"; return
  fi

  # --- Framework: Next.js specific ---
  if echo "$s" | grep -qiE 'getServerSideProps|getStaticProps|middleware.*error|next\.config'; then
    category="framework"; subcategory="nextjs"; severity="error"; return
  fi

  # --- Database: Query errors ---
  if echo "$s" | grep -qiE 'SQLITE_ERROR|syntax error.*sql|relation.*does not exist|column.*not found|QueryFailed'; then
    category="database"; subcategory="query"; severity="error"; return
  fi

  # --- Database: Connection errors ---
  if echo "$s" | grep -qiE 'ECONNREFUSED.*5432|ECONNREFUSED.*3306|ECONNREFUSED.*27017|connection.*refused.*database|SequelizeConnectionError'; then
    category="database"; subcategory="connection"; severity="error"; return
  fi

  # --- Database: Migration errors ---
  if echo "$s" | grep -qiE 'migration.*failed|already.*migrated|pending.*migration|knex.*migrate|prisma.*migrate'; then
    category="database"; subcategory="migration"; severity="error"; return
  fi

  # --- Parse: Structured data ---
  if echo "$s" | grep -qiE 'yaml.*error|toml.*error|invalid.*json|CSV.*parse|XML.*parse'; then
    category="parse"; subcategory="structured-data"; severity="error"; return
  fi

  # --- Config: Missing env vars ---
  if echo "$s" | grep -qiE 'env.*not.*set|missing.*environment|undefined.*env|\.env.*not found|required.*variable'; then
    category="config"; subcategory="env-missing"; severity="warning"; return
  fi

  # --- Resource: Port conflicts ---
  if echo "$s" | grep -qiE 'EADDRINUSE|address already in use|port.*already.*bound|listen EACCES'; then
    category="resource"; subcategory="port-conflict"; severity="error"; return
  fi

  # --- TLS: Certificate errors ---
  if echo "$s" | grep -qiE 'CERT_HAS_EXPIRED|UNABLE_TO_VERIFY|self.signed|ERR_TLS|certificate.*error'; then
    category="tls"; subcategory="certificate"; severity="error"; return
  fi

  # --- Runtime: Infinite loop / hang ---
  if echo "$s" | grep -qiE 'Maximum call stack|too much recursion|heap out of memory|JavaScript heap'; then
    category="runtime"; subcategory="infinite-loop"; severity="critical"; return
  fi

  # --- Infrastructure: Hook errors ---
  if echo "$s" | grep -qiE 'hook.*failed|hook.*error|hook.*timeout|PreToolUse.*error|PostToolUse.*error'; then
    category="infrastructure"; subcategory="hook"; severity="warning"; return
  fi

  # --- Verification commands (grep/test/find as assertions) ---
  if echo "$desc" | grep -qiE 'verify|check.*marker|check.*manifest|confirm|assert.*exist|validate'; then
    case "$cmd_first" in
      grep|test|find|ls|stat|file|wc)
        category="verification"; subcategory="assertion"; severity="info"
        return ;;
    esac
  fi

  # --- Test suite: passing runs (no failure signal) ---
  case "$cmd_first" in
    npx|vitest|jest|pytest|python3|cargo|go|mocha|tap|ava)
      if ! echo "$s" | grep -qiE 'FAIL|ERROR|AssertionError|assert.*fail|panicked|FAILED'; then
        category="test"; subcategory="passed"; severity="info"
        return
      fi ;;
  esac

  # --- Knowledge-infra operations (mulch/seeds) ---
  # Skip if the tool isn't initialized in the project — not a failure,
  # just a hook running in a project without .mulch/ or .seeds/.
  local project_cwd
  project_cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
  case "$cmd_first" in
    ml|mulch)
      [[ -n "$project_cwd" && ! -d "$project_cwd/.mulch" ]] && exit 0
      category="knowledge-infra"; subcategory="mulch"; severity="info"
      return ;;
    sd|seeds)
      [[ -n "$project_cwd" && ! -d "$project_cwd/.seeds" ]] && exit 0
      category="knowledge-infra"; subcategory="seeds"; severity="info"
      return ;;
  esac

  # --- Build: Bundler errors ---
  if echo "$s" | grep -qiE 'webpack.*error|rollup.*error|esbuild.*error|vite.*build.*error|chunk.*error'; then
    category="build"; subcategory="bundler"; severity="error"; return
  fi

  # --- Container registry auth ---
  if echo "$s" | grep -qiE 'ghcr\.io.*denied|unauthorized.*push|docker.*login.*failed'; then
    category="docker"; subcategory="registry-auth"; severity="error"; return
  fi

  # --- Git routine operations (no error signal matched above) ---
  if [[ "$cmd_first" == "git" ]]; then
    category="git"; severity="info"
    if echo "$cmd" | grep -qE 'log|shortlog'; then subcategory="log"
    elif echo "$cmd" | grep -qE 'diff'; then subcategory="diff"
    elif echo "$cmd" | grep -qE 'status'; then subcategory="status"
    elif echo "$cmd" | grep -qE 'branch'; then subcategory="branch"
    elif echo "$cmd" | grep -qE 'add|commit|stash'; then subcategory="commit-ops"
    elif echo "$cmd" | grep -qE 'show|rev-parse|worktree'; then subcategory="inspect"
    else subcategory="routine"
    fi
    return
  fi

  # --- npm/npx routine operations (no error signal matched above) ---
  if [[ "$cmd_first" == "npm" || "$cmd_first" == "npx" ]]; then
    category="npm"; severity="info"
    if echo "$cmd" | grep -qiE 'test|vitest|jest|mocha'; then subcategory="test-run"
    elif echo "$cmd" | grep -qiE 'install|add|remove'; then subcategory="install"
    elif echo "$cmd" | grep -qiE 'run|exec'; then subcategory="script"
    else subcategory="routine"
    fi
    return
  fi

  # --- Python script execution (no error signal matched above) ---
  if [[ "$cmd_first" == "python" || "$cmd_first" == "python3" ]]; then
    category="python"; subcategory="script"; severity="info"; return
  fi

  # --- Infra-CLI: bash-wrapped seeds/mulch (cmd_first is bash but inner cmd is ml/sd) ---
  # Skip if the tool isn't initialized in the project.
  if echo "$cmd" | grep -qE '^(bash |sh ).*\b(ml|mulch|sd|seeds)\b'; then
    if echo "$cmd" | grep -qE '\b(ml|mulch)\b'; then
      [[ -n "$project_cwd" && ! -d "$project_cwd/.mulch" ]] && exit 0
      category="knowledge-infra"; subcategory="mulch"; severity="info"
    else
      [[ -n "$project_cwd" && ! -d "$project_cwd/.seeds" ]] && exit 0
      category="knowledge-infra"; subcategory="seeds"; severity="info"
    fi
    return
  fi

  # --- Script execution (hook scripts, audit scripts) ---
  if [[ "$cmd_first" == "bash" || "$cmd_first" == "sh" ]]; then
    if echo "$cmd" | grep -qE '\.sh\b'; then
      category="script"; subcategory="execution"; severity="info"; return
    fi
  fi


  # --- Compound shell constructs (if/for/while/case — cmd_first is keyword) ---
  # Dream-added: 2026-03-28
  # Pattern: commands starting with shell keywords — if/for/while/until/case/[[
  # Evidence: 3 entries across 2 sessions (if-conditional, for-loop iterations)
  # Root cause: cmd_first extraction strips to first word; compound constructs
  #             don't begin with a classifiable command name
  case "$cmd_first" in
    if|for|while|until|case|\[\[)
      category="script"; subcategory="compound-construct"; severity="info"; return ;;
  esac

  # --- Catch-all for is_error with no pattern match ---
  if [[ "$is_error" == "true" ]]; then
    category="unknown-error"; severity="error"; return
  fi
}

classify

# ─── Detect command tool category ──────────────────────────────────────
cmd_tool="shell"
detect_tool() {
  case "$cmd_first" in
    git)       cmd_tool="git" ;;
    npm|npx)   cmd_tool="npm" ;;
    pnpm)      cmd_tool="pnpm" ;;
    yarn|bun|bunx) cmd_tool="bun" ;;
    pip|pip3|python|python3|pytest|mypy|ruff|black|uvicorn|gunicorn|flask|django)
               cmd_tool="python" ;;
    node|tsx|ts-node|tsc|eslint|prettier|jest|vitest|mocha|playwright)
               cmd_tool="node" ;;
    cargo|rustc|rustfmt|clippy)
               cmd_tool="rust" ;;
    docker|docker-compose|podman)
               cmd_tool="docker" ;;
    go|gofmt)  cmd_tool="go" ;;
    make|cmake|ninja)
               cmd_tool="make" ;;
    curl|wget|http|httpie)
               cmd_tool="http" ;;
    gh)        cmd_tool="github" ;;
    jq|yq)     cmd_tool="data" ;;
    sed|awk|perl)
               cmd_tool="text" ;;
    ml|mulch)  cmd_tool="mulch" ;;
    sd|seeds)  cmd_tool="seeds" ;;
    bash|sh|zsh)
      # For bash -c, try to detect the inner command
      if echo "$cmd" | grep -qE 'python|pip|pytest'; then cmd_tool="python"
      elif echo "$cmd" | grep -qE 'node|npm|npx|tsc'; then cmd_tool="node"
      elif echo "$cmd" | grep -qE 'docker'; then cmd_tool="docker"
      elif echo "$cmd" | grep -qE 'cargo|rustc'; then cmd_tool="rust"
      elif echo "$cmd" | grep -qE 'git '; then cmd_tool="git"
      elif echo "$cmd" | grep -qE 'curl|wget'; then cmd_tool="http"
      elif echo "$cmd" | grep -qE '\.sh'; then cmd_tool="script"
      else cmd_tool="shell"
      fi
      ;;
    *)
      # Check full command for embedded tools
      if echo "$cmd" | grep -qE 'python3?|pip3?'; then cmd_tool="python"
      elif echo "$cmd" | grep -qE 'node |npm |npx '; then cmd_tool="node"
      fi
      ;;
  esac
}

detect_tool

# ─── Detect retry (same command in last 5 journal entries) ─────────────
cmd_hash=$(echo "$cmd" | md5sum | cut -c1-16)
retry="false"
if [[ -f "$JOURNAL" ]]; then
  if tail -5 "$JOURNAL" | grep -qF "\"cmd_hash\":\"$cmd_hash\""; then
    retry="true"
  fi
fi

# ─── Extract first meaningful error line ───────────────────────────────
error_line=""
if [[ "$severity" != "info" ]]; then
  error_line=$(echo "$snippet" | grep -iE \
    'error|Error|FAIL|Traceback|ENOENT|EACCES|Cannot|denied|refused|timeout|warning|WARN|deprecated' \
    | head -1 | head -c 200)
fi

# ─── Detect model-reported deviation ([SNAG] in description) ───────────
snag="false"
if echo "$desc" | grep -qF '[SNAG]'; then
  snag="true"
  # Elevate severity if model flagged it
  [[ "$severity" == "info" ]] && severity="warning"
fi

# ─── Build and append record ───────────────────────────────────────────
record=$(jq -cn \
  --arg ts "$TS" \
  --arg cmd "$cmd" \
  --arg cmd_hash "$cmd_hash" \
  --arg desc "$desc" \
  --arg is_error "$is_error" \
  --arg cat "$category" \
  --arg sub "$subcategory" \
  --arg sev "$severity" \
  --arg err "$error_line" \
  --argjson olen "${output_len:-0}" \
  --arg retry "$retry" \
  --arg snag "$snag" \
  --arg tool "$cmd_tool" \
  --arg source "bash" \
  --arg cwd "$(pwd)" \
  --arg branch "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')" \
  '{
    ts: $ts,
    cmd: ($cmd | .[0:200]),
    cmd_hash: $cmd_hash,
    desc: ($desc | .[0:100]),
    is_error: ($is_error == "true"),
    category: $cat,
    subcategory: $sub,
    severity: $sev,
    error_line: ($err | .[0:200]),
    output_len: ($olen | tonumber),
    retry: ($retry == "true"),
    snag: ($snag == "true"),
    tool: $tool,
    source: $source,
    cwd: $cwd,
    branch: $branch
  }' 2>/dev/null)

[ -z "$record" ] && exit 0
echo "$record" >> "$JOURNAL"

# ─── Size cap: drop oldest half when over limit ────────────────────────
if [[ -f "$JOURNAL" ]]; then
  size=$(stat -c%s "$JOURNAL" 2>/dev/null || stat -f%z "$JOURNAL" 2>/dev/null || echo 0)
  if [[ "$size" -gt "$MAX_JOURNAL_BYTES" ]]; then
    lines=$(wc -l < "$JOURNAL")
    keep=$((lines / 2))
    tail -"$keep" "$JOURNAL" > "${JOURNAL}.tmp" && mv "${JOURNAL}.tmp" "$JOURNAL"
  fi
fi

exit 0
