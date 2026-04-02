# Success Metrics (KPIs) — Pocketwise

## Outcome Metrics (What changes for users?)

### Monthly Active Retention (MAR)
- **Metric**: Percentage of users active in month N who are still active in month N+1
- **Baseline**: Unknown (needs instrumentation). Estimate ~40% based on personal finance app industry benchmarks
- **Target**: 55% MAR within 90 days of shipping next major feature
- **Measurement method**: Analytics event `session_start` tracked per user per month. Active = 2+ sessions/month
- **Leading indicator**: Week-1 retention (users who return within 7 days of signup). Target: 35%
- **Timeframe**: Measure monthly, evaluate trend after 90 days

### Household Conversion Rate
- **Metric**: Percentage of users who invite a partner/household member (if household feature ships)
- **Baseline**: 0% (feature doesn't exist)
- **Target**: 8% of active users send an invite within 60 days of feature launch
- **Measurement method**: Track `invite_sent` and `invite_accepted` events
- **Leading indicator**: Invite button click-through rate. Target: 15% of users who see the prompt
- **Timeframe**: 60 days post-launch

### Budget Adherence Improvement
- **Metric**: Percentage of users whose actual spending comes within 10% of their budget targets (for users who set budgets)
- **Baseline**: Unknown (needs instrumentation)
- **Target**: 30% of budget-setting users achieve adherence in 3+ categories per month
- **Measurement method**: Compare `budget_target` to `actual_spend` per category per month
- **Leading indicator**: Budget creation completion rate. Users who finish setting up budgets are more likely to adhere
- **Timeframe**: Ongoing monthly measurement

## Output Metrics (What did we ship?)

### Feature Completeness
- **Metric**: Percentage of planned roadmap items shipped per quarter
- **Baseline**: Informal (no structured roadmap existed)
- **Target**: 1 major initiative per quarter, fully shipped (not half-built)
- **Measurement method**: Roadmap tracking against this document

### Time-to-Value
- **Metric**: Time from signup to first meaningful action (connecting a bank account OR manually entering a budget)
- **Baseline**: Unknown (needs instrumentation). Industry benchmark: 5-8 minutes for finance apps
- **Target**: Under 4 minutes to first bank connection or budget entry
- **Measurement method**: Timestamp difference between `signup_complete` and `first_bank_connected` or `first_budget_created`
- **Leading indicator**: Onboarding step completion funnel drop-off rates
- **Timeframe**: Measure continuously

## Metric Gaps & Instrumentation Needs

Before any of these KPIs are actionable, Pocketwise needs basic analytics instrumentation:
1. Session tracking (`session_start`, `session_end`)
2. Core action events (`bank_connected`, `budget_created`, `transaction_categorized`, `invite_sent`)
3. Retention cohort tracking (signup date + monthly activity)

**Recommendation**: Ship analytics instrumentation as a prerequisite before or alongside the next major feature. Without measurement, every future decision is guesswork.
