#!/usr/bin/env bash
# readme-seam-check.sh — SessionStart hook that compares README claims against codebase ground truth
# Follows measure-leverage.sh scorecard pattern. Quiet on success. Requires git repo.
# Reuses codebase-analytics.sh cached output. Skips if no README.md.
set +e

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
README="$REPO_ROOT/README.md"
[ -f "$README" ] || exit 0

warnings=0

# R1: Setup commands — check code blocks for commands that reference missing files
while IFS= read -r line; do
  # Extract commands like "npm install", "pip install", "cargo build"
  if echo "$line" | grep -qE '^\s*(npm|yarn|pnpm)\s'; then
    [ ! -f "$REPO_ROOT/package.json" ] && echo "README-SEAM R1 FAIL: README references npm but no package.json found" && warnings=$((warnings+1))
  fi
  if echo "$line" | grep -qE '^\s*pip\s+install|^\s*poetry\s+install'; then
    [ ! -f "$REPO_ROOT/requirements.txt" ] && [ ! -f "$REPO_ROOT/pyproject.toml" ] && echo "README-SEAM R1 FAIL: README references pip/poetry but no requirements.txt or pyproject.toml found" && warnings=$((warnings+1))
  fi
  if echo "$line" | grep -qE '^\s*cargo\s+(build|run|test)'; then
    [ ! -f "$REPO_ROOT/Cargo.toml" ] && echo "README-SEAM R1 FAIL: README references cargo but no Cargo.toml found" && warnings=$((warnings+1))
  fi
done < <(sed -n '/^```/,/^```/p' "$README" | grep -v '^```')

# R2: Directory references — check path-like mentions
grep -oE '\b(src|lib|tests?|docs?|scripts?|cmd|pkg|internal|api)/[a-zA-Z0-9_/-]+' "$README" | sort -u | while read -r dir; do
  [ ! -e "$REPO_ROOT/$dir" ] && echo "README-SEAM R2 WARN: README references $dir — not found" && warnings=$((warnings+1))
done

# R3: Dependency count — compare README mentions vs manifest
if [ -f "$REPO_ROOT/package.json" ]; then
  manifest_deps=$(jq -r '(.dependencies // {}) | keys | length' "$REPO_ROOT/package.json" 2>/dev/null || echo 0)
  readme_deps=$(grep -coE '"[a-z@][a-z0-9@/_-]+"' "$README" 2>/dev/null || echo 0)
  # Only warn if manifest has significantly more deps than README mentions
  if [ "$manifest_deps" -gt 0 ] && [ "$readme_deps" -eq 0 ]; then
    echo "README-SEAM R3 WARN: package.json has $manifest_deps deps but README mentions none"
    warnings=$((warnings+1))
  fi
fi

# R4: Language claims — check against scc/tokei if available
if command -v scc &>/dev/null; then
  actual_langs=$(scc --no-cocomo -f json "$REPO_ROOT" 2>/dev/null | jq -r '.[].Name' 2>/dev/null | head -5 | tr '\n' ', ' | sed 's/,$//')
  # Informational — only warn if README claims a language not in top 5
  for lang in TypeScript JavaScript Python Rust Go Java Ruby; do
    if grep -qi "\b$lang\b" "$README" 2>/dev/null; then
      if ! echo "$actual_langs" | grep -qi "$lang"; then
        echo "README-SEAM R4 WARN: README mentions $lang but scc top languages are: $actual_langs"
        warnings=$((warnings+1))
      fi
    fi
  done
fi
# Skip R4 silently if scc/tokei not installed (graceful degradation)

# R5: Staleness — README age vs last commit
if [ -f "$README" ]; then
  readme_mtime=$(git log -1 --format=%ct -- "$README" 2>/dev/null || echo 0)
  repo_mtime=$(git log -1 --format=%ct 2>/dev/null || echo 0)
  if [ "$readme_mtime" -gt 0 ] && [ "$repo_mtime" -gt 0 ]; then
    age_days=$(( (repo_mtime - readme_mtime) / 86400 ))
    if [ "$age_days" -gt 30 ]; then
      echo "README-SEAM R5 WARN: README last updated $age_days days before latest commit"
      warnings=$((warnings+1))
    fi
  fi
fi

# Orphaned doc checks (from Stale Doc Cleanup section)
# Plan files older than 30 days
if [ -d "$REPO_ROOT/plans" ] || [ -d "$REPO_ROOT/docs/superpowers/plans" ]; then
  plan_dir="$REPO_ROOT/plans"
  [ -d "$REPO_ROOT/docs/superpowers/plans" ] && plan_dir="$REPO_ROOT/docs/superpowers/plans"
  find "$plan_dir" -name '*.md' -not -path '*/archive/*' -mtime +30 2>/dev/null | while read -r plan; do
    echo "README-SEAM STALE: Plan $(basename "$plan") is >30 days old — consider archiving"
    warnings=$((warnings+1))
  done
fi

# Spec files without status frontmatter
if [ -d "$REPO_ROOT/docs/superpowers/specs" ]; then
  for spec in "$REPO_ROOT/docs/superpowers/specs"/*.md; do
    [ -f "$spec" ] || continue
    if ! grep -q '^status:' "$spec" 2>/dev/null; then
      echo "README-SEAM STALE: Spec $(basename "$spec") has no status: frontmatter"
      warnings=$((warnings+1))
    fi
  done
fi

[ $warnings -gt 0 ] && echo "($warnings README/doc seam warnings)"
exit 0
