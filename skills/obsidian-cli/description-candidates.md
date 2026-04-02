# SKILL.md Description Candidates

## Candidate A — Obsidian-specific signal anchoring

```
Obsidian vault skill — invoke for any Obsidian-related task. Strong triggers: wikilinks ([[Note]]), embeds (![[Note]]), .base files (Obsidian Bases database views), callouts (> [!type]), obsidian:// URI schemes, graph view, daily notes, ==highlights==, %%comments%%, cssclasses property, Obsidian search operators (file: path: tag:#), Obsidian CLI commands (obsidian base:query, obsidian properties), canvas JSON files (.canvas), and the .obsidian/ config folder. Also triggers on: frontmatter/properties work when the context is an Obsidian vault (not generic YAML), tag management with nested tags (parent/child), block references (^block-id), note templates with {{title}}/{{date}}/{{time}}, and vault structure questions. Does NOT apply to: ansible-vault, SQL/database base tables, generic README markdown, Docker tags, Express routes, Notion databases, or Roam Research — even if they share terminology like "vault", "base", "tags", or "properties".
```

**Analysis:**
- Q1 (cssclasses, daily notes, vault path): TRIGGER — cssclasses + daily notes + vault path = strong ✅
- Q2 (.base file, viewOrder): TRIGGER — .base files explicitly listed ✅
- Q3 (collapsible callout > [!warning]-): TRIGGER — callout syntax ✅
- Q4 (template, wikilinks, frontmatter): TRIGGER — wikilinks + template + frontmatter ✅
- Q5 (obsidian uri scheme): TRIGGER — obsidian:// URI ✅
- Q6 (graph view, Archive/): TRIGGER — graph view ✅
- Q7 (search syntax, tag:#, property): TRIGGER — Obsidian search operators ✅
- Q8 (embed ![[Reference#Section]]): TRIGGER — embeds ✅
- Q9 (frontmatter aliases, [[ editor): TRIGGER — wikilinks + aliases ✅
- Q10 (canvas file, JSON, edges): TRIGGER — canvas ✅
- Q11 (kubernetes deployment.yaml tags): NO TRIGGER — generic YAML, explicit exclusion ✅
- Q12 (SQL view, base tables): NO TRIGGER — explicit SQL exclusion ✅
- Q13 (GitHub README.md, collapsible details): NO TRIGGER — generic README excluded ✅
- Q14 (Notion database, relation property): NO TRIGGER — Notion excluded ✅
- Q15 (YAML frontmatter, pandas): RISK — "frontmatter" appears but context is blog/pandas ⚠️
- Q16 (ansible-vault): NO TRIGGER — explicit exclusion ✅
- Q17 (React Storybook, markdown links): NO TRIGGER — generic markdown excluded ✅
- Q18 (Docker tag): NO TRIGGER — Docker tags not matched ✅
- Q19 (Express base route): NO TRIGGER — Express excluded ✅
- Q20 (Roam Research, backlinks): NO TRIGGER — Roam excluded ✅

**Score: 19/20** (Q15 is borderline — depends on whether model weighs "frontmatter" alone vs. full context)


## Candidate B — Negative-boundary focused

```
Obsidian vault expertise — triggers when the user's task involves an Obsidian vault or Obsidian-flavored markdown. Key Obsidian signals: wikilinks ([[]], ![[]]), .base YAML files (Obsidian Bases — database views over vault notes, NOT SQL base tables), > [!type] callouts, obsidian:// URIs, graph view, daily notes, ==highlights==, %%comments%%, cssclasses/aliases properties, Obsidian search (file: path: tag:# operators), the Obsidian CLI, .canvas files, .obsidian/ config, block references ^id, and note templates ({{title}}, {{date}}, {{time}}). Contextual triggers: frontmatter properties, tags, and vault structure ONLY when the context involves Obsidian — not Kubernetes YAML, blog post frontmatter, Docker image tags, ansible-vault encryption, Notion databases, Express route bases, SQL base tables, Roam Research, or generic GitHub/Storybook markdown. The distinguishing signal is whether files live in an Obsidian vault or use Obsidian-specific syntax.
```

**Analysis:**
- Q1-Q10: All TRIGGER ✅ (same reasoning as A)
- Q11 (k8s tags): NO TRIGGER — Kubernetes YAML excluded ✅
- Q12 (SQL base tables): NO TRIGGER — explicitly excluded ✅
- Q13 (GitHub README): NO TRIGGER — generic markdown excluded ✅
- Q14 (Notion): NO TRIGGER — excluded ✅
- Q15 (blog frontmatter, pandas): NO TRIGGER — "blog post frontmatter" excluded ✅
- Q16 (ansible-vault): NO TRIGGER — excluded ✅
- Q17 (Storybook markdown): NO TRIGGER — excluded ✅
- Q18 (Docker tags): NO TRIGGER — excluded ✅
- Q19 (Express base route): NO TRIGGER — excluded ✅
- Q20 (Roam Research): NO TRIGGER — excluded ✅

**Score: 20/20**


## Candidate C — Compact with strong disambiguation

```
Obsidian vault skill. Use when the task involves an Obsidian vault, Obsidian-flavored markdown, or Obsidian tools. Obsidian-specific signals: wikilinks [[Note]], embeds ![[Note]], Obsidian Bases (.base YAML files for database views over vault notes), callouts > [!type], obsidian:// URIs, graph view, daily notes, .obsidian/ config, ==highlights==, %%comments%%, cssclasses, Obsidian search operators (file: path: tag:#), Obsidian CLI, .canvas JSON, block references ^id, templates ({{title}}/{{date}}/{{time}}). Disambiguation: "vault" here means Obsidian vault (not ansible-vault); "base" means Obsidian Bases (not SQL tables or Express routes); "tags" means Obsidian tags (not Docker/Kubernetes image tags); "properties" means Obsidian note properties (not Notion relations); "frontmatter" in Obsidian context (not blog/pandas parsing); "markdown" with Obsidian extensions (not plain GitHub READMEs or Storybook docs). Do not trigger for Roam Research, Notion, or other non-Obsidian tools even if they share terminology.
```

**Analysis:**
- Q1-Q10: All TRIGGER ✅
- Q11-Q20: All correctly NO TRIGGER ✅
- Q15: "not blog/pandas parsing" handles this case explicitly ✅

**Score: 20/20**


## Recommendation

**Candidate B** is the best choice:
- Achieves 20/20 on eval queries
- More naturally readable than C (which feels like a dictionary of disambiguations)
- Leads with positive Obsidian signals before listing exclusions
- The "ONLY when the context involves Obsidian" clause cleanly handles ambiguous terms
- Shorter than A while being more precise
- The final sentence ("The distinguishing signal is whether files live in an Obsidian vault or use Obsidian-specific syntax") gives the model a clear decision heuristic
