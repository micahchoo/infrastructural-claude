# Strategic Recommendations: Where to Start

## Recommended Approach: Start Narrow, Prove the Core Loop

Don't build a platform. Build a **decision tool** that proves one hypothesis: *structured feedback triage changes what indie devs build next*.

## Phase 0: Validate Before Building (Weeks 1-3)

### Do this first
1. **Interview 10-15 indie devs** in Early Access. Ask: "Walk me through the last time player feedback changed your roadmap." Listen for the pain, the process, the workarounds.
2. **Shadow 3-5 devs** doing their weekly feedback review. Watch what they actually do vs. what they say they do.
3. **Manual concierge test**: For 3 devs, YOU do the feedback synthesis manually for 2 weeks. Deliver a weekly "feedback digest" and see if it changes their behavior.

### What you're validating
- Do devs change behavior when given synthesized feedback? (If not, tool doesn't matter)
- What format/framing makes the digest actionable?
- Which source (Discord/Steam/Reddit) has the highest signal density?

## Phase 1: Discord-Only MVP (Weeks 4-10)

### Why Discord first
- Highest signal density for active indie games
- Best API access (bot integration)
- Where the most engaged players congregate
- Real-time stream means you can show value quickly

### The MVP is a Discord bot + web dashboard
**Bot capabilities:**
- Monitors specified channels (e.g., #feedback, #suggestions, #bug-reports)
- Classifies messages into categories: bug report, feature request, balance feedback, praise, frustration vent, question
- Extracts the underlying need (not the surface request)
- Deduplicates similar feedback into clusters

**Dashboard capabilities:**
- Shows feedback clusters ranked by frequency and sentiment intensity
- Each cluster shows representative quotes (not just counts)
- Dev can tag clusters with: "planned", "considering", "won't do (with reason)", "shipped"
- Simple impact vs. effort matrix view (dev manually places clusters)
- Weekly trend view: what's rising, what's fading

### What this deliberately lacks
- No Steam/Reddit integration yet (reduces scope)
- No automated prioritization (dev makes the call, tool provides clarity)
- No public-facing roadmap (that's a feature for later, and a separate product decision)
- No analytics/metrics dashboards (resist the urge)

## Phase 2: Close the Loop (Weeks 11-16)

The most underserved part of the feedback cycle is **telling players what happened**.

### Add response automation
- When dev marks a cluster as "shipped" or "planned", bot can post a summary to a designated channel
- Template: "We heard from {N} of you about {theme}. Here's what we're doing: {dev's note}"
- This is the retention flywheel — players who feel heard give more (and better) feedback

### Add Steam integration
- Steam forum scraping (API is limited, may need scraping)
- Steam review sentiment tracking (especially "Recent" vs. "Overall" divergence)
- Merge Steam signals into existing clusters

## Phase 3: Intelligence Layer (Weeks 17-24)

### Now you've earned the right to get smart
- **Trend prediction**: "This theme is accelerating — 3x mentions this week vs. last"
- **Sentiment shift detection**: "Players are talking about combat less, but angrier when they do"
- **Cross-channel correlation**: "Steam reviewers mention X, but Discord regulars don't — different populations"
- **Update impact measurement**: "After patch 0.4.2, complaints about Y dropped 60%"

## Technical Architecture Recommendations

### Start simple, stay boring
```
Discord Bot (Node.js or Python)
    ↓
Message Queue (Redis or even SQLite for MVP)
    ↓
Classification Service (OpenAI API or local model)
    ↓
PostgreSQL (feedback store, clusters, dev annotations)
    ↓
Web Dashboard (Next.js or similar)
```

### Key technical decisions
1. **Use LLMs for classification, not rules**. Feedback language is too varied for regex/keyword matching. A prompted GPT-4o-mini call per message is cheap (~$0.01/1000 messages) and dramatically more accurate.
2. **Cluster incrementally, not batch**. New feedback should join existing clusters in near-real-time, not wait for a nightly job.
3. **Store raw messages forever**. Your classification will improve — you'll want to re-process.
4. **Build the bot as a separate service from the dashboard**. Different scaling profiles, different deployment needs.

### What NOT to build
- Don't build your own NLP pipeline. Use API-based LLMs. You're a product company, not an ML company.
- Don't build real-time collaboration features. One dev looking at a dashboard is the use case.
- Don't build a mobile app. Web dashboard is fine.
- Don't build Slack integration. Game devs use Discord, not Slack.

## Business Model Thinking

### Pricing structure
- **Free tier**: 1 Discord server, 1 channel monitored, 7-day history, basic clustering
- **Indie tier ($15/mo)**: 1 server, unlimited channels, full history, all cluster features, Steam integration
- **Studio tier ($39/mo)**: Multiple servers, team access, API access, priority support

### Why these prices
- $15/mo is "don't even think about it" money for a dev making any revenue
- Below the threshold where purchase approval is needed at small studios
- High enough to filter out non-serious users who would create support load

### Growth strategy
- **Content marketing**: Write the articles/guides about feedback triage that don't exist yet. Become the authority on "how indie devs should handle player feedback." This is your moat — the tool is a commodity, the framework is not.
- **Discord server presence**: Be in the big indie dev Discords (Indie Game Devs, Game Dev League, etc.). Help people manually. Build trust.
- **Showcase devs**: Find 3-5 devs whose games visibly improved because of better feedback triage. Tell their stories.

## The One Thing That Matters Most

Your biggest risk is not technical. It's **building a data tool when devs need a decision framework**.

The tool should feel like a wise advisor who has read everything and says: "Here's what your players are actually telling you, here are the three things that matter most right now, and here's why." Not a dashboard with charts.

If the first reaction is "cool data" instead of "now I know what to build next," you've failed.
