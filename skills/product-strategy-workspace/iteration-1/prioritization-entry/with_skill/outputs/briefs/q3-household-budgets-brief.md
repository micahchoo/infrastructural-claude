# Strategic Brief — Shared Household Budgets (Q3 2026)

*From product-strategy, for downstream build pipeline (brainstorming → product-design → writing-plans)*

## Target Persona
**Coupled-Finances Jordan** — Millennial in a dual-income relationship who coordinates shared expenses across Splitwise, separate bank accounts, and a shared Google Sheet. Monthly "finance meetings" with partner to reconcile. Needs a single view of shared AND personal finances without exposing everything.

## Success Metric
**Household Conversion Rate** — Target: 8%+ of active users send a household invite within 60 days of launch. Secondary: 50%+ invite acceptance rate. Tertiary: Household users show 15+ percentage point higher 90-day retention than solo users.

## Priority Rationale
Adjusted RICE score of 0.480 (accounting for viral coefficient — each household user brings +1). This is Pocketwise's growth engine: the only feature in the pipeline that organically expands the user base. It also justifies the paid tier ($4.99/month) which funds future development including investment tracking. Strategic importance exceeds raw RICE ranking.

## Constraints (Explicitly Out of Scope)
- **Couples/partners only in v1** — no roommate groups (3+ people). Simplifies permission model and reduces edge cases
- **No joint account management** — Pocketwise tracks spending, it doesn't manage bank accounts
- **No financial advisor features** — no recommendations about how couples "should" split expenses
- **Asymmetric visibility is required** — Jordan sees "my stuff" + "our stuff"; Jordan's partner sees their own "my stuff" + "our stuff". Neither sees the other's personal categories. This is the key differentiator vs. Monarch
- **Partner onboarding must take under 2 minutes** — Jordan's partner has lower financial tool tolerance. If onboarding is complex, the invite fails

## Competitive Context
Monarch offers household features but with basic sharing (no asymmetric visibility). YNAB has no multi-user support. Splitwise handles splitting but not budgeting. No competitor offers the "shared budgets with personal privacy" model that Jordan needs. This is genuine differentiation, not parity.

## Technical Context
- Multi-user auth (household membership model, not just user accounts)
- Real-time or near-real-time sync for shared budget updates
- Invitation flow (email/link invite, accept/decline, permission grant)
- Data model: transactions belong to a user but can be tagged as "shared" and appear in household view
- Settlement tracking: "Jordan owes partner $47 this month" calculated from shared transaction splits
- Privacy model must be enforced at the API level, not just UI — partner's personal data must never leak even in API responses
