# Search and Plugins Reference

## Search Query Syntax

**Operators** (prefix to search term):
- `file:` — match file name
- `path:` — match file path
- `tag:` — match tag (includes nested tags)
- `line:` — match within single line
- `block:` — match within same block
- `task:` — match tasks; `task-todo:` unchecked, `task-done:` checked
- `section:` — match within same section
- `property:` — match property values
- `content:` — match note content only (exclude properties)

**Property searches**:
- `[property]` — notes that have this property
- `[property:value]` — notes where property equals value

**Combining**: Parentheses for grouping: `task:(call OR email)`
**Regex**: Forward slashes: `/pattern/`
**Case sensitivity**: Toggleable in search UI
**Embedding results**: Search results can be embedded in notes

## Core Plugins Overview

### Daily Notes
- Creates date-named notes (default YYYY-MM-DD)
- Nested folders via date formatting: `YYYY/MMMM/YYYY-MMM-DD` → `2023/January/2023-Jan-01`
- Configurable template, folder, and date format

### Templates
- Three variables: `{{title}}`, `{{date}}`, `{{time}}`
- Custom Moment.js formats: `{{date:YYYY-MM-DD}}`, `{{time:HH:mm}}`
- Properties in templates merge with existing note properties

### Canvas
- Visual graph with card types: text, file, media, webpage, folder
- Cards support markdown, connections with labels, colors
- Group cards, convert text cards to files

### Graph View
- **Filters**: tag/file filters, show/hide linked/unlinked
- **Groups**: group nodes by property or tag
- **Display**: arrows, text fade, node size, link thickness
- **Forces**: physics simulation (attraction/repulsion)
- **Local Graph**: depth-configurable connected notes view

### Bookmarks
- Bookmark files, folders, searches, graphs, headings, blocks

### Outline
- Shows heading structure of active note

### Backlinks
- Shows all notes linking to active note
- Shows unlinked mentions (text matching note name)

### Tags View
- Browse all tags hierarchically with counts

## Obsidian URI Scheme

Protocol: `obsidian://`

**Actions**:
- `obsidian://open?vault=VaultName&file=NoteName` — open a note
- `obsidian://new?vault=VaultName&name=NewNote&content=text` — create note
- `obsidian://daily?vault=VaultName` — open/create daily note
- `obsidian://search?vault=VaultName&query=text` — run search
- `obsidian://vault-manager` — open vault manager

**Parameters**:
- `vault` — vault name or ID
- `file` — note path (without .md extension)
- `path` — exact path from vault root
- `newWindow` — open in new window
- `openmode` — `tab`, `window`, `split`

**x-callback-url**: Supports `x-success`, `x-error` callbacks returning `name`, `url`, `file`

## Vault Structure

- Notes are plain text Markdown in a vault folder
- `.obsidian/` folder stores vault-specific settings (hidden)
- Don't create vaults within vaults
- Git tip: add `.obsidian/workspace.json` and `.obsidian/workspaces.json` to `.gitignore`
- Obsidian auto-refreshes when external editors modify files
