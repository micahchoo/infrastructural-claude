# Competitive Landscape & Positioning

## Direct Competitors (Feedback Collection for Games)

### None exist specifically for indie game devs.

This is both the opportunity and the warning sign. Either the market is untapped, or previous attempts failed quietly. Investigate both possibilities during validation.

## Adjacent Competitors

### Canny (canny.io)
- **What it does**: Feature request voting boards for SaaS
- **Why devs try it**: It's the most "feedback-shaped" tool they find
- **Why it fails for games**: Voting creates tyranny of the majority. Game balance decisions shouldn't be democratic. No sentiment analysis. No multi-source aggregation. Pricing starts at $79/mo — expensive for indie.
- **Lesson**: The voting paradigm is wrong for games. Don't copy it.

### Nolt
- **Similar to Canny**, slightly cheaper. Same limitations apply.

### UserVoice
- **Enterprise feedback management**. Way too heavy, too expensive, wrong mental model for games.

### FeatureUpvote
- **Simpler voting board**. Same voting-paradigm problem.

### Discord bot ecosystem (Suggestion Bot, Feedback Bot, etc.)
- **What they do**: Collect suggestions in a structured channel, sometimes with upvote reactions
- **Why they're limited**: No synthesis, no clustering, no cross-channel view, no strategic layer
- **Lesson**: The collection layer is commoditized. The intelligence layer is the value.

### Notion/Airtable templates
- **What devs actually use**: Manual databases where they copy-paste feedback
- **Why it works (sort of)**: Flexible, familiar, free
- **Why it breaks**: Requires manual effort to maintain, no aggregation, no dedup, collapses under volume
- **Lesson**: Many devs are doing this manually. That's your clearest signal of demand.

## Indirect Competitors

### Steam's built-in tools
- Store analytics, review stats, forum moderation
- Useful but siloed to Steam only, no synthesis, no cross-platform view

### Amplitude/Mixpanel (behavioral analytics)
- Tells you what players DO, not what they THINK
- Complementary, not competitive — but devs may confuse "I have analytics" with "I understand my players"

### Social listening tools (Brandwatch, Mention, etc.)
- Built for brands, not game devs
- Too expensive, wrong vocabulary, no game-specific understanding

## Positioning Map

```
                    Multi-source aggregation
                           ↑
                           |
    Notion templates       |       [YOUR PRODUCT]
    (manual, flexible)     |       (automated, game-aware)
                           |
  ←─────────────────────────────────────────────→
  Raw collection                    Strategic intelligence
                           |
    Discord bots           |       Canny/Nolt
    (automated, narrow)    |       (structured, SaaS-oriented)
                           |
                           ↓
                    Single-source only
```

## Your Defensible Position

1. **Game-specific ontology**: Understanding that "nerf the sword" and "melee is OP" and "I keep dying to warriors" are the same cluster requires game-domain knowledge. Generic NLP misses this.
2. **The framework, not just the tool**: If you publish the definitive "how to think about player feedback" framework (articles, talks, templates), you own the category definition. Competitors build to your frame.
3. **Network effects (weak but real)**: As you process more game feedback, your classification improves. Games in similar genres benefit from shared patterns.
4. **Integration depth over breadth**: Deep Discord integration (threading, role-based weighting, channel-aware context) beats shallow multi-platform.

## What Could Kill This

| Threat | Likelihood | Mitigation |
|--------|-----------|------------|
| Discord builds native feedback tools | Low-medium | They've shown no interest; focus is on social, not dev tooling |
| Canny pivots to games vertical | Low | Their architecture assumes voting-based prioritization |
| LLM commoditization makes DIY easy | Medium | Any dev CAN build this with ChatGPT + scripts. Your value is doing it well, consistently, integrated |
| Market too small to sustain a business | Medium | ~50K active indie games on Steam. If 2% convert at $15/mo = $180K ARR. Enough for a small team, not VC-scale |
| Devs won't pay (prefer free/manual) | Medium-high | Biggest real risk. Validate hard in Phase 0 |
