# Problem Analysis: Indie Game Dev Feedback Hub

## The Core Problem

Indie game developers face a **feedback triage crisis**. The failure mode is bimodal:

1. **Ignore mode**: Dev gets overwhelmed by volume/noise, stops reading feedback entirely. Community feels unheard, churn increases.
2. **Firehose mode**: Dev tries to implement everything, roadmap becomes player-driven, game loses creative coherence, dev burns out.

The missing capability is **strategic filtering** — a way to see what players actually need (vs. what they say they want), weighed against the game's creative vision and development capacity.

## Why This Problem Persists

### Existing tools don't fit
- **Trello/Linear/Jira**: Project management tools, not feedback intelligence. They track work, not sentiment.
- **Discord bots**: Collect reactions/votes but provide no synthesis or prioritization framework.
- **Steam forums/Reddit**: Read-only firehoses with no structured extraction.
- **Canny/UserVoice**: Designed for SaaS, not games. Voting systems bias toward vocal minorities and feature-request framing. Games need different signal types (bug feel, balance sentiment, content appetite).
- **Spreadsheets**: Where feedback goes to die. No aggregation, no deduplication, no trend detection.

### Game feedback is structurally different from SaaS feedback
| Dimension | SaaS Feedback | Game Feedback |
|-----------|--------------|---------------|
| Signal type | Feature requests, bugs | Feel, balance, pacing, content hunger, social dynamics |
| Urgency curve | Linear (users leave gradually) | Spiky (launch windows, update cycles, streamer events) |
| Creator vision | Product-market fit driven | Artistic vision + market fit tension |
| Community dynamics | Users are individuals | Players form social ecosystems with emergent norms |
| Volume pattern | Steady trickle | Burst on update, silence between |

### The real job-to-be-done
The dev doesn't need "a place to collect feedback." They need:
1. **Signal extraction**: What are players actually experiencing? (Not just what they're requesting)
2. **Pattern recognition**: Which signals cluster into themes?
3. **Strategic weighting**: Which themes align with the game's direction AND have the highest impact-to-effort ratio?
4. **Communication closure**: How do I tell players "heard you, here's what we're doing and why"?

## Who Feels This Pain Most

### Primary persona: Solo/small-team indie dev (1-5 people)
- Has a game in Early Access or recently launched
- 500-50,000 players across Discord + Steam
- Spends 2-5 hours/week manually reading feedback
- Feels guilty about what they're missing
- Has no dedicated community manager

### Secondary persona: Community manager for mid-size indie studio
- Manages feedback for 1-3 active titles
- Manually aggregates from 3+ channels
- Creates weekly reports for the dev team
- Frustrated by signal-to-noise ratio

### Anti-persona: AAA studios
- Already have dedicated tools, teams, and budgets
- Their problem is organizational, not tooling

## Market Timing

- **Steam Early Access** is the dominant indie launch strategy — feedback loops are the product
- **Discord** has become the default community platform for games, but has zero built-in feedback tooling
- **AI/LLM capabilities** now make semantic clustering and sentiment extraction feasible at indie-budget scale
- **Creator economy tools** (Patreon, Ko-fi) have trained creators to think about audience relationships — game devs are next

## Key Risks to Validate

1. **Will devs pay for this?** Indie devs are notoriously cost-sensitive. Need to validate willingness-to-pay at $15-30/mo range.
2. **Is manual triage actually the bottleneck?** Or is the real problem that devs don't have a decision framework? (Tool vs. education)
3. **Can you get good enough data from APIs?** Discord API, Steam API, and Reddit API all have rate limits and access constraints.
4. **Does aggregation create false confidence?** Risk that devs over-index on "the tool says X" without understanding nuance.
