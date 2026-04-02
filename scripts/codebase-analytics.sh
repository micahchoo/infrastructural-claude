#!/usr/bin/env bash
# codebase-analytics.sh — Cached codebase snapshot for prompt enhancement
# Produces a compact analytics summary (~100-140 lines, ~1200 tokens)
# Caches per git state (HEAD + dirty hash) to avoid redundant work
# Best-effort — individual sections can fail without killing the whole script
set +e
command -v jq >/dev/null 2>&1 || exit 0

source "$(dirname "$0")/lib/cache-utils.sh"

# Accept optional target directory
[[ -n "$1" && -d "$1" ]] && cd "$1"
ORIG_DIR=$(pwd)

# Only works inside a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Detect if invoked from a sub-package inside a monorepo
PKG_DIR=""
PKG_REL=""
if [[ "$ORIG_DIR" != "$REPO_ROOT" ]]; then
  check_dir="$ORIG_DIR"
  while [[ "$check_dir" != "$REPO_ROOT" && -n "$check_dir" ]]; do
    if [[ -f "$check_dir/package.json" || -f "$check_dir/Cargo.toml" || \
          -f "$check_dir/pyproject.toml" || -f "$check_dir/go.mod" || \
          -f "$check_dir/pubspec.yaml" || -f "$check_dir/mix.exs" ]]; then
      PKG_DIR="$check_dir"
      PKG_REL="${check_dir#$REPO_ROOT/}"
      break
    fi
    check_dir=$(dirname "$check_dir")
  done
fi

# Serve from cache if fresh (< 5 min old)
init_cache "prompt-enhancer-cache" 1800 && exit 0

# --- Helper functions ---

detect_frameworks() {
  local dir="${1:-.}"
  local fw=""
  # Build systems
  [[ -f "$dir/CMakeLists.txt" ]] && fw+="CMake "
  # JS/TS app frameworks
  [[ -f "$dir/next.config.js" || -f "$dir/next.config.ts" || -f "$dir/next.config.mjs" ]] && fw+="Next.js "
  [[ -f "$dir/svelte.config.js" || -f "$dir/svelte.config.ts" ]] && fw+="SvelteKit "
  [[ -f "$dir/nuxt.config.ts" || -f "$dir/nuxt.config.js" ]] && fw+="Nuxt "
  [[ -f "$dir/angular.json" ]] && fw+="Angular "
  [[ -f "$dir/astro.config.mjs" || -f "$dir/astro.config.ts" ]] && fw+="Astro "
  [[ -f "$dir/remix.config.js" || -f "$dir/remix.config.ts" ]] && fw+="Remix "
  [[ -f "$dir/gatsby-config.js" || -f "$dir/gatsby-config.ts" ]] && fw+="Gatsby "
  # Build tools
  [[ -f "$dir/vite.config.ts" || -f "$dir/vite.config.js" || -f "$dir/vite.config.mjs" ]] && fw+="Vite "
  [[ -f "$dir/webpack.config.js" || -f "$dir/webpack.config.ts" ]] && fw+="Webpack "
  [[ -f "$dir/turbo.json" ]] && fw+="Turborepo "
  # Languages / ecosystems
  [[ -f "$dir/tsconfig.json" ]] && fw+="TypeScript "
  [[ -f "$dir/Cargo.toml" ]] && fw+="Rust/Cargo "
  [[ -f "$dir/go.mod" ]] && fw+="Go "
  [[ -f "$dir/pyproject.toml" || -f "$dir/setup.py" || -f "$dir/setup.cfg" ]] && fw+="Python "
  [[ -f "$dir/pubspec.yaml" ]] && fw+="Flutter/Dart "
  [[ -f "$dir/Gemfile" ]] && fw+="Ruby "
  [[ -f "$dir/mix.exs" ]] && fw+="Elixir "
  [[ -f "$dir/project.clj" || -f "$dir/shadow-cljs.edn" || -f "$dir/deps.edn" ]] && fw+="Clojure "
  [[ -f "$dir/build.sbt" || -f "$dir/build.sc" ]] && fw+="Scala "
  # Backend frameworks (from package.json)
  if [[ -f "$dir/package.json" ]]; then
    grep -q '"express"' "$dir/package.json" 2>/dev/null && fw+="Express "
    grep -q '"fastify"' "$dir/package.json" 2>/dev/null && fw+="Fastify "
    grep -q '"hono"' "$dir/package.json" 2>/dev/null && fw+="Hono "
    grep -q '"@nestjs/core"' "$dir/package.json" 2>/dev/null && fw+="NestJS "
    grep -q '"koa"' "$dir/package.json" 2>/dev/null && fw+="Koa "
  fi
  if [[ -f "$dir/pyproject.toml" ]]; then
    grep -q 'fastapi' "$dir/pyproject.toml" 2>/dev/null && fw+="FastAPI "
    grep -q 'django' "$dir/pyproject.toml" 2>/dev/null && fw+="Django "
    grep -q 'flask' "$dir/pyproject.toml" 2>/dev/null && fw+="Flask "
  fi
  echo "${fw:-none detected}"
}

detect_test_frameworks() {
  local dir="${1:-.}"
  local tf=""
  if [[ -f "$dir/package.json" ]]; then
    grep -q '"vitest"' "$dir/package.json" 2>/dev/null && tf+="Vitest "
    grep -q '"jest"' "$dir/package.json" 2>/dev/null && tf+="Jest "
    grep -q '"mocha"' "$dir/package.json" 2>/dev/null && tf+="Mocha "
    grep -q '"playwright"' "$dir/package.json" 2>/dev/null && tf+="Playwright "
    grep -q '"cypress"' "$dir/package.json" 2>/dev/null && tf+="Cypress "
    grep -q '"@testing-library' "$dir/package.json" 2>/dev/null && tf+="TestingLibrary "
    grep -q '"storybook"' "$dir/package.json" 2>/dev/null && tf+="Storybook "
  fi
  [[ -f "$dir/pytest.ini" ]] && tf+="Pytest "
  [[ -f "$dir/pyproject.toml" ]] && grep -q 'pytest' "$dir/pyproject.toml" 2>/dev/null && tf+="Pytest "
  [[ -f "$dir/phpunit.xml" || -f "$dir/phpunit.xml.dist" ]] && tf+="PHPUnit "
  echo "${tf:-none detected}"
}

print_structure() {
  local dir="${1:-.}" depth="${2:-2}" lines="${3:-35}"
  if command -v tree &>/dev/null; then
    tree -L "$depth" --dirsfirst -I "$TREE_EXCLUDES" --noreport "$dir" 2>/dev/null | head -"$lines"
  else
    find "$dir" -maxdepth "$depth" -type d \
      -not -path '*/node_modules*' -not -path '*/.git*' \
      -not -path '*/vendor*' -not -path '*/dist*' \
      -not -path '*/__pycache__*' -not -path '*/.next*' \
      -not -path '*/build*' -not -path '*/.cache*' \
      | sort | head -"$lines"
  fi
}

list_cargo_deps() {
  local file="${1:?}" limit="${2:-10}"
  grep -A999 '^\[dependencies\]' "$file" 2>/dev/null \
    | grep -E '^[a-zA-Z]' | head -"$limit" | sed 's/ *=.*//' | sed 's/^/  /'
}

# --- Gather analytics ---
{
  # Prime tracked files cache before parallel forks
  tracked_files > /dev/null

  _PAR_DIR=$(mktemp -d)

  # === Launch expensive operations in background ===

  # 1. Language breakdown (scc/tokei)
  if command -v scc &>/dev/null; then
    ( echo "=== LANGUAGES (scc) ==="
      scc --no-cocomo --exclude-dir node_modules,vendor,dist,build,.git -f json 2>/dev/null | jq -r '
        .[] | select(.Code > 0)
        | "\(.Name): \(.Code) LOC, \(.Count) files, complexity \(.Complexity // 0)"
      ' 2>/dev/null | head -12
      echo ""
    ) > "$_PAR_DIR/languages" 2>/dev/null &
    _PID_LANG=$!
  elif command -v tokei &>/dev/null; then
    ( echo "=== LANGUAGES ==="
      tokei --sort code -o json 2>/dev/null | jq -r '
        .inner | to_entries[]
        | select(.value.code > 0)
        | "\(.key): \(.value.code) LOC, \(.value.stats | length) files"
      ' 2>/dev/null | head -12
      echo ""
    ) > "$_PAR_DIR/languages" 2>/dev/null &
    _PID_LANG=$!
  fi

  # 3. Symbol index (ctags) — pipe tracked source files instead of -R
  if command -v ctags &>/dev/null; then
    ( echo "=== SYMBOLS ==="
      tracked_files '\.(c|cpp|cxx|cc|h|hpp|hxx|py|js|ts|tsx|jsx|rb|rs|go|java|cs|scala|clj|cljs|ex|exs|dart|swift|kt|lua|zig|hs|ml|erl)$' \
        | ctags --output-format=u-ctags -f - -L - --fields=+K 2>/dev/null \
        | awk -F'\t' '{
            for(i=1;i<=NF;i++) {
              if($i ~ /^kind:/) { split($i,a,":"); kinds[a[2]]++ }
            }
          }
          END {
            for(k in kinds) printf "%s: %d\n", k, kinds[k]
          }' | sort -t: -k2 -rn | head -10
      echo ""
    ) > "$_PAR_DIR/symbols" 2>/dev/null &
    _PID_SYMBOLS=$!
  fi

  # 4. Hottest files by churn (6 months) — cap history, filter translations
  ( echo "=== CHURN (hottest files, 6mo) ==="
    git log --since="6 months ago" --max-count=2000 --pretty=format: --name-only \
      -- ':!*.po' ':!*.pot' 2>/dev/null \
      | grep -v '^$' \
      | grep -vE "$EXCLUDES" \
      | sort | uniq -c | sort -rn | head -12
    echo ""
  ) > "$_PAR_DIR/churn" 2>/dev/null &
  _PID_CHURN=$!

  # 16. TODO/FIXME/HACK density — single grep pass, skip binary files (-I)
  ( echo "=== TECH DEBT MARKERS ==="
    DEBT_OUTPUT=$(tracked_files | xargs -r grep -I -cE 'TODO|FIXME|HACK|XXX' 2>/dev/null | grep -v ':0$')
    if [[ -n "$DEBT_OUTPUT" ]]; then
      FILE_COUNT=$(echo "$DEBT_OUTPUT" | wc -l)
      echo "files with markers: $FILE_COUNT"
      echo "$DEBT_OUTPUT" | sort -t: -k2 -rn | head -5 | sed 's/^/  /'
    else
      echo "none found"
    fi
    echo ""
  ) > "$_PAR_DIR/debt" 2>/dev/null &
  _PID_DEBT=$!

  # === Collect parallel results in order, interleaved with fast sections ===

  # 1. Languages
  [[ -n "$_PID_LANG" ]] && { wait "$_PID_LANG"; cat "$_PAR_DIR/languages" 2>/dev/null; }

  # 2. Directory skeleton
  echo "=== STRUCTURE ==="
  print_structure . 2 35
  echo ""

  # 3. Symbols
  [[ -n "$_PID_SYMBOLS" ]] && { wait "$_PID_SYMBOLS"; cat "$_PAR_DIR/symbols" 2>/dev/null; }

  # 4. Churn
  wait "$_PID_CHURN" 2>/dev/null; cat "$_PAR_DIR/churn" 2>/dev/null

  # 5. Largest files by extension — filter noise from PRIMARY_EXT detection
  if command -v fd &>/dev/null; then
    PRIMARY_EXT=$(tracked_files \
      | grep -oE '\.[^.]+$' \
      | grep -vE '^\.(json|lock|md|txt|yml|yaml|toml|cfg|ini|csv|svg|png|jpg|gif|ico|woff|ttf|eot|map)$' \
      | sort | uniq -c | sort -rn | head -1 \
      | awk '{print $2}' | sed 's/^\.//')
    if [[ -n "$PRIMARY_EXT" ]]; then
      echo "=== LARGEST FILES (.$PRIMARY_EXT) ==="
      fd -e "$PRIMARY_EXT" --exec wc -l {} \; 2>/dev/null \
        | sort -rn | head -8
      echo ""
    fi
  fi

  # 6. Recent commits
  echo "=== RECENT COMMITS ==="
  git log --oneline -7 2>/dev/null || echo "(no commits)"
  echo ""

  # 7. Contributors (recent) — skip if empty
  CONTRIBUTORS=$(git shortlog -sn --no-merges --since="3 months ago" 2>/dev/null | head -5)
  if [[ -n "$CONTRIBUTORS" ]]; then
    echo "=== CONTRIBUTORS (recent) ==="
    echo "$CONTRIBUTORS"
    echo ""
  fi

  # 8. Working changes
  CHANGES=$(git diff --name-status 2>/dev/null)
  STAGED=$(git diff --cached --name-status 2>/dev/null)
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -5)
  if [[ -n "$CHANGES" || -n "$STAGED" || -n "$UNTRACKED" ]]; then
    echo "=== WORKING CHANGES ==="
    [[ -n "$STAGED" ]] && echo "$STAGED" | sed 's/^/[staged] /'
    [[ -n "$CHANGES" ]] && echo "$CHANGES"
    [[ -n "$UNTRACKED" ]] && echo "$UNTRACKED" | sed 's/^/??\t/'
    echo ""
  fi

  # 9. Branch context
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')
  if [[ -z "$DEFAULT_BRANCH" ]]; then
    for candidate in main master develop; do
      if git show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null; then
        DEFAULT_BRANCH="$candidate"; break
      fi
    done
    DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  fi
  if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
    DIFF_STAT=$(git diff --stat "${DEFAULT_BRANCH}..HEAD" 2>/dev/null | tail -1)
    if [[ -n "$DIFF_STAT" ]]; then
      echo "=== BRANCH: $CURRENT_BRANCH (vs $DEFAULT_BRANCH) ==="
      echo "$DIFF_STAT"
      echo ""
    fi
  fi

  # 9b. All branches — single git branch call for recent, git for-each-ref for stale
  echo "=== BRANCHES ==="
  echo "current: ${CURRENT_BRANCH:-detached}"
  echo "default: $DEFAULT_BRANCH"
  LOCAL_BRANCHES=$(git branch --format='%(refname:short)' 2>/dev/null | wc -l)
  REMOTE_BRANCHES=$(git branch -r --format='%(refname:short)' 2>/dev/null | grep -v HEAD | wc -l)
  echo "local: $LOCAL_BRANCHES, remote: $REMOTE_BRANCHES"
  RECENT=$(git branch --sort=-committerdate --format='%(refname:short) %(committerdate:relative)' 2>/dev/null | head -8)
  if [[ -n "$RECENT" ]]; then
    echo "recent:"
    echo "$RECENT" | sed 's/^/  /'
  fi
  # Stale branches (>30 days, not default/current) — single for-each-ref call
  STALE_COUNT=$(git for-each-ref --sort=committerdate --format='%(committerdate:unix) %(refname:short)' refs/heads/ 2>/dev/null \
    | awk -v cutoff="$(date -d '30 days ago' +%s 2>/dev/null || date -v-30d +%s 2>/dev/null || echo 0)" \
          -v def="$DEFAULT_BRANCH" -v cur="$CURRENT_BRANCH" \
      '$1 < cutoff && $2 != def && $2 != cur' | wc -l)
  [[ $STALE_COUNT -gt 0 ]] && echo "stale (>30d): $STALE_COUNT"
  echo ""

  # 9c. Worktrees
  WORKTREES=$(git worktree list 2>/dev/null)
  WORKTREE_COUNT=$(echo "$WORKTREES" | wc -l)
  if [[ $WORKTREE_COUNT -gt 1 ]]; then
    echo "=== WORKTREES ($((WORKTREE_COUNT - 1)) extra) ==="
    echo "$WORKTREES" | while read -r wt_path wt_hash wt_branch; do
      wt_dirty=""
      if [[ -d "$wt_path" ]]; then
        wt_changes=$(git -C "$wt_path" status --porcelain 2>/dev/null | wc -l)
        [[ $wt_changes -gt 0 ]] && wt_dirty=" [${wt_changes} changes]"
      fi
      echo "  $wt_path $wt_branch${wt_dirty}"
    done
    echo ""
  fi

  # 10. GitHub context — uses init_sub_cache for separate 15min TTL
  if command -v gh &>/dev/null; then
    if init_sub_cache "gh-repo-cache" 900 "$REPO_ROOT"; then
      : # output already printed by init_sub_cache
    elif gh auth status &>/dev/null; then
      REPO_INFO=$(gh repo view --json name,description,primaryLanguage,openIssues,pullRequests 2>/dev/null || true)
      if [[ -n "$REPO_INFO" ]]; then
        {
          echo "=== REPO ==="
          echo "$REPO_INFO" | jq -r '[
            "name: \(.name)",
            "desc: \(.description // "none")",
            "lang: \(.primaryLanguage.name // "unknown")",
            "open issues: \(.openIssues.totalCount)",
            "open PRs: \(.pullRequests.totalCount)"
          ] | .[]' 2>/dev/null
          echo ""
        } | finalize_sub_cache
      fi
    fi
  fi

  # 11. Dependency health
  if [[ -f "package.json" ]] && command -v madge &>/dev/null; then
    CIRCULARS=$(madge --circular --warning src/ 2>/dev/null | head -5)
    if [[ -n "$CIRCULARS" ]]; then
      echo "=== CIRCULAR DEPS ==="
      echo "$CIRCULARS"
      echo ""
    fi
  fi

  # 12. Framework detection — skip if none
  FW_RESULT=$(detect_frameworks .)
  if [[ "$FW_RESULT" != "none detected" ]]; then
    echo "=== FRAMEWORK ==="
    echo "$FW_RESULT"
    echo ""
  fi

  # 13. Dependency landscape — only print if deps found
  DEP_OUTPUT=""
  if [[ -f "package.json" ]]; then
    DEPS=$(jq -r '(.dependencies // {}) | keys[]' package.json 2>/dev/null | head -12 | sed 's/^/  /')
    if [[ -n "$DEPS" ]]; then
      DEV_COUNT=$(jq -r '(.devDependencies // {}) | keys | length' package.json 2>/dev/null || echo 0)
      DEP_OUTPUT+="node (package.json):\n$DEPS\n  (+$DEV_COUNT devDependencies)\n"
    fi
  fi
  if [[ -f "Cargo.toml" ]]; then
    CDEPS=$(list_cargo_deps Cargo.toml 10)
    [[ -n "$CDEPS" ]] && DEP_OUTPUT+="rust (Cargo.toml):\n$CDEPS\n"
  fi
  if [[ -f "pyproject.toml" ]]; then
    PDEPS=$(sed -n '/^dependencies/,/^\[/p' pyproject.toml 2>/dev/null \
      | grep -E '^\s*"' | sed 's/[",]//g' | awk '{print $1}' | head -10 | sed 's/^/  /')
    [[ -n "$PDEPS" ]] && DEP_OUTPUT+="python (pyproject.toml):\n$PDEPS\n"
  fi
  if [[ -f "requirements.txt" ]]; then
    RDEPS=$(grep -v '^#' requirements.txt 2>/dev/null | grep -v '^$' \
      | sed 's/[>=<].*//' | head -10 | sed 's/^/  /')
    [[ -n "$RDEPS" ]] && DEP_OUTPUT+="python (requirements.txt):\n$RDEPS\n"
  fi
  if [[ -f "go.mod" ]]; then
    GDEPS=$(grep -E '^\t' go.mod 2>/dev/null | awk '{print $1}' | head -10 | sed 's/^/  /')
    [[ -n "$GDEPS" ]] && DEP_OUTPUT+="go (go.mod):\n$GDEPS\n"
  fi
  if [[ -f "Gemfile" ]]; then
    RBDEPS=$(grep "^gem " Gemfile 2>/dev/null | sed "s/gem '/  /;s/'.*//;s/gem \"/  /;s/\".*//" | head -10)
    [[ -n "$RBDEPS" ]] && DEP_OUTPUT+="ruby (Gemfile):\n$RBDEPS\n"
  fi
  if [[ -f "pubspec.yaml" ]]; then
    DDEPS=$(sed -n '/^dependencies:/,/^[a-z]/p' pubspec.yaml 2>/dev/null \
      | grep -E '^\s+[a-z]' | awk '{print $1}' | tr -d ':' | head -10 | sed 's/^/  /')
    [[ -n "$DDEPS" ]] && DEP_OUTPUT+="dart (pubspec.yaml):\n$DDEPS\n"
  fi
  if [[ -f "shadow-cljs.edn" ]]; then
    CLDEPS=$(grep -oE '[a-z][a-z0-9.-]+/[a-z][a-z0-9.-]+' shadow-cljs.edn 2>/dev/null \
      | sort -u | head -10 | sed 's/^/  /')
    [[ -n "$CLDEPS" ]] && DEP_OUTPUT+="clojure (shadow-cljs.edn):\n$CLDEPS\n"
  elif [[ -f "deps.edn" ]]; then
    CLDEPS=$(grep -oE '[a-z][a-z0-9.-]+/[a-z][a-z0-9.-]+' deps.edn 2>/dev/null \
      | sort -u | head -10 | sed 's/^/  /')
    [[ -n "$CLDEPS" ]] && DEP_OUTPUT+="clojure (deps.edn):\n$CLDEPS\n"
  elif [[ -f "project.clj" ]]; then
    CLDEPS=$(grep -oE '\[([a-z][a-z0-9.-]+(/[a-z][a-z0-9.-]+)?)' project.clj 2>/dev/null \
      | sed 's/^\[//' | head -10 | sed 's/^/  /')
    [[ -n "$CLDEPS" ]] && DEP_OUTPUT+="clojure (project.clj):\n$CLDEPS\n"
  fi
  if [[ -f "build.sbt" ]]; then
    SDEPS=$(grep -oE '"[^"]+"\s*%%?\s*"[^"]+"' build.sbt 2>/dev/null | head -10 | sed 's/^/  /')
    [[ -n "$SDEPS" ]] && DEP_OUTPUT+="scala (build.sbt):\n$SDEPS\n"
  fi
  if [[ -n "$DEP_OUTPUT" ]]; then
    echo "=== DEPENDENCIES ==="
    echo -e "$DEP_OUTPUT"
  fi

  # 14. Build/run commands — only print if found
  CMD_OUTPUT=""
  if [[ -f "package.json" ]]; then
    SCRIPTS=$(jq -r '(.scripts // {}) | to_entries[] | "  \(.key): \(.value)"' package.json 2>/dev/null | head -10)
    [[ -n "$SCRIPTS" ]] && CMD_OUTPUT+="npm scripts:\n$SCRIPTS\n"
  fi
  if [[ -f "Makefile" ]]; then
    TARGETS=$(grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null | sed 's/:.*//;s/^/  /' | head -8)
    [[ -n "$TARGETS" ]] && CMD_OUTPUT+="make targets:\n$TARGETS\n"
  fi
  JUSTFILE=""
  [[ -f "Justfile" ]] && JUSTFILE="Justfile"
  [[ -f "justfile" ]] && JUSTFILE="justfile"
  if [[ -n "$JUSTFILE" ]]; then
    RECIPES=$(grep -E '^[a-zA-Z_-]+:' "$JUSTFILE" 2>/dev/null | sed 's/:.*//;s/^/  /' | head -8)
    [[ -n "$RECIPES" ]] && CMD_OUTPUT+="just recipes:\n$RECIPES\n"
  fi
  if [[ -f "Taskfile.yml" || -f "Taskfile.yaml" ]]; then
    TASKFILE=""
    [[ -f "Taskfile.yml" ]] && TASKFILE="Taskfile.yml"
    [[ -f "Taskfile.yaml" ]] && TASKFILE="Taskfile.yaml"
    TTARGETS=$(grep -E '^\s+[a-zA-Z_-]+:$' "$TASKFILE" 2>/dev/null | sed 's/:.*//;s/^/  /' | head -8)
    [[ -n "$TTARGETS" ]] && CMD_OUTPUT+="task targets:\n$TTARGETS\n"
  fi
  if [[ -n "$CMD_OUTPUT" ]]; then
    echo "=== COMMANDS ==="
    echo -e "$CMD_OUTPUT"
  fi

  # 15. Test framework detection — skip if none
  TF_RESULT=$(detect_test_frameworks .)
  if [[ "$TF_RESULT" != "none detected" ]]; then
    echo "=== TEST FRAMEWORK ==="
    echo "$TF_RESULT"
    echo ""
  fi

  # 16. Tech debt — collect parallel result
  wait "$_PID_DEBT" 2>/dev/null; cat "$_PAR_DIR/debt" 2>/dev/null

  # 17. CI/CD presence — skip if none
  CICD=""
  if [[ -d ".github/workflows" ]]; then
    WF_COUNT=$(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l)
    CICD+="GitHub Actions ($WF_COUNT workflows) "
  fi
  [[ -f ".gitlab-ci.yml" ]] && CICD+="GitLab CI "
  [[ -f "Jenkinsfile" ]] && CICD+="Jenkins "
  [[ -f ".circleci/config.yml" ]] && CICD+="CircleCI "
  [[ -f ".travis.yml" ]] && CICD+="Travis CI "
  [[ -f "bitbucket-pipelines.yml" ]] && CICD+="Bitbucket Pipelines "
  [[ -f ".drone.yml" ]] && CICD+="Drone "
  if [[ -n "$CICD" ]]; then
    echo "=== CI/CD ==="
    echo "$CICD"
    echo ""
  fi

  # 18. Container signals — skip if none
  CONTAINERS=""
  [[ -f "Dockerfile" ]] && CONTAINERS+="Dockerfile "
  while read -r f; do
    CONTAINERS+="$(echo "$f" | sed 's|^\./||') "
  done < <(find . -maxdepth 2 -name 'Dockerfile*' -not -path '*/.git/*' 2>/dev/null | grep -v '^./Dockerfile$')
  [[ -f "docker-compose.yml" || -f "docker-compose.yaml" || -f "compose.yml" || -f "compose.yaml" ]] && CONTAINERS+="compose "
  [[ -f ".dockerignore" ]] && CONTAINERS+="dockerignore "
  if [[ -n "$CONTAINERS" ]]; then
    echo "=== CONTAINERS ==="
    echo "$CONTAINERS"
    echo ""
  fi

  # 18b. Database signals — skip if none
  DB_SIGNALS=""
  [[ -f "prisma/schema.prisma" ]] && DB_SIGNALS+="Prisma "
  [[ -f "drizzle.config.ts" || -f "drizzle.config.js" ]] && DB_SIGNALS+="Drizzle "
  [[ -f "knexfile.js" || -f "knexfile.ts" ]] && DB_SIGNALS+="Knex "
  [[ -f "alembic.ini" || -d "alembic" ]] && DB_SIGNALS+="Alembic "
  [[ -f "diesel.toml" ]] && DB_SIGNALS+="Diesel "
  [[ -d "migrations" || -d "db/migrate" || -d "db/migrations" ]] && DB_SIGNALS+="migrations/ "
  TYPEORM=$(find . -maxdepth 3 -name 'ormconfig*' -o -name 'data-source*' 2>/dev/null | head -1)
  [[ -n "$TYPEORM" ]] && DB_SIGNALS+="TypeORM "
  [[ -f "sequelize.config.js" || -f ".sequelizerc" ]] && DB_SIGNALS+="Sequelize "
  [[ -f "mongod.conf" || -d ".mongodb" ]] && DB_SIGNALS+="MongoDB "
  SCHEMA_FILES=$(find . -maxdepth 3 \( -name 'schema.sql' -o -name '*.schema' -o -name 'init.sql' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
  [[ "$SCHEMA_FILES" -gt 0 ]] && DB_SIGNALS+="SQL schemas($SCHEMA_FILES) "
  if [[ -f "pyproject.toml" ]]; then
    grep -q 'sqlalchemy\|sqlmodel' pyproject.toml 2>/dev/null && DB_SIGNALS+="SQLAlchemy "
  fi
  if [[ -n "$DB_SIGNALS" ]]; then
    echo "=== DATABASES ==="
    echo "$DB_SIGNALS"
    echo ""
  fi

  # 18c. Queue & cache signals — skip if none
  QC_SIGNALS=""
  if [[ -f "package.json" ]]; then
    grep -q '"bullmq"\|"bull"' package.json 2>/dev/null && QC_SIGNALS+="BullMQ "
    grep -q '"ioredis"\|"redis"' package.json 2>/dev/null && QC_SIGNALS+="Redis "
    grep -q '"kafkajs"\|"@kafka"' package.json 2>/dev/null && QC_SIGNALS+="Kafka "
    grep -q '"amqplib"\|"amqp"' package.json 2>/dev/null && QC_SIGNALS+="RabbitMQ "
  fi
  if [[ -f "pyproject.toml" || -f "requirements.txt" ]]; then
    _PY_DEPS=$(cat pyproject.toml requirements.txt 2>/dev/null)
    echo "$_PY_DEPS" | grep -qi 'celery' && QC_SIGNALS+="Celery "
    echo "$_PY_DEPS" | grep -qi 'redis' && QC_SIGNALS+="Redis "
    echo "$_PY_DEPS" | grep -qi 'kafka' && QC_SIGNALS+="Kafka "
    echo "$_PY_DEPS" | grep -qi 'rabbitmq\|pika\|kombu' && QC_SIGNALS+="RabbitMQ "
  fi
  [[ -f "redis.conf" ]] && QC_SIGNALS+="redis.conf "
  if [[ -n "$QC_SIGNALS" ]]; then
    echo "=== QUEUES & CACHES ==="
    echo "$QC_SIGNALS"
    echo ""
  fi

  # 18d. Orchestration signals — skip if none
  ORCH=""
  [[ -d "k8s" || -d "kubernetes" || -d "kube" ]] && ORCH+="k8s manifests "
  K8S_FILES=$(find . -maxdepth 3 \( -name '*.yaml' -o -name '*.yml' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.github/*' 2>/dev/null \
    | xargs grep -l 'apiVersion:' 2>/dev/null \
    | xargs grep -l 'kind:' 2>/dev/null | wc -l)
  [[ "$K8S_FILES" -gt 0 ]] && ORCH+="k8s yamls($K8S_FILES) "
  [[ -f "Chart.yaml" || -d "charts" ]] && ORCH+="Helm "
  [[ -f "kustomization.yaml" || -f "kustomization.yml" ]] && ORCH+="Kustomize "
  [[ -f "skaffold.yaml" ]] && ORCH+="Skaffold "
  [[ -f "tilt_config.json" || -f "Tiltfile" ]] && ORCH+="Tilt "
  [[ -f "fly.toml" ]] && ORCH+="Fly.io "
  [[ -f "render.yaml" ]] && ORCH+="Render "
  [[ -f "vercel.json" || -f ".vercel" ]] && ORCH+="Vercel "
  [[ -f "netlify.toml" ]] && ORCH+="Netlify "
  [[ -f "railway.toml" || -f "railway.json" ]] && ORCH+="Railway "
  if [[ -n "$ORCH" ]]; then
    echo "=== ORCHESTRATION ==="
    echo "$ORCH"
    echo ""
  fi

  # 18e. Environment architecture — skip if none beyond basic .env
  ENV_ARCH=""
  [[ -f ".env.example" || -f ".env.template" || -f ".env.sample" ]] && ENV_ARCH+="env-template "
  [[ -f "vault.hcl" || -d ".vault" ]] && ENV_ARCH+="HashiCorp Vault "
  [[ -f "doppler.yaml" ]] && ENV_ARCH+="Doppler "
  [[ -f ".sops.yaml" || -f ".sops.yml" ]] && ENV_ARCH+="SOPS "
  [[ -f "chamber.yml" ]] && ENV_ARCH+="Chamber "
  ENV_COUNT=$(find . -maxdepth 3 -name '.env*' \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
  [[ "$ENV_COUNT" -gt 3 ]] && ENV_ARCH+="multi-env($ENV_COUNT files) "
  if [[ -n "$ENV_ARCH" ]]; then
    echo "=== ENV ARCHITECTURE ==="
    echo "$ENV_ARCH"
    echo ""
  fi

  # 19. API surface hints — skip if none found
  API_ROUTES=0
  JS_FILES=$(tracked_files '\.(ts|js)$')
  if [[ -n "$JS_FILES" ]]; then
    API_ROUTES=$(echo "$JS_FILES" \
      | xargs grep -lE '\.(get|post|put|patch|delete)\s*\(' 2>/dev/null \
      | grep -iE '(route|api|controller|handler|endpoint|server)' | wc -l)
  fi
  PY_ROUTES=0
  PY_FILES=$(tracked_files '\.py$')
  if [[ -n "$PY_FILES" ]]; then
    PY_ROUTES=$(echo "$PY_FILES" \
      | xargs grep -lE '@(app|router)\.(get|post|put|patch|delete)' 2>/dev/null | wc -l)
  fi
  GRAPHQL=$(find . -maxdepth 3 \( -name '*.graphql' -o -name '*.gql' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l)
  OPENAPI=$(find . -maxdepth 2 \( -name 'openapi.*' -o -name 'swagger.*' \) \
    -not -path '*/node_modules/*' 2>/dev/null | wc -l)
  if [[ $API_ROUTES -gt 0 || $PY_ROUTES -gt 0 || $GRAPHQL -gt 0 || $OPENAPI -gt 0 ]]; then
    echo "=== API SURFACE ==="
    [[ $API_ROUTES -gt 0 ]] && echo "route files (JS/TS): $API_ROUTES"
    [[ $PY_ROUTES -gt 0 ]] && echo "route files (Python): $PY_ROUTES"
    [[ $GRAPHQL -gt 0 ]] && echo "graphql schemas: $GRAPHQL"
    [[ $OPENAPI -gt 0 ]] && echo "openapi/swagger specs: $OPENAPI"
    echo ""
  fi

  # 20. Environment files — skip if none
  ENV_FILES=$(find . -maxdepth 3 -name '.env*' \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
  if [[ -n "$ENV_FILES" ]]; then
    echo "=== ENV FILES ==="
    echo "$ENV_FILES" | sed 's|^\./||;s/^/  /'
    if [[ -f ".gitignore" ]] && grep -q '\.env' .gitignore 2>/dev/null; then
      echo "  (.gitignore covers .env)"
    else
      echo "  WARNING: .env not in .gitignore"
    fi
    echo ""
  fi

  # 21. QA infrastructure signals
  echo "=== QA INFRASTRUCTURE ==="

  # Linter configs
  echo "linters:"
  for f in .eslintrc* eslint.config* .pylintrc .flake8 ruff.toml .ruff.toml pyproject.toml clippy.toml .clippy.toml \
           .stylelintrc* .markdownlint* .sqlfluff .golangci.yml .golangci.yaml biome.json biome.jsonc; do
    if [[ "$f" == "pyproject.toml" ]]; then
      [[ -f "$f" ]] && grep -q '\[tool\.ruff\]\|\[tool\.pylint\]\|\[tool\.flake8\]' "$f" 2>/dev/null && echo "  $f (has lint config)"
    elif compgen -G "$f" >/dev/null 2>&1; then
      echo "  $(compgen -G "$f" | head -1)"
    fi
  done
  [[ -f "Cargo.toml" ]] && grep -q '\[workspace\.lints\]\|\[lints\]' Cargo.toml 2>/dev/null && echo "  Cargo.toml (has [lints])"

  # Formatter configs
  echo "formatters:"
  for f in .prettierrc* prettier.config* rustfmt.toml .rustfmt.toml .editorconfig; do
    compgen -G "$f" >/dev/null 2>&1 && echo "  $(compgen -G "$f" | head -1)"
  done
  [[ -f "pyproject.toml" ]] && grep -q '\[tool\.black\]\|\[tool\.ruff\.format\]' pyproject.toml 2>/dev/null && echo "  pyproject.toml (has formatter config)"
  [[ -f "biome.json" || -f "biome.jsonc" ]] && echo "  biome (built-in formatter)"

  # Git hook tools
  echo "hooks:"
  [[ -d ".husky" ]] && echo "  .husky/ (husky)"
  [[ -f ".pre-commit-config.yaml" ]] && echo "  .pre-commit-config.yaml (pre-commit)"
  [[ -f ".trunk/trunk.yaml" ]] && echo "  .trunk/trunk.yaml (trunk)"
  if [[ -f "package.json" ]]; then
    jq -e '.["lint-staged"]' package.json &>/dev/null 2>&1 && echo "  package.json (lint-staged config)"
    jq -e '.devDependencies["lint-staged"]' package.json &>/dev/null 2>&1 && echo "  lint-staged (installed)"
  fi
  [[ -f ".lintstagedrc" || -f ".lintstagedrc.json" || -f ".lintstagedrc.js" ]] && echo "  lint-staged config file"

  # Suppression/baseline signals
  echo "baselines:"
  [[ -f "eslint-suppressions.json" ]] && echo "  eslint-suppressions.json"
  NOQA_COUNT=$(tracked_files | xargs grep -l 'noqa\|type: ignore\|eslint-disable\|@ts-ignore\|#\[allow(' 2>/dev/null | wc -l)
  [[ "$NOQA_COUNT" -gt 0 ]] && echo "  $NOQA_COUNT files with inline suppressions"

  # Test topology — what's tested reveals what the team considers load-bearing
  echo "test-topology:"
  TEST_FILES=$(tracked_files | grep -iE '(test|spec)\.' | grep -vE '(node_modules|dist|\.d\.ts$)')
  if [[ -n "$TEST_FILES" ]]; then
    TOTAL_TESTS=$(echo "$TEST_FILES" | wc -l)
    echo "  $TOTAL_TESTS test files"
    # Which directories have tests (top-level grouping)
    echo "$TEST_FILES" | awk -F/ '{
      if (NF > 1) dirs[$1]++
      else dirs["(root)"]++
    } END {
      for (d in dirs) printf "  %s: %d\n", d, dirs[d]
    }' | sort -t: -k2 -rn | head -8
    # Snapshot tests (stable surface contracts)
    SNAP_COUNT=$(tracked_files | grep -c '\.snap$\|__snapshots__' 2>/dev/null || true)
    [[ "$SNAP_COUNT" -gt 0 ]] && echo "  snapshots: $SNAP_COUNT files"
    # Integration vs unit signal (files with 'integration' or 'e2e' in path)
    INT_COUNT=$(echo "$TEST_FILES" | grep -ciE 'integration|e2e|playwright|cypress' || true)
    [[ "$INT_COUNT" -gt 0 ]] && echo "  integration/e2e: $INT_COUNT files"
  else
    echo "  no test files found"
  fi

  echo ""

  # 22. Archetype signals
  echo "=== ARCHETYPE SIGNALS ==="

  # Entry points
  echo "entries:"
  tracked_files \
    | grep -E '(^|/)(main|index|cli|server|app|mod\.rs|__main__\.py)\.[^/]+$' \
    | grep -vE '(node_modules|dist|docs|test|spec|__tests__|\.d\.ts$)' \
    | awk -F/ '{print NF, $0}' | sort -n | cut -d' ' -f2- | head -8

  # Extension surface indicators
  echo "extension-dirs:"
  tracked_files \
    | grep -oE '^.*(plugin|middleware|hook|extension|adapter|provider|strategy|driver)[^/]*/'\
    | sort -u | awk '{print length, $0}' | sort -n | cut -d' ' -f2- | head -5

  # Config surface
  echo "config-files:"
  find . -maxdepth 2 -type f \( \
    -name "*.config.*" -o -name ".*.rc" -o -name "*.toml" -o \
    -name "*.yaml" -o -name "*.yml" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l

  # Test surface — single awk pass for clean formatting
  tracked_files | awk '
    /(test|spec)\./ { tests++ }
    !/(test|spec)\./ { src++ }
    END { printf "test-ratio: %d/%d\n", tests+0, src+0 }
  '

  # Workspace signals
  IS_MONOREPO=""
  [[ -f "lerna.json" || -f "pnpm-workspace.yaml" || -f "nx.json" ]] && IS_MONOREPO="yes" && echo "monorepo: yes"
  [[ -f "Cargo.toml" ]] && grep -q '\[workspace\]' Cargo.toml 2>/dev/null && IS_MONOREPO="yes" && echo "cargo-workspace: yes"
  WORKSPACE_DIRS=$(ls -d packages/ apps/ crates/ libs/ modules/ 2>/dev/null | head -3)
  if [[ -n "$WORKSPACE_DIRS" ]]; then
    echo "$WORKSPACE_DIRS"
    [[ -z "$IS_MONOREPO" ]] && IS_MONOREPO="yes"
  fi
  if [[ -z "$IS_MONOREPO" && -f "package.json" ]]; then
    jq -e '.workspaces' package.json &>/dev/null && IS_MONOREPO="yes" && echo "monorepo: yes (workspaces in package.json)"
  fi
  echo ""

  # 22. Monorepo package map
  if [[ -n "$IS_MONOREPO" ]]; then
    echo "=== PACKAGES ==="
    find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' -not -path './.git/*' -not -path './package.json' 2>/dev/null \
      | sort | while read -r pkg; do
        pkg_dir=$(dirname "$pkg" | sed 's|^\./||')
        pkg_name=$(jq -r '.name // empty' "$pkg" 2>/dev/null)
        [[ -n "$pkg_name" ]] && echo "  $pkg_dir ($pkg_name)" || echo "  $pkg_dir"
      done | head -15
    if [[ -f "Cargo.toml" ]] && grep -q '\[workspace\]' Cargo.toml 2>/dev/null; then
      grep -A20 '^\[workspace\]' Cargo.toml 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"' | sed 's/^/  /' | head -10
    fi
    echo ""
  fi

  # 23. Focused package context
  if [[ -n "$PKG_DIR" && "$PKG_DIR" != "$REPO_ROOT" ]]; then
    echo "=== FOCUSED PACKAGE: $PKG_REL ==="
    cd "$PKG_DIR"

    # Package framework
    PKG_FW=$(detect_frameworks .)
    [[ "$PKG_FW" != "none detected" ]] && echo "framework: $PKG_FW"

    # Package dependencies
    if [[ -f "package.json" ]]; then
      PKG_DEP_COUNT=$(jq -r '(.dependencies // {}) | keys | length' package.json 2>/dev/null || echo 0)
      PKG_DEV_COUNT=$(jq -r '(.devDependencies // {}) | keys | length' package.json 2>/dev/null || echo 0)
      if [[ $PKG_DEP_COUNT -gt 0 ]]; then
        echo "dependencies ($PKG_DEP_COUNT +$PKG_DEV_COUNT dev):"
        jq -r '(.dependencies // {}) | keys[]' package.json 2>/dev/null | head -10 | sed 's/^/  /'
      fi
      PKG_SCRIPTS=$(jq -r '(.scripts // {}) | to_entries[] | "  \(.key): \(.value)"' package.json 2>/dev/null)
      if [[ -n "$PKG_SCRIPTS" ]]; then
        echo "scripts:"
        echo "$PKG_SCRIPTS" | head -8
      fi
    fi
    if [[ -f "Cargo.toml" ]]; then
      echo "crate deps:"
      list_cargo_deps Cargo.toml 8
    fi

    # Package test framework
    PKG_TF=$(detect_test_frameworks .)
    [[ "$PKG_TF" != "none detected" ]] && echo "test framework: $PKG_TF"

    # Package structure
    echo "structure:"
    print_structure . 2 20 | sed 's/^/  /'

    cd "$REPO_ROOT"
    echo ""
  fi

  # Cleanup parallel temp files and tracked files cache
  rm -rf "$_PAR_DIR" 2>/dev/null
  rm -f "$_GIT_FILES_CACHE" 2>/dev/null

} 2>/dev/null | finalize_cache
