# Studio Lead Alex — The Small Studio Decision-Maker

## Behavioral Profile
- **Primary job**: Align a 3-8 person team around what to build next, using player feedback as input (not dictation) for sprint planning
- **Current tools**: Jira/Linear for task tracking, Discord community, Steam reviews, a community manager who summarizes feedback verbally in standups
- **Pain points**:
  - Community manager's verbal summaries are lossy and biased toward recency — decisions get made on incomplete data
  - Team disagrees on priorities because everyone reads different feedback channels and forms different impressions
  - No shared artifact that maps player needs to development priorities — arguments devolve into "I saw a player say..."
  - Steam review sentiment shifts can blindside the team because nobody systematically tracks trends over time
- **Workarounds**: Community manager maintains a Google Doc of "top requests" updated weekly; team votes on priorities in standups (but votes reflect who spoke loudest, not evidence); occasionally uses Steam review analysis tools but they don't connect to Discord/Reddit feedback
- **Switch trigger**: A tool that gives the whole team a shared, evidence-based view of player needs — replacing anecdotal "I saw a player say..." with traceable, quantified demand signals that integrate into their existing sprint planning workflow

## Design Implications
- Must support team collaboration — shared dashboards, not just individual views
- Integration with existing project management tools (Jira, Linear, Notion) is important for adoption
- The "community manager" role needs first-class support — they're the primary operator, but the studio lead is the buyer
- Trend tracking over time matters more than point-in-time snapshots — Alex needs to see "is this getting worse?"
- Pricing can be per-team, not per-seat — studio budgets are small but not zero

## Evidence
- [Source: founder domain expertise] — observed in studios the founder has worked with or alongside
- [Source: market observation] — GDC talks and postmortems frequently cite "misaligned team priorities" as a shipping risk
- [Source: behavioral pattern] — small studios on r/gamedev describe the "everyone has a different read on the community" problem
