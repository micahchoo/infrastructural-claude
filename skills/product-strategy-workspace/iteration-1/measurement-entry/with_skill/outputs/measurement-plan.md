# Measurement Plan — Onboarding Flow Redesign

## Context

- **Initiative**: SaaS onboarding flow redesign
- **Launch date**: ~2 weeks ago (approx. 2026-03-12)
- **Evaluation window**: 60 days post-launch (target: ~2026-05-11)
- **Current position**: 2 weeks into 60-day evaluation window (~23% elapsed)

## Entry Mode

Entering the product lifecycle at **Phase 4: Measure**. The build pipeline has completed
(new onboarding flow shipped). We now evaluate outcomes against the success criteria
defined pre-launch.

## Pre-Defined Success Criteria (Phase 2 Reference)

The PM defined these targets before launch:

| KPI | Baseline | Target | Timeframe |
|-----|----------|--------|-----------|
| Trial-to-paid conversion | 12% | 18% | 60 days |
| Time-to-first-value (TTFV) | 45 minutes | < 15 minutes | 60 days |

## Measurement Approach

### Signal Types Required (minimum 2 per eval checkpoint `signal-diversity`)

1. **Quantitative** — Analytics dashboard data: conversion rates, TTFV distributions, funnel drop-off points, cohort comparisons (pre/post redesign)
2. **Qualitative** — Support ticket analysis: 30 tickets since launch categorized by theme, sentiment, and onboarding stage
3. **UX Audit** — Shadow-walk the new onboarding flow from a new-user perspective to identify friction points visible in the implementation
4. **Technical** — Error rates, page load times, and reliability metrics for the new flow

### Evaluation Timing

At 2 weeks (14 days into 60-day window), we have:
- **Sufficient data for**: Leading indicator assessment, early trend detection, qualitative signal analysis
- **Insufficient data for**: Definitive PASS/MISS verdict on conversion (need full cohort maturation)
- **Recommended**: Treat this as an **early read**, not a final evaluation. Schedule full evaluation at day 45-60.

## Deliverables

1. `kpi-evaluation.md` — Current KPI status against targets with attribution confidence
2. `signal-collection-plan.md` — Detailed plan for gathering each signal type
3. `retrospective-synthesis.md` — Early learnings and recommended actions

## Bias Checks Applied

- **`substitution`**: Are we measuring what matters (user outcomes), or what's easy to measure (page views, clicks)? Both KPIs are outcome-layer metrics — good.
- **`overconfidence`**: 2 weeks of data in a 60-day window. High uncertainty on conversion (lagging indicator). More confidence on TTFV (leading indicator, measurable per-session).
- **`wysiati`**: What signals are we NOT seeing? Users who bounced before completing onboarding. Users who converted but aren't retained. Competitors' onboarding improvements during this period.
