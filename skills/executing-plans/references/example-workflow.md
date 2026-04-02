# Subagent Mode Example Workflow

```
You: I'm using executing-plans (Subagent Mode) to execute this plan.

[ENTRY GATE]
[Invoke hybrid-research on modules the plan touches]
  → Mapped: src/hooks/, src/config/, src/cli/ — identified 4 integration points
[Invoke characterization-testing on those code paths]
  → 6 characterization tests written and passing

[Read plan file once: docs/superpowers/plans/feature-plan.md]
[Extract all 5 tasks with full text and context]
[Create TodoWrite with all tasks]

Task 1: Hook installation script

[Get Task 1 text and context (already extracted)]
[Dispatch implementation subagent with full task text + context]

Implementer: "Before I begin - should the hook be installed at user or system level?"

You: "User level (~/.config/superpowers/hooks/)"

Implementer: "Got it. Implementing now..."
[Later] Implementer:
  - Implemented install-hook command
  - Added tests, 5/5 passing
  - Self-review: Found I missed --force flag, added it
  - Committed

[Dispatch spec compliance reviewer]
Spec reviewer: ✅ Spec compliant - all requirements met, nothing extra

[Get git SHAs, dispatch code quality reviewer]
Code reviewer: Strengths: Good test coverage, clean. Issues: None. Approved.

[Mark Task 1 complete]

Task 2: Recovery modes

[Get Task 2 text and context (already extracted)]
[Dispatch implementation subagent with full task text + context]

Implementer: [No questions, proceeds]
Implementer:
  - Added verify/repair modes
  - 8/8 tests passing
  - Self-review: All good
  - Committed

[Dispatch spec compliance reviewer]
Spec reviewer: ❌ Issues:
  - Missing: Progress reporting (spec says "report every 100 items")
  - Extra: Added --json flag (not requested)

[Implementer fixes issues]
Implementer: Removed --json flag, added progress reporting

[Spec reviewer reviews again]
Spec reviewer: ✅ Spec compliant now

[Dispatch code quality reviewer]
Code reviewer: Strengths: Solid. Issues (Important): Magic number (100)

[Implementer fixes]
Implementer: Extracted PROGRESS_INTERVAL constant

[Code reviewer reviews again]
Code reviewer: ✅ Approved

[Mark Task 2 complete]

...

[After all tasks]

[PRE-COMPLETION GATE]
[Fresh hybrid-research: wiring analysis of modified codebase]
  → Traced inter-component connections: hooks → config → CLI pipeline intact
  → End-to-end flow: install command → hook registration → verification — mostly wired
  → Gap found: config module exports hook paths but CLI doesn't import them — uses hardcoded paths
  → Wiring spec produced: current state + end state + 1 gap (CLI→config path binding)
[Build missing wiring]
  → Gap is small (one import + replace hardcoded path with config lookup)
  → TDD: wrote test for CLI using config-provided paths, implemented, passing
[Fresh characterization-testing: wiring validation]
  → Original 6 characterization tests: 5/6 pass, 1 failure expected (hook format changed per plan)
  → 3 new wiring tests: install→register→verify end-to-end, config→hook boundary, CLI→config path binding
  → All pass

[Dispatch final code-reviewer]
Final reviewer: All requirements met, wiring spec confirms architecture, ready to merge

Done!
```
