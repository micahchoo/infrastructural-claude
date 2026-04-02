# DevPulse — Product Strategy Overview (Cycle 1)

## One-Line Vision

DevPulse helps indie game developers treat player feedback as evidence for strategic decisions — not as a popularity contest or an obligation to build everything.

## The Problem in One Paragraph

Indie game developers face a false binary: ignore community feedback entirely, or try to build everything players ask for. Feedback is fragmented across Discord, Steam, and Reddit. No tool helps developers aggregate it, filter it through their creative vision, and make confident prioritization decisions. The result: 5-20 hours/week wasted on manual reading, gut-feel priority decisions, and eroding community trust when players feel unheard.

## Three Personas

| Persona | Role | Primary Pain | Switch Trigger |
|---------|------|-------------|----------------|
| **Solo Dev Sam** | Solo indie developer | 5-10 hrs/week manual reading, feedback paralysis | Saves 3+ hrs/week AND helps say "no" confidently |
| **Studio Lead Alex** | Small studio (3-8 person) lead | Team has no shared truth about player needs | Shared evidence-based view replaces anecdotal impressions |
| **Community Manager Jordan** | CM at indie studio | 15-20 hrs/week data entry, can't prove ROI | Automates aggregation so they can focus on strategy |

## Core Hypothesis

Developers want a **feedback filter, not a feedback funnel**. The value is in helping them decide what NOT to build (with confidence and communication templates) as much as what TO build. If developers actually just want a voting board, Canny wins and this product should not exist.

## Competitive Positioning

No existing tool combines: (1) multi-platform ingestion (meet players where they are), (2) game-specific intelligence (categorization that understands balance vs. bug vs. content requests), and (3) vision-aligned prioritization (filter feedback through the developer's creative direction) — at indie-friendly pricing.

## Four-Wave Roadmap

| Wave | Weeks | Bet | KPI Gate |
|------|-------|-----|----------|
| 1. Aggregate | 1-4 | Multi-source ingestion saves time | KPI-1: 50% triage time reduction |
| 2. Intelligize | 5-8 | Clustering transforms inbox into insights | KPI-5: 70% categorization accuracy |
| 3. Filter | 9-14 | Vision alignment beats popularity voting | KPI-2: Decision confidence >= 4.0 |
| 4. Teamify | 15-20 | Shared views unlock studio market | KPI-3: 60% feedback loop closure |

Each wave has a kill/pivot gate. If a gate fails, investigate before proceeding.

## Key Success Metrics

| KPI | What It Measures | Target |
|-----|-----------------|--------|
| KPI-1: Triage Time | Hours saved on feedback reading | 50% reduction in 30 days |
| KPI-2: Decision Confidence | Developer confidence in priorities | >= 4.0/5.0 in 60 days |
| KPI-3: Loop Closure | Feedback themes publicly addressed | >= 60% in 90 days |
| KPI-4: Platform Coverage | Ingestion sources at MVP | 3 (Discord, Steam, Reddit) |
| KPI-5: Categorization Accuracy | Auto-categorization acceptance rate | >= 70% |

## Riskiest Assumption

Vision alignment scoring (Wave 3) is the entire bet, estimated at 55% probability of being meaningfully better than popularity voting. Validate early with paper prototypes or Wizard-of-Oz testing before building the full scoring engine.

## Where to Start (next action)

1. **Validate the hypothesis cheaply**: Interview 5-10 indie devs about their feedback workflow. Ask: "When you get conflicting feedback, how do you decide?" If the answer is "I go with what most people want" — the filter hypothesis may be wrong. If the answer is "I try to figure out what fits my vision" — the filter hypothesis has legs.

2. **Build Wave 1 MVP**: Discord bot + manual entry + game-aware tagging. Ship in 4 weeks. Target 20 beta users from your existing game dev network.

3. **Measure KPI-1 ruthlessly**: If triage time doesn't drop by 50%, the aggregation layer has a UX problem. Fix before proceeding.

## Artifact Index

| Artifact | Path | Phase |
|----------|------|-------|
| Persona: Solo Dev Sam | `personas/solo-dev-sam.md` | 1a |
| Persona: Studio Lead Alex | `personas/studio-lead-alex.md` | 1a |
| Persona: Community Manager Jordan | `personas/community-manager-jordan.md` | 1a |
| Competitive Landscape | `competitive-landscape.md` | 1b |
| Opportunity Framing | `opportunity-framing.md` | 1c |
| Product Vision | `vision.md` | 2a |
| Success Metrics (KPIs) | `kpis.md` | 2b |
| Prioritization | `prioritization.md` | 2c |
| Roadmap | `roadmap.md` | 2d |
| Strategic Brief (Wave 1) | `briefs/strategic-brief-wave1.md` | 3 |
| This overview | `strategy-overview.md` | — |
