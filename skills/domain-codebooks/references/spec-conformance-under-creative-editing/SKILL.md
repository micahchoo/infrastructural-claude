---
name: spec-conformance-under-creative-editing
description: >-
  Spec fidelity vs creative freedom vs implementation cost when building editors
  that produce or consume standardized formats (W3C Web Annotation, IIIF, GeoJSON,
  OpenDocument, SVG, MusicXML, BPMN). The tension: specs define what's valid, but
  users want to do things specs didn't anticipate, and strict conformance makes
  simple features expensive.

  Triggers: "IIIF manifest editor", "W3C annotation serialization", "GeoJSON
  feature editor that must round-trip", "SVG editor spec compliance", "export
  valid OpenDocument", "BPMN modeler validation", "spec version detection",
  "round-trip fidelity through edit cycles", "user wants feature X but the spec
  doesn't support it", "extension mechanisms vs spec purity", "MusicXML
  backward-compatible export", "JSON-LD compact vs expanded serialization",
  "BPMN DI waypoint constraint enforcement", "custom geometry types beyond
  GeoJSON RFC 7946".

  Brownfield triggers: "exported annotations fail validation", "round-trip
  loses custom properties", "supporting multiple spec versions is getting
  unmaintainable", "heuristic version detection breaks on edge cases",
  "extension data gets stripped on save", "SVG features work in browsers
  but not in SVG 1.1 spec", "custom IIIF annotation types silently dropped
  by other viewers", "internal properties leak into GeoJSON export and break
  parsers", "need to preserve unknown BPMN elements from other tools",
  "creative effects don't map to any SVG version", "incoming file has no
  version declaration", "older MusicXML readers can't handle new elements",
  "spec constraints block user's creative layout choices".

  Symptom triggers: "SVG features work in browsers but not in the SVG 1.1
  spec", "IIIF custom annotation types silently dropped by other viewers",
  "internal properties like selection state leak into GeoJSON export and
  break parsers", "BPMN editor needs to preserve unknown elements from other
  tools like Camunda", "pressure-sensitive strokes and animated gradients
  dont map to any SVG version", "incoming SVG has no version declaration and
  we need to detect SVG 1.1 vs 2 vs Tiny", "W3C Web Annotations compact
  vs expanded JSON-LD serialization for different consumers", "MusicXML 4.0
  elements that 3.1 readers like Finale and MuseScore cant handle",
  "BPMN DI waypoint constraints make creative layout invalid", "custom
  GeoJSON geometry types like circles and arcs rejected by other tools".
---

# Spec Conformance Under Creative Editing

The tension between faithfully implementing a standard and giving users creative
freedom that the standard didn't anticipate. This cluster produces spaghetti when
unresolved because spec-handling logic infiltrates every layer — parsing, UI,
validation, serialization — and version detection heuristics compound.

## Evidence repos
- **iiif-manifest-editor** — IIIF Presentation API v2/v3, W3C Annotations
- **allmaps** — IIIF + W3C Annotations as georeferencing envelope, 3-layer versioning (IIIF v1/2/3, annotation v0/1, DbMap v1/2/3), 10+ Zod schemas for version detection

## Force tensions

| Force A | vs | Force B | Pain when unresolved |
|---------|-----|---------|---------------------|
| Spec fidelity | vs | Creative features | Custom properties lost on round-trip; users blocked by spec limitations |
| Single spec version | vs | Multi-version support | Heuristic version detection, conditional code paths everywhere |
| Strict validation | vs | Permissive import | Valid documents rejected; invalid documents silently corrupted |
| Extension mechanisms | vs | Spec purity | Namespace pollution; extensions break other tools |
| Spec-native data model | vs | Internal convenience model | Translation layers, lossy mapping, impedance mismatch |

## Classify

1. **Spec** — which standard(s)? How stable? How many versions in the wild?
2. **Conformance level** — must-validate, best-effort, or import-only?
3. **Extension mechanism** — does the spec provide one (JSON-LD, XML namespaces, custom properties)?
4. **Round-trip requirement** — must unsupported properties survive edit cycles?
5. **Multi-version scope** — how many spec versions must coexist?

## Patterns

### Version-Gated Schema Hierarchy
Separate Zod/JSON Schema per spec version, with a detector that routes to the right
schema. Allmaps pattern: detect IIIF version heuristically, parse with version-specific
schema, normalize to internal model.

**Tradeoff**: Explicit but schema count grows multiplicatively (versions × entity types).

### Extension-Preserving Round-Trip
Store raw spec-conformant data alongside internal model. On save, merge edits back
into the original structure, preserving unknown properties.

**Tradeoff**: Complex merge logic, but no data loss.

### Conformance-Level Layering
Import permissively (accept invalid), edit freely (internal model), export strictly
(validate on output). Validation is a serialization concern, not an editing concern.

**Tradeoff**: Users may create documents they can't export without fixing validation errors.

### Spec-as-Serialization-Envelope
Use the spec format purely for interchange, with a richer internal model. Allmaps uses
W3C Annotations as a container for georeference data that the W3C spec knows nothing about.

**Tradeoff**: Other tools can't interpret the domain-specific content, but the envelope validates.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| schema-evolution-under-distributed-persistence | Spec versions ARE schema versions — migration strategies apply directly |
| embeddability-and-api-surface | Embedded editors must expose spec-conformant API while hiding internal model |
| distributed-state-sync | Multi-user editing of spec-conformant documents adds merge conflicts at the spec validation layer |

## References

Load as needed:
- `get_docs("domain-codebooks", "spec-conformance version detection")` — Heuristic detection, version-gated schema hierarchies, Vault normalization; evidence from allmaps `iiif-parser` + Digirati Manifest Editor
- `get_docs("domain-codebooks", "spec-conformance round-trip fidelity")` — Spec-as-envelope, normalize-edit-serialize, parse-convert-generate, three-layer impedance; evidence from allmaps `annotation` + Digirati Manifest Editor Vault
