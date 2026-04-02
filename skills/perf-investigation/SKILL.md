---
name: perf-investigation
description: >-
  Rigorous performance investigation with baselines, profiling, and evidence-backed
  decisions. 10-phase workflow: setup → baseline → breaking-point → constraints →
  hypotheses → code-paths → profiling → optimization → decision → consolidation.
  Triggers: "why is this slow", "performance investigation", "benchmark this",
  "find the bottleneck", "perf regression", "/perf", or when verification-before-completion
  reveals a performance concern. Fills the gap between systematic-debugging (correctness)
  and this skill (speed/throughput/resource usage).
---

# Performance Investigation

Evidence-driven performance analysis. Every claim backed by measurement. Every optimization verified against baseline.

**Core rule:** One variable at a time. No parallel experiments. No unmeasured claims.

## When to Use

- Performance regression detected
- New feature needs performance validation
- System hitting throughput/latency limits
- Pre-release performance certification
- "It feels slow" needs to become "it IS slow because X"

**Not this skill:** Correctness bugs (systematic-debugging), load testing as part of TDD red-team (test-driven-development Level 4).

## The 10 Phases

```
setup → baseline → breaking-point → constraints → hypotheses →
code-paths → profiling → optimization → decision → consolidation
```

Each phase produces artifacts. Skip phases that don't apply, but document why.

Before starting: `ml search "performance"` for prior baselines (if `.mulch/` exists); `sd ready` for related perf issues (if `.seeds/` exists).

---

## Phase 1: Setup

Define the investigation scope.

| Field | Value |
|-------|-------|
| **Scenario** | One-sentence description of what's slow |
| **Success metric** | Concrete target (e.g., "p95 < 200ms", "throughput > 1k rps") |
| **Benchmark command** | The command that produces measurable output |
| **Environment** | OS, hardware, relevant versions |

```bash
mkdir -p .perf/investigations
```

Write setup to `.perf/investigations/<id>-setup.md`.

`[eval: criteria-precommit]` Success metric is concrete and falsifiable before any measurement.

## Phase 2: Baseline

Establish what "now" looks like. This is the number everything else compares to.

**Rules:**
- Minimum 3 runs (use median for high-variance workloads, mean for stable ones)
- Record: min, max, median, p95, stddev
- If stddev > 15% of median → environment is noisy. Increase runs or isolate.
- Warm-up run discarded (first run often includes JIT, cache population, etc.)

```markdown
## Baseline — v<version>
- Command: `<benchmark command>`
- Runs: N (after 1 warm-up)
- Median: Xms | Mean: Xms | p95: Xms
- Stddev: X (Y% of median)
- Timestamp: <ISO>
```

Write to `.perf/baselines/<version>.md`.

`[eval: baseline-stability]` Stddev < 15% of median, or noise explicitly acknowledged with mitigation.

## Phase 3: Breaking Point

Binary-search for the load level where the system degrades or fails.

**Method:**
1. Start with current normal load (param-min)
2. Double until failure/degradation
3. Binary-search between last-good and first-bad
4. Record the threshold

**What "degrades" means:** latency > 2x baseline, error rate > 1%, OOM, timeout, or user-defined threshold from Phase 1.

```
Breaking point: N items/requests/connections
Degradation mode: <what happens — timeout, OOM, error spike>
Headroom from normal: Xx (normal=M, breaking=N)
```

**Skip if:** The investigation is about a specific slow path, not capacity limits.

## Phase 4: Constraints

Run the baseline under resource constraints to surface hidden bottlenecks.

| Constraint | How | What it reveals |
|-----------|-----|-----------------|
| CPU limit | `taskset -c 0` or cgroup | Single-core bottleneck, parallelism assumptions |
| Memory limit | `ulimit -v` or cgroup | Memory-hungry allocations, cache dependency |
| I/O limit | `ionice -c 3` | I/O-bound vs CPU-bound |
| Network limit | `tc qdisc` | Latency sensitivity, retry storms |

Compare constrained performance to baseline. If constraint has < 10% impact → system isn't bottlenecked there.

**Skip if:** You already know the bottleneck class from Phase 3.

## Phase 5: Hypotheses

Generate and rank hypotheses about what's causing the performance issue.

**Sources:**
- Phase 2-4 measurements (what surprised you?)
- `git log --oneline --since="<when it was fast>"` — what changed?
- Architecture knowledge (N+1 queries, unbounded allocations, synchronous I/O)
- If `.mulch/` exists: `ml search "performance failure"` for prior perf issues. If profiling reveals a correctness bug, route to systematic-debugging instead.

**Format each hypothesis:**
```
H1: <statement>
Expected impact: <quantified prediction>
Test: <how to confirm/deny>
Effort: <low/medium/high>
```

Rank by expected-impact × inverse-effort. **Test one at a time.**

`[eval: hypothesis-specificity]` Each hypothesis makes a quantified prediction that measurement can falsify.

## Phase 6: Code Paths

**Before profiling, know where to look.** Static analysis to narrow the profiling scope.

1. Trace the hot path from entry point to the slow operation
2. Identify: allocations, I/O calls, locks, serialization points
3. Mark: "expected hot" vs "should be cold but might not be"

```bash
# Example: find all database calls in the hot path
grep -rn "query\|execute\|fetch" <hot-path-files>
```

This prevents "profile everything and hope" — profiling is expensive, narrowing first is cheap. Use foxhound `search("<framework> performance patterns")` for known perf anti-patterns in your stack.

## Phase 7: Profiling

Instrument the code paths identified in Phase 6.

**Tool selection by stack:**

| Stack | Profiling tool | Visualization |
|-------|---------------|---------------|
| Node.js | `--prof` or `clinic.js` | flamegraph |
| Python | `cProfile` + `snakeviz`, or `py-spy` | flamegraph |
| Rust | `cargo flamegraph` or `perf` | flamegraph |
| Go | `pprof` | flamegraph, top |
| JVM | `async-profiler` | flamegraph |
| General | `perf record` + `perf report` | flamegraph |

**Record:**
- Top 5 hotspots (function, % of total time)
- Allocation hotspots (if memory is a concern)
- I/O wait time vs CPU time ratio

`[eval: hotspot-evidence]` Hotspots identified from profiling data, not guesses.

## Phase 8: Optimization

Change one thing. Measure. Compare to baseline. Consider characterization-testing to capture current behavior as a safety net before optimizing.

**Rules:**
- ONE change per optimization cycle
- Re-run full baseline measurement (same parameters as Phase 2)
- Record: what changed, before, after, delta, delta%
- If delta < measurement noise (stddev from Phase 2) → optimization is not statistically significant

```markdown
## Optimization: <description>
- Change: <what was modified>
- Before: <baseline measurement>
- After: <new measurement>
- Delta: <absolute and %>
- Significant: yes/no (vs baseline stddev)
```

**Do not stack optimizations without measuring each individually.** You need to know which changes actually helped.

`[eval: isolation]` Each optimization measured individually against baseline, not stacked.

## Phase 9: Decision

With evidence from Phases 2-8, decide: continue optimizing, ship, or stop.

| Verdict | When |
|---------|------|
| **Ship** | Success metric from Phase 1 is met |
| **Continue** | Progress is measurable, more headroom exists |
| **Stop** | Diminishing returns, or constraint is external (network, DB, hardware) |

**Format:**
```
Verdict: <ship/continue/stop>
Rationale: <evidence-backed reasoning>
Remaining risk: <what's still uncertain>
```

`[eval: evidence-backed-decision]` Verdict references specific measurements from earlier phases.

## Phase 10: Consolidation

Merge all findings into a durable artifact.

1. **Final baseline**: run full measurement at current state → `.perf/baselines/<new-version>.md`
2. **Investigation report**: summary of all phases → `.perf/investigations/<id>-report.md`
3. **Mulch record** (if `.mulch/` exists):
   ```bash
   ml record <domain> --type pattern \
     --description "Perf: <summary of finding>" \
     --classification foundational \
     --tags "scope:<module>,category:performance,source:perf-investigation"
   ```
4. **Seeds close** (if investigation was tracked):
   ```bash
   sd close <id> --reason "outcome:success — <perf improvement summary>"
   ```

## Quick Reference

| Phase | Artifact | Skip when |
|-------|----------|-----------|
| 1. Setup | `.perf/investigations/<id>-setup.md` | Never |
| 2. Baseline | `.perf/baselines/<version>.md` | Never |
| 3. Breaking point | In investigation report | Specific slow path, not capacity |
| 4. Constraints | In investigation report | Bottleneck class already known |
| 5. Hypotheses | In investigation report | Never |
| 6. Code paths | In investigation report | Obvious single hotspot |
| 7. Profiling | Flamegraph artifacts | Hypothesis is I/O or external |
| 8. Optimization | Per-change measurements | Investigation-only, no fix needed |
| 9. Decision | Verdict in report | Never |
| 10. Consolidation | Baseline + report + mulch | Never |

## Anti-Patterns

| Anti-pattern | Why it's wrong |
|-------------|---------------|
| "I profiled and it's obvious" | Without a baseline, you can't prove the fix helped |
| Stacking 3 optimizations, measuring once | You don't know which one helped |
| "It feels faster" | Feelings aren't measurements |
| Profiling before narrowing code paths | Wasted time in cold code |
| Optimizing without a success metric | No definition of done |
| Comparing against no baseline | Before/after requires a before |

