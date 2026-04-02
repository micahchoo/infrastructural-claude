#!/usr/bin/env python3
"""Run description optimization loops on all skills with eval sets.

For each skill that has an eval set in eval-sets/, runs the run_loop.py
optimization. Parses results from stderr (where run_loop prints verbose output)
and from the results directory. Resumable — skips skills with existing results.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

WORKSPACE = Path(__file__).parent
EVAL_SETS_DIR = WORKSPACE / "eval-sets"
RESULTS_DIR = WORKSPACE / "results"
LOGS_DIR = WORKSPACE / "logs"
SKILLS_DIR = Path(os.path.expanduser("~/.claude/skills"))
RUNNER_DIR = Path(os.path.expanduser(
    "~/.claude/plugins/cache/claude-plugins-official/skill-creator/614a283a7087/skills/skill-creator"
))

RESULTS_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)


def parse_run_loop_output(stderr: str, stdout: str) -> dict | None:
    """Extract results from run_loop's verbose output.

    run_loop prints to stderr (verbose mode) and may output JSON to stdout.
    We parse both to find: best_score, original description scores, exit reason,
    and the best description from the history.
    """
    combined = stderr + "\n" + stdout

    # Try stdout JSON first (run_loop outputs final JSON there)
    for line in stdout.strip().split("\n"):
        line = line.strip()
        if line.startswith("{"):
            try:
                data = json.loads(line)
                if "best_description" in data:
                    return data
            except json.JSONDecodeError:
                continue

    # Try finding JSON block in stdout
    try:
        brace_start = stdout.rfind("\n{")
        if brace_start >= 0:
            data = json.loads(stdout[brace_start:])
            if "best_description" in data:
                return data
    except (json.JSONDecodeError, ValueError):
        pass

    # Parse stderr for scores
    # Format: "Train: 11/12 correct, precision=86% recall=100% accuracy=92%"
    # Format: "Best score: 4/8 (iteration 1)"
    # Format: "Exit reason: max_iterations (3)"
    best_match = re.search(r'Best score:\s*(\d+)/(\d+)\s*\(iteration\s*(\d+)\)', combined)
    exit_match = re.search(r'Exit reason:\s*(.+)', combined)

    # Extract all iteration scores from Train lines
    train_scores = re.findall(r'Train:\s*(\d+)/(\d+)\s+correct', combined)

    if best_match:
        best_passed = int(best_match.group(1))
        best_total = int(best_match.group(2))
        best_iter = int(best_match.group(3))
        best_score = best_passed / best_total if best_total > 0 else 0

        # Get iteration 1 score as original
        original_score = None
        if train_scores:
            orig_passed, orig_total = int(train_scores[0][0]), int(train_scores[0][1])
            original_score = orig_passed / orig_total if orig_total > 0 else 0

        return {
            "best_score": best_score,
            "best_passed": best_passed,
            "best_total": best_total,
            "best_iteration": best_iter,
            "original_score": original_score,
            "exit_reason": exit_match.group(1).strip() if exit_match else "unknown",
            "iterations": len(train_scores),
        }

    return None


def run_optimization(skill_name: str, eval_set_path: Path, model: str, max_iterations: int = 5) -> dict | None:
    """Run the optimization loop for a single skill."""
    skill_path = SKILLS_DIR / skill_name
    log_path = LOGS_DIR / f"{skill_name}.log"
    result_path = RESULTS_DIR / f"{skill_name}.json"
    skill_results_dir = RESULTS_DIR / skill_name

    cmd = [
        sys.executable, "-m", "scripts.run_loop",
        "--eval-set", str(eval_set_path),
        "--skill-path", str(skill_path),
        "--model", model,
        "--max-iterations", str(max_iterations),
        "--runs-per-query", "2",
        "--verbose",
        "--results-dir", str(skill_results_dir),
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True, text=True,
            timeout=600,  # 10 min per skill
            cwd=str(RUNNER_DIR),
        )

        # Write log
        with open(log_path, "w") as log_f:
            log_f.write(f"=== STDOUT ===\n{result.stdout}\n")
            log_f.write(f"=== STDERR ===\n{result.stderr}\n")
            log_f.write(f"=== RETURN CODE: {result.returncode} ===\n")

        # Parse results from both stdout and stderr
        data = parse_run_loop_output(result.stderr, result.stdout)

        if data:
            with open(result_path, "w") as f:
                json.dump(data, f, indent=2)
            return data

        if result.returncode != 0:
            print(f"  FAILED (rc={result.returncode})", file=sys.stderr)
        else:
            print(f"  WARNING: No parseable result in output", file=sys.stderr)
        return None

    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT (>600s)", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return None


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else "claude-sonnet-4-6"
    apply_results = "--apply" in sys.argv
    max_iterations = 3

    for arg in sys.argv:
        if arg.startswith("--max-iterations="):
            max_iterations = int(arg.split("=")[1])

    print(f"Model: {model}, Max iterations: {max_iterations}, Apply: {apply_results}")
    print(f"Runner dir: {RUNNER_DIR}")
    print()

    # Find all eval sets
    eval_sets = sorted(EVAL_SETS_DIR.glob("*.json"))
    print(f"Found {len(eval_sets)} eval sets")

    results_summary = []
    completed = 0
    skipped = 0
    failed = 0

    for eval_set_path in eval_sets:
        skill_name = eval_set_path.stem
        result_path = RESULTS_DIR / f"{skill_name}.json"

        if result_path.exists():
            print(f"SKIP {skill_name} (result exists)")
            with open(result_path) as f:
                data = json.loads(f.read())
            results_summary.append({"skill": skill_name, "status": "cached", **data})
            skipped += 1
            continue

        print(f"OPTIMIZING {skill_name}...", end=" ", flush=True)
        data = run_optimization(skill_name, eval_set_path, model, max_iterations)

        if data:
            score = data.get("best_score", 0)
            orig = data.get("original_score")
            delta = f" (delta: {score - orig:+.0%})" if orig is not None else ""
            print(f"score={score:.0%}{delta} [{data.get('exit_reason', '?')}]")
            results_summary.append({"skill": skill_name, "status": "optimized", **data})
            completed += 1
        else:
            print("FAILED")
            results_summary.append({"skill": skill_name, "status": "failed"})
            failed += 1

    # Write summary
    summary_path = WORKSPACE / "optimization-summary.json"
    with open(summary_path, "w") as f:
        json.dump({
            "model": model,
            "max_iterations": max_iterations,
            "completed": completed,
            "skipped": skipped,
            "failed": failed,
            "results": results_summary,
        }, f, indent=2)
    print(f"\nSummary written to {summary_path}")
    print(f"Completed: {completed}, Skipped: {skipped}, Failed: {failed}")

    # Show results table
    if results_summary:
        print(f"\n{'Skill':<35} {'Status':<10} {'Original':>8} {'Best':>8} {'Delta':>8}")
        print("-" * 75)
        for entry in sorted(results_summary, key=lambda x: x.get("best_score", 0)):
            s = entry["skill"][:34]
            status = entry["status"]
            orig = entry.get("original_score")
            best = entry.get("best_score")
            orig_s = f"{orig:.0%}" if orig is not None else "—"
            best_s = f"{best:.0%}" if best is not None else "—"
            delta_s = f"{best - orig:+.0%}" if orig is not None and best is not None else "—"
            print(f"{s:<35} {status:<10} {orig_s:>8} {best_s:>8} {delta_s:>8}")


if __name__ == "__main__":
    main()
