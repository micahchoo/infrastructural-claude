# Community Manager Jordan — The Feedback Translator

## Behavioral Profile
- **Primary job**: Translate raw player sentiment into actionable insights for the development team, while keeping the community feeling heard
- **Current tools**: Discord (primary), Steam forums, Reddit, Twitter/X — monitors all manually; uses spreadsheets or Notion to compile weekly summaries for the dev team
- **Pain points**:
  - Spends 15-20 hours/week just reading and categorizing feedback across platforms — most of the role is data entry, not strategic thinking
  - Struggles to quantify sentiment: "players are unhappy about combat" — how many? How unhappy? Compared to what?
  - Gets blamed when the team ships something players didn't want ("why didn't you tell us?") even when they flagged it
  - No way to prove ROI of their role — leadership asks "what did you do this week?" and the answer is "read 500 messages"
- **Workarounds**: Creates elaborate tagging systems in spreadsheets that break down after 2 weeks; uses Discord bot reaction tracking as a poor proxy for sentiment; writes long summary docs that devs skim or skip; manually cross-references Steam reviews with Discord complaints to find patterns
- **Switch trigger**: A tool that automates the aggregation/categorization grunt work so they can focus on interpretation and strategy — and provides artifacts (reports, trend charts) that demonstrate their value to leadership

## Design Implications
- This persona is the power user and daily operator — the tool must be designed for their workflow first
- Automated ingestion from Discord/Steam/Reddit is the core value proposition for this persona
- Categorization and tagging must be flexible (every game has different feedback categories) but come with smart defaults
- Reporting and export capabilities are critical — Jordan needs to produce artifacts that justify their role
- Must not replace Jordan — must amplify them. The tool should make the CM look like a strategic asset, not automate them away

## Evidence
- [Source: founder domain expertise] — community managers in indie game studios consistently describe this "data entry trap"
- [Source: market observation] — CM job postings increasingly list "data analysis" as a requirement, signaling the role is evolving
- [Source: behavioral pattern] — r/communitymanagement and GDC CM roundtables surface the "proving value" struggle repeatedly
