# Convergence Protocol

Use at integration milestones and before marking a plan complete.

## Steps

1. **Define "done well"** — beyond "tests pass":
   - Code reads clearly to someone who didn't write it
   - Error cases handled, not just happy paths
   - Integration between components feels clean, not forced
   - Acceptance criteria from plan verified with evidence

2. **Measure** — run verification AND read the code with fresh eyes. Automated checks catch functional issues; human-like review catches design issues.

3. **Identify gaps** — two categories:
   - **Functional**: tests failing, missing edge cases, broken integration → fix immediately
   - **Qualitative**: unclear naming, awkward APIs, unnecessary complexity → fix if it affects future tasks, note otherwise

4. **Fix** — route to appropriate skill:
   - Functional → systematic-debugging or test-driven-development
   - Quality → code review loop
   - Integration → focused subagent

5. **Re-measure** — fresh verification. Never assume the fix worked.

6. **Iterate** — until threshold met.

## Caps

- **3 iterations** on the same gap → gap isn't closing incrementally. Reassess approach with user.
- **Each iteration must show measurable progress.** If it doesn't move the needle, the diagnosis is wrong.

## Quality Ratchet

After convergence succeeds, the quality bar becomes the new baseline. If a later task degrades quality below that baseline, treat it as a regression — verify the system still meets the bar, not just that the new task works.

Exception: sometimes a task legitimately requires temporarily loosening a bar (e.g., a workaround to be cleaned up later). Make it explicit and track the cleanup.
