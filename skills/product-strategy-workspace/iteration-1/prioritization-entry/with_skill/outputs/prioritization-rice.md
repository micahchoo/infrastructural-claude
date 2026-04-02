# Prioritization — RICE Framework

## Framework Choice Rationale

RICE chosen because: multiple competing features need ranking, solo dev constraint makes sequencing critical, and the quantification forces honest assessment of reach and confidence rather than "what feels exciting."

## Scoring Criteria

- **Reach**: How many current/potential users does this affect per quarter? (Estimated from user base signals)
- **Impact**: How much does this move the outcome KPIs? (3 = massive, 2 = high, 1 = medium, 0.5 = low, 0.25 = minimal)
- **Confidence**: How sure are we about reach and impact estimates? (100% = high evidence, 80% = moderate, 50% = low)
- **Effort**: Person-quarters of work for a solo dev (1 = ~1 month, 2 = ~2 months, 3 = full quarter)

## Candidates

### 1. Bill Reminders
- **Reach**: 70% of active users (nearly universal need; Maya persona's calendar workaround confirms)
- **Impact**: 1.5 (Medium-high. Reduces churn by addressing a daily pain point, but doesn't expand product scope)
- **Confidence**: 90% (Direct feature request + observable workaround behavior + low technical risk)
- **Effort**: 1 (Notification scheduling is well-understood; Plaid has bill detection APIs)
- **RICE Score**: (0.70 * 1.5 * 0.90) / 1 = **0.945**
- **Evidence**: Feature request volume; Maya persona's calendar-reminder workaround; bill reminders are table-stakes in competitors (YNAB, Monarch both have them)
- **KPI connection**: Monthly Active Retention (users who get timely reminders have reason to open app regularly)

### 2. Shared Household Budgets
- **Reach**: 30% of active users (couples/roommates subset, but each converts +1 new user)
- **Impact**: 3 (Massive. Creates viral growth loop — every household user brings a partner. Expands TAM. Opens paid tier justification)
- **Confidence**: 80% (Direct feature request + clear competitive gap + Splitwise usage validates shared-finance need. But: collaboration features are complex to get right)
- **Effort**: 3 (Multi-user auth, permission models, real-time sync, invitation flow, asymmetric visibility — full quarter minimum)
- **RICE Score**: (0.30 * 3.0 * 0.80) / 3 = **0.240**
- **Adjusted consideration**: Raw RICE undervalues this because Reach is per-user, not accounting for the +1 viral coefficient. Effective reach with viral factor: 0.30 * 2 = 0.60 → adjusted score: (0.60 * 3.0 * 0.80) / 3 = **0.480**
- **Evidence**: Jordan persona; direct feature request; Monarch's household features are basic (no asymmetric visibility); Splitwise doesn't integrate with budgeting
- **KPI connection**: Household Conversion Rate (primary), Monthly Active Retention (secondary — couples who budget together stay longer)

### 3. Investment Tracking
- **Reach**: 25% of active users (wealth-builder subset; not all budgeters want this)
- **Impact**: 2 (High. Transforms product from "budget tool" to "financial dashboard" — major positioning upgrade. Strong retention signal)
- **Confidence**: 50% (Feature request exists, but: brokerage Plaid connections are flakier than bank connections; cost doubles per user; unclear if users want visibility-only or expect analysis)
- **Effort**: 2.5 (Plaid brokerage integration, net worth calculation, portfolio display, handling investment-specific edge cases like unrealized gains)
- **RICE Score**: (0.25 * 2.0 * 0.50) / 2.5 = **0.100**
- **Evidence**: Alex persona; Mint's investment tracking was a top retention feature; YNAB deliberately excludes it (gap). But: Monarch already does this well, so differentiation is weaker here
- **KPI connection**: Monthly Active Retention (users who see net worth trend are stickier)

### 4. Analytics Instrumentation (Infrastructure)
- **Reach**: 100% of users (affects all measurement capability)
- **Impact**: 1 (Medium. Users don't see this directly, but every future decision depends on it. Enables all KPI measurement)
- **Confidence**: 100% (No uncertainty — this is engineering work with known scope)
- **Effort**: 0.75 (2-3 weeks for basic event tracking + retention cohorts)
- **RICE Score**: (1.0 * 1.0 * 1.0) / 0.75 = **1.333**
- **Evidence**: KPIs document identifies multiple "baseline: unknown" metrics. Without instrumentation, success/failure of any future feature is unmeasurable
- **KPI connection**: Enables ALL KPIs

## Final Ranking

| Rank | Initiative | RICE Score | Rationale |
|------|-----------|------------|-----------|
| **1** | Analytics Instrumentation | 1.333 | Highest RICE. Prerequisite for measuring everything else. Smallest effort. Ship first. |
| **2** | Bill Reminders | 0.945 | Second-highest RICE. High reach, high confidence, low effort. Quick win that improves retention while household feature is built. |
| **3** | Shared Household Budgets | 0.480 (adj.) | Viral growth engine justifies higher effort. But must follow instrumentation so we can measure household conversion. Sequence: Q2-Q3. |
| **4** | Investment Tracking | 0.100 | Lowest confidence, highest per-user cost. Defer until household feature validates paid tier revenue that funds increased Plaid costs. Sequence: Q4 at earliest. |

## Explicit Trade-offs

- **YES to bill reminders before household budgets**: Even though household has higher strategic impact, bill reminders are 3x faster to ship and directly improve retention for the existing user base. Retention now funds growth later.
- **NO to investment tracking in the near term**: Confidence is too low and cost is too high. The right sequence: (1) ship household budgets to validate paid tier, (2) use paid tier revenue to fund brokerage Plaid costs, (3) then ship investment tracking for paying users.
- **YES to instrumentation first**: "Build measurement before building features" is counterintuitive but essential. Every week without analytics is a week of unrecoverable user behavior data.

## WYSIATI Check (bias:wysiati)

What's missing from this analysis:
- **No direct user interviews**: All evidence is from feature requests and public community patterns. Actual user interviews would sharpen confidence scores significantly.
- **No churn data**: We don't know WHY users leave (no exit surveys, no analytics). The retention KPI baseline is a guess.
- **Android vs. iOS split unknown**: If the user base is predominantly one platform, cross-platform effort estimates change.
- **Revenue model validation**: The assumption that household features justify a paid tier is untested. Users may expect all features free given the indie positioning.
- **Competitor pricing sensitivity**: We assume lower price is an advantage, but haven't validated willingness-to-pay.
