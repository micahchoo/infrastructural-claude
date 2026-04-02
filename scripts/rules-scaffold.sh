#!/usr/bin/env bash
# rules-scaffold.sh — Scaffold .claude/rules/ from project signals
# SessionStart hook. Idempotent: exits immediately if rules/ already exists.
# Templates live at ~/.claude/rule-templates/. Missing templates are skipped.
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

# Don't scaffold in the infra repo itself
[[ "$PROJECT_ROOT" = "$HOME/.claude" ]] && exit 0

# Idempotent — already scaffolded
[[ -d ".claude/rules" ]] && exit 0

mkdir -p ".claude/rules"

TEMPLATE_DIR="$HOME/.claude/rule-templates"
signals=()

# --- Helper: copy template with sed substitution ---
# Usage: apply_template <template_name> <placeholder=value ...>
apply_template() {
  local tpl="$TEMPLATE_DIR/$1"
  local out=".claude/rules/$1"
  [[ -f "$tpl" ]] || return 0
  cp "$tpl" "$out"
  shift
  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    sed -i "s|{{${key}}}|${val}|g" "$out"
  done
}

# --- Signal: .mulch/ ---
if [[ -d .mulch ]]; then
  signals+=("mulch")
  apply_template "mulch-workflow.md"
fi

# --- Signal: .seeds/ ---
if [[ -d .seeds ]]; then
  signals+=("seeds")
  apply_template "seeds-workflow.md"
fi

# --- Signal: package.json ---
if [[ -f package.json ]]; then
  signals+=("package.json")
  tools=()
  for tool in eslint prettier vitest jest; do
    if grep -q "\"$tool\"" package.json 2>/dev/null; then
      tools+=("$tool")
    fi
  done
  tools_list="${tools[*]:-none detected}"
  apply_template "js-conventions.md" "TOOLS_LIST=${tools_list}"
fi

# --- Signal: Cargo.toml ---
if [[ -f Cargo.toml ]]; then
  signals+=("Cargo.toml")
  edition=$(grep -m1 '^edition' Cargo.toml 2>/dev/null | sed 's/.*=\s*"\?\([^"]*\)"\?/\1/' || echo "unknown")
  [[ -z "$edition" ]] && edition="unknown"
  tools=()
  command -v clippy-driver >/dev/null 2>&1 && tools+=("clippy")
  command -v rustfmt >/dev/null 2>&1 && tools+=("rustfmt")
  # Also check Cargo.toml for clippy/rustfmt config sections
  if grep -q '\[clippy\]' Cargo.toml 2>/dev/null; then
    [[ ! " ${tools[*]:-} " =~ " clippy " ]] && tools+=("clippy")
  fi
  tools_list="${tools[*]:-none detected}"
  apply_template "rust-conventions.md" "EDITION=${edition}" "TOOLS_LIST=${tools_list}"
fi

# --- Signal: pyproject.toml ---
if [[ -f pyproject.toml ]]; then
  signals+=("pyproject.toml")
  py_version=$(grep -m1 'requires-python' pyproject.toml 2>/dev/null | sed 's/.*=\s*"\?\([^"]*\)"\?/\1/' || echo "unknown")
  [[ -z "$py_version" ]] && py_version="unknown"
  tools=()
  for tool in ruff mypy pytest; do
    if grep -q "$tool" pyproject.toml 2>/dev/null; then
      tools+=("$tool")
    fi
  done
  tools_list="${tools[*]:-none detected}"
  apply_template "python-conventions.md" "PYTHON_VERSION=${py_version}" "TOOLS_LIST=${tools_list}"
fi

# --- Signal: tsconfig.json ---
if [[ -f tsconfig.json ]]; then
  signals+=("tsconfig.json")
  strict=$(grep -m1 '"strict"' tsconfig.json 2>/dev/null | grep -o 'true\|false' || echo "unknown")
  target=$(grep -m1 '"target"' tsconfig.json 2>/dev/null | sed 's/.*:.*"\([^"]*\)".*/\1/' || echo "unknown")
  if grep -q '"paths"' tsconfig.json 2>/dev/null; then
    paths="configured"
  else
    paths="none"
  fi
  [[ -z "$strict" ]] && strict="unknown"
  [[ -z "$target" ]] && target="unknown"
  apply_template "typescript.md" "STRICT=${strict}" "TARGET=${target}" "PATHS=${paths}"
fi

# --- Signal: schema files (prisma/drizzle/graphql) ---
schema_path=""
schema_dir=""
if [[ -f prisma/schema.prisma ]]; then
  schema_path="prisma/schema.prisma"
  schema_dir="prisma"
elif [[ -d drizzle ]]; then
  schema_path="drizzle/"
  schema_dir="drizzle"
else
  gql_file=$(find . -maxdepth 3 -name '*.graphql' -print -quit 2>/dev/null || true)
  if [[ -n "$gql_file" ]]; then
    schema_path="${gql_file#./}"
    schema_dir=$(dirname "$schema_path")
  fi
fi
if [[ -n "$schema_path" ]]; then
  signals+=("schema")
  apply_template "schema-contracts.md" "SCHEMA_DIR=${schema_dir}" "SCHEMA_PATH=${schema_path}"
fi

# --- Signal: API specs (openapi/swagger/proto) ---
api_spec=""
api_dir=""
for candidate in openapi.yaml openapi.yml swagger.json swagger.yaml; do
  if [[ -f "$candidate" ]]; then
    api_spec="$candidate"
    api_dir="."
    break
  fi
done
if [[ -z "$api_spec" ]]; then
  proto_file=$(find . -maxdepth 3 -name '*.proto' -print -quit 2>/dev/null || true)
  if [[ -n "$proto_file" ]]; then
    api_spec="${proto_file#./}"
    api_dir=$(dirname "$api_spec")
  fi
fi
if [[ -n "$api_spec" ]]; then
  signals+=("api-spec")
  apply_template "api-contracts.md" "API_SPEC_DIR=${api_dir}" "API_SPEC_PATH=${api_spec}"
fi

# --- Signal: CI configs ---
ci_dir=""
if [[ -d .github/workflows ]]; then
  ci_dir=".github/workflows"
elif [[ -f Jenkinsfile ]]; then
  ci_dir="."
fi
if [[ -n "$ci_dir" ]]; then
  signals+=("ci")
  apply_template "build-deploy.md" "CI_DIR=${ci_dir}"
fi

# --- Signal: test fixtures ---
fixtures_dir=""
for candidate in __fixtures__ fixtures testdata; do
  found=$(find . -maxdepth 3 -type d -name "$candidate" -print -quit 2>/dev/null || true)
  if [[ -n "$found" ]]; then
    fixtures_dir="${found#./}"
    break
  fi
done
if [[ -n "$fixtures_dir" ]]; then
  signals+=("test-fixtures")
  apply_template "test-fixtures.md" "FIXTURES_DIR=${fixtures_dir}"
fi

# --- Signal: config coupling ---
config_dir=""
if [[ -f .env.example ]]; then
  config_dir="."
  signals+=("config")
elif [[ -d config ]]; then
  file_count=$(find config -maxdepth 1 -type f 2>/dev/null | wc -l)
  if [[ "$file_count" -gt 1 ]]; then
    config_dir="config"
    signals+=("config")
  fi
fi
if [[ -n "$config_dir" ]]; then
  apply_template "config-coupling.md" "CONFIG_DIR=${config_dir}"
fi

# --- Signal: public API (package.json exports or barrel index.ts) ---
exports_pattern=""
if [[ -f package.json ]] && grep -q '"exports"' package.json 2>/dev/null; then
  exports_pattern="package.json exports field"
  signals+=("public-api")
elif [[ -f index.ts ]] || [[ -f src/index.ts ]]; then
  if [[ -f src/index.ts ]]; then
    exports_pattern="src/index.ts"
  else
    exports_pattern="index.ts"
  fi
  signals+=("public-api")
fi
if [[ -n "$exports_pattern" ]]; then
  apply_template "public-api.md" "EXPORTS_PATTERN=${exports_pattern}"
fi

# --- Write _meta.json ---
if [[ ${#signals[@]} -gt 0 ]]; then
  signals_json=$(printf '"%s",' "${signals[@]}" | sed 's/,$//')
else
  signals_json=""
fi
cat > ".claude/rules/_meta.json" <<EOF
{ "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "signals": [${signals_json}], "version": 1 }
EOF

# --- Append scoped rules section to .claude/CLAUDE.md ---
scoped_rules_tpl="$TEMPLATE_DIR/scoped-rules-claude-md.md"
if [[ -f "$scoped_rules_tpl" ]]; then
  if [[ ! -f ".claude/CLAUDE.md" ]]; then
    cp "$scoped_rules_tpl" ".claude/CLAUDE.md"
  elif ! grep -q '## Scoped Rules' ".claude/CLAUDE.md" 2>/dev/null; then
    printf '\n' >> ".claude/CLAUDE.md"
    cat "$scoped_rules_tpl" >> ".claude/CLAUDE.md"
  fi
fi

echo "Scaffolded .claude/rules/ with ${#signals[@]} rule files from: ${signals[*]:-none}"
