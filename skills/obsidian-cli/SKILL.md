---
name: obsidian-cli
description: "Obsidian vault expertise \u2014 triggers when the user\u2019s task involves an Obsidian vault or Obsidian-flavored markdown. Key Obsidian signals: wikilinks ([[]], ![[]]), .base YAML files (Obsidian Bases \u2014 database views over vault notes, NOT SQL base tables), > [!type] callouts, obsidian:// URIs, graph view, daily notes, ==highlights==, %%comments%%, cssclasses/aliases properties, Obsidian search (file: path: tag:# operators), the Obsidian CLI, .canvas files, .obsidian/ config, block references ^id, and note templates ({{title}}, {{date}}, {{time}}). Contextual triggers: frontmatter properties, tags, and vault structure ONLY when the context involves Obsidian \u2014 not Kubernetes YAML, blog post frontmatter, Docker image tags, ansible-vault encryption, Notion databases, Express route bases, SQL base tables, Roam Research, or generic GitHub/Storybook markdown. The distinguishing signal is whether files live in an Obsidian vault or use Obsidian-specific syntax. Also triggered when chat-archive-ner-tuning needs vault operations for generated notes, or when hybrid-research encounters Obsidian vault files during investigation."
---

# Obsidian

Guide for working with Obsidian vaults — creating notes, writing Obsidian-flavored markdown, managing properties and tags, linking and embedding, building Bases, using the CLI, and more.

## Quick Reference

Core Obsidian concepts are covered in dedicated reference files. Load them as needed:

| Topic | Reference file |
|-------|---------------|
| OFM syntax, callouts, highlights, comments | `references/markdown-and-formatting.md` |
| Properties (frontmatter), tags, types | `references/properties-and-tags.md` |
| Wikilinks, embeds, block references | `references/linking-and-embedding.md` |
| Bases: filters, formulas, views, .base files | `references/bases.md` |
| Obsidian CLI commands, Flatpak setup | `references/cli-commands.md` |
| Search operators, plugins | `references/search-and-plugins.md` |

**Key vault rules:**
- Notes are plain text Markdown files in a vault folder
- `.obsidian/` stores vault-specific settings — `.gitignore` should include `workspace.json` and `workspaces.json`
- Obsidian auto-refreshes when external editors modify files
- Don't nest vaults inside vaults (links won't update correctly)

If docs are incomplete or stale: `[UNKNOWN: what official docs or vault investigation needed]`.

`[eval: vault-identified]` Obsidian vault root (.obsidian/ directory) located and confirmed.

## When to Look Up Reference Details

Use `get_docs` before reading reference files — two packages: `obsidian-skill` (43 sections: bases, CLI, properties, linking, formatting, search) and `obsidian` (2183 sections: official help docs, plugins, settings, troubleshooting). Query with 2-4 keywords.

`[eval: reference-consulted]` Relevant reference docs or Context MCP queried before creating or modifying vault content.

## Discovery Layer

For designing vault navigation systems (properties for graph edges, bases for queries, hub pages, canvas overviews), see `references/discovery-patterns.md`.

`[eval: structure-designed]` Navigation scheme selected (properties, tags, folder layout, or bases) with rationale tied to vault's existing conventions.

## Patterns

Common recipes for notes, bases, templates, and validation — see `references/patterns.md`. When chat-archive-ner-tuning produces entity-tagged notes for a vault, this skill handles path selection, frontmatter, and wikilink wiring. When hybrid-research traverses vault files, use Obsidian syntax awareness to avoid misinterpreting wikilinks and callouts.

`[eval: content-authored]` Note or base file written to disk at the correct vault path with valid frontmatter properties.

`[eval: links-wired]` All wikilinks, embeds, and block references resolve to existing notes or are flagged as intentional stubs.

`[eval: syntax-validated]` Output uses Obsidian-flavored markdown (wikilinks, callouts, highlights, comments) — not generic markdown equivalents.

