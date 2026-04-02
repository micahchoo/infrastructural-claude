# Risks, Assumptions, and Open Questions

## Critical Assumptions (Must Validate)

### A1: Indie devs actively struggle with feedback triage
- **Assumption**: Devs spend meaningful time on feedback and find it painful
- **Risk if wrong**: The problem is real but not painful enough to pay for
- **Validation method**: Phase 0 interviews — look for workarounds, time spent, emotional weight
- **Kill criterion**: Fewer than 5 of 12 interviewees describe active pain

### A2: Synthesis changes behavior
- **Assumption**: When devs see organized, clustered feedback, they make different (better) decisions
- **Risk if wrong**: Devs already know what players want — the bottleneck is elsewhere (time, skill, resources)
- **Validation method**: Concierge MVP — does the digest change what they work on?
- **Kill criterion**: 0 of 3 concierge devs change behavior based on digest

### A3: LLMs can reliably classify game feedback
- **Assumption**: Current LLMs can distinguish between bug reports, balance complaints, feature requests, and venting with >85% accuracy
- **Risk if wrong**: Classification errors erode trust; devs stop using the tool
- **Validation method**: Take 200 real feedback messages, manually label, test against LLM classification
- **Kill criterion**: Accuracy below 75% on real data

### A4: Devs will pay $15/mo
- **Assumption**: The value justifies a monthly subscription at indie-friendly pricing
- **Risk if wrong**: Market exists but revenue won't sustain development
- **Validation method**: Direct pricing questions in interviews + concierge willingness-to-pay test
- **Kill criterion**: Fewer than 3 of 12 interviewees say they'd pay at $15/mo

### A5: Discord API access is sufficient
- **Assumption**: A Discord bot can access message history and real-time messages in feedback channels without friction
- **Risk if wrong**: API rate limits, permission complexity, or Terms of Service changes break the core pipeline
- **Validation method**: Build a proof-of-concept bot that reads and classifies messages from one channel
- **Kill criterion**: Rate limits prevent processing >1000 messages/day per server

## Secondary Risks

### R1: Privacy and data sensitivity
- Player messages may contain personal information, offensive content, or context that shouldn't leave Discord
- **Mitigation**: Process messages through classification, store only extracted themes + anonymized quotes. Never store raw messages outside the dev's own dashboard. Make data retention policies clear.

### R2: Community manipulation
- Organized groups could flood feedback channels to manipulate priorities
- **Mitigation**: Weight signals by unique users, not message volume. Flag sudden spikes. Show "N unique players mentioned this" not just mention count.

### R3: Over-reliance on tool recommendations
- Devs might abdicate creative judgment to "what the tool says"
- **Mitigation**: Frame as "here's what players are experiencing" not "here's what you should build." Never auto-generate a roadmap. Keep the human in the decision seat.

### R4: Single-platform dependency (Discord)
- If Discord changes API terms, rate limits, or bot policies, the core product breaks
- **Mitigation**: Abstract the ingestion layer. Store processed data independent of source. Plan Steam and Reddit integration early in roadmap (Phase 2).

### R5: Scope creep toward analytics
- Natural temptation to add dashboards, charts, metrics, and trends
- **Mitigation**: The product is a decision tool, not an analytics platform. Every feature should answer "what should I build next?" not "what happened?"

## Open Questions (Require Research)

### Q1: What's the actual TAM?
- How many indie games have active communities on Discord?
- How many of those are in Early Access (highest feedback volume)?
- What percentage of those devs are solo vs. small team?
- Starting estimate: ~50K active indie games on Steam, ~20% have active Discord, ~10K addressable, ~2% conversion = 200 users. Enough?

### Q2: Is this a tool or a service?
- The concierge MVP might reveal that the value is in human judgment, not data processing
- If so, the right product might be "fractional community analyst" not "SaaS dashboard"
- Stay open to this pivot during validation

### Q3: Should the tool be opinionated?
- Should it just present data, or should it recommend priorities?
- Opinionated = higher value but higher risk of bad recommendations
- Neutral = safer but might not differentiate from a spreadsheet
- Let concierge testing answer this — which digest format drives action?

### Q4: What about games without Discord?
- Some devs rely solely on Steam forums or Reddit
- Is Discord-first excluding a meaningful segment?
- Research during interviews: what percentage of target devs have active Discords?

### Q5: Multiplayer vs. single-player dynamics
- Feedback patterns differ dramatically between these genres
- Multiplayer: balance, matchmaking, social features dominate
- Single-player: content, difficulty, story, performance dominate
- Does the tool need genre-aware classification from day one?

## Decision Log Template

Use this as you work through validation:

| Date | Decision | Evidence | Confidence | Revisit By |
|------|----------|----------|------------|------------|
| | | | | |

Fill this in weekly. When confidence drops below "medium" on any critical assumption, that's your signal to pivot or kill.
