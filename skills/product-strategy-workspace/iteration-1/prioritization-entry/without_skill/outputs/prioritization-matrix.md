# Pocketwise: Prioritization Scoring Matrix

## Methodology

Each feature scored 1-5 across five dimensions relevant to a solo-dev consumer app. Weights reflect the reality that retention and feasibility matter more than growth for an early-stage solo product.

## Scoring

| Dimension | Weight | Bill Reminders | Shared Budgets | Investment Tracking |
|-----------|--------|---------------|----------------|---------------------|
| Retention impact | 25% | 5 | 4 | 2 |
| Growth leverage | 20% | 3 | 5 | 3 |
| Solo-dev feasibility | 25% | 5 | 3 | 1 |
| Core alignment | 15% | 5 | 4 | 2 |
| Engagement frequency | 15% | 5 | 4 | 1 |

## Weighted Scores

| Feature | Calculation | Total |
|---------|------------|-------|
| **Bill Reminders** | (5x.25)+(3x.20)+(5x.25)+(5x.15)+(5x.15) | **4.60** |
| **Shared Budgets** | (4x.25)+(5x.20)+(3x.25)+(4x.15)+(4x.15) | **3.95** |
| **Investment Tracking** | (2x.25)+(3x.20)+(1x.25)+(2x.15)+(1x.15) | **1.85** |

## Priority Order

1. **Bill Reminders** (4.60) — Build now
2. **Shared Household Budgets** (3.95) — Build next
3. **Investment Tracking** (1.85) — Defer

## Dimension Rationale

### Retention Impact (25%)
How much does lacking this feature risk losing existing users? Bill reminders are table-stakes for anyone tracking their money. Shared budgets solve a real pain point for coupled millennials. Investment tracking is a "nice to have" that users will get elsewhere.

### Growth Leverage (20%)
Will this feature bring in new users organically? Shared budgets have a built-in viral loop (invite your partner). Bill reminders increase engagement which feeds word-of-mouth. Investment tracking competes with well-funded alternatives.

### Solo-Dev Feasibility (25%)
Can one person build, ship, and maintain this in a reasonable timeframe? Bill reminders are straightforward CRUD + notification scheduling. Shared budgets need multi-tenancy but can be scoped. Investment tracking requires external API integrations, real-time data, and ongoing maintenance.

### Core Alignment (15%)
Does this deepen the budgeting core or dilute it? Bill reminders are a natural extension of "where does my money go." Shared budgets extend budgeting to households. Investment tracking is an adjacent but distinct domain.

### Engagement Frequency (15%)
How often will this feature bring users back to the app? Bill reminders create weekly/bi-weekly return visits. Shared budgets create daily check-ins for active households. Investment tracking drives quarterly glances at best for casual investors.
