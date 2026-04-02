# Strategic Brief — Wave 1: Aggregation MVP (from product-strategy)

**Target persona**: Solo Dev Sam — solo indie developer who spends 5-10 hrs/week manually reading feedback across Discord, Steam forums, and Reddit, then makes priority decisions based on gut feeling and incomplete information.

**Success metric**: KPI-1 (Feedback Triage Time Reduction) — baseline 5-10 hrs/week self-reported, target 50% reduction within 30 days of active use. Measured via weekly in-app survey prompt.

**Priority rationale**: Aggregation is the foundational layer. Without multi-source ingestion, the intelligence layer (Wave 2) and vision-alignment hypothesis (Wave 3) have nothing to operate on. Discord is the #1 channel — Solo Dev Sam says "Discord is where my players are." Starting with Discord + manual entry proves the aggregation thesis with minimum engineering investment.

**Constraints**:
- Single-user only — no team features, no collaboration
- Discord ingestion + manual entry only — no Steam/Reddit API integration yet
- No NLP/clustering — categorization is manual with smart defaults (game-aware tag presets)
- No vision alignment scoring — that's the Wave 3 hypothesis test
- Must work for a developer with 50-500 active community members (not 50,000 — scale is a post-validation concern)
- Target price point: free tier or <$10/mo — solo devs pay out of pocket
- Must be usable within 10 minutes of signup — solo devs abandon complex onboarding

**Competitive context**: Canny requires players to visit a separate site (high friction). Discord bots capture suggestions but offer no categorization or cross-platform aggregation. DevPulse Wave 1 meets players where they are (Discord) and provides structure that bots lack — without the overhead of a full feedback platform.

**Kill criteria**: If fewer than 5 of 20 beta users return in week 2, the aggregation thesis is wrong and the product should not proceed to Wave 2. Investigate whether the problem is the solution (wrong approach) or the distribution (right approach, wrong users).
