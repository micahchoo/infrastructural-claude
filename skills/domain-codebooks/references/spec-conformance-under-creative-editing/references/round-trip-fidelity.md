# Round-Trip Fidelity

## The Problem

When an editor imports a spec-conformant document, allows the user to modify it, and exports it again, the output must remain spec-conformant AND preserve data the editor didn't touch. This is harder than it sounds because:

1. **The editor's internal model is rarely isomorphic to the spec** — it includes UI state, omits "uneditable" properties, and restructures data for convenience.
2. **The spec may contain extension data the editor doesn't understand** — JSON-LD contexts, custom namespaces, vendor-specific properties.
3. **Re-serialization from the internal model drops everything not in the model** — a naive generate-from-scratch approach destroys unknown properties.

The failure mode is silent data loss: the user imports a document, changes one field, exports it, and discovers that metadata, extensions, or structural properties they never touched are gone. This erodes trust and makes the editor unsuitable for workflows where documents pass through multiple tools.

## Pattern: Spec-as-Serialization-Envelope

**When to use**: The domain data doesn't map naturally to the spec, but the spec provides a well-known container format that other tools can at least partially interpret.

### Allmaps: W3C Annotations as georeference envelope

Allmaps uses W3C Web Annotations not as an annotation system but as a **serialization envelope** for georeference data. The W3C spec knows nothing about ground control points or coordinate transformations, but the annotation structure provides body/target slots that Allmaps fills with domain-specific content:

- **Annotation body**: GeoJSON FeatureCollection containing GCPs (pixel-to-geo coordinate pairs)
- **Annotation target**: IIIF Canvas URI with SVG selector encoding the resource mask polygon
- `generateSvgSelector()` encodes polygon masks as SVG strings inside W3C annotation selectors — creative encoding within spec constraints

The result validates as a W3C Annotation (other tools can see it's an annotation targeting a IIIF canvas), but the domain-specific content in the body is opaque to generic annotation tools.

**Tradeoff**: Interoperability is partial — the envelope validates, but only Allmaps-aware tools can interpret the georeference data inside. This is acceptable because the alternative (a custom format) would have zero interoperability.

**Key files (allmaps repo)**:
- `packages/annotation/src/generator.ts` — generates W3C annotations from internal model; `generateSvgSelector()` for mask encoding
- `packages/annotation/src/parser.ts` — parses W3C annotations back to internal model

## Pattern: Normalize-Edit-Serialize with Vault

### IIIF Manifest Editor: Vault as round-trip mediator

The Digirati IIIF Manifest Editor uses Vault as an in-memory IIIF store. All editing happens against the normalized Vault representation, and export re-serializes from Vault state.

**Round-trip risk**: Vault mutations are immediate and irreversible (no undo stack, no dirty state tracking). Since the Vault normalizes inbound manifests to a single internal form, version-specific properties from the original document may not survive the normalize-edit-serialize cycle.

**Observed gap**: No conflict detection, no mutation history. The `EditingStack` tracks navigation (which resource is being edited) but not mutation history. Export is re-generation from Vault state, not a diff-merge against the original.

**Key architecture**:
- Vault (IIIF state manager) — single source of truth, `useVault()` hook
- No raw-document preservation alongside Vault — once normalized, the original structure is lost

## Pattern: Parse-Convert-Generate (Explicit Version Migration)

### Allmaps: Bidirectional conversion without in-place mutation

Rather than mutating documents in-place, Allmaps uses explicit conversion functions that parse old versions and generate new versions:

- `toGeoreferencedMap2()` — parse any version, generate v2
- `toAnnotation1()` — parse any annotation version, generate v1

This is a **lossy-by-design** approach: conversion doesn't attempt to preserve unknown properties from the source. It parses what the schema understands, discards the rest, and generates a clean document in the target version.

**When this works**: When the system controls both sides (parse and generate) and the conversion is between known versions of its own format — not round-tripping external documents.

**When this breaks**: When the document contains extension data from other tools. The parse-generate cycle strips anything not in the schema.

**Key file (allmaps repo)**:
- `packages/annotation/src/convert.ts`

## Pattern: Three-Layer Impedance Management

### Allmaps: IIIF spec / Annotation format / Editor DB

Allmaps operates across three independently-versioned data layers, each with its own schema:

| Layer | Versions | Schema location | Purpose |
|-------|----------|-----------------|---------|
| IIIF Presentation API | v2, v3 | `packages/iiif-parser/src/schemas/` | External spec for source manifests |
| Allmaps Annotation | Annotation v0/v1, GeoreferencedMap v1/v2 | `packages/annotation/src/schemas/` | Interchange format for georeference data |
| Editor DB | DbMap1, DbMap2, DbMap3 | `apps/editor/src/lib/schemas/maps.ts` | Internal persistence during editing |

Data flows through all three: IIIF manifest (layer 1) is parsed to extract canvas references, user edits create GeoreferencedMaps (layer 3 / DbMap), which serialize to W3C Annotations (layer 2) for export.

**Round-trip path**: Each layer boundary is a potential fidelity loss point. The system manages this by making conversions explicit and unidirectional — no attempt to reconstruct IIIF manifest properties from editor state. The IIIF manifest is read-only input; only the annotation layer is read-write.

**Key files (allmaps repo)**:
- `apps/editor/src/lib/schemas/maps.ts` — DbMap versioned schemas
- `apps/editor/src/lib/types/maps.ts` — DbMap TypeScript types

## Decision Framework

| Scenario | Recommended pattern | Why |
|----------|-------------------|-----|
| Domain data fits naturally in spec structure | Raw-document preservation (store original, merge edits back) | Minimizes data loss |
| Domain data is shoehorned into spec | Spec-as-envelope (Allmaps) | Accept partial interop, validate the envelope |
| Editor controls both import and export format | Parse-convert-generate (Allmaps convert.ts) | Clean versioned migration, acceptable loss |
| Editor must preserve arbitrary third-party extensions | Shadow-document pattern (store raw alongside internal model, merge on export) | Complex merge logic but no data loss |
| Single spec version, stable | Normalize-edit-serialize (Vault) | Simplest editing layer |

## Anti-Patterns

### Generate-from-scratch on every export
Rebuilding the entire document from internal model state, ignoring the original document structure. Guarantees data loss for any property the editor doesn't model.

### Implicit round-trip assumption
Assuming that parse(generate(parse(doc))) === parse(doc). In practice, generate() produces a canonical form that may differ from the original's formatting, property ordering, and optional fields.

### Shared mutable model across all three layers
When the IIIF model, annotation model, and editor model share the same objects. Mutations intended for one layer leak into others, making it impossible to reason about which layer "owns" a property.
