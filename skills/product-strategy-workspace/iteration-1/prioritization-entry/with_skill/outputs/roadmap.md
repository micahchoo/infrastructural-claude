# Product Roadmap — Pocketwise

## Roadmap Philosophy

This is a sequence of bets, not a promise. Each entry states what we're betting on, why, how we'll know it worked, and what we're explicitly NOT doing. Sequencing is optimized for a solo dev shipping one major initiative per quarter.

---

## Q2 2026: Foundation — Instrument + Quick Win

### Bet 1: Analytics Instrumentation (Weeks 1-3)
- **What**: Basic event tracking (session, core actions, retention cohorts) + simple dashboard
- **Why (persona)**: All personas. Without measurement, every decision is guesswork
- **Why (KPI)**: Enables Monthly Active Retention baseline, Time-to-Value measurement, all future KPI tracking
- **How we'll know it worked**: Can answer "what is our current monthly retention rate?" with a real number within 30 days of shipping
- **NOT doing**: Fancy analytics UI, A/B testing framework, or third-party analytics integrations. Simple event logging + SQL queries is enough for now

### Bet 2: Bill Reminders (Weeks 3-8)
- **What**: Recurring bill detection (via Plaid) + configurable push/email reminders + "upcoming bills" dashboard widget
- **Why (persona)**: Maya — replaces her calendar-reminder workaround. Also benefits Jordan (shared bills awareness)
- **Why (KPI)**: Monthly Active Retention — users with bill reminders have a reason to open the app even when not actively budgeting
- **How we'll know it worked**:
  - 40%+ of users with connected bank accounts enable at least one bill reminder (within 60 days)
  - Week-1 retention improves by 5+ percentage points vs. pre-feature baseline (measurable because instrumentation ships first)
- **NOT doing**: Bill pay / automatic payments, bill negotiation, subscription management. Reminders only.

---

## Q3 2026: Growth Engine — Shared Household Budgets

### Bet 3: Household Budgets v1 (Full Quarter)
- **What**: Multi-user household with invite flow, shared budget categories, personal categories (asymmetric visibility), settlement tracking, and household dashboard
- **Why (persona)**: Jordan — eliminates the Splitwise + spreadsheet + budget app fragmentation. Every household user brings +1 new user
- **Why (KPI)**: Household Conversion Rate (8% invite rate target), Monthly Active Retention (couples who budget together are stickier)
- **How we'll know it worked**:
  - 8%+ of active users send a household invite within 60 days
  - 50%+ of invites are accepted
  - Household users have 15+ percentage point higher 90-day retention than solo users
- **NOT doing**: Group expense splitting (roommates with 3+ people), joint account management, financial advisor features. Couples/partners only in v1.

### Paid Tier Launch (alongside Bet 3)
- **What**: Introduce paid tier ($4.99/month) for household features. Free tier remains fully functional for solo budgeting
- **Why**: Validates willingness-to-pay before investing in expensive features (investment tracking). Revenue funds increased Plaid costs
- **NOT doing**: Paywalling any existing free features. Trust is the brand.

---

## Q4 2026: Retention Deepening — Investment Visibility (Conditional)

### Bet 4: Investment Account Balances + Net Worth (Conditional on Q3 Results)
- **Gate condition**: Ship ONLY if (a) paid tier has 200+ subscribers AND (b) investment tracking remains a top-3 feature request
- **What**: Read-only brokerage account connections, account balance display, net worth trend chart, savings-rate-to-investment correlation view
- **Why (persona)**: Alex — transforms Pocketwise from "budget tool" to "financial home." Bridges the gap between spending discipline and wealth building
- **Why (KPI)**: Monthly Active Retention — net worth tracking is the stickiest feature in personal finance apps (Mint data pre-shutdown)
- **How we'll know it worked**:
  - 20%+ of paid-tier users connect a brokerage account within 90 days
  - Users with investment tracking have 20+ percentage point higher 6-month retention
- **NOT doing**: Portfolio analysis, tax optimization, rebalancing suggestions, trade execution. Visibility only — this is a budgeting app that shows investments, not an investment app.

### If Gate Fails
- **Alternative**: Double down on household features — add roommate/group splitting, shared financial goals, household analytics
- **Rationale**: If paid tier hasn't validated, adding more Plaid cost (brokerages) is irresponsible. Instead, deepen the feature that IS working

---

## Rolling: User Research Debt

Across all quarters, allocate 2-3 hours/week to:
- **Exit surveys**: Why do users leave? (Instrument in Q2)
- **Feature request tagging**: Categorize by persona and frequency
- **5 user interviews per quarter**: Even informal Reddit DM conversations count. Sharpen persona accuracy and confidence scores

---

## Roadmap Visualization

```
Q2 2026                    Q3 2026                    Q4 2026
├─ Instrumentation (3wk)   ├─ Household Budgets       ├─ [GATE: paid tier validated?]
├─ Bill Reminders (5wk)    │  (full quarter)           │  YES → Investment Visibility
│                          ├─ Paid Tier Launch         │  NO  → Household Deepening
│  ► Measure: retention    │                           │
│    baseline established  │  ► Measure: invite rate,  │  ► Measure: brokerage
│                          │    paid conversion         │    connection rate, retention
└──────────────────────────┴───────────────────────────┴──────────────────────────────
  Maya served (reminders)    Jordan served (household)   Alex served (investments)
  ALL served (analytics)     Growth engine activated      Revenue model validated
```

## Substitution Check (bias:substitution)

Does this roadmap answer "what should I build next?" or did I substitute "what's easy to build"?

- **Instrumentation** is neither exciting nor easy, but it's genuinely the highest-leverage first move. Without it, we can't evaluate anything.
- **Bill reminders before household** could be criticized as the easy choice — but RICE scoring justifies it: 3x less effort, measurable retention impact, and it buys time to design the harder household feature properly.
- **Investment tracking last** is the most controversial call. It's the "exciting" feature. But confidence is lowest, cost is highest, and it depends on paid-tier revenue that doesn't exist yet. Sequencing it behind the revenue gate is disciplined, not avoidant.
- **Each entry traces to a persona and KPI** — not to "what's fun to build."
