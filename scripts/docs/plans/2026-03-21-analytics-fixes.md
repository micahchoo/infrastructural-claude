# Codebase Analytics Script Fixes

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all bugs, quality issues, completeness gaps, and efficiency problems identified in the simplify review + eval-protocol analysis.

**Architecture:** Two files — `lib/cache-utils.sh` (shared utilities) and `codebase-analytics.sh` (main script). Cache-utils gets helper functions that the main script consumes. Main script gets a coordinated rewrite since 20+ interrelated changes are cleaner to apply together than surgically.

**Tech Stack:** Bash, git, scc, ctags, jq, gh CLI

---

## Execution Waves

- **Wave 1**: Task 1 (cache-utils.sh) — foundation, no deps
- **Wave 2**: Task 2 (codebase-analytics.sh rewrite) — depends on Wave 1
- **Wave 3**: Task 3 (verification) — depends on Wave 2

---

### Task 1: Fix cache-utils.sh

**Files:**
- Modify: `/home/micah/.claude/scripts/lib/cache-utils.sh`

**Fixes applied:**
- Q6: finalize_cache detects upstream failures (check PIPESTATUS, rm partial on failure)
- Q7: Cache key includes untracked files (git ls-files --others --exclude-standard)
- Q3: Add TREE_EXCLUDES glob pattern alongside regex EXCLUDES
- R7: Add `tracked_files()` helper that caches git ls-files to temp file, with optional extension filter
- R1 (partial): Add `init_sub_cache()` supporting custom cache keys for GH cache reuse

- [ ] **Step 1: Implement all cache-utils.sh changes**

Key changes:
```bash
# TREE_EXCLUDES for tree -I (glob, not regex)
TREE_EXCLUDES="node_modules|.git|vendor|dist|build|__pycache__|.next|.cache|.venv|target|.worktrees"

# tracked_files helper — caches git ls-files to temp, optional ext filter
_GIT_FILES_CACHE=""
tracked_files() {
  if [[ -z "$_GIT_FILES_CACHE" ]]; then
    _GIT_FILES_CACHE=$(mktemp)
    git ls-files 2>/dev/null > "$_GIT_FILES_CACHE"
    trap 'rm -f "$_GIT_FILES_CACHE"' EXIT
  fi
  if [[ -n "$1" ]]; then
    grep -E "$1" "$_GIT_FILES_CACHE" | grep -vE "$EXCLUDES"
  else
    grep -vE "$EXCLUDES" "$_GIT_FILES_CACHE"
  fi
}

# Cache key includes untracked files
git_dirty=$({ git diff --raw 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sha256sum | cut -c1-16)

# finalize_cache checks for upstream failure
finalize_cache() {
  local tmp="${_CACHE_FILE}.$$"
  if tee "$tmp" && [[ -s "$tmp" ]]; then
    mv -f "$tmp" "$_CACHE_FILE"
  else
    rm -f "$tmp"
  fi
}
```

- [ ] **Step 2: Verify cache-utils.sh sources cleanly**

Run: `bash -n /home/micah/.claude/scripts/lib/cache-utils.sh && echo OK`
Expected: OK

---

### Task 2: Rewrite codebase-analytics.sh

**Files:**
- Modify: `/home/micah/.claude/scripts/codebase-analytics.sh`

**All fixes applied (organized by source):**

**Bugs (Quality review):**
- Q1: Container find|while subshell → process substitution
- Q2: Tech debt grep binary files → add `-I` flag
- Q3: tree -I uses TREE_EXCLUDES (glob) not EXCLUDES (regex)
- Q4: Archetype test-ratio formatting → use awk single-pass
- Q5: Non-git subdir traversal → verify ORIG_DIR has .git or is repo root, warn otherwise
- Q8: find -o grouping parens for GraphQL/OpenAPI
- Q9: PRIMARY_EXT filters lockfiles/json/md before counting
- Q10: Remove redundant `2>&1` on gh auth line
- Q11: Justfile/justfile existence check before grep
- Q13: PKG_DEP_COUNT uses jq length, not echo|grep -c

**Completeness (Eval-protocol gaps):**
- Add CMake framework detection
- Add primary framework distinction (list primary first, others as "also:")
- Add Dart/pubspec.yaml dependency parsing
- Add Clojure/shadow-cljs dependency parsing
- Add Scala/sbt dependency parsing
- Filter .po/.pot translation files from churn output

**Efficiency:**
- Eff1: ctags uses `tracked_files` pipe instead of -R
- Eff2: Churn adds pathspec exclusions + caps at --max-count=2000
- Eff3: Tech debt collapsed to single grep pass
- Eff4: All `git ls-files` calls replaced with `tracked_files` helper
- Eff5: API surface uses cached file list
- Eff6: scc gets --exclude-dir flags
- Eff9: Parallelize scc, ctags, churn, tech debt into background subshells
- Eff11: Merge duplicate git branch calls
- Eff12: Test-ratio uses single awk pass

**Reuse:**
- R3: Framework detection → `detect_frameworks` function (called from root + focused pkg)
- R4: Test framework detection → `detect_test_frameworks` function
- R5: Structure printing → `print_structure` function
- R6: Cargo deps → `list_cargo_deps` function
- R1: GH cache uses init_sub_cache from cache-utils.sh

- [ ] **Step 1: Write the rewritten codebase-analytics.sh**

The rewrite preserves all 23 sections and output format, incorporating every fix above. Key structural changes:
1. Parallel subshells for scc/ctags/churn/tech-debt with temp files
2. Helper functions at top for detect_frameworks, detect_test_frameworks, print_structure, list_cargo_deps
3. `tracked_files` from cache-utils.sh replaces all inline `git ls-files` calls
4. Non-git-subdir guard after REPO_ROOT detection

- [ ] **Step 2: Syntax check**

Run: `bash -n /home/micah/.claude/scripts/codebase-analytics.sh && echo OK`
Expected: OK

---

### Task 3: Verification

**Files:** (none modified — testing only)

- [ ] **Step 1: Test on krita (large C++ repo, performance + binary grep + framework)**

Run: `bash /home/micah/.claude/scripts/codebase-analytics.sh /path/to/krita`
Expected:
- Runs in < 10s (was 18.6s)
- FRAMEWORK shows "CMake" (not just "Python")
- TECH DEBT does not list .png files
- SYMBOLS section either produces useful output or is cleanly skipped
- CHURN does not show .po files in top 12

- [ ] **Step 2: Test on tldraw (TS monorepo)**

Expected:
- PACKAGES section populated correctly
- Monorepo detection works
- CONTAINERS shows Dockerfiles from subdirs (not just root)

- [ ] **Step 3: Test on Graphite (Rust project)**

Expected:
- FRAMEWORK shows "Rust/Cargo" as primary, not "TypeScript"
- Cargo workspace detected

- [ ] **Step 4: Test on non-git subdir (obsidian-help)**

Expected:
- Exits cleanly without analyzing parent repo
- OR warns that it's analyzing the parent repo

- [ ] **Step 5: Test on neko (Go + Docker)**

Expected:
- Go framework detected
- All Dockerfiles found in CONTAINERS section
