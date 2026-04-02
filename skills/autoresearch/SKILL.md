---
name: autoresearch
description: >-
  Audit and gate the skill-tree against three principles: holistic integration,
  closing the loop, and baseline-enrichment. Two modes: audit (full tree scan)
  and gate (post-skill-creator validation). Produces infrastructure-mapped
  recommendations gated by simplify + eval-protocol, with automatic seeds
  issue creation. Triggers: "audit skill tree", "check principles",
  "skill tree health", "autoresearch audit", "/autoresearch", or after
  skill-creator writes a SKILL.md (via PostToolUse hook).
  Do NOT trigger for: running A/B tests directly (run_ab.py, grade.py),
  debugging, code review, or general codebase exploration.
---

# Autoresearch: Skill-Tree Principle Enforcement

Three principles keep the skill tree healthy. Two modes let you enforce them: **audit** (full tree scan) and **gate** (single skill after skill-creator).

## Principles

1. **Holistic Integration (P1):** Skills connect to the tree — cross-references, pipeline wiring, hooks. No islands.
2. **Closing the Loop (P2):** Skills have `[eval:]` checkpoints, measurable outcomes, and feedback mechanisms.
3. **Baseline-Enrichment (P3):** Core insights diffuse as `[eval:]` checkpoints across related skills, improving behavior even when this skill isn't invoked.

## Mode Detection

- **Gate mode:** PostToolUse hook fires after skill-creator writes a SKILL.md. Audit that skill only.
- **Audit mode:** User-triggered ("audit skill tree", "/autoresearch audit"). Scans everything.

## Procedure

### Step 1: Run Multi-Class Analysis

```bash
bash ~/.claude/autoresearch/skill-tree-audit.sh --deep [skill-name]
```

- Gate mode: pass the changed skill name
- Audit mode: no argument (scans all)

Output has 5 classes: `skill-md` (cross-refs + eval checkpoints across SKILL.md and references/), `hooks` (direct wiring + script references), `pipelines` (pipeline membership), `memory` (behavioral constraints), `claude-md` (global routing).

### Step 1.5: Load Evidence Records (Audit Mode Only)

Query mulch first — prior decisions and failures save you from re-running settled experiments:

```bash
ml search "<skill-name> experiment"
ml search "grading calibration"
```

- **Prior decision found:** Skip re-testing. Reference the mulch record ID.
- **Prior failure found:** Check if conditions still apply. Adjust experiment design if so.
- **No results:** Proceed normally.

Then load pre-built evidence from `~/.claude/autoresearch/evidence/`:

```bash
# Rebuild if stale (derived views of results.jsonl)
python3 ~/.claude/autoresearch/build_evidence.py
```

Read `evidence/<skill-name>.json` for each skill. Key fields:

- `empirical.tier` — evidence level (0=static, 1=loom, 1.5=behavioral, 2=attributed cloth, 3=calibrated)
- `empirical.cloth.attributed_mean` — cloth score from isolated runs (null if none)
- `empirical.loom.hit_rate` / `loom_behavioral.hit_rate` — firing reliability
- `empirical.loom_behavioral.injection_conversion` — of injected runs, fraction showing skill patterns
- `empirical.flags` — failure conditions: `contradiction`, `stale_evidence`, `weak_injection`
- `empirical.attributed_runs` — runs where cloth is attributable to this skill
- `static.p1/p2/p3` — cross-ref counts, eval checkpoints, diffusion targets

No evidence record? Treat as tier 0. Don't read raw `results.jsonl` or trace files — `build_evidence.py` has already processed those.

Also run `bash ~/.claude/scripts/observability-scan.sh --quiet` for infrastructure health (orphans, dead refs aren't in evidence records). Skip any component that doesn't exist — these signals supplement static analysis, they don't block it.

### Step 2: Score Through Principles

Score P1/P2/P3 using all five classes from Step 1 plus empirical data from Step 1.5. The scoring is strict on purpose — a skill that looks connected in one dimension but is invisible in another is effectively disconnected.

**P1 (Integration) — scored per class, lowest wins.** The min-across-classes rule matters because a skill that's well cross-referenced but has no hook wiring is still invisible to automation:
- skill-md: refs_out=0 AND refs_in=0 → 0; one direction → 1; both → 2
- hooks: not in any script → 0; in scripts but not settings.json → 1; both → 2
- pipelines: not in any pipeline → 0; in 1 → 1; in 2+ or is a gate → 2
- Empirical override: if traces show a hook fires for this skill but the hooks class says P1=0, trust the trace.
- **Overall P1 = min across classes.**

**P2 (Loop) — tier-capped scoring:**

P2 is capped by the highest evidence tier available for the skill:

| Evidence tier | P2 cap | What it means |
|--------------|--------|---------------|
| 0 (static only) | 1 | No empirical data. Score from eval checkpoint count only. |
| 1 (loom) | 1 | Skill fires but no outcome measurement. |
| 1.5 (behavioral) | 1 | Behavioral patterns detected but not outcome measurement. |
| 2 (attributed cloth) | 2 | Output quality measured and attributed to this skill. |
| 3 (calibrated) | 2 (high confidence) | Attributed cloth with calibration agreement. |

P2 score = min(static_p2_score, tier_cap)

Where static_p2_score is:
- 0: eval_checkpoints=0 AND no evidence data
- 1: eval_checkpoints>0 but no outcome mechanism; OR evidence tier < 2
- 2: eval_checkpoints>0 AND (outcome tracking OR evidence tier >= 2)

Watch for evidence flags:
- `contradiction`: Cap P2 at 1 regardless of tier — the skill fires but output worsens, so the loop isn't actually closing.
- `weak_injection`: Note it in findings but don't cap P2. The skill may work fine via Skill tool invocation even though injection-based A/B tests underestimate it.

**P3 (Enrichment) — static + regression:**
- Score 0: skill contains diffusable insights but no `[eval:]` in related skills; OR regress.py shows this skill's injection worsened outcomes
- Score 1: some diffusion exists; regression data neutral
- Score 2: fully diffused or purely procedural; regression data positive or N/A

P3 requires reading skill content and related skills — cannot be scored from TSV alone.

### Step 3: Generate Findings

For each principle score < 2, generate a finding with concrete infrastructure action:

```
[P{n}:{principle}] {skill-name} — {one-line description}
  → {action-type}: {concrete artifact}
  → hypothesis: {testable claim, if autoresearch command}
```

**Action types and what they produce:**

| Score gap | Action type | Concrete output |
|-----------|------------|-----------------|
| P1: island | `cross-ref` | Specific routing line to add to a related skill, with trigger condition |
| P1: unwired | `hook` | Specific settings.json hook entry (PreToolUse/PostToolUse) |
| P2: no checkpoints | `eval-checkpoint` | Specific `[eval: tag]` text with file:line placement |
| P2: no measurement | `autoresearch-command` | `run_ab.py` command with flags, domain filter, hypothesis |
| P2: deterministic check possible | `script` | Shell command or script that validates without LLM |
| P3: trapped insight | `diffusion` | `[eval:]` checkpoint text + target skill files |
| P3: hook-worthy | `hook` | PreToolUse/PostToolUse hook that fires the check always |
| P3: global | `claude-md` | Line to add to CLAUDE.md |

**Flag-driven findings** — for each skill with non-empty `empirical.flags`:

- `contradiction` → "[P2:loop] {skill} — fires reliably (loom hit_rate: {X}) but attributed cloth is below baseline (mean: {Y}). The skill may be actively harmful for these task types."
  → hypothesis: "{skill} reduces output quality on {domain} tasks"
  → action-type: `autoresearch-command` (subtraction test to confirm)

- `stale_evidence` → "[P2:loop] {skill} — last tested {N} days ago, modified since. Evidence may not reflect current behavior."
  → action-type: `autoresearch-command` (re-run attributed tests)

- `weak_injection` → "[P2:loop] {skill} — low injection→behavior conversion ({X}). A/B results from injection runs may underestimate this skill's value."
  → action-type: `autoresearch-command` (re-test with skilled templates or subtraction runs)

### Step 4: Quality Gate

Raw findings are noisy — filter before surfacing. Order matters here because simplify removes duplicates and noise, so eval-protocol grades signal instead of volume:

1. `/simplify` on the findings (recs only) — filter noise, deduplicate, rank
2. `/eval-protocol` on survivors — grade each: right action? right target? right scope?
3. Keep A/B grades only. Drop C/D/F.

`[eval: quality-gated]` `[eval: simplify-before-eval]`

### Step 5: Classify and Act

**Gate mode** — blocking vs. non-blocking matters because the skill-creator session is still active:
- **Blocking** (missing cross-refs, missing eval checkpoints): Present to user with specific lines to add. The skill isn't done until these are resolved.
- **Non-blocking** (autoresearch commands, diffusion candidates): Create seeds issues automatically.

**Audit mode** — everything is non-blocking since there's no active skill-creator session:
- Present tree-wide scorecard summary (counts only, not per-skill scores)
- Create seeds issues for all surviving findings

**Cross-skill analysis (audit mode only):**
- **Islands:** skills with P1=0
- **Checkpoint coverage:** percentage of skills with eval_checkpoints > 0
- **Diffusion gaps:** `[eval:]` tags in only one skill whose concept applies to 2+

`[eval: gate-blocking]`

### Step 6: Create Seeds Issues

Each non-blocking finding becomes a seeds issue. Wire `--blocked-by` when one finding depends on another (e.g., "add eval checkpoint" before "diffuse that checkpoint"):

```bash
sd create \
  --title "[P{n}] {action-type}: {skill-name} — {description}" \
  --type task --priority medium \
  --labels "{principle},{action-type},autoresearch" \
  --description "{full finding with concrete artifact and hypothesis}"
```

**Delta mode (audit only):** Check existing seeds first (`sd list --labels autoresearch --status open`) — close resolved ones, create new ones, auto-close orphans.

`[eval: seeds-created]`

### Step 7: Record to Mulch

Record reusable insights only — conventions (patterns that worked), decisions (resolved blockers), outcomes (closed seeds), and experiment results (significant deltas). Use `ml record autoresearch-principles` with appropriate `--type`.

The point is to close the loop: experiment outcomes become queryable by Step 1.5's mulch query in the next cycle. Raw scorecards and per-skill P1/P2/P3 scores are not worth recording — they go stale immediately.

`[eval: no-score-mulch]`

### Step 8: Generate Autoresearch Commands

For each finding where A/B testing would validate the hypothesis, generate commands.

**If experiment.py exists** (preferred — isolates runs, tracks hypotheses):
```bash
python3 ~/.claude/autoresearch/hypotheses.py create \
  --hypothesis "{testable claim}" --skill "{skill-name}" --seeds-id "{seeds-issue-id}"

python3 ~/.claude/autoresearch/experiment.py \
  --name "{finding-id}" --hypothesis "{testable claim}" \
  -- --random --domain {domain} --inject-skill-a {skill-name} \
  --variant-a variants/all-active --variant-b variants/baseline
```

**If experiment.py doesn't exist yet** (fallback — raw run_ab.py):
```bash
python3 ~/.claude/autoresearch/run_ab.py \
  --random --domain {domain} \
  --inject-skill-a {skill-name} \
  --variant-a ~/.claude/autoresearch/variants/all-active \
  --variant-b ~/.claude/autoresearch/variants/baseline
```

For subtraction tests:
```bash
python3 ~/.claude/autoresearch/run_ab.py \
  --random --domain {domain} \
  --subtract-skill {skill-name} \
  --variant-a ~/.claude/autoresearch/variants/all-active \
  --variant-b ~/.claude/autoresearch/variants/baseline
```

For interaction effects (when multiple skills may conflict or reinforce), use multi-arm mode (when available):
```bash
python3 ~/.claude/autoresearch/run_ab.py \
  --multi-arm --domain {domain} \
  --arms "{skill-a},{skill-b},{skill-a+skill-b}" \
  --variant-a ~/.claude/autoresearch/variants/all-active \
  --variant-b ~/.claude/autoresearch/variants/baseline
```
This tests each skill individually AND their combination — surfaces interaction effects that single-skill A/B tests miss.

Present each command with its hypothesis. Don't auto-execute — A/B tests are expensive and the user should decide which ones are worth running.
