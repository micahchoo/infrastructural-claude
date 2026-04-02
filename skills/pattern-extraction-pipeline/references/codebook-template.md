# Codebook Template

Extracted from annotation-state-advisor — the first and reference implementation of a domain pattern codebook.

## Skill Structure

```
domain-name-advisor/
├── SKILL.md                    (trigger + classify + routing table + principles)
└── references/
    ├── axis-one.md             (one reference per domain axis)
    ├── axis-two.md
    ├── ...
    └── sources/                (optional deep-dives)
        ├── production-analysis.md
        └── developer-interviews.md
```

## SKILL.md Format

### Frontmatter

```yaml
name: domain-name-advisor
description: >-
  Architectural advisor for [domain]. NOT [adjacent domains that shouldn't trigger].

  Triggers: [specific technical concepts, 15-25 items]

  Diffused triggers (how users phrase these): [casual phrasings, 15-25 items]

  Libraries: [specific tools/frameworks this covers]

  Skip: [explicit negative space — what NOT to trigger for]
```

### Body: Classify → Load Reference → Advise

**Step 1: Classify** — 5-6 questions that narrow the problem space:
1. What sub-domain? (e.g., spatial vs temporal vs visual)
2. What axis? (list all domain axes covered)
3. What scale? (affects pattern choice)
4. What collaboration model? (if applicable)
5. What framework/runtime?

**Step 2: Load reference** — Table mapping axes to reference files:
| Axis | File |
|------|------|
| Axis name | `references/axis-name.md` |

**Step 3: Advise and scaffold** — Present 2-3 patterns with tradeoffs. Framework-appropriate code.

**Principles** — 6-8 numbered principles distilled from all reference files. Each is a decision rule, not a platitude.

## Reference File Format

Each reference file covers one domain axis:

```markdown
# Axis Name

## The Problem
What goes wrong without a solution. Concrete symptoms, not abstract concerns.

## Competing Patterns

### Pattern A: [Name]
**When to use:** [specific project characteristics]
**When NOT to use:** [specific counter-indicators]
**How it works:** [2-3 paragraphs with code example]
**Production example:** [real project + specific architectural decision]
**Tradeoffs:** [what you give up]

### Pattern B: [Name]
(same structure)

### Pattern C: [Name]
(same structure)

## Decision Guide
Questions that select the right pattern:
- "If X, choose Pattern A because..."
- "If Y, choose Pattern B because..."

## Anti-Patterns
### Don't: [Bad approach]
**What happens:** [concrete consequence, not vague warning]
**Instead:** [pointer to the right pattern]
```

## Minimum Viable Codebook by Tier

Not all codebooks need the full structure above. Thresholds scale with evidence:

### Tier 1 (5+ repos, high universality)
- SKILL.md with full frontmatter (triggers, negative space, distinguishing test)
- At least 1 reference file per identified axis
- 3+ competing patterns per reference with production examples from 2+ systems
- Full pre-ship checklist (all 12 items)

### Tier 2 (3-4 repos, cross-domain)
- SKILL.md with full frontmatter
- At least 1 reference file with 3+ competing patterns
- Production examples from 2+ systems
- Eval set recommended but not blocking

### Tier 3 (1-2 repos, domain-specific)
- SKILL.md with inline patterns acceptable — patterns documented in the body rather than separate reference files
- Must still include: decision gates, anti-patterns with consequences, cross-references
- Production examples and eval set recommended but not blocking
- **Flagged as thin** when loaded by the router (see domain-codebooks quality caveat protocol)

A Tier 3 codebook graduating to Tier 2 must upgrade to the Tier 2 structure via the enrichment protocol.

## Sources Directory (Optional)

For deep-dives that don't fit in reference files:
- **Production analysis**: How specific companies solved specific problems. Cite talks, blog posts, source code.
- **Developer interviews**: Quotes and insights from maintainers. Cite podcasts, conference talks, GitHub discussions.
- **Cross-project comparison**: How 3+ projects approach the same problem differently.
