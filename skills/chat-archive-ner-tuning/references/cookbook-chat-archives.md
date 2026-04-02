# Cookbook: Tuning NER for Multilingual Chat Archives (WhatsApp + Discord)

Field notes from tuning a GLiNER-based NER pipeline across 5,600+ daily notes spanning WhatsApp group chats and Discord channels in a multilingual (English/Hindi/Kannada) community archive.

## Context

- **Source data**: WhatsApp exports (`_chat.txt`) and Discord CSV exports, converted to Obsidian daily notes with YAML frontmatter
- **NER model**: GLiNER (`urchade/gliner_multi-v2.1`) — zero-shot, multilingual
- **Validation model**: Ollama (Qwen 27B) for iterative quality scoring
- **Fields extracted**: `entities` (orgs/projects), `places`, `people_mentioned`, `senders`
- **Scale**: 5,629 notes, 20 iterations of quality tuning

## What We Learned

### 1. Chat format IS your best dedup signal

Before reaching for embeddings or string similarity, mine the structural markers that chat platforms give you for free:

**WhatsApp format markers:**
```
[9/6/19, 23:23:15] Dinesh Janastu: How did the call go today?
```
- Sender name before `:` is authoritative — 100% precision, no NER needed
- System messages ("X created group", "X added Y") reveal participant identity
- Compound sender names ("Dinesh Janastu", "Shalini Slvts") encode org affiliation

**Discord format markers:**
```
> [!discord-msg] [[shreyas_srivatsa]] — 12:17
```
- Wikilinked username in callout header is authoritative
- `@username` mentions in body text are explicit identity references
- `participants` frontmatter lists everyone who sent a message that day
- `display_names.yaml` maps user IDs to usernames vault-wide

**The principle**: Structural markers from the source format are more reliable than any model-based extraction. Use them as ground truth for filtering, not as just another signal.

### 2. Senders and mentioned people are fundamentally different

In conversational data, there are two categories of people:

- **Senders**: people who authored messages. Known with certainty from message format. Extracted via regex, not NER.
- **Mentioned people**: people discussed in message content. Uncertain, NER-dependent.

These must be separate fields. A person who sends a message is part of the "meaning-making apparatus" — they're metadata. A person who is *discussed* is content. Conflating them inflates people counts and creates noise.

**Implementation**: Extract senders via format-specific regex (WhatsApp timestamp-name pattern, Discord callout-wikilink pattern). Store in `senders` field. Use the sender set as an exclusion filter for `people_mentioned`.

### 3. Platform identity leaks into NER output

When NER runs on chat text, platform-specific identifiers leak through as "entities":

| Leak pattern | Example | Frequency in our data |
|---|---|---|
| @-mention with prefix | `@Naveen`, `@Harsha` | ~160 entries |
| Discord username as person | `harsh005`, `vini_malge` | ~280 entries |
| Case variants | `Abhiram` / `abhiram` | ~200 entries |

**Fixes applied (in order of impact):**

1. **Strip `@` prefix** before any sender matching or stoplist check. Without this, `@naveen` won't match `naveen` in the sender exclusion set.

2. **Discord username regex filter**: `^[a-z][a-z0-9._]+$` with at least one `_`, `.`, or digit. Catches `harsh005`, `vini_malge`, `capn.ash` but not real lowercase names.

3. **Vault-wide username registry**: Load all known usernames from platform config files (Discord `display_names.yaml` + person note filenames). Provides broader exclusion than same-day sender lists alone. In our case: 186 usernames loaded, catching names like `fishybubbly` that have no `_`/digit pattern.

4. **Case-insensitive dedup with preference hierarchy**: UPPER (acronyms like `APC`) > Capitalized (`Shreyas`) > lowercase (`shreyas`) > longer form. Simple set-based, no embeddings needed.

### 4. Org suffixes in sender names cause phantom entities

In WhatsApp groups, people often include their organisation in their display name:

```
"Dinesh Janastu"    → real name: Dinesh, org: Janastu
"Shalini Slvts"     → real name: Shalini, org: Servelots
"Vinay Team Yuva"   → real name: Vinay, org: Team Yuva
"Micah Srishti"     → real name: Micah, org: Srishti
```

When GLiNER processes text mentioning these senders, it sometimes extracts the org suffix as a standalone person name ("Janastu" as a person, "Srishti" as a person).

**Fix**: Maintain an `_ORG_NOT_PERSON` set of known org tokens. During post-processing, reclassify matching `people_mentioned` values to `entities` — don't just stoplist them, because they ARE valid entities, just miscategorised.

### 5. Stoplists need language-aware honorifics

Standard English stoplists miss honorifics and discourse markers from other languages in the archive:

- `ji` (Hindi honorific suffix) — extracted as standalone person name 23 times
- `sir`, `madam` — already in English stoplists but compound forms like "Ambika ji" and "Ruksana madam" should be preserved
- `haan`, `hai` (Hindi affirmatives) — noise when extracted as entities

**Pattern**: When working with multilingual chat, audit extracted entities for common discourse markers in ALL languages present, not just English. Sort by frequency — high-frequency single-word "entities" are almost always noise.

### 6. Sampling must stratify by source

With 4,750 Discord notes and 879 WhatsApp notes, random sampling produced 85% WhatsApp samples. This hid the fact that Discord notes had near-zero entities (GLiNER hadn't been run on them).

**Fix**: Channel-first stratification — sample N/2 from each source, then stratify by entity count within each source (zero / few / many entities). This ensures both platforms are represented and you see the full range of entity density.

### 7. Multi-pass extraction beats single-threshold

A single confidence threshold forces a precision/recall tradeoff. Multi-pass avoids it:

| Pass | Threshold | Strategy | Purpose |
|------|-----------|----------|---------|
| 1 | High (0.7) | All labels | Precision — catch confident extractions |
| 2 | Low (0.4) | Seed entities only | Recall — recover known entities GLiNER was uncertain about |
| 3 | N/A | Gazetteer regex | Recall — catch entities GLiNER missed entirely |

The seed entity list in `guidelines.yaml` drives passes 2-3. Seeds are reference, not injection — they inform the recovery process but are never blindly added to output.

### 8. Domain-tuned GLiNER labels outperform generic ones

Changing GLiNER labels from generic to domain-specific improved extraction:

| Generic | Domain-tuned | Why it helps |
|---------|-------------|--------------|
| "person" | "person name" | Reduces extraction of pronouns and role titles |
| "place" | "city or village" | Focuses on settlement names, not generic "place" words |
| "organization" | "organization or institution" | Better matches for local NGOs and government bodies |
| — | "cultural site or landmark" | New label capturing heritage-specific places |
| — | "project or initiative" | Separates project names from org names |

### 9. The int coercion trap

WhatsApp participants sometimes include phone numbers. YAML parses these as integers. Any code that calls `.lower()` on participant values will crash on `91953867064.lower()`.

**Fix**: Always coerce participant/sender values to `str()` before string operations. Apply defensively in both the caller and the callee.

## Metrics Journey

| Phase | Entity precision | Places precision | People precision |
|-------|-----------------|-----------------|-----------------|
| Pre-tuning (iter 1-10) | 37-60% | 25-100% | 25-83% |
| Post-prompt-correction (iter 11-20) | 29-87% | 53-94% | 15-86% |
| Post-dedup overhaul (iter 21+) | TBD | TBD | TBD |

**Key observation**: Places precision improved most consistently after prompt correction. People precision remained the most variable field — the sender/mentioned distinction is hard for LLM validators because they see both categories in the same text.

## Architecture Decisions

1. **Senders are a separate field**, not merged into `people_mentioned`
2. **Seed entities are reference, not injection** — they inform GLiNER recovery and Ollama prompts but are never blindly added to frontmatter
3. **Stoplists are merged at runtime** — hardcoded `_NOISE_LEMMAS` + `guidelines.yaml ner_stoplists.noise_entities`, so tuning doesn't require code changes
4. **Post-processing runs after stoplist filtering** — dedup, username filter, org reclassification happen on the already-filtered set
5. **GPU acceleration deferred** — CPU is fine for iteration samples (20-40 notes); GPU only matters for full-vault re-enrichment (5,600+ notes, ~120min on CPU)
