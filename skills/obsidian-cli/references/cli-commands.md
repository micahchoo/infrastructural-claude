# Obsidian CLI Command Reference

## Requirements
- Obsidian 1.12+ (early access, Catalyst license)
- App must be running
- Enable: Settings → General → Command line interface
- **Flatpak install**: Every command needs `DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"` prefix (the CLI communicates with the running app via D-Bus, but Flatpak-exported binaries don't inherit the session bus address). All examples below omit this for brevity.

## Modes
- Single command: `obsidian <command>`
- TUI (interactive): `obsidian` alone, with autocomplete, history, reverse search

## Parameter Syntax
- `parameter=value` (quote values with spaces)
- Flags are boolean switches (no value)
- Multiline: `\n` for newline, `\t` for tab
- Target vault: `vault=<name>` (must be first param)
- Target file: `file=<name>` (wikilink-style) or `path=<path>` (exact from vault root)

## Command Reference

### General
- `help` — show help
- `version` — show version
- `reload` — reload vault (pick up external file changes)
- `restart` — restart Obsidian

### Bases
- `bases` — list all .base files
- `base:views path=<base>` — list views in a base
- `base:create` — create a new base
- `base:query path=<base> format=json|tsv` — query a base, see rendered results
  - `view="View Name"` — query specific view

### Files & Folders
- `file` — show file info
- `files` — list files
- `folder` — show folder info
- `folders` — list folders
- `open path=<file>` — open a file
- `create` — create a file
- `read path=<file>` — read file contents
- `append path=<file> content=<text>` — append to file
- `prepend path=<file> content=<text>` — prepend to file
- `move` — move/rename a file
- `delete` — delete a file

### Properties
- `properties counts sort=count` — list all properties with counts
- `properties name=<prop>` — check specific property
- `properties path=<file>` — check properties on file
- `property:set` — set a property value
- `property:remove` — remove a property
- `property:read` — read a property value
- `aliases` — list aliases

### Tags
- `tags counts sort=count` — list all tags
- `tag name=<tag> verbose` — check specific tag

### Search
- `search query=<text> path=<folder> format=text|json` — search vault
- `search:context query=<text> limit=N` — search with line context
- `search:open` — open search in app

### Links
- `backlinks` — list backlinks
- `links` — list outgoing links
- `unresolved` — list unresolved links
- `orphans` — list orphan notes
- `deadends` — list dead-end notes

### Daily Notes
- `daily` — open/create today's daily note
- `daily:read` — read today's daily note
- `daily:append` — append to daily note
- `daily:prepend` — prepend to daily note

### Templates
- `templates` — list templates
- `template:read` — read a template
- `template:insert` — insert a template into a file

### Tasks
- `tasks` — list tasks (filters: `file`, `status`, `all`, `daily`, `todo`, `done`, `verbose`)
- `task` — show/update task (`toggle`/`done`/`todo`)

### Plugins
- `plugins` — list plugins
- `plugins:enabled filter=core` — list enabled plugins
- `plugin:enable id=<id> filter=core` — enable a plugin
- `plugin:disable` — disable a plugin
- `plugin:install` — install a plugin
- `plugin:uninstall` — uninstall a plugin
- `plugin:reload` — reload a plugin

### Themes & Snippets
- `themes` — list themes
- `theme:set` — set active theme
- `theme:install` — install a theme
- `theme:uninstall` — uninstall a theme
- `snippets` — list CSS snippets
- `snippets:enabled` — list enabled snippets
- `snippet:enable` — enable a snippet
- `snippet:disable` — disable a snippet

### Workspace
- `workspace` — show current workspace
- `workspaces` — list workspaces
- `workspace:save` — save workspace
- `workspace:load` — load workspace
- `workspace:delete` — delete workspace
- `tabs` — list open tabs
- `tab:open` — open a tab
- `recents` — list recently opened files

### Sync
- `sync` — show sync info
- `sync:status` — show sync status
- `sync:history` — show sync history
- `sync:read` — read a synced version
- `sync:restore` — restore a synced version
- `sync:open` — open sync in app
- `sync:deleted` — list deleted files in sync

### Publish
- `publish:site` — show publish site info
- `publish:list` — list published files
- `publish:status` — show publish status
- `publish:add` — add file to publish
- `publish:remove` — remove file from publish
- `publish:open` — open publish in app

### Developer/Debugging
- `devtools` — open Chrome DevTools
- `dev:debug` — toggle debug mode
- `dev:screenshot path=/tmp/screenshot.png` — capture screenshot
- `dev:errors` — check for JS errors
- `dev:console` — open dev console
- `dev:css` — inspect CSS
- `dev:dom` — inspect DOM
- `dev:mobile` — toggle mobile emulation
- `eval code="<js>"` — run JS in Obsidian console
  - `eval code="app.vault.getFiles().length"`
  - `eval code="app.metadataCache.getTags()"`

### Other
- `bookmarks` — list bookmarks
- `bookmark` — manage a bookmark
- `commands` — list commands
- `command` — run a command
- `hotkeys` — list hotkeys
- `hotkey` — manage a hotkey
- `outline` — show document outline
- `random` — open a random note
- `random:read` — read a random note
- `unique` — unique note creator
- `vault` — show vault info
- `vaults` — list vaults
- `vault:open` — open a vault
- `web` — web viewer
- `wordcount` — show word count
- `diff` — show file diff
- `history` — show file history
- `history:list` — list file history entries
- `history:read` — read a history entry
- `history:restore` — restore a history entry
- `history:open` — open history in app

## Common Debugging Patterns

### Debug a .base file
```bash
obsidian bases                                      # Check if listed
obsidian base:query path=timeline.base format=json  # See rendered results
obsidian base:query path=timeline.base view=Monthly format=tsv  # Specific view
obsidian tag name=whatsapp/daily verbose             # Verify filter tags exist
```

### Verify properties
```bash
obsidian properties name=topic_priority             # Check if recognized
obsidian property:read name=topic_priority path="path/to/note.md"
```

### Force refresh
```bash
obsidian reload    # Pick up external file changes
```
