# Enrichment Protocol

Protocol for incrementally improving existing codebooks with new evidence. This is NOT the full extraction pipeline — it's a scoped update process for codebooks that already exist.

## When to Use

- A codebook exists but scores poorly on quality criteria
- New repo evidence adds competing patterns, production examples, or anti-patterns
- The enrichment roadmap identifies specific thin areas
- pattern-advisor surfaces a gap during project consultation

**Distinguishing test**: Does a codebook already exist? → enrichment protocol. No codebook? → full 5-stage pipeline.

## Enrichment Steps

### 1. Audit Target

Score the existing codebook against the 7 eval criteria in `quality-criteria.md`. Identify specific thin areas:

- Which reference files have <3 competing patterns?
- Which patterns lack production examples from 2+ systems?
- Which decision gates are missing or vague?
- Which anti-patterns lack concrete consequences?
- Is de-factoring evidence present or assumed?

Document the current quality score as the **baseline** — enrichment must not regress below this.

### 2. Scoped Extraction

Skip Orient/Characterize for known patterns. Focus extraction on the thin areas only:

1. **Study new repo with hybrid-research**, scoped to the specific gaps identified in step 1
2. **Map seams** only for the thin axes — don't re-map what's already well-documented
3. **De-factor** only new patterns or new evidence for existing patterns

### 3. Merge Rules

Additions go into existing reference files. Do NOT create new files unless documenting a genuinely new axis.

| New evidence type | Where it goes |
|-------------------|---------------|
| New competing pattern | New `### Pattern N` section in the relevant reference file |
| New production example | Add under existing pattern's `**Production example:**` section |
| New anti-pattern | Add under existing `## Anti-Patterns` section |
| Correction to existing guidance | Update in-place with source note: `[Updated YYYY-MM-DD from {repo}]` |
| Genuinely new axis | New reference file (rare — verify it's truly orthogonal to existing axes) |

### 4. Contradiction Protocol

When new evidence conflicts with existing guidance:

1. **Do NOT silently overwrite.** Document both positions as competing perspectives.
2. **Add the discriminating factor** to the decision guide:
   - "Pattern X works when [condition from repo A]; Pattern Y works when [condition from repo B]"
3. **If contradiction is fundamental** (one repo shows pattern X is essential, another shows it's cargo-cult):
   - Present de-factoring evidence from each repo side by side
   - The decision guide absorbs the discriminator
   - The original pattern is NOT deleted — it gains a narrower "when to use"
4. **Flag for review** if the discriminating factor is unclear:
   - Add to `enrichment-roadmap.md` § Gap Log with description: "Contradiction: [pattern] — [repo A] says X, [repo B] says Y. Discriminator unclear."

### 5. Quality Re-grade

After merging new evidence, re-score the codebook against all 7 criteria.

**Regression gate**: The codebook must score equal or higher than the baseline from step 1. If it scores lower (e.g., a new contradiction muddied a previously clear decision gate), iterate until the score recovers.

### 6. Update Cross-Domain Map

In `cross-domain-map.md`:
- Increment repo count in Section 1 if a new repo was studied
- Update tier if repo count crosses a threshold (2→Tier 3, 3→Tier 2, 5→Tier 1)
- Add new interaction pairs to Section 2 if the enrichment revealed cross-codebook interactions
- Update deferred candidates in Section 3 if relevant

### 7. Regenerate Enrichment Roadmap

Update `enrichment-roadmap.md` to reflect the improvement:
- Update the codebook's quality score
- Remove or downgrade thin area entries that were addressed
- Update the Gap Log if advisor-reported gaps were filled

## Scope Guard

Enrichment is scoped. Watch for these scope-creep signals:

| Signal | Action |
|--------|--------|
| "While I'm here, let me also restructure..." | Stop. File a separate enrichment task. |
| "This pattern contradicts the entire codebook premise" | Stop. This may need a full re-extraction, not enrichment. Flag for review. |
| "I need to add 3+ new reference files" | Stop. This is closer to a new codebook than enrichment. Consider full pipeline. |
| "The existing structure doesn't accommodate this" | Stop. Structural changes are pipeline work, not enrichment. |

## Integration with Lifecycle

```
Advisor surfaces gap → Gap Log in enrichment-roadmap.md
                              ↓
Audit mode prioritizes → Enrichment Priorities list
                              ↓
User triggers enrichment → This protocol
                              ↓
Codebook improves → Quality score rises → Roadmap regenerated
```
