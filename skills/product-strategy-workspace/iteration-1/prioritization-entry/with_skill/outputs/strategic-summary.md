# Pocketwise — Strategic Summary

## The Question
"I have no idea what to prioritize next — I'm a solo dev and I can't do everything."

## The Answer (One Paragraph)
Ship analytics instrumentation first (3 weeks), then bill reminders (5 weeks) in Q2. Both are low-effort, high-confidence moves that establish measurement capability and improve retention for your existing Maya-persona users. In Q3, ship shared household budgets — the only feature in your pipeline that organically grows the user base (every household user brings +1) and justifies a paid tier. Defer investment tracking to Q4, gated on paid-tier validation, because it has the lowest confidence score and highest per-user cost. This sequence respects your solo-dev constraint by shipping one major initiative per quarter, building on each previous bet's results.

## Artifacts Produced

| Artifact | Path | Purpose |
|----------|------|---------|
| Persona: Maya | `personas/budget-conscious-maya.md` | Core retention persona — the intentional budgeter |
| Persona: Jordan | `personas/coupled-finances-jordan.md` | Growth persona — the household coordinator |
| Persona: Alex | `personas/aspiring-investor-alex.md` | Future retention persona — the wealth builder |
| Competitive Landscape | `competitive-landscape.md` | YNAB, Monarch, Copilot, Splitwise positioning map |
| Product Vision | `vision.md` | "Adapts to how you think about money" — positioning statement + constraints |
| Success Metrics | `kpis.md` | MAR, Household Conversion, Budget Adherence + instrumentation prerequisites |
| RICE Prioritization | `prioritization-rice.md` | Scored ranking: Instrumentation > Bill Reminders > Household > Investments |
| Roadmap | `roadmap.md` | Q2-Q4 2026 sequenced bets with conditional gates |
| Opportunity Framing | `opportunity-framing.md` | Three opportunity statements + compound probability assessment |
| Brief: Bill Reminders | `briefs/q2-bill-reminders-brief.md` | Strategic context for Q2 build pipeline |
| Brief: Household Budgets | `briefs/q3-household-budgets-brief.md` | Strategic context for Q3 build pipeline |

## Key Strategic Insights

1. **Instrument before you build.** Every KPI baseline is currently "unknown." Shipping features without measurement means you can't evaluate success. Three weeks of analytics work unlocks all future decision-making.

2. **Bill reminders are churn prevention, not differentiation.** Competitors already have them. Their absence hurts more than their presence helps. Ship fast, move on.

3. **Household budgets are your growth engine.** It's the only feature with a viral coefficient (each user invites +1). It justifies a paid tier. And asymmetric visibility (my stuff vs. our stuff) is genuine differentiation no competitor nails.

4. **Investment tracking is a Q4 conditional bet, not a Q2 priority.** Lowest confidence (50%), highest cost (Plaid brokerage connections), and dependent on paid-tier revenue that doesn't exist yet. The RICE score (0.100) is 10x lower than bill reminders (0.945).

5. **Your indie identity is a strategic asset, not a limitation.** Reddit-native users trust solo devs over VC-backed companies. Protect this: don't paywall existing features, don't sell data, keep responding to feedback.

## What This Analysis Cannot Tell You

- **Whether users will actually pay** — willingness-to-pay for a $4.99/month indie finance tool is untested
- **Why users churn** — no exit survey data exists; all retention estimates are benchmarks, not measurements
- **Whether the Reddit channel is saturated** — if growth has plateaued, household viral mechanics matter even more
- **Platform distribution** — Android vs. iOS split affects effort estimates for push notifications and multi-platform features

## Recommended Next Action
Start Q2 by implementing basic analytics event tracking. While that ships, begin designing the bill reminders feature. The strategic brief at `briefs/q2-bill-reminders-brief.md` has the full context for a brainstorming or product-design session.
