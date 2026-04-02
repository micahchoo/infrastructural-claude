# Aspiring-Investor Alex — The Wealth Builder

## Behavioral Profile
- **Primary job**: Graduate from "just budgeting" to building wealth — wants to see net worth grow, not just track spending. Budgeting is a means to an end (investing more)
- **Current tools**: Pocketwise for budgeting, Robinhood/Fidelity for brokerage, Google Sheets to manually track net worth across accounts
- **Pain points**:
  - No unified view of spend + invest — has to context-switch between budget app and brokerage to answer "can I invest more this month?" (evidence: investment tracking feature request)
  - Portfolio performance is siloed in brokerage apps that don't show relationship to savings rate
  - Doesn't need a full trading platform — wants visibility, not execution
- **Workarounds**: Monthly net worth spreadsheet that pulls from multiple account balances; screenshots brokerage balances into a notes app
- **Switch trigger**: A budgeting app that also shows investment account balances and net worth trend — "financial dashboard" not "budget tracker"

## Design Implications
- Investment tracking means read-only account aggregation (Plaid connections to brokerages), NOT trade execution
- Net worth view is the killer feature for this persona — it reframes budgeting as a means to wealth building
- This is a retention play: users who see net worth growing alongside budget discipline are stickier
- Scope risk: investment tracking can expand infinitely (performance analytics, tax optimization, rebalancing). Must be constrained to visibility only in v1

## Evidence
- Source: Direct feature request — "investment tracking" is one of three named feature requests — 2026-03
- Source: Millennial wealth-building behavior shift (post-2020 retail investing boom, documented in Financial Planning Association surveys)
- Source: Competitor gap — Mint added investment tracking and it became a top retention feature before shutdown; YNAB deliberately excludes it, creating a gap
