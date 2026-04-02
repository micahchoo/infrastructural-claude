#!/usr/bin/env python3
"""Generate trigger eval sets for all skills using claude -p.

For each skill, reads the SKILL.md frontmatter and generates 20 realistic
eval queries (10 should-trigger, 10 should-not-trigger) via Claude.

Saves each eval set to eval-sets/<skill-name>.json. Skips skills that
already have an eval set (resumable).
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

SKILLS_DIR = Path(os.path.expanduser("~/.claude/skills"))
EVAL_SETS_DIR = Path(__file__).parent / "eval-sets"
EVAL_SETS_DIR.mkdir(exist_ok=True)

# Skills to skip (meta/stub skills that don't need optimization)
SKIP_SKILLS = {
    "writing-skills",  # stub that suppresses plugin version
}


def extract_frontmatter(skill_path: Path) -> tuple[str, str]:
    """Extract name and description from SKILL.md frontmatter."""
    content = (skill_path / "SKILL.md").read_text()
    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if not m:
        return "", ""
    fm = m.group(1)

    name = ""
    name_match = re.search(r'^name:\s*(.+)', fm, re.MULTILINE)
    if name_match:
        name = name_match.group(1).strip().strip('"\'')

    desc = ""
    desc_match = re.search(r'description:\s*>-?\s*\n((?:\s+.*\n)*)', fm)
    if desc_match:
        desc = re.sub(r'\n\s+', ' ', desc_match.group(1)).strip()
    else:
        desc_match = re.search(r'description:\s*(.+)', fm)
        if desc_match:
            desc = desc_match.group(1).strip().strip('"\'')

    return name, desc


def get_all_skill_names_and_descriptions() -> list[dict]:
    """Get all skill names and descriptions for context."""
    skills = []
    for name in sorted(os.listdir(SKILLS_DIR)):
        skill_path = SKILLS_DIR / name
        if not (skill_path / "SKILL.md").exists():
            continue
        sname, sdesc = extract_frontmatter(skill_path)
        if sname:
            skills.append({"name": sname, "description": sdesc[:200]})
    return skills


def generate_eval_set(skill_name: str, skill_description: str, all_skills: list[dict], model: str) -> list[dict]:
    """Generate eval set for a single skill using claude -p."""
    # Build context about other skills for negative cases
    other_skills = [s for s in all_skills if s["name"] != skill_name]
    other_skills_text = "\n".join(
        f"- {s['name']}: {s['description']}" for s in other_skills[:15]
    )

    prompt = f"""Generate exactly 20 trigger evaluation queries for this Claude Code skill.

SKILL NAME: {skill_name}
SKILL DESCRIPTION: {skill_description}

OTHER SKILLS (for context on what should NOT trigger this skill):
{other_skills_text}

Requirements:
- 10 should-trigger queries (realistic things a user would type that SHOULD activate this skill)
- 10 should-not-trigger queries (near-misses that share keywords but need a DIFFERENT skill or no skill)

Query quality rules:
- Queries must be REALISTIC — things actual developers type in Claude Code
- Include personal context, file paths, company names, casual speech, typos, abbreviations
- Vary length: some terse ("fix the auth bug"), some detailed (2-3 sentences with backstory)
- Should-trigger queries: cover different phrasings of the same intent, uncommon use cases, cases where this skill competes with another but should win
- Should-not-trigger queries: NEAR MISSES that share keywords but actually need something different. NOT obviously irrelevant queries.
- Do NOT make should-not-trigger queries obviously unrelated. They must be genuinely tricky.

Output ONLY a JSON array, no markdown fences, no explanation:
[
  {{"query": "...", "should_trigger": true}},
  {{"query": "...", "should_trigger": false}}
]"""

    try:
        result = subprocess.run(
            ["claude", "-p", "--model", model, "--output-format", "json", prompt],
            capture_output=True, text=True, timeout=120,
            cwd=os.path.expanduser("~")
        )

        if result.returncode != 0:
            print(f"  ERROR: claude -p failed: {result.stderr[:200]}", file=sys.stderr)
            return []

        # Parse the JSON response - extract from claude's output
        output = result.stdout.strip()
        # claude --output-format json wraps in {"result": "..."}
        try:
            wrapper = json.loads(output)
            if isinstance(wrapper, dict) and "result" in wrapper:
                text = wrapper["result"]
            else:
                text = output
        except json.JSONDecodeError:
            text = output

        # Find JSON array in the text
        # Try to find [ ... ] pattern
        bracket_start = text.find("[")
        bracket_end = text.rfind("]")
        if bracket_start >= 0 and bracket_end > bracket_start:
            json_text = text[bracket_start:bracket_end + 1]
            eval_set = json.loads(json_text)
            if isinstance(eval_set, list) and len(eval_set) > 0:
                return eval_set

        print(f"  ERROR: Could not parse eval set from output", file=sys.stderr)
        return []

    except subprocess.TimeoutExpired:
        print(f"  ERROR: Timeout generating eval set", file=sys.stderr)
        return []
    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return []


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else "claude-opus-4-6"
    print(f"Using model: {model}")

    all_skills = get_all_skill_names_and_descriptions()
    print(f"Found {len(all_skills)} skills")

    generated = 0
    skipped = 0
    failed = 0

    for name in sorted(os.listdir(SKILLS_DIR)):
        skill_path = SKILLS_DIR / name
        if not (skill_path / "SKILL.md").exists():
            continue
        if name in SKIP_SKILLS:
            print(f"SKIP {name} (in skip list)")
            skipped += 1
            continue

        eval_file = EVAL_SETS_DIR / f"{name}.json"
        if eval_file.exists():
            print(f"SKIP {name} (eval set exists)")
            skipped += 1
            continue

        sname, sdesc = extract_frontmatter(skill_path)
        if not sdesc or len(sdesc) < 10:
            print(f"SKIP {name} (no/short description)")
            skipped += 1
            continue

        print(f"GENERATING {name}...", end=" ", flush=True)
        eval_set = generate_eval_set(sname, sdesc, all_skills, model)

        if eval_set:
            with open(eval_file, "w") as f:
                json.dump(eval_set, f, indent=2)
            n_trigger = sum(1 for e in eval_set if e.get("should_trigger"))
            n_no = len(eval_set) - n_trigger
            print(f"OK ({n_trigger} trigger, {n_no} no-trigger)")
            generated += 1
        else:
            print("FAILED")
            failed += 1

    print(f"\nDone: {generated} generated, {skipped} skipped, {failed} failed")


if __name__ == "__main__":
    main()
