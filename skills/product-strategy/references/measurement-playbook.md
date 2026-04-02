# Measurement Playbook

Reference for Phase 4 (Measure) of product-strategy. How to evaluate whether what
was built actually worked.

## The Measurement Stack

```
┌──────────────────────────────┐
│   OUTCOME METRICS            │  ← Measure these (user behavior change)
│   "Users complete task in    │
│    <5 min" / "Churn < 3%"    │
├──────────────────────────────┤
│   OUTPUT METRICS             │  ← Track these (what was shipped)
│   "3-step onboarding live"   │
│   "API response <200ms"      │
├──────────────────────────────┤
│   ACTIVITY METRICS           │  ← Don't celebrate these (what we did)
│   "12 PRs merged" / "5       │
│    designs reviewed"         │
└──────────────────────────────┘
```

Activity metrics are not evidence of success. They're evidence of effort. Distinguish
between them explicitly in every measurement report.

## Signal Types

### Quantitative Signals

Data that can be counted, measured, or aggregated.

| Signal | Source | Good for | Watch out for |
|--------|--------|----------|---------------|
| Usage analytics | Event tracking, logs | Adoption, engagement, drop-off | Can't tell you WHY |
| Performance metrics | APM, monitoring | Speed, reliability | Fast != useful |
| Conversion rates | Funnel analysis | Effectiveness of flows | Correlation != causation |
| Error rates | Error tracking | Reliability, edge cases | Low errors != good UX |
| Retention/churn | Cohort analysis | Long-term value | Slow-moving, lagging indicator |

### Qualitative Signals

Data that reveals intent, satisfaction, and experience quality.

| Signal | Source | Good for | Watch out for |
|--------|--------|----------|---------------|
| User feedback | Surveys, interviews, support | Understanding WHY | Selection bias |
| UX audit | shadow-walk through code | Flow quality, dead ends | Auditor bias |
| Usability testing | Task completion observation | Specific interaction issues | Small sample |
| Support tickets | Help desk, forums | Real pain points | Only captures vocal users |
| Workarounds | User-created scripts, exports | Unmet needs | Hard to discover |

### Technical Signals

Data about system health and implementation quality.

| Signal | Source | Good for | Watch out for |
|--------|--------|----------|---------------|
| Test coverage | Test suite analysis | Code confidence | Coverage != correctness |
| Error handling | silent-failure-hunter | Resilience | Absence of evidence != evidence of absence |
| Architecture quality | Anti-pattern scan | Maintainability | Subjective thresholds |
| Dependency health | Audit tools | Security, freshness | Not all outdated deps are risks |

## Measurement Timing

| When | What to measure | Why |
|------|-----------------|-----|
| **Before launch** (baseline) | Current state of KPIs | Can't measure change without a starting point |
| **Week 1** | Leading indicators only | Too early for outcomes, but early signals matter |
| **Month 1** | Leading indicators + early outcomes | First real signal on whether the bet is paying off |
| **Quarter 1** | Full KPI evaluation | Enough time for outcome metrics to stabilize |

Leading indicators are the early-warning system. If the leading indicator is flat at
Week 1, the outcome metric won't magically improve at Month 1.

## Attribution

The hardest question in measurement: did OUR change cause the improvement?

**Strong attribution**: A/B test, before/after with no other changes, feature flag rollout.
**Medium attribution**: Before/after with controlled variables, cohort comparison.
**Weak attribution**: Before/after with many simultaneous changes, anecdotal evidence.

Be honest about attribution confidence. "We shipped X and metric Y improved" is
correlation. "We A/B tested X and treatment group showed Y improvement" is causation.

In practice, most product teams operate at medium attribution. That's fine — just
don't claim strong attribution when you don't have it.

## Anti-Patterns

### Vanity Metrics
Metrics that look good but don't indicate actual value.
- Page views without engagement depth
- Registered users without activation
- Feature usage without task completion

**Fix**: For every metric, ask: "If this number doubled, would users be better off?"

### Metric Fixation
Optimizing a metric at the expense of the thing it's supposed to measure.
- Reducing onboarding steps (metric) by removing important setup (user value)
- Increasing DAU (metric) by adding notification spam (user trust)

**Fix**: Always pair a metric with a counter-metric. If DAU is up but NPS is down,
you're optimizing wrong.

### Post-Hoc Rationalization
Measuring everything, then finding the metric that improved and claiming success.

**Fix**: Define KPIs BEFORE building (Phase 2b). The measurement phase evaluates those
specific KPIs, not whatever happened to go up.

## Shadow-Walk Integration

When dispatching shadow-walk for UX measurement:

```
Walk the [feature name] flow as [persona name].
Starting point: [entry action].
Success: [persona completes their job-to-be-done].

Focus on:
- Does the flow support [KPI name]?
- Where does the persona get stuck or confused?
- What workarounds would the persona use?

Reference: product/strategy/personas/[persona].md
KPI target: [metric] from product/strategy/kpis.md
```

Shadow-walk findings feed directly into the qualitative signal column of the
measurement report.
