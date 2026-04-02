# Annotation Templates/Symbols

Template instances, property overrides, upstream sync, detach/fork. Distinct from OOP
inheritance — must interact correctly with undo, collaboration, and spatial transforms.

## Template-instance model

**Template** (Figma component, Penpot component): canonical shape with default properties.
**Instance**: references template, may override specific properties, inherits rest.

**Key principle: store only overrides.** Enables upstream sync — when template changes,
non-overridden properties automatically update.

Resolution: `{ ...template.properties, ...instance.overrides }`.

## Override tracking

Distinguish inherited (from template), overridden (explicitly set), and reset (reverted).
Track via Set of property paths, not value comparison — an override that coincidentally
matches the template value is still an override. Figma and Penpot both use explicit path
tracking.

On template update: iterate properties, propagate changes only to non-overridden paths.
Overridden properties untouched.

## Library sync

When templates live in shared libraries (Figma team libs, Penpot shared libs):

- **Eager** (Figma default): Library publishes → all files notified → user accepts/defers
- **Lazy**: Version check on file open, flag stale instances for batch update
- **Pinned**: Instance pins to template version, manual bump only

Template updates are document mutations → flow through collab channel → create undo entries.

## Detach/fork

Permanently breaks template-instance link. Instance becomes standalone with all resolved
values, loses future template updates.

When to offer: heavy overrides making template coupling pointless, template deletion from
library, export to formats without template refs (GeoJSON, W3C, IIIF — all instances must
resolve before export).

Detach creates undo entry. Undo must restore full link (templateId, version, overriddenPaths).

## Interactions with other axes

- **Undo**: Template changes and override changes are separate entries
- **Collaboration**: Same conflict resolution as other mutations (property-level LWW)
- **Selection**: Instance select ≠ template edit. Double-click enters template editing
- **Export**: Portable formats don't support templates — resolve all instances first

## Decision guide

| Context | Approach |
|---------|---------|
| Single-user, few reusable shapes | No templates — copy/paste |
| Team with shared styles | Library + eager sync |
| Offline-first | Pinned versions + manual bump |
| Export-heavy (GeoJSON, IIIF) | Templates internal; auto-resolve on export |
| Multi-file project | Shared library with cross-file tracking |
