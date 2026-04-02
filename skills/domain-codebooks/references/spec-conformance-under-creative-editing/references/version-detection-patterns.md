# Version Detection Patterns

## The Problem

When a system must consume multiple versions of the same spec (IIIF Presentation API v2 vs v3, W3C Annotation v0 vs v1), every inbound document needs version detection before parsing. The naive approach — a single parser with version-conditional branches — quickly becomes unmaintainable as version count and entity types grow multiplicatively (versions x entity types = schema count). Heuristic detection that works for 95% of documents silently misroutes the other 5%, producing parse errors that look like data corruption rather than version mismatches.

## Pattern: Heuristic Detect, Then Route to Version-Specific Schema

**How it works**: A lightweight detector examines structural signals to determine the spec version, then routes the document to a version-specific Zod schema for full validation.

### Allmaps IIIF version detection

Allmaps must read IIIF Presentation API v2 and v3, plus IIIF Image API v1/v2/v3. The key structural differences:

| Signal | IIIF v2 | IIIF v3 |
|--------|---------|---------|
| Identity field | `@id` | `id` |
| Type field | `@type` | `type` |
| JSON-LD context | `http://iiif.io/api/presentation/2/context.json` | `http://iiif.io/api/presentation/3/context.json` |

**Detection strategy**: `IIIF.parse()` checks `@context` first (most reliable), then falls back to `@id` presence (structural heuristic). Once version is determined, the document routes to version-specific Zod schemas in `packages/iiif-parser/src/schemas/`.

**Key files (allmaps repo)**:
- `packages/iiif-parser/src/classes/iiif.ts` — `IIIF.parse()` with heuristic detection
- `packages/iiif-parser/src/schemas/iiif.ts` — version-specific Zod schemas
- `packages/iiif-parser/src/schemas/` — 10+ schema files across IIIF versions

### Allmaps annotation version detection

Separate from IIIF, Allmaps maintains its own versioned annotation format:
- **Annotation v0/v1** — wrapper format versions
- **GeoreferencedMap v1/v2** — domain entity versions
- **AllVersionsSchema** — Zod union of all known versions, used as the entry point

**Key files (allmaps repo)**:
- `packages/annotation/src/schemas/georeferenced-map/` — versioned GeoreferencedMap schemas
- `packages/annotation/src/schemas/annotation/` — versioned annotation wrapper schemas
- `packages/annotation/src/parser.ts` — parse entry point using AllVersionsSchema

## Pattern: Version-Gated Schema Hierarchy

**Architecture**: One Zod schema per (version x entity type) combination. A discriminated union at the top level routes to the correct branch. Version conversion functions provide explicit migration paths.

**Allmaps three-layer versioning**:
1. **IIIF API versions** (v1/v2/v3) — external spec, parsed via `iiif-parser`
2. **Allmaps annotation versions** (Annotation v0/v1, GeoreferencedMap v1/v2) — domain format
3. **Editor DB map versions** (DbMap1/DbMap2/DbMap3) — internal persistence schema

Each layer has independent version detection and version-specific schemas. Conversion between layers goes through explicit functions:
- `convert.ts` provides `toGeoreferencedMap2()`, `toAnnotation1()` — round-trip via parse-then-generate
- No in-place migration; always parse old version, generate new version

**Key file (allmaps repo)**:
- `packages/annotation/src/convert.ts`

### IIIF Manifest Editor (Digirati)

Uses **Vault** — an in-memory IIIF store that normalizes all IIIF resources into a consistent internal representation. The Vault acts as a version-absorbing layer: inbound manifests (v2 or v3) are normalized on import, edited in normalized form, and serialized back to the target spec version on export.

**Architecture difference from Allmaps**: Allmaps routes to version-specific schemas and preserves version context. The Manifest Editor normalizes to a single internal form, losing version-specific structure but simplifying the editing layer.

**Key file (iiif-manifest-editor repo)**:
- Vault (IIIF state manager) — single source of truth for all IIIF resources

## Tradeoffs

| Approach | Pros | Cons |
|----------|------|------|
| Heuristic detect + version-specific schema | Preserves version fidelity; explicit migration paths | Schema count grows multiplicatively; heuristic can misroute edge cases |
| Normalize-on-import (Vault pattern) | Editing layer is version-agnostic; simpler UI code | Lossy — version-specific properties may not survive round-trip; export must reconstruct spec-specific structure |
| AllVersionsSchema union | Single parse entry point; Zod discriminates automatically | Union error messages are confusing when no branch matches; performance cost of trying all branches |

## Anti-Patterns

### Version detection scattered across call sites
When version checks (`if (doc['@id']) ...`) appear throughout the codebase instead of being centralized in a detector. Leads to inconsistent detection logic and missed version signals.

### Implicit version assumption
When code assumes a specific spec version without detection. Works until a user submits a document in a different version, which silently parses incorrectly rather than failing loudly.

### Version-conditional branches in business logic
When `if (version === 2) { ... } else { ... }` appears in editing/rendering code rather than being absorbed by the schema/normalization layer. The version concern should be contained in the parse and serialize boundaries.
