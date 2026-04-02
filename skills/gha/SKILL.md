---
name: gha
description: >-
  Diagnose and root-cause GitHub Actions (GHA) workflow failures. Triggers: GHA run URL,
  "GitHub Actions failed", "CI checks are red", "workflow run failed", "build broke in CI",
  "checks failing on my PR". Disambiguate: "actions" must mean GHA (not task lists),
  "CI" must mean GitHub Actions (not Jenkins/CircleCI/GitLab), "build broke" must be
  a GHA run (not local). NOT for: editing workflow YAML, GitHub Issues, or local test failures.
argument-hint: <url>
---

Investigate this GitHub Actions failure: $ARGUMENTS

Look up CI tools, build systems, and test frameworks via `get_docs` before diagnosing unfamiliar tooling. Check mulch for known CI pitfalls (`mulch search --type failure`) and record new ones with resolutions.

## Workflow

1. **Fetch failure details** via `gh` CLI. Focus on what actually caused exit code 1, not warnings.

2. **Check flakiness** — past 10-20 runs of the specific failing job (not just the workflow). Is it consistently failing or intermittent? When did it last pass?

3. **Find breaking commit** (if pattern of failures) — identify first failing run and last passing run. Verify the commit boundary: does the job fail in all runs after? Pass in all before?

4. **Check for existing fixes** — search open PRs matching error keywords or modified files.

5. **Report**: failure summary, flakiness assessment, breaking commit (with confidence), root cause, existing fix PR if found, recommendation.

`[eval: verify]` Did you run the command and see the output? State the evidence.
`[eval: target]` Root cause in failing code, not test/CI config, unless evidence says otherwise.
`[eval: root-cause]` Before proposing a fix, can you name the source, not just the symptom?
`[eval: execution]` Fix addresses root cause, not symptom.

When root cause is in application code (not CI config), transition to systematic-debugging with the evidence gathered here. If a fix PR exists, offer interactive-pr-review.

## Common GHA Failure Patterns

Watch for these recurring causes — they account for the majority of non-obvious CI breaks:

- **Permission errors**: `GITHUB_TOKEN` lacks required scopes (e.g., `contents: write` for pushing, `packages: write` for registry). Also: `permissions:` block in workflow YAML restricts the default token below what a step needs.
- **Path filter mismatches**: `on.push.paths` / `on.pull_request.paths` excludes files that actually affect the build. Common when a shared utility changes but the filter only watches `src/`.
- **Matrix strategy issues**: A single matrix combination fails while others pass. Check for OS-specific behavior, Node/Python version incompatibilities, or conditional steps that assume a specific matrix value.
- **Action version pinning**: `uses: actions/checkout@v3` breaks when the action releases a breaking change. Pin to SHA (`@<sha>`) for stability. Also: third-party actions disappearing or changing behavior silently.
- **Secret access failures**: Secrets unavailable in PRs from forks (by design). Also: secret names are case-sensitive, environment-scoped secrets require the `environment:` key, and org-level secrets may not propagate to new repos.
- **Runner environment differences**: `ubuntu-latest` resolves to a new image and a system dependency disappears or changes version. Check the runner image changelog. Also: `macos-latest` vs `macos-13` differences in Xcode/Homebrew state.
- **Timeout and concurrency issues**: Jobs hitting the 6-hour limit (or a shorter `timeout-minutes:`). `concurrency:` groups cancelling in-flight runs unexpectedly, especially on force-pushes to the same branch.
- **Cache poisoning / invalidation**: `actions/cache` key mismatch causes a stale cache hit. Symptoms: "works on retry" or "fails only after cache restore." Check `hashFiles()` inputs and restore-keys fallback order.
