# Pocketwise: Strategic Prioritization Analysis

## Situation Summary

Pocketwise is a 6-month-old solo-dev personal finance app that started as a budgeting tool. The user base is primarily millennials acquired organically through a Reddit post. Three feature requests are competing for attention: investment tracking, bill reminders, and shared household budgets.

---

## User Persona Assumptions

Given the millennial Reddit demographic, reasonable assumptions:

- **Age range**: 28-42 (born ~1984-1998)
- **Life stage**: Dual-income households, early parenthood, first-time homebuyers, student loan tail-end
- **Financial sophistication**: Moderate — they budget intentionally (they sought out a budgeting app) but aren't power investors
- **Pain points**: Subscription creep, rent/mortgage coordination with partners, wanting to "get into investing" but overwhelmed
- **Channel behavior**: Reddit-acquired users are word-of-mouth amplifiers if delighted, vocal critics if disappointed

---

## Framework: Impact vs. Effort with Retention Lens

For a solo dev, the right framework is not "what's most requested" but "what keeps existing users and compounds growth." Three lenses:

### 1. Retention Risk (Will users leave without this?)
### 2. Growth Leverage (Will this bring new users?)
### 3. Solo-Dev Feasibility (Can one person build and maintain this?)

---

## Feature-by-Feature Analysis

### Bill Reminders

| Dimension | Assessment |
|-----------|-----------|
| **Retention Risk** | HIGH. Users who budget need to know when money leaves. Missing a bill because your budgeting app didn't warn you feels like betrayal. This is table-stakes functionality adjacent to your core value prop. |
| **Growth Leverage** | MEDIUM. Not a Reddit-post-worthy feature, but it increases daily/weekly engagement (users open the app more), which correlates with retention and word-of-mouth. |
| **Solo-Dev Feasibility** | HIGH. Conceptually simple: recurring dates + push/email notifications. You can ship a V1 in 1-2 weeks. The data model is straightforward (amount, due date, recurrence pattern, notification preferences). |
| **Compounding Effect** | Bill reminders create a habit loop — users return to the app on a schedule. This is the most important thing for a young app. |

**Verdict: BUILD FIRST.**

---

### Shared Household Budgets

| Dimension | Assessment |
|-----------|-----------|
| **Retention Risk** | MEDIUM-HIGH. Millennials in partnerships need this. If both partners can't use Pocketwise together, one of them will churn and pull the other toward a competitor. |
| **Growth Leverage** | HIGH. Every shared budget is a built-in referral — one user invites their partner. This is organic 2x growth per household. Reddit millennials skew toward the "we just moved in together and need to split expenses" demographic. |
| **Solo-Dev Feasibility** | MEDIUM. Multi-user data models, permissions, invitation flows, conflict resolution (two people editing the same budget). Not trivial, but scoped correctly it's manageable. |
| **Compounding Effect** | Network effects at the household level. Once a couple is on Pocketwise, switching costs double. |

**Verdict: BUILD SECOND.**

---

### Investment Tracking

| Dimension | Assessment |
|-----------|-----------|
| **Retention Risk** | LOW. Your users came for budgeting. They won't leave because you don't track their Robinhood portfolio — they'll use a separate app for that. |
| **Growth Leverage** | LOW-MEDIUM. The investment tracking space is crowded (Personal Capital, Mint, Empower, every brokerage's own app). You'd be competing with well-funded incumbents. |
| **Solo-Dev Feasibility** | LOW. Real investment tracking requires brokerage API integrations (Plaid, Yodlee), real-time price feeds, tax lot tracking, asset allocation views. Massive ongoing maintenance burden. |
| **Compounding Effect** | Weak. Investment tracking doesn't drive daily engagement for casual investors. They check quarterly at best. |

**Verdict: DEFER. Revisit when you have a team or a clear differentiation angle.**

---

## Recommended Roadmap

```
Q1 (Now)          Q2                    Q3+
-----------        -----------           -----------
Bill Reminders     Shared Budgets V1     Shared Budgets V2
  - Recurring       - Partner invite      - Split tracking
    schedules        - Shared categories   - Expense approval
  - Push notifs      - Combined view       - Investment tracking
  - Calendar view    - Basic permissions     (if validated)
```

### Q1: Bill Reminders (2-4 weeks)
1. **Week 1-2**: Core engine — recurring bill model, notification scheduler, basic UI for adding/editing bills
2. **Week 3**: Calendar/timeline view showing upcoming bills against budget
3. **Week 4**: Polish, test with 5-10 existing users, ship

### Q2: Shared Household Budgets (6-8 weeks)
1. **Week 1-2**: Multi-user data model, invitation system
2. **Week 3-4**: Shared budget views, category-level permissions
3. **Week 5-6**: Conflict resolution, activity feed ("Alex added a $45 grocery expense")
4. **Week 7-8**: Polish, beta with couples from your Reddit community

### Q3+: Reassess
By this point you'll have 2-3 months of data on what shared-budget users actually need. Investment tracking may or may not still be the right next move — let the data decide.

---

## Strategic Principles for Solo Devs

### 1. Deepen before you widen
Your core is budgeting. Bill reminders and shared budgets deepen that core. Investment tracking widens into a new domain. Deepening retains users; widening fragments your attention.

### 2. Every feature should create a return visit
Bill reminders bring users back weekly. Shared budgets bring two users back. Investment tracking brings users back quarterly. Optimize for engagement frequency.

### 3. Let users pull you into adjacencies
If shared-budget users start asking "can we split the investment account too?", that's a pull signal. If investment tracking requests come from non-users or tire-kickers, that's push — and push features have low ROI for solo devs.

### 4. Your Reddit channel is an asset — feed it
Ship bill reminders, post an update to the subreddit that discovered you. Ship shared budgets, post again. Each ship is a growth event. Investment tracking would take so long that you'd go silent for months — silence kills Reddit momentum.

### 5. Scope ruthlessly
V1 of bill reminders doesn't need smart categorization, OCR, or bank sync. V1 of shared budgets doesn't need granular permissions or audit logs. Ship the 80% version, learn, iterate.

---

## Risk Factors

| Risk | Mitigation |
|------|-----------|
| Bill reminders feel too simple to announce | Frame as "never miss a payment" — the outcome, not the feature |
| Shared budgets scope creep | Define V1 as "two people, one shared budget, view-only for invited partner" — expand from there |
| Investment tracking requesters churn | Survey them — are they power users or casual askers? If power users, consider a lightweight "net worth" view (manual entry, no API) as a bridge |
| Reddit community goes cold | Maintain a shipping cadence of every 4-6 weeks. Even small updates keep momentum |

---

## Metrics to Track

- **Bill Reminders**: DAU/MAU ratio change (expect +15-25%), notification open rate, bills-added-per-user
- **Shared Budgets**: Invitation acceptance rate, household DAU, partner retention at 30/60/90 days
- **Overall**: NPS before and after each launch, churn rate by cohort, organic acquisition rate
