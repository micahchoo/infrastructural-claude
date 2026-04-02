# Properties and Tags Reference

## Properties (YAML Frontmatter)

Structured metadata at the top of a note, enclosed in `---` fences.

```yaml
---
title: "My Note"
tags:
  - project
  - active
date: 2026-03-15
rating: 4.5
done: true
aliases:
  - "alternate name"
cssclasses:
  - wide-page
---
```

### Property Types

| Type | Format | Example |
|------|--------|---------|
| **Text** | Single-line string | `author: "Jane Doe"` |
| **List** | YAML list (hyphens) | `tags:\n  - one\n  - two` |
| **Number** | Integer or decimal | `rating: 4.5` |
| **Checkbox** | Boolean | `done: true` |
| **Date** | ISO date | `date: 2026-03-15` |
| **Date & time** | ISO datetime | `due: 2026-03-15T14:30:00` |
| **Tags** | Special list type | Only valid for the `tags` property |

- No expressions in Number fields (`rating: 3+1` is invalid).
- Text fields don't render markdown. URLs and `[[links]]` work but must be quoted.

### Reserved Properties

| Property | Type | Purpose |
|----------|------|---------|
| `tags` | List | Organizing tags |
| `aliases` | List | Alternate names for link autocomplete |
| `cssclasses` | List | CSS classes applied to the note view |

### Publish-Only Properties

`publish`, `permalink`, `description`, `image`, `cover` -- used by Obsidian Publish.

### Rules

- Property names must be **unique** within a note.
- A property name's type is **vault-global**: once assigned, all notes use that type for that name.
- **Hotkey**: `Cmd/Ctrl + ;` adds a new property.
- Templates **merge** properties (don't overwrite existing values).
- Display modes: **Visible** (default), **Hidden**, **Source**.

## Tags

### Syntax

**Inline** (note body):
```markdown
This is about #project-management and #research/nlp.
```

**Property** (frontmatter):
```yaml
tags:
  - project-management
  - research/nlp
```

Both forms are equivalent for search and Dataview queries.

### Format Rules

- **Allowed characters**: letters, numbers, `_`, `-`, `/`
- **Must contain at least one non-numeric character**: `#1984` is invalid, `#y1984` is valid
- **Case-insensitive**: `#Tag` and `#tag` match; display preserves first-created casing
- **No spaces**: use `camelCase`, `PascalCase`, `snake_case`, or `kebab-case`

### Nested Tags

Use `/` to create hierarchy: `#parent/child/grandchild`

- Searching `tag:inbox` matches `#inbox` **and** all descendants like `#inbox/to-read`
- Each level is independently searchable: `tag:inbox/to-read` matches only that specific tag and its children
