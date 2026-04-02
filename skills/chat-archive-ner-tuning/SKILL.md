---
name: chat-archive-ner-tuning
description: >-
  Tune NER extraction quality on multilingual chat archives (WhatsApp, Discord).
  Covers stoplist management, threshold tuning, alias normalization,
  sender/mentioned separation, cross-source dedup, and precision/recall sampling.

  TRIGGER when: tuning NER output on chat data; managing stoplists or noise
  filters for chat entities; deduping entities across chat platforms; debugging
  platform metadata leaking into entity fields.

  DO NOT trigger for: training or fine-tuning NER models (this tunes their
  output); NER on formal text; general data cleaning unrelated to entity
  extraction.
---

**Warning:** Python caches module imports — kill/restart the process after edits. (See Phase 4.)

# NER Quality Tuning for Multilingual Chat Archives

Iterative methodology for improving entity extraction quality in pipelines that process multilingual conversational data from WhatsApp and Discord archives.

## When This Skill Applies

You have a pipeline that extracts entities (people, places, organizations, topics) from text, and the output quality isn't good enough. Common scenarios:

- NER produces too much noise on informal text (chat, transcripts, social media)
- Entities need deduplication or matching across multiple sources
- Stoplists need expansion to filter non-entities
- Similarity thresholds need calibration for fuzzy matching
- Multilingual or code-switched text breaks standard models

Before tuning, run `search_patterns("NER extraction <entity-type>")` to check for known failure modes and threshold guidance.

## The Tuning Loop

Quality tuning is inherently iterative. Each iteration:

```
Sample → Assess → Hypothesize → Adjust → Re-sample → Compare
```

Adjusting thresholds or stoplists without first sampling output means you're guessing at the failure mode — sample first so adjustments target something real.

### Phase 1: Sample and Categorize Failures

Before changing anything, understand what's broken.

**Sampling method:**
1. Take a random sample of extracted entities (50-100 is usually enough for a tuning round)
2. Categorize each as: **correct**, **wrong type** (entity but miscategorized), **non-entity** (noise), **partial** (truncated or merged), **missing** (found by manual review but not extracted)
3. Calculate rough precision (correct / total extracted) and recall (correct / correct + missing)

**Common noise categories in informal text:**
- Day names, month names, greetings ("Monday", "Hello", "Good morning")
- Pronouns and determiners ("He", "This", "That one")
- Emoji and emoticons (extracted as entity by some models)
- Organization suffixes appearing standalone ("Inc", "Ltd")
- Code-switched fragments that look like proper nouns to English NER
- Repeated sender names or platform metadata

**Categorizing failures tells you what to fix.** If 80% of noise is day names and greetings, a stoplist addition solves it. If noise is model hallucination on code-switched text, you need a different extraction approach.

`[eval: baseline-survey-complete]` Vault-wide frequency survey produced: unique counts per field, top-30 by frequency, case-duplicate group count, and cross-field misclassification check — all recorded before any tuning adjustments.

`[eval: failure-categories-quantified]` Sample of >= 50 entities categorized into correct/wrong-type/non-entity/partial/missing with counts, and precision + recall computed as numeric values.

### Phase 2: Choose the Right Lever

| Failure mode | Lever | Notes |
|-------------|-------|-------|
| Known noise words (days, pronouns, greetings) | **Stoplist** | Cheap, precise, no side effects |
| Entities from the wrong domain (person names in place list) | **Type filtering / reclassification** | Check model confidence by type |
| Partial matches or fragments | **Post-processing rules** | Regex cleanup, minimum length, context window |
| Model extracts garbage on informal text | **Model selection** | GLiNER > spaCy for noisy multilingual; LLM-based for highest quality |
| Duplicates within a source | **Alias normalization** | Lowercase, strip affixes, string similarity |
| Duplicates across sources | **Cross-source matching** | Embedding similarity + string similarity + type agreement |
| Low recall (missing real entities) | **Lower confidence threshold** or **add seed entities** | Trade-off: lower threshold = more noise |

### Phase 3: Adjust and Measure

**Stoplist management:**
- Organize stoplists by category (temporal, pronominal, greeting, platform-specific) for maintainability
- When adding to a stoplist, grep the full entity list first — make sure the word isn't also a legitimate entity in your domain (e.g., "April" is a month AND a person name)
- Case handling matters: "the" is noise, "The Hague" is an entity. Consider case-aware filtering

**Threshold tuning:**
- Move thresholds in small increments (0.05) and re-sample after each change
- Track the precision/recall tradeoff explicitly — write down the numbers
- Different entity types may need different thresholds (person names tolerate lower similarity than place names)
- For cross-source matching, same-source thresholds are typically stricter than cross-source (same-source duplicates are usually exact or near-exact)

**Alias normalization:**
- Strip common affixes (org suffixes, honorifics, possessives)
- Normalize unicode (diacritics, ligatures, fullwidth chars)
- For multilingual: transliteration may help matching but destroys information — keep originals

`[eval: lever-selected-with-rationale]` Dominant failure mode mapped to a specific lever from the table above, with the failure-mode-to-lever justification stated explicitly (not "try everything"). Seed/stoplist conflict audit run with zero unresolved conflicts.

### Phase 4: Re-sample and Compare

After adjustments, repeat Phase 1 sampling on the new output. Compare:

- Did precision improve without killing recall?
- Did the specific failure category shrink?
- Did any new failure mode appear? (Stoplist too aggressive? Threshold too low?)

**When to stop tuning:**
- Precision and recall are both acceptable for your use case (define "acceptable" before you start)
- Remaining errors are edge cases that would require disproportionate effort to fix
- The same failures keep appearing despite 3+ adjustment rounds (model limitation, not tuning issue)

`[eval: adjustments-applied-and-re-enriched]` Configuration changes written to config files AND extraction re-run on the corpus with the updated pipeline (not just config saved but stale output).

`[eval: iteration-delta-measured]` Re-sampled precision and recall computed on new output, delta from baseline recorded (e.g., "precision +12%, recall -2%"), and any newly introduced failure modes identified. Tuning round produces a net-positive delta or documents why it does not.

## NER Model Selection Guide

For informal/multilingual text, model choice matters more than parameter tuning.

| Approach | Strengths | Weaknesses | Best for |
|----------|-----------|------------|----------|
| **spaCy NER** | Fast, well-supported, good on formal English | High noise on informal/multilingual text | Clean, monolingual documents |
| **GLiNER** | Zero-shot, handles noisy text well, multilingual | Slower, needs GPU for speed | Informal multilingual chat, social media |
| **Regex / gazetteer** | Precise, predictable, no false positives from novel text | No generalization, manual maintenance | Known entity lists, structured patterns |
| **LLM extraction** | Highest quality, understands context | Expensive, slow, non-deterministic | High-stakes extraction, small volumes |
| **Hybrid** | Combine regex (known) + model (novel) | Pipeline complexity | Production systems with mixed entity types |

## Cross-Source Entity Disambiguation

When matching entities across different datasets (e.g., two chat platforms, or chat + database):

**Three-signal approach:**
1. **String similarity** (Levenshtein, Jaro-Winkler): catches spelling variants
2. **Type agreement**: same entity type in both sources boosts confidence
3. **Context overlap**: entities that co-occur with the same other entities are likely the same

**Decision framework:**
- High string similarity (>0.85) + same type → auto-merge
- Medium similarity (0.5-0.85) + same type → review manually or add to candidates
- High similarity + different type → flag for retype decision (is it really a person in one and org in another?)
- Low similarity (<0.5) → only match if strong context evidence

**Alias boosting:** When you confirm a match, record it as an alias. Future runs can use the alias list to skip re-matching known pairs. Organize aliases in tiers by confidence: confirmed (human-verified), high-confidence (auto-matched above threshold), candidate (needs review).

## Chat Archive Patterns (WhatsApp / Discord)

These patterns apply specifically to NER pipelines processing conversational data from messaging platforms in multilingual archives. See `references/cookbook-chat-archives.md` for the full case study.

### Sender vs Mentioned: the fundamental split

In chat data, separate **senders** (who authored messages — known from format, 100% precision) from **people mentioned** (discussed in content — NER-dependent, uncertain). Use senders as an exclusion filter for people_mentioned. Store them in separate fields.

Extract senders via format-specific regex, not NER:
- WhatsApp: `**HH:MM** **Name:**` pattern in converted notes
- Discord: `> [!discord-*] [[username]]` callout pattern

### Structural markers beat embeddings for dedup

Before reaching for embedding similarity, mine the structural signals chat platforms give you for free:

- **Participant lists** in frontmatter (authoritative sender set per day)
- **@-mention patterns** (`@username`) are explicit identity references — strip the `@` before matching
- **Platform config files** (Discord `display_names.yaml`, WhatsApp `sender_aliases.yaml`) provide vault-wide identity registries far broader than per-document sender lists
- **System messages** ("X created group", "X added Y") reveal participant identity
- **Person notes** (if your pipeline generates per-person notes) serve as an authoritative cross-platform identity registry

### Platform identity leakage

Username patterns leak into NER output. Filter with a three-layer approach:

1. **@-prefix stripping** — `@Naveen` → `Naveen`, then re-check against sender exclusion set
2. **Username regex** — Discord usernames match `^[a-z][a-z0-9._]+$` with `_`, `.`, or digits. Filter these from people_mentioned.
3. **Vault-wide username set** — Load all known usernames from platform config + person note filenames. Catches usernames that don't match the regex pattern.

### Org suffixes in compound sender names

WhatsApp users often include their org in their display name ("Dinesh Janastu", "Micah Srishti"). When NER processes text mentioning these senders, it extracts the org suffix as a standalone person. **Reclassify** (move to entities), don't stoplist — the org name IS a valid entity, just miscategorised as a person.

### Case-insensitive dedup with preference hierarchy

Simple set-based dedup without embeddings: `UPPER` (acronyms like APC) > `Capitalized` (Shreyas) > `lowercase` (shreyas). Within same case class, prefer the longer form. Apply to entities, places, and people.

### Multilingual honorifics and discourse markers

Standard English stoplists miss noise from other languages in the archive. Audit extracted entities for common discourse markers in ALL languages present — Hindi `ji` (honorific), `haan`/`hai` (affirmatives), etc. High-frequency single-word "entities" are almost always noise. Preserve compound forms containing honorifics ("Ambika ji") — only stoplist the bare form.

### Channel-first sampling stratification

When evaluating quality across multiple chat sources, stratify by source first (50/50 Discord/WhatsApp), then by entity density within each source. Without this, the larger source dominates samples and hides problems in the smaller one.

### Multi-pass extraction escalation

Avoid the single-threshold precision/recall tradeoff:

1. **High confidence (0.7)** — all labels, catches confident extractions
2. **Low confidence (0.4)** — seed entities only, recovers known entities the model was uncertain about
3. **Gazetteer regex** — catches entities the model missed entirely using word-boundary search

Seed entities are reference, not injection — they inform recovery but are never blindly added to output.

**Gazetteer aggression varies by entity type.** Models like GLiNER already handle places well — common place names (cities, countries, states) are among the easiest things for NER models to detect. A gazetteer that force-injects places via regex match adds noise without meaningfully improving recall. In one pipeline, disabling place gazetteer dropped places noise from 27.7% to ~15% while barely affecting recall. Keep gazetteer recovery for entities (org names, acronyms, project names) and people, where models genuinely miss domain-specific terms.

### Seed/stoplist conflict detection

Seeds and stoplists are managed by different processes (seeds from manual curation, stoplists from iteration validators). Over time, contradictions creep in — the same term appears in both. This silently degrades quality: the seed injects it, the stoplist removes it (or doesn't, depending on processing order), and neither achieves its goal.

**Run a conflict audit before each tuning round:**
```python
stop_low = {s.lower() for s in stoplist}
for field, items in seeds.items():
    for item in items:
        if item.lower() in stop_low:
            print(f"CONFLICT: '{item}' in {field} seeds AND stoplist")
```

Resolution: decide which is correct (is the term noise or a real entity?), then remove it from the wrong list. When a term is genuinely ambiguous (e.g., "Srishti" is both an org name and a person name), prefer keeping it as a seed and handling the ambiguity via type-specific reclassification rather than stoplisting. Ambiguous terms in both seeds and stoplists: >50% ambiguous → type-specific rule or context-based disambig.

### Cross-note case normalization

Per-note case dedup (preferring `UPPER` > `Capitalized` > `lowercase`) handles within-document variants but creates cross-document inconsistency. "Bidar" in one note and "bidar" in another become separate wikilinks, polluting graph views and base queries.

Normalize at pipeline output:
- All-uppercase → preserve (acronyms: APC, KHPT)
- Already capitalized → preserve (Bidar, Shreyas)
- All-lowercase → title case (bidar → Bidar, eshwari → Eshwari)

This is cheap, catches the majority of cross-note duplication, and produces consistent wikilink targets. Apply to people and places; entities are more varied (acronyms, mixed-case project names) and benefit less.

### Org-not-place reclassification

NER models frequently misclassify organization acronyms as places — "HNC" (a nodal centre), "BNC", "YNC" all look like place abbreviations to a model. Similarly, initiative names like "Samagra Arogya" get classified as places because they contain words that sound geographic.

Maintain an explicit reclassification set (`_ORG_NOT_PLACE`) and check it during classification routing. This is cheaper and more precise than trying to retrain or prompt-engineer the model. The set grows organically from eval feedback — when the validator flags a miscategorization, add it to the set.

### Building-type noise in places

Words like "Dargah" (shrine), "Gurudwara" (temple), "Karez" (water system) are building/structure types, not specific place names. NER models classify them as places because they appear in geographic contexts. Stoplist these — they're categorical noise (every instance is wrong), unlike ambiguous terms that need case-by-case handling.

## General Patterns

### Expanding a stoplist systematically

Don't add words one at a time as you spot them. Instead:

1. Extract all unique entities from current output
2. Sort by frequency (high-frequency "entities" are often noise)
3. Review the top-50 by frequency — bulk-categorize as keep/stop
4. Check for categorical patterns (all day names? all pronouns?) and add the full category
5. Re-run and re-sample

### Debugging a threshold that "doesn't work"

If adjusting a similarity threshold doesn't improve results:

1. Sample 10 false positives and 10 false negatives
2. Compute their actual similarity scores
3. If FPs and FNs have overlapping score distributions, the similarity metric itself is wrong — no threshold will separate them. Switch metrics (e.g., from Levenshtein to embedding similarity) or add a second signal.

### Vault-wide frequency survey before tuning

Before adjusting stoplists, seeds, or thresholds, survey the actual data:

1. **Count unique values per field** across the full corpus — not a sample
2. **Sort by frequency** — the top-30 entities/places/people reveal the real distribution
3. **Count case-duplicate groups** — if 134 people groups have mixed casing, that's a normalization problem, not a model problem
4. **Cross-check fields** — entities appearing in places (or vice versa) signal misclassification
5. **Check for noise patterns** — single-word entities without uppercase, generic event words, building types

This survey takes minutes and prevents wasted iterations. It often reveals that the dominant quality issue is something structural (case variants, config conflicts) rather than model-level.

### Iteration convergence and re-enrichment timing

LLM-based validation iterations (sampling notes, validating extractions via a local model) converge quickly — after 20-30 rounds, the validator's suggestions stabilize. But **iterations validate frontmatter, not the pipeline**. If you change pipeline code (stoplists, thresholds, classification rules) without re-running extraction, iterations just re-validate stale data and show no improvement.

The iteration is: **fix → re-enrich → eval → repeat**, not fix → iterate.

**Critical timing detail:** Python caches module imports at startup. If you edit `enrichment.py` while a re-enrichment process is running, the running process uses the old code. Config files (YAML) that are loaded per-note are picked up live. Kill and restart the process after any Python code changes.

### Eval-driven seed discovery

The eval harness doesn't just measure quality — it discovers new seeds. When the validator identifies entities that should have been extracted but weren't (`missed_sample` in eval results), those become seed candidates. When it flags miscategorizations (`category_corrections`), those become reclassification-set candidates.

Feed eval outputs directly into configuration:
- `missed_sample` → new entries in `ner_seed_entities`
- `category_corrections` → new entries in `_ORG_NOT_PLACE`, `_ORG_NOT_PERSON`, etc.
- `stoplist_candidates` → review and add to `ner_stoplists` (but verify they're genuinely noise first — validators sometimes flag legitimate entities)

### Handling code-switched text

Text that mixes languages (English + Hindi, English + Kannada, Spanish + English):

- Standard NER models trained on one language will misclassify code-switch boundaries as entities
- GLiNER with multilingual models handles this better than spaCy
- Post-processing: if an "entity" is a common word in any of the text's languages, stoplist it
- Consider language detection per-segment if text has clear language boundaries

