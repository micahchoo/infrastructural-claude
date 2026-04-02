# Prioritization — DevPulse MVP

## Framework Selection: Impact-Effort Matrix

**Why this framework**: Small founding team (1 person + potential early collaborators), few competing options at MVP stage, need depth of reasoning over numerical precision. Impact-Effort gives visual clarity and supports the "what do we build first?" conversation better than RICE (which needs reach data we don't have) or MoSCoW (too coarse for sequencing).

## Prioritized Feature Map

### High Impact, Low Effort — DO FIRST

| Feature | Impact | Effort | Evidence | Persona |
|---------|--------|--------|----------|---------|
| **Discord bot ingestion** | Captures feedback from the #1 channel where indie players talk | Bot API is well-documented; basic message collection is straightforward | Sam: "Discord is where my players are"; Jordan: "I spend most time reading Discord" | Sam, Jordan |
| **Manual feedback entry** | Allows import of feedback from any source (fallback for platforms without API integration) | Basic CRUD interface | All personas need a way to add feedback that isn't auto-ingested | Sam, Alex, Jordan |
| **Tag-based categorization with game-aware defaults** | Reduces categorization time; game-specific defaults (bug, balance, content request, QoL, performance) beat generic labels | Predefined tag taxonomy + user-editable tags | Jordan: "I build elaborate tagging systems that break down"; Sam: "I can't tell bugs from feature requests from complaints" | Jordan, Sam |
| **Feedback cluster view** (group similar items) | Transforms noise into signal — "47 players mentioned combat pacing" vs. reading 47 individual messages | NLP topic clustering (can use off-the-shelf LLM API) | Alex: "everyone reads different channels and forms different impressions" — clustering creates shared truth | Alex, Jordan |

### High Impact, High Effort — DO SECOND (post-MVP)

| Feature | Impact | Effort | Evidence | Persona |
|---------|--------|--------|----------|---------|
| **Steam review ingestion** | Second-most important feedback source; review sentiment shifts blindside teams | Steam review scraping has anti-bot measures; sentiment analysis adds complexity | Alex: "Steam review sentiment shifts can blindside the team" | Alex, Jordan |
| **Reddit ingestion** | Third major feedback channel; captures longer-form player analysis | Reddit API has rate limits and auth complexity | Sam: feedback scattered across 3+ platforms | Sam, Jordan |
| **Vision alignment scoring** | Core differentiator — "does this feedback align with where I'm taking the game?" | Requires developer to articulate game vision + matching algorithm (LLM-based) | This is the central bet (opportunity framing: 55% probability hypothesis) | Sam, Alex |
| **Team dashboard with shared views** | Enables Alex's team to have a single source of truth | Multi-user auth, permissions, shared state | Alex: "team disagrees on priorities because everyone reads different channels" | Alex, Jordan |

### Low Impact, Low Effort — DO IF TIME

| Feature | Impact | Effort | Evidence | Persona |
|---------|--------|--------|----------|---------|
| **Weekly digest email** | Builds habit + provides measurement data | Template email on cron | Supports KPI measurement infrastructure | All |
| **Export to CSV** | Bridges to existing workflows (spreadsheets, Jira import) | Standard export function | Jordan: "I create elaborate tagging systems in spreadsheets" — CSV export eases migration | Jordan |
| **Public roadmap page** | Closes the player communication loop | Static page generated from "decided" items | Supports KPI-3 (loop closure) | Sam |

### Low Impact, High Effort — DO NOT DO (explicit trade-offs)

| Feature | Why Not |
|---------|---------|
| **In-game feedback widget** | High integration effort per game engine; Discord/Steam already capture this; revisit post-PMF |
| **Automated response generation** | Risk of inauthentic communication; developers must own their voice; the tool should surface insights, not speak for the dev |
| **Competitive benchmarking** ("your game vs. similar games") | Requires massive data aggregation across games; interesting but not core to the "what should I build" problem |
| **Jira/Linear deep integration** | Important for Alex eventually, but premature before validating core value; CSV export covers 80% of the need |
| **Multi-language feedback support** | Important market (Asian, European devs) but multiplies NLP complexity; English-first, expand later |

## Prioritization Rationale Summary

The MVP sequence optimizes for one thing: **validate the core hypothesis as fast as possible**. The core hypothesis is that developers want a feedback filter (vision-aligned prioritization), not a feedback funnel (more feedback surfaced).

The fastest path to validation:
1. Get feedback INTO the tool (Discord bot + manual entry — low effort, immediate value)
2. Make feedback UNDERSTANDABLE (categorization + clustering — moderate effort, proves the aggregation value)
3. Test the FILTER hypothesis (vision alignment scoring — high effort, but this is the entire bet)

Everything else is sequenced after the hypothesis is validated or invalidated.
