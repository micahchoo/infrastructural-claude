# Quality Criteria for Domain Codebooks

Eval-protocol rubric for grading a completed codebook. Every codebook must pass these before shipping.

## Expectations

### Completeness
`[eval: completeness]` "Every domain axis identified in Stage 1 has at least one reference file."

A codebook that covers mutation sync and collaboration but ignores persistence is incomplete if persistence was identified as a gap.

### Depth — Competing Patterns
`[eval: depth]` "Each reference file presents 3+ competing patterns, not a single recommendation."

One-answer references are lectures. A codebook presents the design space: "Here are 4 ways to solve this. Here's when each is right." If only one approach exists, document why alternatives were rejected.

### Shape — Decision Gates
`[eval: shape]` "Decision gates ask project-specific questions before recommending a pattern."

Not "use Pattern A" but "If your collaboration model is server-authoritative, use Pattern A. If P2P, use Pattern B. If offline-first, use Pattern C." The gate questions should be answerable by someone who knows their project requirements.

### Boundary — Anti-Patterns
`[eval: boundary]` "Anti-patterns documented with concrete consequences, not vague warnings."

Not "don't use global state" but "global state causes [specific problem] in [this domain] because [mechanism]. We saw this in [production system] when [incident]."

### Depth — Production Examples
`[eval: depth]` "Each reference file cites 2+ real production systems with specific architectural decisions."

One system's approach could be idiosyncratic. Two or more systems solving the same problem differently reveal the actual design space and validate that the competing patterns are real, not hypothetical.

### Approach — Forces via De-factoring
`[eval: approach]` "Every force claim traces to de-factoring evidence, not assumption."

Not "this pattern provides flexibility" but "removing this pattern made it impossible to [specific thing] without [specific cost], as demonstrated when [characterization test X broke / code became Y]."

### Boundary — Trigger Discrimination
`[eval: boundary]` "Trigger description has positive triggers, negative space, diffused user phrasings, and a distinguishing test."

The trigger should fire for queries in this domain and NOT fire for adjacent domains. Test with 5+ should-trigger and 5+ should-not-trigger examples.

## Pre-Ship Checklist

Machine-readable gate — every item must be YES before shipping to `domain-codebooks/`.

| # | Check | Criteria |
|---|-------|----------|
| 1 | Reference files | Every domain axis identified in Stage 1 has at least one reference file |
| 2 | Competing patterns | Each reference file presents 3+ competing patterns (or documents why fewer exist) |
| 3 | Decision gates | Project-specific questions before recommending a pattern — not "use X" but "if Y, use X" |
| 4 | Anti-patterns | Documented with concrete consequences and production incident examples |
| 5 | Production examples | Each reference cites 2+ real production systems with specific decisions |
| 6 | De-factoring evidence | Every force claim traces to "we removed this and it hurt because..." |
| 7 | Trigger discrimination | Trigger has positive triggers, negative space, diffused phrasings, distinguishing test |
| 8 | Cross-references | Related codebooks identified; cross-domain-map interaction pairs documented |
| 9 | Cross-domain-map update | New codebook added to universality tiers; interaction pairs added to Section 2 |
| 10 | Router update | domain-codebooks/SKILL.md updated with new codebook in appropriate table |
| 11 | Eval set created | 20 queries (10 should-trigger, 10 should-not); baseline >80% recall |
| 12 | Eval baseline passing | Eval set run; recall meets threshold |

### Minimum Viable Codebook by Tier

- **Tier 1** (5+ repos): SKILL.md + at least 1 reference file with 3+ competing patterns per axis. Full pre-ship checklist required.
- **Tier 2** (3-4 repos): SKILL.md + at least 1 reference file with 3+ competing patterns. Items 11-12 recommended but not blocking.
- **Tier 3** (1-2 repos): SKILL.md with inline patterns acceptable (no separate reference files required if patterns are documented in the SKILL.md body). Items 5, 11-12 recommended but not blocking. Must still have decision gates and anti-patterns.

Tier 3 codebooks should be flagged as thin when loaded by the router.

## Grading

A codebook passes when all expectations grade PASS. Partial failures require iteration:

| Failure | Recovery |
|---------|----------|
| Missing reference file for an axis | Write the reference, or demote the axis (document why it doesn't need a codebook) |
| Only 1-2 patterns in a reference | Research more production systems. If genuinely only one approach exists, document alternatives that were considered and rejected. |
| Missing decision gates | Add project-specific questions. Use annotation-state-advisor's Step 1 Classify as a model. |
| Vague anti-patterns | Add specific consequences and production incident examples |
| Single production example | Research more systems. Cross-reference with cross-domain-map.md. |
| Forces without de-factoring | Go back to Stage 4. Actually remove the pattern and document what hurts. |
| Trigger overlap with another skill | Sharpen negative space. Add distinguishing test. Run eval-protocol discrimination check. |
