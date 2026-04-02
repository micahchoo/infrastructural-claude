# Prioritization Frameworks

Reference for Phase 2c of product-strategy. Choose the framework that fits the decision context.

## RICE (Reach, Impact, Confidence, Effort)

Best for: ranking many competing features when you need quantified comparison.

**Formula**: `RICE Score = (Reach × Impact × Confidence) / Effort`

| Factor | What it measures | Scale |
|--------|-----------------|-------|
| **Reach** | How many users affected per time period | Actual number (e.g., 500 users/quarter) |
| **Impact** | How much it moves the target KPI per user | 3 = massive, 2 = high, 1 = medium, 0.5 = low, 0.25 = minimal |
| **Confidence** | How sure you are about Reach and Impact | 100% = high, 80% = medium, 50% = low |
| **Effort** | Person-months to build | Actual estimate (e.g., 2 person-months) |

**Worked example:**

| Initiative | Reach | Impact | Confidence | Effort | Score |
|-----------|-------|--------|------------|--------|-------|
| Onboarding redesign | 800 | 2 | 80% | 3 | 427 |
| CSV export | 200 | 1 | 100% | 0.5 | 400 |
| Dashboard filters | 500 | 1 | 50% | 2 | 125 |

**Pitfall**: RICE rewards high-reach, low-effort features. Strategic bets (new market,
new persona) often have low confidence and high effort — RICE will rank them low. Use
a separate "strategic bets" track for these.

## Impact-Effort Matrix

Best for: quick visual triage with a small team and few options.

```
         HIGH IMPACT
              │
    Quick     │    Big Bets
    Wins      │    (plan carefully)
              │
──────────────┼──────────────
              │
    Fill-ins  │    Money Pits
    (if time) │    (avoid)
              │
         LOW IMPACT
   LOW EFFORT          HIGH EFFORT
```

Place each initiative on the grid. Work quadrants in order:
1. Quick Wins (high impact, low effort) — do first
2. Big Bets (high impact, high effort) — plan carefully, do next
3. Fill-ins (low impact, low effort) — do if spare capacity
4. Money Pits (low impact, high effort) — don't do

**Pitfall**: "Impact" and "effort" are both subjective. Anchor impact to a specific KPI
from Phase 2b, and effort to actual implementation estimates from engineering.

## MoSCoW

Best for: fast triage, stakeholder alignment, scope negotiations.

| Category | Meaning | Decision rule |
|----------|---------|---------------|
| **Must** | Product doesn't work without this | Failure to ship = product failure |
| **Should** | Important but not critical | Ship without it if pressed |
| **Could** | Nice to have | Only if time/budget allows |
| **Won't** | Explicitly out of scope this cycle | Documented for future consideration |

**How to use**: Start by putting everything in "Should." Then ask: "If we don't ship
this, does the product fail?" — those are Musts. Then ask: "Would we delay launch for
this?" — remaining Shoulds stay; rest become Coulds.

**Pitfall**: Everything becomes a "Must" under stakeholder pressure. Counter by limiting
Musts to 30% of total scope — if more than 30% is "must-have," the product vision is
too broad.

## Weighted Scoring

Best for: ongoing backlog management with custom dimensions.

Define 3-5 scoring dimensions relevant to your product:

| Dimension | Weight | Description |
|-----------|--------|-------------|
| User impact | 30% | How much it improves target persona's experience |
| Strategic alignment | 25% | How well it supports product vision |
| Revenue potential | 20% | Direct or indirect revenue impact |
| Technical debt reduction | 15% | Reduces maintenance burden |
| Learning value | 10% | Teaches us something about users/market |

Score each item 1-5 on each dimension. Weighted sum = priority.

**Pitfall**: Weights reflect what you value today. Review and adjust weights each cycle
during the Learn phase.

## Choosing a Framework

Ask these questions:

1. **How many items?** <5 → Impact-Effort. 5-20 → RICE or MoSCoW. 20+ → Weighted Scoring.
2. **Who decides?** Technical team → RICE. Mixed stakeholders → MoSCoW. Product owner → any.
3. **How precise?** Quick triage → MoSCoW or Impact-Effort. Quantified ranking → RICE.
4. **Recurring?** One-time → Impact-Effort or MoSCoW. Ongoing → Weighted Scoring.

Don't overthink framework choice. The value is in forcing explicit trade-offs, not in
the specific scoring method.
