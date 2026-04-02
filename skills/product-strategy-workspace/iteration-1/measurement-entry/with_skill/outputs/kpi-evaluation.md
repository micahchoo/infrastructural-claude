# KPI Evaluation — Onboarding Flow Redesign

## Evaluation Context

- **Evaluation date**: 2026-03-26 (Day ~14 of 60-day window)
- **Evaluation type**: Early read (not definitive verdict)
- **Pre-defined targets source**: PM-defined success criteria (pre-launch)

---

## KPI 1: Trial-to-Paid Conversion — PENDING (too early for verdict)

- **Target**: 18% (up from 12% baseline)
- **Actual**: _Not yet determinable_ — requires analytics dashboard data
- **Leading indicator**: Onboarding completion rate + activation rate (extract from dashboard)
- **Attribution confidence**: TBD
- **Timeframe status**: 23% through evaluation window (14 of 60 days)

### Assessment Framework

This KPI cannot be reliably evaluated at 2 weeks because:

1. **Cohort maturity**: Users who signed up in the last 14 days are likely still in their trial period. Most SaaS trials run 14-30 days. The majority of conversion decisions haven't been made yet.
2. **Comparison validity**: The 12% baseline was measured over a mature period. Comparing a 2-week immature cohort against a mature baseline will always show an artificially low conversion rate.

**What to do instead at Day 14:**
- Compare onboarding completion rate (new flow vs. old flow at same point in lifecycle)
- Compare activation rate (users who performed core action within 24 hours of signup)
- Compare Day-7 retention (new cohort vs. historical cohort)
- If these leading indicators are flat or declining, the conversion target is at risk

**Projection methodology**: If trial length is N days, the earliest reliable conversion read is at Day N+14 (to allow a full cohort to mature plus 2 weeks of decision time). For a 14-day trial, that's Day 28. For a 30-day trial, that's Day 44.

### When to Escalate
- If onboarding completion rate < 60% → intervene now (don't wait for conversion data)
- If activation rate declined vs. old flow → investigate friction points immediately
- If Day-7 retention dropped → the flow may be faster but less effective at building habits

### Verdict Criteria (for Day 45-60 evaluation)

| Outcome | Conversion Rate | Verdict |
|---------|----------------|---------|
| **PASS** | >= 18% | Target met, initiative successful |
| **PARTIAL** | 15-17.9% | Meaningful improvement but below target; iterate |
| **MISS** | 12-14.9% | Marginal improvement; investigate what's not working |
| **REGRESSION** | < 12% | Below baseline; urgent investigation required |

---

## KPI 2: Time-to-First-Value — PRELIMINARY READ POSSIBLE

- **Target**: < 15 minutes (down from 45-minute baseline)
- **Actual**: _Requires analytics dashboard data extraction_
- **Leading indicator**: Per-step completion times in onboarding flow
- **Attribution confidence**: TBD
- **Timeframe status**: Measurable now (per-session metric, doesn't need cohort maturation)

### Assessment Framework

Unlike conversion, TTFV is measurable immediately because it's a per-session metric. Every
user who completes onboarding has a TTFV measurement.

**What to extract from analytics:**
1. **Median TTFV** (last 14 days) — the primary comparison against 45-minute baseline
2. **TTFV distribution** — P25, P50, P75, P95 to understand spread
3. **TTFV by user segment** — if available, different user types may have very different times
4. **TTFV trend line** — is it improving day-over-day as users or the team iterate?

### Interpretation Guidance

| Median TTFV | Signal | Action |
|-------------|--------|--------|
| < 10 min | Exceeding target | Validate that "first value" event is correctly defined |
| 10-15 min | On target | Monitor; ensure quality of value moment is maintained |
| 15-25 min | Improved but below target | Identify bottleneck steps; likely 1-2 steps consuming disproportionate time |
| 25-45 min | Marginal improvement | Flow may be faster but fundamental structure hasn't changed |
| > 45 min | Regression | Something is broken; likely a new blocker added |

### Critical Nuance: "First Value" Definition

The entire TTFV metric depends on what event constitutes "first value." Verify:
- Is this defined as a specific analytics event? Which one?
- Does it represent genuine user value, or just flow completion?
- Could users reach value FASTER by skipping parts of the onboarding?
- Is the event firing correctly in the new flow? (instrumentation bugs can fake improvement)

**`bias:substitution` check**: If TTFV is measured as "time to complete onboarding" rather than
"time to achieve the user's actual goal," we're measuring output (flow completion), not
outcome (user value). These are different. A shorter flow that doesn't actually help users
accomplish their goal is not an improvement.

---

## Support Ticket Analysis — QUALITATIVE SIGNAL

- **Volume**: 30 tickets in ~14 days = ~2.1 tickets/day
- **Benchmark needed**: What was the ticket rate in the 14 days before launch?

### Pre-Analysis Assessment

30 tickets in 2 weeks requires context to interpret:

| Scenario | Interpretation |
|----------|---------------|
| Old flow generated 50 tickets/2 weeks | 30 is a 40% reduction — strong positive signal |
| Old flow generated 30 tickets/2 weeks | Flat — new flow hasn't reduced confusion |
| Old flow generated 15 tickets/2 weeks | Doubled — new flow is creating new problems |
| No historical comparison available | Categorize by type to assess severity regardless |

### What to Look For in the 30 Tickets

**High-value signals (prioritize these):**
- Tickets where user explicitly mentions the onboarding flow
- Tickets from users who signed up but didn't convert (lost revenue signal)
- Tickets clustering around a specific step in the flow
- Tickets expressing confusion about "what to do next" after onboarding

**Red flags:**
- Any ticket mentioning data loss or errors during onboarding
- Multiple tickets about the same step or screen
- Tickets from users who couldn't complete onboarding at all
- Tickets comparing the new flow unfavorably to the old one

---

## Composite Assessment — Day 14 Status

### What We Can Say Now
- TTFV is measurable and should be extracted immediately
- Conversion requires more time — set calendar reminder for Day 30 interim check and Day 45-60 final evaluation
- Support tickets need categorization before they become useful signal
- No definitive PASS/MISS verdict is responsible at this point

### Recommended Immediate Actions

1. **Extract TTFV data from analytics** — this is the one KPI you can evaluate right now
2. **Categorize the 30 support tickets** using the framework in signal-collection-plan.md
3. **Establish the ticket baseline** — pull ticket volume from the 2 weeks before launch
4. **Check onboarding completion rate** — the single best leading indicator for conversion
5. **Schedule formal evaluation** at Day 45 with all four signal types

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Conversion target missed due to flow friction | Unknown (need data) | High | Early intervention if leading indicators are negative |
| TTFV improved but "first value" poorly defined | Medium | Medium | Validate the analytics event definition now |
| Support tickets indicate systemic issue | Low-Medium | High | Categorize tickets this week; fix any blocking bugs immediately |
| Premature conclusion from insufficient data | High (at Day 14) | High | Resist declaring success or failure; commit to Day 45-60 evaluation |

---

## Bias Audit

- **`measurement-baseline` (eval checkpoint)**: Both KPIs compare against pre-defined targets (12% conversion, 45-min TTFV) established by PM before launch. Not post-hoc rationalization. PASS.
- **`signal-diversity` (eval checkpoint)**: Plan incorporates 4 signal types (quantitative analytics, qualitative tickets, UX audit, technical health). Minimum 2 required. PASS.
- **`substitution`**: Watching for TTFV definition conflating "flow completion" with "user value." Flagged as risk above.
- **`overconfidence`**: Explicitly noting that Day 14 data is insufficient for conversion verdict. Refusing to call PASS or MISS prematurely.
