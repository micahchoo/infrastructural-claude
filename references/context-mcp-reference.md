# Context MCP Reference

## Package Discovery by Task

When starting a task, check which packages are relevant. Key mappings:

| Task type | Packages to query |
|-----------|------------------|
| **Architecture/patterns** | `domain-codebooks`, `claude-skill-tree` |
| **System design / infrastructure** | `system-design` (skill), `domain-codebooks` |
| **Obsidian vault work** | `obsidian-skill`, `obsidian` |
| **Security review/pentest** | `payloads`, `secret-knowledge` |
| **CLI command lookup** | `tldr`, `cheatsheets` |
| **Docker/containers** | `docker`, `portainer`, `ollama` |
| **Claude/Anthropic API** | `claude-code`, `anthropic-cookbook`, `anthropic-quickstarts`, `mcp-spec`, `mcp-ts-sdk` |
| **Frontend implementation** | `react`, `next`, `svelte`, `tailwindcss`, `vue`, `astro` |
| **Backend/API** | `express`, `nestjs`, `fastapi`, `hono`, `drizzle-orm`, `prisma` |
| **Testing** | `vitest`, `jest`, `eslint` |
| **Build tooling** | `vite`, `webpack`, `rollup`, `esbuild`, `turbo`, `typescript` |
| **State/data** | `zustand`, `jotai`, `rxjs`, `bullmq`, `kysely` |
| **Mapping/geo** | `leaflet`, `maplibre`, `allmaps`, `threejs` |
| **Collaboration/CRDT** | `yjs`, `weavejs`, `upwelling-code`, `excalidraw`, `tldraw-docs` |
| **Canvas/drawing apps** | `tldraw-docs`, `excalidraw`, `penpot`, `domain-codebooks` |
| **ML/AI** | `ai`, `fastapi`, `pydantic` |
| **Reference codebases** | `allmaps`, `excalidraw`, `FossFLOW`, `iiif-manifest-editor`, `memories`, `neko`, `penpot`, `recogito2`, `upwelling-code`, `weavejs`, `yjs` |
| **Skill system** | `claude-skill-tree`, `domain-codebooks`, `obsidian-skill` |

| **Design patterns** | `refactoring-examples`, `design-patterns-*` (13 languages indexed from RefactoringGuru) |

Run `context list` to see all installed packages. For missing libraries, `context browse <name>` or `context add <repo>`.

## Query Style Guide

FTS5 queries work best with **2-4 short keywords**, not natural language. Verbose queries return 0 results.

| Intent | Bad query (0 results) | Good query (hits) |
|--------|----------------------|-------------------|
| API lookup | "how to use dependency injection with async" | `dependency injection` |
| Config | "container query responsive grid breakpoint" | `container queries` |
| Pattern | "CRDT OT operational transform collaborative text editing tradeoffs" | `CRDT conflict` |
| Debug | "hydration mismatch server client component" | `hydration mismatch` |

## CLI Reference

```
context browse <name>          # Search registry: context browse npm/next, context browse react
context install npm/<pkg>      # Install from registry: context install npm/next 15.0.4
context install pip/<pkg>      # Python: context install pip/django
context add <url>              # Build from git: context add https://github.com/org/repo --path docs --name mylib --tag v2.0
context add <dir>              # Build from local: context add ./my-project --name mylib --pkg-version 1.0
context add <file.db>          # Install pre-built: context add ./mylib@2.0.db
context list                   # Show installed packages
context remove <name>          # Remove a package
context query '<pkg>' '<q>'    # Test queries: context query 'next@15.5.13' 'server actions'
```

If `context add` warns "few sections found", the docs likely live in a separate repo (`project-docs`, `project.dev`, `project-website`).

## Skill Tree Lookup (`claude-skill-tree@1.0`)

The entire `~/.claude/` directory is indexed as `claude-skill-tree@1.0`. Use it to look up skills, codebooks, hooks, and references without reading files into context:

- **Before invoking a skill**: `get_docs("claude-skill-tree", "<skill-name> workflow")` to refresh on the skill's process.
- **When routing between skills**: `get_docs("claude-skill-tree", "<skill> trigger")` to check trigger conditions and negative space.
- **When advising on architecture**: `get_docs("claude-skill-tree", "<force-cluster> codebook")` to pull relevant codebook sections.
- **When onboarding to the skill system**: `get_docs("claude-skill-tree", "skill tree overview")` to understand what's available.
- **Keep it current**: After creating or modifying skills, rebuild with `context add ~/.claude --name claude-skill-tree --pkg-version <new-version>`.
