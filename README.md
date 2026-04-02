# How This `.claude` Got This Way

This is a Claude Code configuration directory that grew from a vanilla install into a layered system of 45 skills, 48 hooks, 10 pipelines, and three persistence layers. It was built by one person over many sessions, mostly by experimenting and then figuring out how the experiments relate.

If you use Claude Code and know what `CLAUDE.md`, `settings.json`, and hooks are, this document explains what's here and why.

## The Problem: Siloed Knowledge

Claude Code gives you powerful primitives out of the box. You can write a `CLAUDE.md` that shapes behavior. You can install plugins that add skills. You can write hooks that fire before and after tool calls. You can configure MCP servers that give the model access to external systems.

But these primitives don't talk to each other.

A skill fires, does its work, and leaves no trace. The next skill starts from scratch. A hook runs but has no idea what skill is active or what the session is trying to accomplish. Knowledge you painstakingly encoded in one skill stays trapped there — invisible to every other skill, every hook, every future session.

This works fine when you have five skills and a couple of hooks. It stops working when you have thirty skills, hooks that need to coordinate, and sessions that build on work from previous sessions. At that scale, siloed knowledge isn't just inefficient — it actively causes problems. Skills give contradictory advice because they can't see each other's constraints. The same failure happens in three consecutive sessions because there's no memory of the first. You spend more time re-establishing context than doing work.

Everything here is an attempt to solve that.

## The Experiments

None of this was designed top-down. It grew from individual experiments, each trying to solve a specific problem I kept hitting. Here's what those experiments were, roughly grouped by what they were trying to fix.

### Making skills smarter about the world

- **Domain codebooks** — I was tired of skills giving generic architectural advice. So I extracted patterns from 24 reference codebases (tldraw, Excalidraw, Immich, penpot, Graphite, krita, etc.) and organized them into codebooks by *force cluster* — the competing forces that produce spaghetti when unresolved. A force cluster is something like "undo needs to capture state, but CRDTs need to merge state, and these two requirements fight each other." When you name the cluster, you can document the known resolution patterns instead of letting the agent reason from first principles every time. 24 domains now: distributed state/sync, undo/redo, gesture disambiguation, CRDTs, rendering pipelines, focus management, optimistic UI/rollback, text editing, constraint solving, schema evolution, embeddability, hierarchical composition, node graph evaluation, annotation systems, and more. The `pattern-extraction-pipeline` skill is the methodology for building these — it has four modes: extraction (new codebooks), audit (grade existing ones), enrichment (add production examples from new repos), and de-factoring (remove patterns to discover what forces they actually resolve).

- **Characterization testing** — The inverse of TDD. Instead of "write a test for what the code should do," it's "write a test for what the code actually does." The distinguishing test: do you know what the assertion should be? If yes, use TDD. If no, use this. Started as a way to build safety nets before modifying unfamiliar code, turned into an architectural probe for mapping unknown territory. Pairs naturally with seam identification — find the joints, then characterize what happens at each one.

- **Seam identification** — Maps the architectural joints of unfamiliar codebases: where behavior can be altered without editing surrounding code. Produces a seam map showing dependency structure, coupling topology, and which code is structural vs incidental. The distinguishing test vs pattern-extraction-pipeline: do you want to understand the *shape* of a codebase (this), or extract *reusable patterns* from it (that)?

- **Shadow walk** — Traces what users actually experience through code. Not a code review — a UX audit from the code's perspective. "What does the user see when they click this?" followed through every layer. Triggered by brainstorming (single flow), systematic-debugging (single file), characterization-testing (signal cluster), executing-plans (component boundary), or requesting-code-review (regression check). Major/critical findings get tracked as seeds issues with a `ux-gap` label.

- **System design reference** — A reference library covering networking, databases, distributed systems, architectural patterns, and real-world case studies across 5 chapters and 14 reference files. Not a skill that does work — a knowledge base that other skills can draw from when discussing architecture, infrastructure decisions, database selection, or scaling strategies.

### Measuring whether things actually help

- **Autoresearch** — The question that started it: do skills actually make Claude Code produce better output, or do they just cost tokens? Built an A/B testing framework that uses real git commits from 24 repos as test fixtures. Each commit encodes a known problem and solution — the diff is the answer key. Two Claude Code variants (with and without skills) run against the same problem, and their outputs are graded against the actual diff.

  The framework introduced a metaphor that governs everything: **the Loom and the Cloth**. The Loom is the `.claude` system itself — skills, hooks, scripts, settings. The Cloth is what the agent actually produces — the designs, diagnoses, code, and tests. Autoresearch edits the Loom but measures the Cloth. A beautiful Loom that weaves the same Cloth as no Loom is a vanity project.

  The manifesto was not written then tested — it was tested then written. Every principle survived a falsification loop: state a claim, design an experiment that can disprove it (not confirm it), run at least 3 orthogonal tests across different repos and task types, rewrite or kill claims that fail. The noise-filter claim didn't get a footnote when it failed — it got split into "ambient vs authoritative guidance" because the experiment revealed a boundary the original claim missed. 10 claims were tested; all 10 survived but several were rewritten based on what the tests revealed.

  Key findings from the evidence table:
  - Skills differentiate on complex tasks (Tier 3): 5/5 vs 4/5 on sync diagnosis, 5/6 vs 3/6 on Immich API testing
  - Skills don't differentiate on simple tasks (Tier 1): 4/5 vs 4/5 tie on excalidraw keyboard shortcut fix
  - Skilled template never degrades quality across 8 non-timeout comparisons
  - Skilled template uses 53% fewer tool calls for equivalent output (42 vs 90 on tldraw)
  - The grader correctly scores decisions not prose: eloquent wrong answers got 0-2, terse correct answers got 3-4 across 3 tests
  - Grader stability requires observable criteria: vague criteria got 67% agreement, observable criteria got 100%
  - The weakest skill in a pipeline bottlenecks the whole pipeline: excellent+mediocre scored 3/8, excellent+excellent scored 7/8
  - Diagnostic questions improve output: with-questions scores of 4/5, 3/4, 4/4 vs without-questions scores of 2/5, 2/4, 1/4

  A critical discovery about skill routing: when guidance is *ambient* (background context), the agent filters well — tangled guidance produced the same output, just cost 2x tokens. But when guidance is *authoritative* (presented as instructions), the agent follows it even when it's wrong. Worktree setup guidance made the agent add git worktree isolation for editing 3 markdown files. This means skill routing (knowing when NOT to fire) matters as much as skill content.

  The infrastructure is deliberately simple: the commit harvester is `git log | grep | jq`, the A/B runner is two parallel `claude --print` calls, the grader is one agent with a fixed prompt template, results are one JSONL line per comparison. Token cost is tracked as data, not just a tiebreaker — over time it reveals which skills add cost without adding score.

  Three pre-configured variants for testing: `all-active` (full skill tree), `baseline` (no skills, no lookups, no context-mode — standard Claude Code), `lookups-only` (library lookups enabled, skills disabled), `context-only` (context-mode plugin, skills disabled). Each variant is a `.claude/` directory with its own `settings.json` and `CLAUDE.md`, swapped via `CLAUDE_CONFIG_DIR`.

- **Eval protocol** — Decision-quality checkpoints at workflow phase transitions. Not "did the code work?" but "did the agent choose the right tool, the right approach, the right research target?" Three primitives: expect (define what should happen), capture (record what actually happened), grade (compare). These checkpoints are embedded as `[eval:]` tags throughout skills — 180+ of them. Concrete examples from `executing-plans`:
  - `[eval: safety-net]` — Characterization tests exist and pass for all modules the plan modifies
  - `[eval: pivot-or-persist]` — When friction was encountered, a deliberate continue/pivot decision was made with stated rationale — not silent persistence
  - `[eval: propagation]` — After completing each task: did this reveal anything that changes the approach for remaining tasks? Learning without updating is drift
  - `[eval: assumption-check]` — At each review gate, revisit key assumptions. If any have been invalidated by implementation evidence, flag before proceeding
  - `[eval: no-rediscovery]` — Context init consumed handoff Knowledge State — searches used productive tiers, gaps were addressed upfront
  - `[eval: efficiency]` — Orchestrator did not use Read/Grep/Bash(cat) on any file the subagent created or modified

- **Quality linter** — Evaluates a project's tests, linter rules, and formatter configs as a unified system. The insight: QA infrastructure signals (lint configs, suppressions, CI gates) reveal *team contracts* — what the team actually enforces vs what they aspire to. This is useful beyond quality assessment; it feeds into any brownfield onboarding. Two modes: Evaluate (brownfield deep analysis of existing test/linter/formatter quality) and Design (greenfield or post-Evaluate QA architecture). Went through three experiment iterations in `archive/experiments/quality-linter/` before landing on a design that produced +44pp greenfield and +45pp brownfield improvements — seam-first scaffolding and grounding annotations drove the greenfield gains.

- **Measure-leverage scorecard** — A shell script (`measure-leverage.sh`) that checks 10 high-leverage infrastructure metrics, each using the most specific check possible to avoid false positives:
  - M1: Router recall — tests prompts against actual SKILL.md description text (not hardcoded keywords), checks if >=2 content words appear
  - M2: Deprecated references — counts deprecated skill names in active files (excluding deliberate DEPRECATED stubs)
  - M3: Skill resolution — tests empirically whether standalone overrides contain their unique marker strings AND the plugin version doesn't
  - M4: Cache atomicity — `atomic mv` instead of `tee` for `/tmp/` cache writes
  - M5: jq guards — all scripts that parse JSON have error handling
  - M6: Context pressure — PreCompact hook exists and fires
  - M7: Brainstorm gate — writing-plans has Input Validation section
  - M8: Memory TTL — all memory files have `last-verified` + `ttl-days` fields
  - M9: Settings backup — rotating backup with contamination detection
  - M10: Portable stat — zero GNU-only constructs (BSD fallbacks added)

  The initial commit scored 10/10 on this scorecard, which tells you something about when things got serious about measurement.

### Persistence and memory across sessions

- **Mulch** — Structured expertise records in JSONL that accumulate across sessions and live in git. Six record types: convention, pattern, failure, decision, reference, guide. Each record carries a classification (foundational, tactical, operational, observational), and tags from a taxonomy namespace system (scope, assumption, source, lifecycle, etc.). Organized by domain — six here: hooks, skills, infrastructure, agents-dream, agents-gate-enforcer, agents-record-extractor. When you make a decision, mulch records why, what it rules out, and what assumptions it rests on — so the next session can `ml search "scope:<module>"` and find prior art instead of re-deriving from first principles. Outcome tracking closes the loop: `ml outcome <domain> <id> --status success/failure` records whether a decision actually worked.

- **Seeds** — Git-native issue tracking in JSONL. Issues live in `.seeds/` and are tracked in git alongside the code. DAG-aware scheduling (`sd ready` returns unblocked work sorted by priority, `sd next` picks the highest-priority unblocked task), atomic task claiming for multi-agent workflows (`sd claim` sets in_progress + assignee, fails if already claimed), priority sorting, dependency wiring (`--blocked-by`). Two instances in this repo: main (skill tree work) and autoresearch (experiment tasks) — each subsystem tracks its own work. Templates (`sd tpl pour`) scaffold recurring workflows like codebook enrichment cycles.

- **Handoff structure** — Session continuity protocol. When context window usage gets critical — specifically, when PreCompact fires (the most reliable signal, no percentage guessing) — a `HANDOFF.md` gets written so a fresh session can resume where the last one left off. The `check-handoff` skill reads it on startup, validates referenced files still exist, summarizes state, and proposes a session plan. Before writing a handoff, the system runs assumption checks against mulch, README seam checks, and seeds cross-references — cleaning up loose ends before handing off.

- **Memory system** — Claude Code's built-in auto-memory (`projects/.../memory/`), but with structure. Four types: user (role, goals, preferences), feedback (corrections and confirmations — both what to avoid AND what worked), project (ongoing work context with absolute dates), and reference (pointers to external systems). Memory files have YAML frontmatter with name, description, and type. An index (`MEMORY.md`) keeps it navigable. A `check-memory-freshness.sh` SessionStart hook warns about stale memories so they don't become trusted lies.

- **Documentation freshness checks** — A pipeline that wires doc-producing skills to mulch and seeds. When a skill generates documentation, the pipeline tracks what was produced and when. A deterministic freshness checker (`context-freshness-hashes`) detects when indexed documentation drifts from its source, creating issues for updates rather than silently serving stale docs.

### Automation and reactivity

- **Hooks system** — 48 hooks across 6 event types: SessionStart (prime context on startup), PreToolUse (inject guidance before a tool fires), PostToolUse (capture outcomes after), UserPromptSubmit (enhance user prompts), PreCompact (save state before context compression), TaskCompleted. Each script is stateless — state lives in `.mulch/` and `.seeds/`, not in the scripts. The scripts don't call each other directly, but share state through `/tmp/` caches and `anti-pattern-report.txt`. All hooks must be idempotent and respect the timeouts configured in `settings.json`.

- **Session start priming** — When a session begins, a cascade of 18 SessionStart hooks fires (nested in 3 top-level settings.json entries). The ordering matters because async hooks can race:
  - `codebase-analytics.sh` (sync, runs first) — produces a compact codebase snapshot (~100-140 lines, ~1200 tokens) covering languages, structure, symbols, churn, largest files, recent commits, working changes, branches, tech debt markers, QA infrastructure, and archetype signals. Detects monorepo sub-packages. Cached per git state for 5 minutes.
  - `seeds-session-inject.sh` — loads issue context, summarizes ready/blocked work count
  - `check-memory-freshness.sh` — warns about stale memories by checking `last-verified` and `ttl-days` fields
  - `check-plugin-overrides.sh` — detects plugin version drift since last sync, warns if overrides may need re-applying
  - `observability-scan.sh` — runs 5 detection classes (dead references, orphaned scripts, stale infrastructure, dual-instance conflicts, untested core scripts) against the three principles
  - `claude-md-nudge.sh` — detects missing or stale project-level CLAUDE.md and emits guidelines
  - `anti-pattern-summary.sh` — surfaces anti-pattern scan counts from the cached report
  - `backup-settings.sh` — snapshots `settings.json` on start, detects mid-session mutation using autoresearch's guard/restore pattern
  - `readme-seam-check.sh` — compares README claims against codebase ground truth (follows the measure-leverage scorecard pattern: quiet on success)
  - `apply-file-overrides.sh` — copies local file-level overrides into plugin cache
  - `override-audit.sh` — detects plugin override version drift
  - `rules-scaffold.sh` — scaffolds `.claude/rules/` from project signals (idempotent)
  - `dream-trigger-hook.sh` — counts accumulated signal and offers /dream when thresholds met

- **Prompt enhancer** — A UserPromptSubmit hook that uses Haiku (claude-haiku-4-5) to bridge the gap between raw codebase analytics and user intent. The value proposition: things a small model can derive cheaply that would cost the large model multiple tool calls — intent-to-file mapping, relevance filtering, change connection.

  Five gates prevent wasteful invocations:
  1. **Too short** — skip if the user message is trivially brief
  2. **Acknowledgments** — skip for simple responses ("ok", "thanks", "yes")
  3. **Slash commands** — skip for skill invocations (they have their own context)
  4. **Cooldown** — 120-second minimum between invocations to avoid token burn
  5. **Git repo** — must be inside a git repo (needs analytics to work with)

  When it fires, it feeds Haiku a compressed version of the codebase analytics — only working changes (most valuable for intent mapping), recent commits (intent context), hot files (what's actively being worked), and top-level structure. Haiku has an 8-second timeout via `claude -p`. The enhanced output gets injected as hook context that the main model receives alongside the user's message.

- **Failure journal** — A PostToolUse:Bash hook that silently observes every Bash command's exit status, stderr, and signal patterns. Designed for maximum observability at zero context window cost — it injects nothing during normal operation.

  The classifier is thorough. It categorizes failures across 15+ domains: filesystem (not-found, permission, path-type, disk-full), module resolution (not-found, resolve failures), Python tracebacks (sub-classified into name/value/key/attribute/type/import/index/json-decode/assertion/timeout errors), Node.js runtime errors (runtime, promise, module-system), syntax errors (cross-language), type errors (cross-language), TypeScript compilation, test failures (assertion, mismatch, generic), build failures, git errors (conflict, not-repo, detached, diverged, noop), network errors (connection, DNS, HTTP 5xx, auth, 404, rate-limit), resource exhaustion (memory, file descriptors, disk), and deprecation warnings.

  It also detects retries (same command in last 5 journal entries), extracts the first meaningful error line, and captures `[SNAG]` markers from the model's own output. The journal is capped at 100KB with oldest-half-dropped rotation. Downstream consumers: a checkpoint hook reads the journal at skill boundaries for high-risk skills, and `failure-journal-sweep.sh` (PreCompact) surfaces unresolved errors before context compression.

- **Anti-pattern pipeline** — Three scripts, one pipeline that wasn't designed as a pipeline but grew into one:
  1. `anti-pattern-scan.sh` — detects risk signals by running rule-driven pattern matching against git-tracked source files. Rules are loaded from a rules file, each with a pattern, negative-pattern window, and severity. Results are cached in `anti-pattern-report.txt`.
  2. `anti-pattern-query.sh` — unified query interface with three modes: `scan` (full scan), `summary` (count), `inject` (context slice for a specific skill). The inject mode replaced the former `anti-pattern-hook.sh`.
  3. `anti-pattern-summary.sh` — SessionStart hook that surfaces the finding count as a one-liner

- **Context pressure** — A PreCompact hook. PreCompact fires when the context window is being compacted — the most reliable signal of context pressure, since it's an actual system event rather than a percentage estimate. When it fires, it does three things: warns that context is critical and remaining work should be handed off, checkpoints mulch state (prompts to record any in-flight expertise before context is lost), and checkpoints seeds state (counts in-progress issues and prompts to update them with current status). Then it triggers handoff consideration.

- **Settings backup** — A SessionStart hook that snapshots `settings.json` on start and detects mid-session mutation. Adopts autoresearch's guard/restore pattern: take a snapshot at the beginning, detect if it changes during the session, and flag the change so it can be reviewed rather than silently drifting.

- **Context MCP nudge** — A PreToolUse hook that fires when the model is about to use Read on a reference/doc file or do a web search. It checks whether the target might be served faster by `get_docs()` from indexed library documentation, and if so, nudges toward Context MCP. Prevents redundant web fetches and slow file reads when the answer is already indexed locally.

- **Context MCP post-fetch** — A PostToolUse hook that fires after WebFetch or WebSearch. Evaluates whether the fetched content is worth indexing in Context MCP for future sessions, prompting for `context add` when it finds high-value library documentation that isn't yet indexed.

### Knowledge access

- **Foxhound** — An MCP server that provides unified search across indexed knowledge. Six tiers: patterns (codebooks and reference patterns), references (reference projects and concept queries), projects (studied codebases), ecosystem (dependency docs — unreachable without project names in query), security, and session (context-mode's persistent event DB — never auto-routed, must be explicitly requested). Auto-routes queries to the right tiers based on keywords: "testing" routes to patterns, "excalidraw" routes to projects, "undo/crdt" routes to references+projects.

  Beyond keyword search, foxhound provides project-specific tools: `sync_deps` indexes Cargo/npm dependencies locally, `query_seeds` queries the issue tracker with views (list, ready, blocked, stats), `next_seed` is a DAG-aware scheduler for picking the highest-priority unblocked task, and `claim_seed` atomically claims a task (sets in_progress + assignee, fails if already claimed).

  A `foxhound-nudge.sh` PreToolUse hook fires before research/analysis skills — hybrid-research, pattern-advisor, quality-linter, shadow-walk, seam-identification, strategic-looping, characterization-testing, domain-codebooks, system-design, research-protocol, product-design, and check-handoff — if foxhound hasn't been called in the current session. The nudge isn't aggressive; it's a one-time reminder that indexed knowledge exists.

- **Context MCP** — Targeted library doc lookup when you know which package has the answer. `search_packages` finds it, `get_docs` retrieves it with 2-4 keyword FTS5 queries (not natural language). Required before any API call or import you haven't used in the current session. When a library isn't indexed: `context browse <name>`, then `context add <repo-url>`. Skill and codebook lookups use a special package: `get_docs("claude-skill-tree", "<topic>")`.

- **Context-mode** — A plugin that keeps large command output in a sandbox instead of flooding the context window. The primary tool is `ctx_batch_execute` — one call that runs multiple commands, auto-indexes all output, and searches with multiple queries, replacing what would otherwise be 30+ individual execute calls and 10+ search calls. Went through at least one major iteration (started as SecureContext/zc-ctx, became context-mode). Also provides `ctx_fetch_and_index` for web content and `ctx_execute_file` for running analysis scripts whose output stays in the sandbox.

- **Codebase analytics** — A shell script (`codebase-analytics.sh`, 688 lines) that produces a cached compact snapshot of any codebase. The snapshot covers: languages (via `scc`), directory structure, symbol definitions, file churn (hottest files over 6 months), largest files by extension, recent commits, working changes, branches, tech debt markers (TODO/FIXME/HACK counts per file), QA infrastructure (linters, formatters, hooks, baselines, test topology), and archetype signals (extension dirs, config files, test ratio). ~100-140 lines, ~1200 tokens. Detects monorepo sub-packages and scopes appropriately. Cached per git state (HEAD + dirty hash) for 5 minutes, served from cache on subsequent calls. The cache in `/tmp/codebase-analytics-*` is the shared bus — consumed by `prompt-enhancer.sh`, `anti-pattern-summary.sh`, and `readme-seam-check.sh`.

### Self-governance

- **Cognitive guardrails** — A plugin with 11 bias checks that fire at decision points. Each has a specific trigger condition wired into `CLAUDE.md`:
  - **WYSIATI** — "Before acting on evidence: what's missing?" Fires before decisions based on incomplete data.
  - **Substitution** — "After analysis or plan: did you answer the actual question?" Fires after brainstorming narrows to a recommendation.
  - **Overconfidence** — "When building on factual claims: how do you know?" Fires especially for Claude Code internals where training data goes stale fast.
  - **Reframe** — "When reaching a conclusion: strongest counter-argument?"
  - **Availability** — "After 3+ searches from few source types: what haven't you looked at?"
  - **Conjunction** — "When assessing compound likelihood: narrative vs math?"
  - **Sunk-cost** — "Deep into execution, plan feels locked: would a fresh agent continue?"
  - **Criteria-precommit** — "Before any evaluate/measure loop: have I defined success criteria?" Don't define passing after seeing results.
  - **Pivot-or-persist** — "When encountering friction during execution: am I deciding or drifting?"
  - **Propagation** — "After completing a task in a sequence: did insights update remaining work?"
  - **Operationalize** — "When making an evaluative claim: specific identifiers or vague quality?"

  These started as individual skill experiments and got packaged into a plugin. They're also wired into pipeline gates — the `decision-check` gate fires `wysiati` + `overconfidence` at plan-to-execute transitions and `substitution` at execute-to-verify transitions.

- **Override management** — When the superpowers plugin updates upstream, local skill overrides might conflict. There are currently 15 active overrides that add eval checkpoints, context MCP library lookups, mulching, merged/deprecated skill redirects, and skill-creation customizations. A four-part system manages the lifecycle:
  1. `plugin-override-guidebook.md` — documents the protocol, tracks active overrides with version numbers and what each override adds
  2. `override-audit.sh` — detects version drift and assesses override value (SessionStart)
  3. `override-prefilter.sh` — checks which overrides need re-evaluation after a plugin update
  4. `apply-file-overrides.sh` — copies local overrides into plugin cache (SessionStart)
  5. `override-ctl.sh` + `update-override-version.sh` — manage override lifecycle
  6. A three-verdict protocol resolves each override:

  | Verdict | When | Action |
  |---------|------|--------|
  | **Reapply as-is** | Upstream didn't address what the override fixes | Copy override onto new version unchanged |
  | **Reapply reshaped** | Upstream partially adopted our approach | Hybrid: upstream's new structure + our core improvements |
  | **Drop override** | Upstream now does what our override did, or better | Accept upstream, remove from guidebook |

  Every override stores a `.marketplace-base.md` snapshot of the marketplace version it was built from. This enables 3-way diff at update time: `diff .marketplace-base.md → new-marketplace` (what upstream changed) vs `diff .marketplace-base.md → SKILL.md` (what you changed). Non-overlapping diffs auto-merge; overlapping diffs surface for human review.

- **Observability scan** — A SessionStart health check (`observability-scan.sh`) that runs 5 detection classes against the three principles. Finds: dead references (plans that reference scripts that don't exist), orphaned scripts (scripts not wired in settings.json), stale infrastructure (core scripts with multiple commits but no test files), dual-instance conflicts (multiple `.seeds/` instances that can cause issue tracking confusion), and hook validation issues (silent failures in hook scripts). Currently reporting 6 high findings — 3 dead refs to planned-but-never-written scripts, 1 dual-instance conflict, and 2 untested core autoresearch scripts.

### Orchestration

- **Pipelines** — 10 named pipelines defined in `pipelines.yaml`, each a named sequence of stages:
  - **brainstorm-to-ship** — brainstorming → writing-plans → executing-plans → requesting-code-review
  - **product-to-ship** — product-design → writing-plans → executing-plans → requesting-code-review
  - **override-evaluation** — detect-update → diff → test → verdict → apply
  - **eval-protocol** — expect → capture → grade
  - **skill-creation** — capture-intent → diffusion-decision → interview → write-draft → ...
  - **pattern-extraction** — characterization-testing → domain-codebooks → pattern-extraction-pipeline
  - **architecture-discovery** — seam-identification → characterization-testing → quality-linter → domain-codebooks
  - **session-continuity** — check-handoff → ... → handoff
  - **code-review-loop** — interactive-pr-review → requesting-code-review
  - **deploy** — portainer-deploy → requesting-code-review

  A `pipeline-stage-hook.sh` (PreToolUse) detects when an invoked skill is a pipeline stage, writes state for the status line, and enforces 4 cross-cutting gates:
  1. **context-init** — fires at the first stage of research-type pipelines. Primes mulch/seeds, syncs deps — things that need to happen once per pipeline.
  2. **decision-check** — fires at high-stakes transitions only. Plan-to-execute: fires `wysiati` + `overconfidence` guardrails. Execute-to-verify: fires `substitution`.
  3. **quality-grade** — fires at verify/land stages after implementation. Runs the simplify → eval-protocol chain to grade recommendations before action.
  4. **close-loop** — fires at the last stage of ALL pipelines. Ensures mulch/seeds/eval loops are closed before the pipeline completes.

  Gates are deduplicated via a session-scoped `integration-state.json` file so they fire once per pipeline, not once per skill invocation.

- **Strategic looping** — Plan-execution coherence for multi-step work. When executing plans with 3+ tasks, this skill maintains cross-task learning and quality ratcheting through iterative refinement cycles: tune → measure → compare → decide. The key behavior: after each task, propagate learnings to remaining tasks — don't just execute the plan as originally written.

- **Skill close-loop bus** — `skill-closeloop-hook.sh` is a PostToolUse hook that fires after every skill completion. It knows about 20+ skills and injects skill-specific close-loop actions for each. Examples:
  - After **brainstorming**: record locked decisions in mulch, create seeds issues for deferred work
  - After **executing-plans**: close completed seeds issues with outcome descriptions, create issues for deferred tasks
  - After **handoff**: run assumption checks against mulch, README seam checks, seeds cross-references before writing HANDOFF.md
  - After **shadow-walk**: create seeds issues for major UX findings with `ux-gap` label
  - After **pattern-advisor**: create seeds issues for discovered pattern gaps
  - After **quality-linter**: record force clusters in mulch, create codebook gap issues
  - After **failure-capture**: create seeds issues for unresolved failures, propose candidate anti-pattern rules for generalizable failures
  - After **research-protocol**: record novel findings as mulch reference records

  Each injection fires once per session (tracked via `istate_set/istate_get` helpers) so it doesn't repeat if you invoke the same skill twice. Also includes a failure journal checkpoint component that reads the session's failure journal at skill boundaries for high-risk skills. Wasn't designed as a bus — it grew into the centralized lifecycle hook for all skills.

- **Parallel dispatch** — For independent work streams. When facing 2+ tasks with no shared state or sequential dependencies, dispatch them as concurrent subagents. The key distinction: dispatching-parallel-agents is for concurrent independent investigations; executing-plans is for sequential plan execution with review gates.

## The Infrastructure Frame

When these experiments accumulated, the question became: how do they relate? Some skills referenced each other. Some hooks supported specific skills. Some persistence systems fed back into other experiments. But there was no governing principle — just a growing tangle of "this thing I built talks to that other thing I built."

That's when three principles crystallized. Not as top-down design, but as a way to describe what was already working and identify what wasn't.

### P1: Holistic Integration

No islands. Every skill connects to the tree through cross-references, hook wiring, and pipeline membership. If a skill can't explain how it relates to at least one other skill, it's not pulling its weight.

In practice, this means:
- Skills have explicit **Integration** sections naming upstream and downstream connections. For example, brainstorming names 5 connections: writing-plans (downstream — outputs feed plan creation), product-design (greenfield route), domain-codebooks (force detection when competing forces surface), shadow-walk (single flow trace before committing to a design), and cognitive-guardrails (substitution check after narrowing to a recommendation).
- Hooks fire based on skill context, not just tool names — `skill-context-inject.sh` loads the full skill catalog and pipeline catalog before planning/brainstorming skills so they can route to the right next step. `foxhound-nudge.sh` fires before 12 specific research/analysis skills if foxhound hasn't been called this session.
- Pipelines compose skills into named workflows — `brainstorm-to-ship` chains brainstorming → writing-plans → executing-plans → requesting-code-review, with cross-cutting gates at each transition.

The audit measures P1 across 5 classes: skill-md (cross-references), hooks (wiring), pipelines (membership), memory (behavioral constraints), and claude-md (global routing). A skill scoring P1=2 in cross-references but P1=0 in hooks is effectively P1=0 — the minimum across classes wins.

Currently: most skills score P1=1 in hooks (referenced in scripts but not directly wired in settings.json). The deeply integrated ones — seeds (12 script references, direct wiring), mulch (8 script references), autoresearch (6 script references), skill-creator (direct wiring) — score P1=2 across all classes. 5 skills are referenced in `CLAUDE.md` for global routing: mulch, seeds, autoresearch, cognitive-guardrails, and eval-protocol.

### P2: Closing the Loop

If you can't tell whether something helped, it's superstition. Every skill should have eval checkpoints, measurable outcomes, and feedback mechanisms.

In practice, this means:
- Skills contain `[eval:]` tags — inline checkpoints that mark where a decision should be verified. 180+ of these across the skill tree. The heaviest: `executing-plans` has 19, `brainstorming` has 13, `autoresearch` has 11. These aren't aspirational — they're specific enough to be testable: `[eval: scavenge]` checks whether you looked in the codebase before searching externally; `[eval: breadth]` checks whether you found 3+ candidates from different domains before going deep.
- Autoresearch provides empirical evidence via A/B testing. Evidence tiers rank maturity: tier 0 (static analysis only — cross-refs and checkpoints exist but untested), tier 1 (loom — skill fires in traces but no outcome measurement), tier 2 (output quality measured and attributed to the specific skill), tier 3 (attributed with inter-grader calibration agreement).
- The eval-protocol skill provides expect/capture/grade primitives for checking decisions at phase transitions.
- Mulch records capture decisions with rationale, and outcome tracking (`ml outcome`) closes the feedback loop by recording whether decisions worked.
- The skill close-loop bus ensures every skill completion triggers a check: record what was learned, close or create seeds issues, prompt for mulch expertise recording.

The audit measures P2 with a tier-capped score: no matter how many eval checkpoints a skill has, its P2 score is capped by its evidence tier. Static-only skills (tier 0) cap at P2=1. You need empirical data to reach P2=2. Special cases: if a skill has a `contradiction` flag (it fires reliably but output worsens), P2 is capped at 1 regardless of tier.

Currently: most skills are tier 0. Seven have tier 1 (skill fires in A/B traces): writing-plans (22 runs), shadow-walk (20 runs), characterization-testing (14 runs), executing-plans (11 runs), seam-identification (11 runs), test-driven-development (7 runs), domain-codebooks (4 runs). `userinterface-wiki` has tier 2 with 39 runs and 2 attributed. `gha` and `requesting-code-review` have tier 3 (calibrated), with `weak_injection` flags noting that A/B results from injection-based runs may underestimate their value.

### P3: Baseline Enrichment

The best insights shouldn't be trapped in one skill. Core patterns should diffuse as `[eval:]` checkpoints across related skills, improving the system's baseline even when the originating skill isn't invoked.

The autoresearch manifesto puts it: "Better baseline over individually brilliant skills. A rising tide, not tall spikes." Optimize for the weakest skill's contribution, not the strongest. A system where brainstorming is excellent but writing-plans is mediocre produces mediocre plans. The diagnostic questions that improve every task slightly (opposing goals, producer/consumer assumptions, search before proposing) compound more than a single brilliant skill that improves one task type.

In practice, this means:
- When brainstorming surfaces a principle (like "check existing code before proposing new abstractions"), that principle gets diffused as an `[eval: scavenge]` checkpoint into other skills that face the same decision — writing-plans, hybrid-research, pattern-advisor. The checkpoint fires in those skills whether or not brainstorming was invoked.
- The autoresearch skill's principles about falsification and evidence aren't just in autoresearch — they appear as evaluation criteria in skills that produce claims (quality-linter, pattern-advisor, research-protocol).
- Cognitive guardrails don't just live in the plugin — they're wired into `CLAUDE.md` with specific trigger conditions AND into pipeline gates. The `decision-check` gate fires `wysiati` and `overconfidence` at plan-to-execute transitions in every pipeline. You hit these guardrails even if you've never heard of the cognitive-guardrails skill.
- The failure-capture skill's `[SNAG]` pattern is wired into `CLAUDE.md` as a general habit: "When something goes wrong, surprises you, or doesn't work as expected — emit `[SNAG] brief description` inline." The failure journal hook picks these up alongside Bash errors. The pattern works whether or not failure-capture is invoked.

The audit measures P3 by checking whether a skill's diffusable insights actually appear in related skills. A skill containing a unique insight that exists nowhere else scores P3=0 on that insight. The regression runner checks that diffused checkpoints don't worsen outcomes — a diffused checkpoint that helps brainstorming but hurts writing-plans is a contamination, not an enrichment.

## The Architecture

The current system has 6 layers. Each emerged from experiments becoming infrastructure — not from a designed architecture.

```
L5  ORCHESTRATION    pipelines.yaml — 10 active pipelines, 4 cross-cutting gates
L4  COGNITION        cognitive-guardrails (11 checks), eval-protocol (180+ checkpoints), 3 agents
L3  KNOWLEDGE        foxhound (6 tiers + session) + context MCP (FTS5) — dual search
L2  AUTOMATION       48 hooks across 6 event types, prompt-enhancer (Haiku)
L1  PERSISTENCE      2x seeds, 2x mulch (10 domains), memory files, autoresearch evidence
L0  RUNTIME          settings.json, 11 plugins, MCP servers, permissions
```

### L0: Runtime

The substrate everything else runs on.

- `settings.json` wires hooks to scripts and configures permissions. This is where automation lives — not in CLAUDE.md. The file contains hook definitions mapping event types to shell scripts with timeout configurations.
- 11 plugins: superpowers (skill framework — the foundation for all skills), cognitive-guardrails (bias checks), context-mode (output sandbox), frontend-design (UI generation), code-simplifier (post-implementation cleanup), ralph-loop (recurring task runner), pr-review-toolkit (PR review agents), plugin-dev (plugin development tools), claude-code-setup (automation recommender), plus LSP plugins (TypeScript via typescript-lsp, Python via pyright-lsp) for language intelligence.
- MCP servers: foxhound for unified search across all indexed knowledge.
- Two CLAUDE.md files with different scopes: the global `~/.claude/CLAUDE.md` is loaded in ALL projects and sets behavioral defaults, routing rules for the knowledge infrastructure, cognitive guardrail trigger conditions, and a dictionary of precise terms (pipeline vs stage vs gate vs phase vs wave vs task vs step vs checkpoint — these have exact meanings here). The project-level `.claude/CLAUDE.md` describes this specific repo's structure, conventions, seams, subsystem boundaries, gotchas, and caching topology.

### L1: Persistence

Four systems that give sessions memory:

- **Mulch** — expertise records in `.mulch/expertise/`. Six domains: hooks, skills, infrastructure, agents-dream, agents-gate-enforcer, agents-record-extractor. Each record has a type (convention, decision, failure, etc.), classification (foundational/tactical/operational/observational), and taxonomy tags. Queryable via `ml search`. Records are append-only JSONL — git tracks the history.
- **Seeds** — issue tracking in `.seeds/issues.jsonl`. Two instances: main repo and autoresearch. DAG-aware scheduling, priority sorting, atomic claiming. Cross-referenced via `sd-cross-ref.sh` which queries both global and autoresearch instances.
- **Memory** — auto-memory files in `projects/.../memory/`. User preferences, feedback corrections, project state, external references. Indexed by `MEMORY.md`. Freshness-checked on SessionStart.
- **Evidence** — autoresearch evidence records in `autoresearch/evidence/`. One JSON file per skill (34 total) with empirical tier, attributed cloth scores, loom hit rates, behavioral pattern detection, injection conversion rates, and flags (`contradiction`, `stale_evidence`, `weak_injection`). Built by `build_evidence.py` from raw `results.jsonl`.

### L2: Automation

48 hooks are the connective tissue — they're what make P1 (integration) real at runtime. Settings.json uses nested `hooks` arrays within top-level entries, so 3 top-level SessionStart entries expand to 18 sub-hooks.

Six event types, with actual hook counts:
- **SessionStart** (18 hooks): codebase analytics, seeds priming, mulch priming, memory freshness, plugin override checks (audit + apply-file-overrides + check-plugin-overrides), observability scan, CLAUDE.md nudge, anti-pattern summary, settings backup, README seam check, foxhound health, context freshness, rules scaffold, dream trigger, context-mode init.
- **PreToolUse** (10 hooks): context MCP nudge (on Read/WebSearch/WebFetch), ccstatusline, pipeline stage detection (on Skill), foxhound nudge (on Skill), context-mode routing, subagent preflight (on Agent), rules injection (on Edit/Write), brownfield flow check (on Edit/Write), statusline.
- **PostToolUse** (11 hooks): failure journal (on Bash), context MCP post-fetch (on WebFetch/WebSearch), eval capture (on Skill), skill close-loop bus (on Skill), hookify rule check (on Skill), update-config detection (on Skill), failure journal tool (on Edit/Write/Agent/mcp), edit quality check (on Edit/Write), subagent postflight (on Agent), context turn tracker.
- **UserPromptSubmit** (6 hooks): ccstatusline, context handoff trigger, context usage logger, prompt enhancer (Haiku), statusline.
- **PreCompact** (2 hooks): context pressure warning, failure journal sweep.
- **TaskCompleted** (1 hook): skill close-loop.

Three emergent multiplexers — things that weren't designed as buses but grew into them:
1. **PostToolUse:Skill bus** — eval-capture, skill-closeloop, hookify rule check, and update-config detection all fire on every skill completion. New "after skill finishes" behavior goes here. This is the skill lifecycle bus.
2. **Anti-pattern pipeline** — 3 scripts sharing state through `anti-pattern-report.txt`, functioning as scan → query (3 modes) → summarize.
3. **Caching topology** — scripts share state through `/tmp/` caches. The producer must run before consumers:

   | Cache | Producer | Consumers |
   |-------|----------|-----------|
   | `/tmp/codebase-analytics-*` | `codebase-analytics.sh` (sync) | `anti-pattern-summary.sh`, `readme-seam-check.sh`, `prompt-enhancer.sh` |
   | `anti-pattern-report.txt` | `anti-pattern-scan.sh` (async) | `anti-pattern-query.sh`, `anti-pattern-summary.sh` |
   | `/tmp/enhancer-*` | `prompt-enhancer.sh` | (don't duplicate its file-relevance work) |

   Cache races between async hooks are a real operational concern. The 5-minute TTL and git-state keying help but don't eliminate all races.

### L3: Knowledge

Two search systems, different purposes:

- **Foxhound** — discovery. When you don't know where the answer is. Auto-routes across 6 tiers based on query keywords. Also provides project tools: `sync_deps` (index package dependencies), `query_seeds` (query issue tracker), `next_seed` (DAG-aware scheduler), `claim_seed` (atomic task claim). The default search layer.
- **Context MCP** — targeted lookup. When you know which library. FTS5-indexed package docs with 2-4 keyword queries. Also indexes the skill tree itself as `claude-skill-tree`.

The discriminator: foxhound searches what you haven't seen yet. Context-mode's `ctx_search` searches what you just produced. They're complementary, not competing.

### L4: Cognition

Systems that check the quality of decisions, not just outputs:

- **Cognitive guardrails** — 11 bias interrupts wired into CLAUDE.md with specific trigger conditions and into pipeline gates for automatic enforcement. The `decision-check` gate fires `wysiati` + `overconfidence` at plan-to-execute, `substitution` at execute-to-verify. These fire regardless of which pipeline you're in.
- **Eval protocol** — expect/capture/grade at workflow phase transitions. 180+ `[eval:]` checkpoints across the skill tree. The `quality-grade` pipeline gate runs simplify → eval-protocol to grade recommendations before action at verify/land stages.
- **Agents** — 3 autonomous agents in `agents/`, each with dedicated mulch expertise domains: **dream-agent** (cross-session knowledge consolidation — enrichment, detect-gaps, integrate modes, invoked via `/dream`), **gate-enforcer** (pipeline gate verification — guardrails, quality grading, claim verification, dispatched by skills at gate transitions), **record-extractor** (extract decisions/conventions/failures from skill artifacts at close-loop). Each has principle-pipeline templates in `agents/dream-templates/`.

### L5: Orchestration

Skills composed into workflows:

- **10 pipelines** in `pipelines.yaml` with defined stage sequences and skill mappings.
- **4 cross-cutting gates** enforced by `pipeline-stage-hook.sh`: context-init (research priming), decision-check (bias interrupts), quality-grade (recommendation grading), close-loop (mulch/seeds/eval completion). Deduplicated via session-scoped state file.
- **Strategic looping** for multi-step coherence — cross-task learning and quality ratcheting.
- **Parallel dispatch** for independent work streams — concurrent subagent execution without shared state.

## The Archive

Failed experiments and superseded designs live in `archive/`. Agent journals from parallel dispatch experiments (agents A through J, each testing different aspects: rule architecture, anti-pattern harvesting, hooks integration, resilience and contradiction, assessment adoption, measurement fixtures, test design evaluation, force cluster QA export). Design specs and implementation plans for autoresearch enhancements, foxhound redesign, and evidence tier systems. Research syntheses on quality infrastructure. Fragments from experiments that produced useful byproducts but whose main thesis didn't hold up. The archive is the graveyard — but it's a useful graveyard, because it prevents future sessions from re-testing dead ends.

## Current State

### By the numbers

| Metric | Count |
|--------|-------|
| Skills | 45 |
| Eval checkpoints | 180+ |
| Cross-references between skills | 160+ |
| Hook bindings (total) | 48 |
| Hook scripts | 55 |
| Hook event types | 6 |
| Named pipelines | 10 active + 4 forming/planned |
| Cross-cutting pipeline gates | 4 |
| Agents | 3 |
| Plugins | 11 |
| Mulch domains | 10 (6 main + 4 autoresearch) |
| Seeds instances | 2 |
| Memory files | 7 |
| Autoresearch evidence records | 34 |
| Reference codebases (A/B test fixtures) | 24 |
| Codebook domains | 24 |
| Shell script LOC | ~5,900 |

### Evidence maturity

Most of the system is still at tier 0 — validated by static analysis (cross-references exist, eval checkpoints present) but not empirically tested via A/B runs.

| Tier | Skills | Runs | What it means |
|------|--------|------|---------------|
| 3 (calibrated) | gha, requesting-code-review | 5 | Output quality measured, attributed, calibrated between graders |
| 2 (attributed) | userinterface-wiki | 39 | Output quality measured and attributed to the skill |
| 1 (loom) | writing-plans, executing-plans, shadow-walk, characterization-testing, seam-identification, test-driven-development, domain-codebooks | 7-22 each | Skill fires in traces, no outcome measurement yet |
| 0 (static only) | 26 skills | 0 | No empirical data. Cross-refs and checkpoints exist, untested. |

### Known issues

The observability scan reports 3 high findings:
- 1 dual-instance conflict (2 `.seeds/` instances — main and autoresearch — intentional by design, mitigated by `sd-cross-ref.sh`)
- 2 core autoresearch scripts (`grade.py` at 4 commits, `run_ab.py` at 4 commits) with no test files — core eval infrastructure that's untested by its own standards

### What's honest

This system works well for one person's workflow. It's opinionated. Many experiments are still rough. The autoresearch framework has proven that skills don't make things worse and often make them more efficient — but most individual skills haven't been empirically validated yet. The infrastructure frame (the three principles) is useful primarily as a tool for deciding what to polish next and what to leave alone. The evidence tiers tell you where to trust and where to be skeptical.

The three principles didn't come from reading a book. They came from building too many disconnected things and then needing a vocabulary for "why does this part work and that part doesn't." The frame itself is an experiment. It's just the one that currently makes sense of all the other experiments.
