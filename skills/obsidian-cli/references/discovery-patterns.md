# Discovery Layer — Service Design

A discovery layer turns a vault from a filing cabinet into a navigable service. Three touchpoints — properties, bases, and graph — work together to support user journeys through the vault's content.

## Touchpoints

| Touchpoint | Role | Strengths |
|------------|------|-----------|
| **Properties** | Structured metadata per note | Powers base queries; wikilink values create graph edges |
| **Bases** | Filtered, grouped, computed views | Answers specific questions ("who?", "when?", "about what?") |
| **Graph** | Link topology and spatial exploration | Reveals connections, clusters, and orphans that queries miss |

These are complementary: bases answer "show me all X sorted by Y," graph answers "what connects to what?"

## Designing Properties for Discovery

Properties serve double duty — they power base queries AND create graph structure when their values are wikilinks:

- **Wikilink-valued properties** create edges visible in graph view — use for entities you want to *navigate between* (people, channels, places)
- **Plain text properties** are invisible to graph but queryable in bases — use for values you want to *filter and aggregate* (topics, counts, URLs)
- **Tag hierarchies** define note types for base filtering without cluttering graph — use `source/type` patterns (e.g., `project/task`, `meeting/standup`), keep shallow (2 levels max)

## Designing Bases for Discovery

Each base answers one discovery question using the **filter-formula-view stack**:

1. **Filters** narrow to relevant note types (tag-based) and non-empty data
2. **Formulas** compute derived values (durations, counts, formatted dates, categorization)
3. **Views** offer lenses — table for scanning, cards for browsing, grouped views for patterns

**Pattern: hub page.** A single note embeds the most useful view from each base using `![[some.base#ViewName]]` syntax, creating a unified dashboard without duplicating query logic.

**Pattern: base hierarchy.** Cross-cutting bases at vault root give the unified view. Scoped bases in subdirectories give deep-dive access into specific collections.

## Configuring Graph View

**WARNING: Do NOT configure native `graph.json` programmatically.** Obsidian overwrites `.obsidian/graph.json` every time the graph panel opens. Any programmatic changes will be lost.

**Use Extended Graph plugin** instead — its config persists in `.obsidian/plugins/extended-graph/data.json` and survives graph panel opens.

- **Groups** color-code nodes by search query (e.g., `tag:#project/task` in one color, `tag:#person` in another)
- **Filters** hide noise — toggle off attachments and orphans, or use search to focus on subsets
- **Local graph** on a specific note shows immediate connections — useful for exploring a node's neighborhood
- **Extended Graph features**: auto-colormap for tags, shapes per note type, property-based edges. Configure via the plugin's settings UI — per-tag color override JSON format is not well documented, so prefer the UI.

**Graph + bases workflow:** Use a base to find something interesting → open the note → switch to local graph to see context. The base gets you *to* the right node; graph shows the *neighborhood around* it.

## Discovery Canvas Pattern

A `.canvas` file provides a spatial overview of the discovery layer — a map of maps. Use group nodes for logical sections, file nodes with `subpath` to embed specific base views, and text nodes for orientation. Color-code groups to match graph scheme. This gives newcomers to the vault a visual entry point.

## Building a Discovery Layer

1. **Define entity types** — what gets its own note vs. what stays as a plain property. Entities appearing across many notes benefit most from wikilinks.
2. **Design tag hierarchies** — `source/type` patterns for base filtering. Keep shallow.
3. **Create per-question bases** — one `.base` per discovery question. Start with tables, add views as patterns emerge.
4. **Build a hub page** — embeds the best view from each base. Tag it distinctively for easy access.
5. **Configure graph via Extended Graph** — NOT native `graph.json`. Use auto-colormap, shapes, property edges.
6. **Create a discovery canvas** — spatial map linking hub, bases, and collection sections.
7. **Iterate** — when bases reveal entity clusters, that signals a new base or graph group.

## Discovery Layer Maintenance

- **Zombie properties**: audit `.obsidian/types.json` — remove entries with zero occurrences
- **Schema consistency**: ensure all note collections use the same property names and types
- **Wikilink integrity**: verify wikilinked property values resolve to actual notes (broken links create orphan graph nodes)
- **Extended Graph config**: lives in `.obsidian/plugins/extended-graph/data.json` — back up before plugin updates
- **Re-enrichment**: after pipeline or schema changes, re-run enrichment across existing notes to propagate updates
