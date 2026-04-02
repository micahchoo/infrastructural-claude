# Obsidian Patterns

## Create a new note with proper frontmatter

```markdown
---
tags:
  - category/subcategory
aliases:
  - Alternate Name
created: 2025-06-01
---

# Note Title

Content using [[links]], ==highlights==, and %%comments%%.
```

## Debug a .base file

1. **Read the .base file first** — validate YAML syntax, check filter expressions match actual tag/folder names
2. **Common mistakes**: wrong tag name (`#topic` vs `#topics`), missing quotes around strings in filters, `note.prop` for frontmatter vs just `prop`
3. **If CLI available**, verify against live vault:
```bash
obsidian base:query path=mybase.base format=json    # What renders?
obsidian base:query path=mybase.base format=tsv     # Tabular view
obsidian tags counts sort=count                     # Do filter tags exist?
obsidian properties name=my_prop                    # Property recognized?
obsidian reload                                     # Force refresh
```
4. If CLI unavailable, check tags/properties by grepping frontmatter in vault files.

## Embed a base in a note

````markdown
```base
filters:
  - file.hasTag("meeting")
views:
  - type: table
    order:
      - file.name
      - date
      - attendees
```
````

## Create a base that tracks the active note's context

Use `this` to make the base reactive to what's open:
```yaml
filters:
  - file.hasLink(this.file)
views:
  - type: list
    name: Related Notes
```

## `this` gotcha in templates

When embedding a base in a **template** file, `this.file` refers to the template itself during editing — but after the template is inserted into a new note, `this.file` correctly refers to the new note. Keep this in mind when testing template-embedded bases. If the base is in a standalone `.base` file, `this` always refers to the `.base` file itself.

## Validating Programmatically Generated Notes

When building or maintaining tools that generate Obsidian notes (converters, importers, archive pipelines), validate output against these common failure modes:

**Frontmatter validation:**
- Properties must be valid YAML between `---` fences — a single unquoted colon in a value breaks the entire note
- Property names used across notes must have consistent types (don't use `status` as text in one note and list in another)
- Tags in frontmatter must follow Obsidian rules: no spaces, no leading numbers, `_-/` only for special chars
- Dates must be ISO 8601 (`YYYY-MM-DD`) or Obsidian won't recognize them as date-type properties

**Wikilink integrity:**
- `[[Target]]` links should resolve to actual files in the vault — orphan links create graph noise
- Display text `[[Target|Display]]` must not contain `|` in the display portion
- Filenames used in links must avoid Obsidian-illegal chars: `* " \ / < > : | ?`

**.base file validation:**
- Filter expressions must reference tags/properties that actually exist in the vault
- Formula properties must handle null/missing values (notes without the property will error)
- `displayName` entries in `properties:` should match the column set in `views.[].order`

**Bulk generation checklist:**
```bash
# If Obsidian CLI is available:
obsidian properties counts sort=count        # Spot unexpected property names
obsidian tags counts sort=count              # Spot malformed or duplicate tags
obsidian base:query path=mybase.base         # Verify base renders correctly
obsidian dev:errors                          # Check for vault-level errors

# Without CLI — grep-based validation:
# Find notes with broken frontmatter (no closing ---)
grep -rL '^---$' vault/ --include='*.md' | head -20
# Find wikilinks to nonexistent notes
# (extract [[targets]], diff against file list)
```

These patterns apply to any programmatic vault generation — WhatsApp/Discord converters, API importers, static site migrations, Notion exports, etc.

## Note template best practices

When creating Obsidian note templates:
- Always include `cssclasses` in frontmatter for custom styling
- Use `{{title}}`, `{{date:YYYY-MM-DD}}`, `{{time:HH:mm}}` template variables
- Use native `> [!type]` callouts, not HTML for structured sections
- For embedded task queries, prefer ` ```base ` code blocks over Dataview — Bases is the native, built-in solution
- Include `%%comments%%` for template instructions that disappear in reading view
