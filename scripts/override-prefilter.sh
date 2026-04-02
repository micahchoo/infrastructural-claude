#!/usr/bin/env bash
# override-prefilter.sh — Check which overrides need re-evaluation after plugin update
#
# For each overridden skill, check if marker strings unique to the override content
# appear in the NEW upstream version. If markers are absent, the override is still
# needed and evaluation can be skipped. If markers are present, upstream may have
# adopted the override content and manual evaluation is required.
set +e

PLUGIN_CACHE="$HOME/.claude/plugins/cache/claude-plugins-official"

# Find newest version directory for a plugin (version number or commit hash)
find_newest_version() {
    local plugin="$1"
    local plugin_dir="$PLUGIN_CACHE/$plugin"
    if [[ ! -d "$plugin_dir" ]]; then
        echo ""
        return
    fi
    # List directories, exclude .orphaned_at files, sort by modification time (newest first)
    local newest
    newest=$(ls -td "$plugin_dir"/*/ 2>/dev/null | head -1)
    if [[ -n "$newest" ]]; then
        # Skip orphaned versions
        while [[ -f "$newest/.orphaned_at" ]]; do
            newest=$(ls -td "$plugin_dir"/*/ 2>/dev/null | grep -v "^$newest$" | head -1)
            if [[ -z "$newest" ]]; then
                echo ""
                return
            fi
        done
        echo "${newest%/}"
    fi
}

# ── Marker definitions ──────────────────────────────────────────────────────
# Each key is plugin/relative-path-to-file (from plugin version root).
# Each value is pipe-delimited marker strings unique to the override content.
# If ALL markers are absent from upstream → override still needed → SKIP eval.
# If ANY marker is present → upstream may have adopted it → EVALUATE manually.

declare -A MARKERS
declare -A DESCRIPTIONS

# superpowers overrides
MARKERS["superpowers|agents/code-reviewer.md"]="Blast radius|Reversibility|### 3. Refine"
DESCRIPTIONS["superpowers|agents/code-reviewer.md"]="Full rewrite: risk framework + negative scope + refine step"

MARKERS["superpowers|skills/brainstorming/SKILL.md"]="Locked Decisions|questioning-techniques.md|\\[eval: context\\]"
DESCRIPTIONS["superpowers|skills/brainstorming/SKILL.md"]="Eval checkpoints + questioning techniques + locked decisions output"

MARKERS["superpowers|skills/writing-plans/SKILL.md"]="extract-interfaces.sh|Plan Verification|Execution Waves|Domain-Codebook Annotations|Codebooks:.*gesture-disambiguation|codebook.*annotation"
DESCRIPTIONS["superpowers|skills/writing-plans/SKILL.md"]="Interface extraction + plan verification + execution waves + locked decisions boundary + domain-codebook annotations for UI tasks"

MARKERS["superpowers|skills/executing-plans/SKILL.md"]="Context Budget Discipline|Wave-Based Dispatch|\\[eval: efficiency\\] Orchestrator|UI Task Co-Loading|frontend-design.*subagent prompt|co-loading.*UI"
DESCRIPTIONS["superpowers|skills/executing-plans/SKILL.md"]="Full rewrite: merged subagent-driven-development with context budget + wave dispatch + UI task co-loading with frontend-design"

MARKERS["superpowers|skills/subagent-driven-development/SKILL.md"]="DEPRECATED.*executing-plans|consolidated into.*executing-plans"
DESCRIPTIONS["superpowers|skills/subagent-driven-development/SKILL.md"]="Deprecation redirect to executing-plans"

MARKERS["superpowers|skills/verification-before-completion/SKILL.md"]="anti-pattern-scan.sh|scan-secrets.sh|\\[eval: depth\\].*wiring check"
DESCRIPTIONS["superpowers|skills/verification-before-completion/SKILL.md"]="Anti-pattern scan + secret scan + mulch failure check"

MARKERS["superpowers|skills/dispatching-parallel-agents/SKILL.md"]="Do NOT trigger for.*executing-plans|\\[eval: approach\\] Tasks dispatched"
DESCRIPTIONS["superpowers|skills/dispatching-parallel-agents/SKILL.md"]="Negative triggers vs executing-plans + eval checkpoints"

MARKERS["superpowers|skills/systematic-debugging/SKILL.md"]="\\[eval: evidence\\]|mulch search --type failure"
DESCRIPTIONS["superpowers|skills/systematic-debugging/SKILL.md"]="Eval checkpoints + context MCP library lookups + mulch failure search"

MARKERS["superpowers|skills/requesting-code-review/SKILL.md"]="Landing Decision|Worktree Cleanup|finish branch.*land this.*merge this|UI Quality Audit|userinterface-wiki.*rule audit|shadow-walk regression"
DESCRIPTIONS["superpowers|skills/requesting-code-review/SKILL.md"]="Full rewrite: merged finishing-a-development-branch with landing decision gate + UI quality audit with userinterface-wiki + shadow-walk regression"

MARKERS["superpowers|skills/finishing-a-development-branch/SKILL.md"]="DEPRECATED.*requesting-code-review|consolidated into.*requesting-code-review"
DESCRIPTIONS["superpowers|skills/finishing-a-development-branch/SKILL.md"]="Deprecation redirect to requesting-code-review"

MARKERS["superpowers|skills/using-git-worktrees/SKILL.md"]="DEPRECATED.*writing-plans|consolidated into.*writing-plans"
DESCRIPTIONS["superpowers|skills/using-git-worktrees/SKILL.md"]="Deprecation redirect to writing-plans Step 0"

MARKERS["superpowers|skills/test-driven-development/SKILL.md"]="Red Team Escalation|Scale Tests Drive Architecture|Red team ladder applied"
DESCRIPTIONS["superpowers|skills/test-driven-development/SKILL.md"]="Red Team Escalation ladder + scale-drives-architecture"

# skill-creator overrides
MARKERS["skill-creator|skills/skill-creator/SKILL.md"]="Guiding Principles|Holistic integration|Closing the loop|Baseline-enrichment|Standalone vs Diffusion|Diffusion Decision|diffused checkpoint|Pre-creation Collision Check|config-lens-structural|Description Trap|Token Efficiency|Skill Types|Flowchart Usage"
DESCRIPTIONS["skill-creator|skills/skill-creator/SKILL.md"]="Guiding Principles (holistic integration, closing the loop, baseline-enrichment) + Diffusion Decision + collision check + CSO Description Trap + token efficiency + skill types + flowchart guidance (writing-skills retired, all customizations ported)"

# frontend-design overrides
MARKERS["frontend-design|skills/frontend-design/SKILL.md"]="search_packages.*get_docs|mulch search.*UI convention|Context MCP|Technical Constraints|userinterface-wiki.*co-loaded|hard constraints.*creative direction"
DESCRIPTIONS["frontend-design|skills/frontend-design/SKILL.md"]="Context MCP library lookups + mulch UI convention search + userinterface-wiki technical constraints precedence rule"

# ── Report ───────────────────────────────────────────────────────────────────

echo "Override Pre-Filter Report"
echo "========================="
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

skip_count=0
eval_count=0
missing_count=0

for key in $(echo "${!MARKERS[@]}" | tr ' ' '\n' | sort); do
    plugin="${key%%|*}"
    file="${key#*|}"
    markers="${MARKERS[$key]}"
    desc="${DESCRIPTIONS[$key]}"

    # Find newest upstream version
    version_dir=$(find_newest_version "$plugin")
    if [[ -z "$version_dir" ]]; then
        printf "  %-60s  MISSING (no plugin version found)\n" "$plugin/$file"
        ((missing_count++))
        continue
    fi

    version_name=$(basename "$version_dir")
    upstream_file="$version_dir/$file"

    if [[ ! -f "$upstream_file" ]]; then
        printf "  %-60s  MISSING (file not in %s)\n" "$plugin/$file" "$version_name"
        ((missing_count++))
        continue
    fi

    # Check each marker against the upstream file
    found_markers=()
    absent_markers=()
    IFS='|' read -ra marker_list <<< "$markers"
    for marker in "${marker_list[@]}"; do
        if grep -qP "$marker" "$upstream_file" 2>/dev/null || grep -qE "$marker" "$upstream_file" 2>/dev/null; then
            found_markers+=("$marker")
        else
            absent_markers+=("$marker")
        fi
    done

    total=${#marker_list[@]}
    found=${#found_markers[@]}

    if [[ $found -eq 0 ]]; then
        status="SKIP"
        color="\033[32m"  # green
        ((skip_count++))
    elif [[ $found -eq $total ]]; then
        status="EVALUATE (all ${found}/${total} markers present)"
        color="\033[31m"  # red
        ((eval_count++))
    else
        status="EVALUATE (${found}/${total} markers present)"
        color="\033[33m"  # yellow
        ((eval_count++))
    fi

    printf "  %-60s  ${color}%s\033[0m\n" "$plugin/$file [$version_name]" "$status"
    printf "    %s\n" "$desc"

    if [[ $found -gt 0 && $found -lt $total ]]; then
        echo "    Found: ${found_markers[*]}"
        echo "    Absent: ${absent_markers[*]}"
    fi
done

echo ""
echo "─────────────────────────────────────────────────────"
echo "Summary: $skip_count SKIP, $eval_count EVALUATE, $missing_count MISSING"
echo ""
if [[ $eval_count -eq 0 && $missing_count -eq 0 ]]; then
    echo "All overrides still needed. No manual evaluation required."
elif [[ $skip_count -gt 0 ]]; then
    echo "Overrides marked SKIP can be reapplied without evaluation."
    echo "Overrides marked EVALUATE need manual diff review (see plugin-override-guidebook.md)."
fi
