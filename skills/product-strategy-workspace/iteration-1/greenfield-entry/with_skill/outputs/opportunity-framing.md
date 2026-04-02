# Opportunity Framing

## Opportunity Statements

**Primary**: For solo and small-studio indie game developers (Sam, Alex), who spend hours manually reading scattered feedback yet still make priority decisions based on gut feeling, DevPulse provides an automated multi-platform feedback hub with vision-aligned prioritization — unlike Canny (requires players to use a separate site) or Steam analytics (read-only, single platform).

**Secondary**: For community managers at indie studios (Jordan), who spend 15-20 hours/week on feedback aggregation data entry with no way to prove ROI, DevPulse automates ingestion and categorization — unlike spreadsheets (manual, inconsistent) or Discord bots (single-platform, no analysis).

## Compound Probability Assessment (bias:conjunction)

This opportunity depends on multiple conditions being true simultaneously. Independent estimates:

| Condition | Probability | Rationale |
|-----------|-------------|-----------|
| Indie devs will pay for feedback tooling | 65% | Evidence: they pay for analytics (SteamDB premium), marketing (Keymailer), and wishlisting tools. Feedback is a known pain. But price sensitivity is real — must be under $20/mo for solo devs. |
| Multi-platform ingestion is technically feasible at indie pricing | 80% | Discord and Reddit APIs are accessible. Steam reviews are scrapeable. NLP costs have dropped. The technical risk is moderate, not high. |
| "Vision alignment" scoring is meaningfully better than popularity voting | 55% | This is the core bet. If developers just want a voting board, Canny wins. The hypothesis is that devs want a FILTER, not a FUNNEL. Needs validation. |
| Market timing is right (not too early, not too late) | 70% | Indie market is growing, community expectations are rising, no dominant player in this niche yet. Risk: a well-funded competitor could enter. |

**Compound probability** (all four): ~20%. This is honest — most products fail. The mitigation is to validate the riskiest assumption first (vision alignment scoring, 55%) before investing heavily in the others.

## Known Gaps (bias:wysiati)

- **Personas not interviewed**: Mid-size studios (20-50 people) with dedicated CM teams — they might be a better initial market but we haven't researched them
- **Competitors not analyzed**: Game-specific community platforms like Paradox Mods, Nexus Mods community features, or Chinese market equivalents (TapTap)
- **User needs not explored**: Localization challenges (non-English feedback), moderation overlap (is feedback management intertwined with community moderation?), the role of content creators/streamers as feedback proxies
- **Technical risks not assessed**: API rate limits and terms of service for Discord/Steam/Reddit ingestion at scale; GDPR implications of aggregating user-generated content across platforms
