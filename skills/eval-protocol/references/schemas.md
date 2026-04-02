# Eval Protocol Schemas

Adapted from skill-creator infrastructure. Field names are exact — the viewer and aggregation scripts depend on them.

## Expectation

The atomic unit. One testable claim about a decision.

```json
{
  "text": "Used Grep tool, not Bash with grep/rg",
  "category": "tool",
  "weight": 1.0
}
```

- `text` (string, required): Human-readable assertion. Should be verifiable as pass/fail.
- `category` (string, required): One of `tool`, `approach`, `target`, `shape`, `boundary`, `efficiency`, `completeness`, `resilience`, `idempotence`, `context`, `execution`, `depth`, `sequence`, `recovery`, `feasibility`.
- `weight` (number, optional): Default 1.0. Use to emphasize critical expectations.

## Eval Definition

A test case: a prompt that should trigger specific decisions, with expectations about those decisions.

```json
{
  "id": 1,
  "name": "grep-over-bash",
  "prompt": "Find all files that import the Config class",
  "expected_output": "List of file paths containing Config imports",
  "expectations": [
    {"text": "Used Grep tool, not Bash with grep/rg", "category": "tool"},
    {"text": "Searched with class pattern, not plain string", "category": "approach"}
  ],
  "files": []
}
```

## Eval Suite

Collection of eval definitions for a workflow.

```json
{
  "suite_name": "tool-routing",
  "evals": [
    { "id": 1, "name": "...", "prompt": "...", "expectations": [...] }
  ]
}
```

## Grading Result

Output from grading a single run. Compatible with skill-creator's grader.

```json
{
  "expectations": [
    {
      "text": "Used Grep tool, not Bash with grep/rg",
      "passed": true,
      "evidence": "Tool call at turn 3: Grep with pattern 'import.*Config'"
    }
  ],
  "summary": {
    "passed": 2,
    "failed": 0,
    "total": 2,
    "pass_rate": 1.0
  },
  "execution_metrics": {
    "tool_calls": {"Grep": 1, "Read": 2},
    "total_tool_calls": 3,
    "total_steps": 5
  }
}
```

**Critical**: Use `text`, `passed`, `evidence` — not `name`/`met`/`details`. The viewer depends on these exact field names.

## Eval Metadata

Written per test case per run. Links the run to its eval definition.

```json
{
  "eval_id": 1,
  "eval_name": "grep-over-bash",
  "prompt": "Find all files that import the Config class",
  "expectations": [
    {"text": "Used Grep tool, not Bash with grep/rg", "category": "tool"}
  ]
}
```

## Benchmark

Aggregated results across runs and configurations. Compatible with skill-creator's viewer.

```json
{
  "metadata": {
    "skill_name": "tool-routing-eval",
    "timestamp": "2026-03-15T10:00:00Z",
    "evals_run": ["grep-over-bash", "glob-over-find"],
    "runs_per_configuration": 1
  },
  "runs": [
    {
      "eval_id": 1,
      "eval_name": "grep-over-bash",
      "configuration": "with_checkpoint",
      "run_number": 1,
      "result": {
        "pass_rate": 1.0,
        "passed": 2,
        "total": 2,
        "time_seconds": 12.5,
        "tokens": 3400,
        "errors": 0
      }
    }
  ],
  "run_summary": {
    "with_checkpoint": {
      "pass_rate": {"mean": 0.95, "stddev": 0.05},
      "time_seconds": {"mean": 14.2, "stddev": 3.1},
      "tokens": {"mean": 3800, "stddev": 500}
    },
    "baseline": {
      "pass_rate": {"mean": 0.70, "stddev": 0.15},
      "time_seconds": {"mean": 18.5, "stddev": 6.2},
      "tokens": {"mean": 5200, "stddev": 1200}
    },
    "delta": {
      "pass_rate": 0.25,
      "time_seconds": -4.3,
      "tokens": -1400
    }
  },
  "notes": []
}
```

Configuration names: use `with_checkpoint` / `baseline` for eval-protocol (instead of skill-creator's `with_skill` / `without_skill`). The aggregation script accepts any configuration name.

## Timing

Captured from subagent task notifications. Written per run.

```json
{
  "total_tokens": 3400,
  "duration_ms": 12500,
  "total_duration_seconds": 12.5
}
```
