# Success Metrics (KPIs) — DevPulse

## Outcome Metrics (what user behavior changes)

### KPI-1: Feedback Triage Time Reduction
- **Metric**: Hours per week spent by the developer/CM on manual feedback reading and categorization
- **Baseline**: 5-10 hrs/week (solo dev), 15-20 hrs/week (community manager) — self-reported in onboarding survey
- **Target**: 50% reduction within 30 days of active use (e.g., 5 hrs → 2.5 hrs for solo dev)
- **Measurement method**: Weekly self-report prompt in-app ("How many hours did you spend on feedback this week?") + platform usage analytics (time-in-tool as proxy)
- **Leading indicator**: Number of feedback items auto-categorized vs. manually re-categorized in first week. If auto-categorization accuracy is below 70%, time savings won't materialize.
- **Timeframe**: Evaluate at 30 days post-activation per cohort

### KPI-2: Decision Confidence
- **Metric**: Developer self-reported confidence in "what to build next" decisions (1-5 Likert scale)
- **Baseline**: None (new product) — establish in onboarding survey before first use
- **Target**: Average score >= 4.0 within 60 days (from expected baseline of ~2.5)
- **Measurement method**: Monthly in-app survey: "How confident are you that your current development priorities reflect what your players actually need?" (1 = guessing, 5 = evidence-based)
- **Leading indicator**: Percentage of sprint/update decisions that reference a DevPulse insight (tracked by "used in decision" action on feedback clusters)
- **Timeframe**: Evaluate at 60 days post-activation per cohort

### KPI-3: Player Communication Loop Closure
- **Metric**: Percentage of top-20 feedback themes that have a public developer response (roadmap update, devlog mention, or "won't do" explanation)
- **Baseline**: None (new product) — estimate current state in onboarding: "Of your top player requests, how many have you publicly responded to?"
- **Target**: >= 60% of top-20 themes addressed within 90 days of use
- **Measurement method**: Track "responded" status on feedback theme clusters; cross-reference with public roadmap or devlog publishing events
- **Leading indicator**: Number of feedback themes marked as "reviewed" in first 14 days
- **Timeframe**: Evaluate at 90 days post-activation

## Output Metrics (what we ship — tracked but not success criteria)

### KPI-4: Platform Coverage at Launch
- **Metric**: Number of feedback source integrations available at MVP launch
- **Baseline**: 0
- **Target**: 3 sources (Discord, Steam reviews, Reddit) at MVP
- **Measurement method**: Integration test suite — each source has automated ingestion verification
- **Leading indicator**: API access secured and ingestion pipeline functional for each platform
- **Timeframe**: MVP launch date

### KPI-5: Categorization Accuracy
- **Metric**: Percentage of auto-categorized feedback items that users do not re-categorize
- **Baseline**: None
- **Target**: >= 70% accuracy (items accepted as-categorized)
- **Measurement method**: Track re-categorization events as a percentage of total categorized items per user per week
- **Leading indicator**: Accuracy on the first 100 items per user (if below 50%, the categorization model needs retraining on game-specific vocabulary)
- **Timeframe**: Ongoing, evaluate weekly from launch

## Anti-Metrics (what we explicitly do NOT optimize for)

- **Feedback volume ingested**: More feedback is not better. If we optimize for volume, we recreate the noise problem.
- **Feature request count**: We are not a voting board. Counting requests incentivizes the wrong behavior.
- **Daily active usage time**: Spending MORE time in DevPulse is a failure signal. The tool should save time, not consume it.

## Measurement Infrastructure Required

For MVP, measurement is lightweight:
1. In-app survey prompts (onboarding baseline + monthly pulse) — no external analytics needed
2. Event tracking on key actions: categorize, re-categorize, mark-as-reviewed, mark-as-decided, export-to-roadmap
3. Weekly digest email to the dev showing their own metrics (builds habit + captures data)

Heavy analytics (cohort analysis, retention curves, funnel optimization) is premature before product-market fit.
