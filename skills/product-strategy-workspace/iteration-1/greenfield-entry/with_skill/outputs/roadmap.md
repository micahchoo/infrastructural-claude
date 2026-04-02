# Product Roadmap — DevPulse

This roadmap is a sequence of bets, not a promise. Each entry is evaluated against the opportunity framing and KPIs defined in this strategy cycle.

---

## Wave 1: "Can we aggregate?" (Weeks 1-4) — Validation MVP

### Bet: Multi-source ingestion into a single view is valuable enough that indie devs will use it weekly

**Why**: Before testing the vision-alignment hypothesis, we need to prove the base layer — that aggregating feedback from multiple sources into one place saves enough time to be worth adopting. If this doesn't work, nothing downstream matters.

**What we're building**:
- Discord bot that captures messages from designated feedback channels
- Manual feedback entry (paste from any source)
- Basic tag-based categorization with game-aware defaults (bug, balance, content, QoL, performance)
- Simple list view with filtering by source, category, date

**Target persona**: Solo Dev Sam (simplest needs, fastest feedback loop)

**Success metric**: KPI-1 (Feedback Triage Time) — does Sam report spending less time on manual reading?

**Leading indicator**: Does Sam return to the tool in week 2? (Retention signal)

**What we're NOT doing**: No Steam/Reddit ingestion, no clustering, no vision scoring, no team features. This is deliberately minimal.

**How we'll know it worked**: 5+ beta users active in week 4, with self-reported time savings.

---

## Wave 2: "Can we make it smart?" (Weeks 5-8) — Intelligence Layer

### Bet: Automated clustering and categorization transforms the tool from "another inbox" to "insight engine"

**Why**: Wave 1 proves aggregation value. Wave 2 tests whether machine intelligence on top of aggregation is meaningfully better than the dev just reading a list. This is where DevPulse differentiates from a spreadsheet.

**What we're building**:
- NLP-powered feedback clustering ("47 players mentioned combat pacing")
- Steam review ingestion (second platform = proves multi-source thesis)
- Trend tracking ("combat complaints up 30% this week")
- Weekly digest email summarizing top themes

**Target persona**: Community Manager Jordan (power user who benefits most from automation)

**Success metric**: KPI-5 (Categorization Accuracy >= 70%) + KPI-1 (time reduction deepens)

**Leading indicator**: Re-categorization rate in first 100 items per user

**What we're NOT doing**: No vision alignment yet, no team features, no public roadmap. Still single-user focused.

**How we'll know it worked**: Jordan-type users report categorization accuracy above 70% and describe the clustering as "useful" (not just "neat").

---

## Wave 3: "Can we filter, not funnel?" (Weeks 9-14) — Core Hypothesis Test

### Bet: Vision-aligned prioritization is meaningfully better than popularity-based prioritization

**Why**: This is the central hypothesis. If developers just want to see what's popular, Canny wins. DevPulse bets that developers want to evaluate feedback against their own creative direction — and that this produces better games and healthier communities.

**What we're building**:
- "Game Vision" setup flow (developer articulates direction, themes, values)
- Vision alignment scoring (each feedback cluster scored against stated vision)
- Priority recommendation engine ("high player demand + high vision alignment = strong signal")
- "Why not" templates (helps developers communicate decisions back to players)
- Reddit ingestion (third platform)

**Target persona**: Solo Dev Sam + Studio Lead Alex (decision-makers who need prioritization help)

**Success metric**: KPI-2 (Decision Confidence >= 4.0) — do developers feel more confident about what to build?

**Leading indicator**: Do developers actually set up a game vision? (If <30% complete setup, the feature has a UX problem)

**What we're NOT doing**: No team features yet, no deep integrations, no competitive benchmarking.

**How we'll know it worked**: Developers describe the prioritization as changing their decision process, not just confirming what they already thought. "It helped me say no to X" is the golden signal.

---

## Wave 4: "Can teams use this?" (Weeks 15-20) — Team & Growth

### Bet: Expanding from single-user to team use unlocks the small studio market (higher willingness to pay, lower churn)

**Why**: Solo devs validate the product. Small studios pay for it. Alex's team needs shared views and collaboration to replace the "everyone has a different read" problem.

**What we're building**:
- Multi-user accounts with team roles (owner, editor, viewer)
- Shared dashboard with team-visible feedback themes and decisions
- Export to CSV/JSON (bridges to Jira/Linear/Notion)
- Public roadmap page (closes the player communication loop — KPI-3)

**Target persona**: Studio Lead Alex + Community Manager Jordan (team workflow)

**Success metric**: KPI-3 (Loop Closure >= 60%) + team retention > individual retention

**What we're NOT doing**: No Jira/Linear native integration (CSV covers 80%), no in-game widget, no multi-language support.

---

## Future Waves (post-validation, not committed)

- **Jira/Linear/Notion native integrations** — only after validating team adoption
- **In-game feedback widget SDK** — only after proving multi-platform ingestion is insufficient
- **Multi-language support** — only after English market is validated
- **Competitive benchmarking** — only if users request it AND it aligns with the "filter not funnel" positioning
- **API for custom integrations** — only after the product stabilizes

---

## Roadmap as Strategy Map

```
Week:    1─────4    5─────8    9──────14    15─────20
         │         │          │            │
Wave 1:  ██████████│          │            │
         Aggregate │          │            │
         (Sam)     │          │            │
                   │          │            │
Wave 2:            ██████████ │            │
                   Intelligence            │
                   (Jordan)   │            │
                              │            │
Wave 3:                       █████████████│
                              Filter Hypothesis
                              (Sam + Alex) │
                                           │
Wave 4:                                    ██████████
                                           Teams
                                           (Alex + Jordan)

KPI gates:  ▲ KPI-1      ▲ KPI-5      ▲ KPI-2        ▲ KPI-3
            Time saved?   Accuracy?    Confidence?     Loop closed?
```

Each wave has a KPI gate. If a gate fails, we pivot before investing in the next wave. This is a sequence of bets, not a waterfall.
