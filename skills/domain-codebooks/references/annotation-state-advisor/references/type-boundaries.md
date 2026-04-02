# Type Safety at Library Boundaries

## The Problem

Annotation editors sit at the intersection of multiple library ecosystems — mapping libraries (MapLibre, Mapbox), CRDT frameworks (Yjs), rendering engines (Konva, Canvas 2D), and annotation standards (W3C Web Annotation, IIIF, GeoJSON). Each library defines its own type universe with subtly incompatible assumptions. A GeoJSON `Feature` from MapLibre has different fields than one from the GeoJSON spec. Yjs Maps are typed as `any`. W3C Web Annotation bodies can be deeply nested discriminated unions that no UI component wants to consume directly.

The result is a codebase riddled with `@ts-ignore`, `as unknown as`, and runtime type errors that TypeScript was supposed to prevent. Developers suppress type errors to ship, then spend hours debugging runtime failures where a tile-internal integer ID hits an API expecting a UUID string, or a shallow merge silently drops extension data nested three levels deep. The type system becomes adversarial rather than helpful — it flags real problems but offers no path to resolution that doesn't involve unsafe casts.

These aren't one-off issues to patch individually. They're structural consequences of combining libraries that weren't designed to work together, operating on data formats that predate TypeScript's type system. The solution requires systematic patterns: validation at boundaries, branded types for semantic distinctions, coordinate system contracts, and extension-aware update strategies.

## Competing Patterns

## Ambient declaration conflicts

MapLibre issue #4855: `@types/css-font-loading-module` declares `FontFaceSet.onloadingdone` with `FontFaceSetLoadEvent`, conflicting with `lib.dom.d.ts` (`Event`). Produces `TS2717`. Breaks without `skipLibCheck: true`. Root cause: transitive dependency introduces clashing ambient declarations.

## MapLibre / Mapbox dual-support

Anti-pattern: `// @ts-ignore` on every `addControl()` call.

Solution (MapLibre blog, Tyler Austin, Jan 2023) — intersection types work because the libraries are structurally similar:
```typescript
import { IControl as MapboxIControl, Map as MapboxMap } from 'mapbox-gl';
import { IControl as MaplibreIControl, Map as MaplibreMap } from 'maplibre-gl';
type IControl = MapboxIControl & MaplibreIControl;
type Map = MapboxMap & MaplibreMap;
```

Since Mapbox GL JS v3.5.0 ships own types, naming diverges: Mapbox uses `*Specification` suffixes (`StyleSpecification`) where community types used bare names (`Style`, `AnyLayer`).

## Terra Draw type isolation

Before monorepo split (issue #350), Terra Draw bundled all adapter types in one package, forcing installation of `@types/google.maps`, `@arcgis/core`, OpenLayers types even for MapLibre-only users. Fix: separate packages (`terra-draw-maplibre-gl-adapter`).

`@watergis/maplibre-gl-terradraw` adds peer deps on `maplibre-gl ^4.0.0 || ^5.0.0` + `terra-draw ^1.0.0`.

## GeoJSON Geometry union friction

MapLibre discussion #6323: `event.features[0].geometry.coordinates` fails because `GeometryCollection` lacks `coordinates`. Narrow on `geometry.type`:
```typescript
const geom = feature.geometry;
if (geom.type === 'Point') {
  const coords = geom.coordinates; // safe
}
```
Anti-pattern: `@ts-expect-error` instead of narrowing.

## MapLibre / GeoJSON feature types

`MapGeoJSONFeature` adds `layer`, `source`, `sourceLayer` and types `id` as `string | number | undefined`, diverging from `GeoJSON.Feature`. Use `as unknown as` with documentation:
```typescript
const feature = event.features[0] as unknown as GeoJSONFeature;
// TYPE_DEBT: MapGeoJSONFeature has optional fields that GeoJSONFeature requires.
// Safe here because we always set feature IDs when adding to the map.
```
Direct `as T` fails when types don't overlap — two-step cast via `unknown` is the approved escape hatch. Document every instance for audit.

## Feature ID divergence across source types

`feat.id` means different things by source — all typed `string | number | undefined`:
- **GeoJSON source**: whatever you set — typically database UUID
- **Vector tile source**: tile-internal integer from tiling; DB ID is in `properties.id`
- **Hot overlay**: database UUID you set when adding

Bug manifests at runtime when tile integer hits an API expecting UUID (annotation anchors, selection).

Resolution — resolve through properties first, fall back to `feat.id`:
```typescript
function resolveFeatureId(
  feat: { id?: string | number; properties?: Record<string, unknown> | null }
): FeatureUUID | null {
  const props = feat.properties;
  return (
    toFeatureUUID(props?.['_id'] as string) ??   // GeoJSON source
    toFeatureUUID(props?.['id'] as string) ??     // Vector tile
    toFeatureUUID(feat.id as string)               // Direct GeoJSON id
  );
}
```
Branded `FeatureUUID` (`string & { readonly __brand: 'FeatureUUID' }`) makes this a compile-time error. Zod schema at API boundary is the runtime guard.

## Annotorious: three coordinate worlds

Semantic mismatch, not structural:
1. **Native**: pixel coordinates — `{ x: 272, y: 169, w: 121, h: 90 }`
2. **W3C Web Annotation**: string selectors — `xywh=pixel:272,169,121,90` or SVG markup
3. **GeoJSON**: WGS84 `[longitude, latitude]`

No shared type structure. Bridged via `W3CImageAdapter`. For geographic contexts, IIIF uses dual coordinates: W3C `#xywh` Fragment Selectors for pixel regions, annotation bodies with GeoJSON-LD for geographic coordinates — but nested GeoJSON coordinate arrays are incompatible with JSON-LD 1.0 processing.

## Yjs / application types

`Y.Map` entries are `any`. Wrap with typed accessors:
```typescript
function getAnnotation(map: Y.Map<unknown>, id: string): Annotation | undefined {
  const raw = map.get(id);
  return isAnnotation(raw) ? raw : undefined;
}
```
Yjs awareness state is `Record<string, any>` — define a typed wrapper for presence.

## Validation at system boundaries

Validate at the edge, trust internally. Zod/Valibot at entry points (API response, file import, library callback, user input):
```typescript
const AnnotationSchema = z.object({
  id: z.string(),
  geometry: GeoJSONGeometrySchema,
  properties: z.record(z.unknown()),
});
function onFeatureCreated(raw: unknown): Annotation {
  return AnnotationSchema.parse(raw); // no casts downstream
}
```

## W3C Web Annotation type complexity

Deep nesting (bodies, targets, selectors, agents, collections, pages). field-studio's approach:
- Discriminated unions for body types (`TextualBody | ExternalWebResource | ...`)
- Selector unions (`FragmentSelector | CssSelector | TextQuoteSelector | ...`)
- `AnnotationSummary` — lightweight derived type for list/filter UI that flattens W3C nesting into simple properties (`bodyPreview`, `motivation`, `hasSpatialTarget`)

Rule: derive simpler view types for UI; keep full W3C model in store layer only.

## Plugin registry and typed handler dispatch

### Node handler lifecycle contract

Every annotation type implements:
```typescript
interface AnnotationHandler<T extends BaseAnnotation = BaseAnnotation> {
  readonly type: string;
  create(params: CreateParams): T;
  onRender(annotation: T, context: RenderContext): RenderOutput;
  onUpdate(prev: T, next: T): void;
  onDestroy(annotation: T): void;
  serialize(annotation: T): SerializedAnnotation;
  deserialize(data: SerializedAnnotation): T;
  getGeometry(annotation: T): Geometry2d;
  getHandles?(annotation: T): Handle[];
}
```
Annotation-specific: `getGeometry()`, `getHandles()`, and the render/update/destroy lifecycle exist because annotation types participate in hit-testing, selection, and spatial indexing.

### Type-safe handler registry

```typescript
class HandlerRegistry {
  #handlers = new Map<string, AnnotationHandler>();
  register<T extends BaseAnnotation>(handler: AnnotationHandler<T>): void {
    if (this.#handlers.has(handler.type)) throw new Error(`Duplicate: ${handler.type}`);
    this.#handlers.set(handler.type, handler);
  }
  get<T extends BaseAnnotation>(type: string): AnnotationHandler<T> {
    const h = this.#handlers.get(type);
    if (!h) throw new Error(`No handler for: ${type}`);
    return h as AnnotationHandler<T>;
  }
}
```
Validate at registration, not dispatch — catches missing implementations at startup, not during user interaction.

### Renderer-agnostic annotation types

`onRender` receives a discriminated `RenderContext`:
```typescript
type RenderContext =
  | { type: 'svg'; parent: SVGElement }
  | { type: 'canvas'; ctx: CanvasRenderingContext2D }
  | { type: 'konva'; layer: Konva.Layer }
  | { type: 'component' };
```
Production examples: tldraw `ShapeUtil` registry (gold standard — `getGeometry()`, `component()`, `indicator()`, `getHandles()`), Excalidraw per-type render dispatch by `element.type`, WeaveJS `WeaveNodeBase` with Konva rendering, Terra Draw mode system per geometry type.

### Framework-agnostic plugin lifecycle

For cross-framework libs (React/Svelte/Vue/vanilla): encode lifecycle phases in hook names with phase prefixes (`init:`, `render:`, `destroy:`) via `registerHook('init:myPlugin', callback)` rather than relying on framework lifecycle methods.

## Coordinate system bridging

### Common coordinate pairs

| Domain | Storage | Display |
|--------|---------|---------|
| Maps | WGS84 (lng, lat) | Screen pixels |
| Image annotation | Normalized (0-1) or pixel | Viewport-relative pixels |
| Canvas | World/document coords | Screen pixels with zoom/pan |
| Timeline | Time offset (s/frames) | Pixel position |

### Bidirectional transform contract

```typescript
function storageToDisplay(pos: StorageCoord, viewport: Viewport): DisplayCoord;
function displayToStorage(pos: DisplayCoord, viewport: Viewport): StorageCoord;
```

**Roundtrip invariant**: `displayToStorage(storageToDisplay(pos, vp), vp) === pos` within acceptable precision. Test explicitly — floating point drift and rounding at zoom extremes break it silently.

**Upwelling's lesson**: `PositionMapper.ts` includes commented-out roundtrip assertions logging inconsistencies — right instinct, make the invariant testable.

### Caching

Coordinate transforms fire on every mouse event during draw/drag (60+ Hz):
- **Lazy per-frame**: cache viewport transform matrix per frame. MapLibre's `project()`/`unproject()` works this way (matrix cached internally).
- **Explicit invalidation**: cache derived positions, invalidate on zoom/pan/resize. Use for expensive transforms (geodetic projections with datum shifts).

Anti-pattern: caching display coordinates as annotation positions. Display coords change on zoom/pan; storage coords don't.

### Boundary edge cases

- **Document edges**: position at exact boundary may round inside or outside (Upwelling PositionMapper: "the last position of the document does not necessarily match")
- **Zoom extremes**: high zoom causes integer overflow in pixel coords; low zoom collapses sub-pixel positions
- **Antimeridian wrap**: lng +/-180 requires splitting annotations into two visual segments

## Extension-aware updates

W3C Web Annotation, IIIF, and GeoJSON all support extensibility. Shallow-merge (`{ ...existing, ...patch }`) silently orphans extension data in nested paths.

**Three fix patterns:**

1. **Deep-merge with extension awareness:**
```typescript
function updateAnnotation(existing: Annotation, patch: Partial<Annotation>): Annotation {
  return {
    ...existing, ...patch,
    extensions: deepMerge(existing.extensions ?? {}, patch.extensions ?? {}),
    body: patch.body ?? existing.body,
  };
}
```

2. **Separate extension API:** `updateAnnotation()` for core, `updateExtension(id, namespace, patch)` for extensions.

3. **Immutable-with-restore:** save extensions before merge, restore after.

Affected standards:
- **W3C**: extensions on `body`, `target`, annotation itself; bodies can be arrays with mixed types
- **IIIF**: extensions on Manifests, Canvases, Annotations, Ranges
- **GeoJSON**: freeform `properties` object — shallow-merge drops nested structures

Rule: if the model supports extensibility, updates must deep-merge or use separate paths. Shallow-merge is only safe with complete objects, not partial patches.

## Decision Guide

| Constraint | Recommended pattern |
|-----------|-------------------|
| Multiple map libraries (MapLibre + Mapbox) | Intersection types for structural overlap |
| GeoJSON geometry access from events | Narrow on `geometry.type` discriminant |
| Feature IDs from mixed sources (GeoJSON, tiles, overlay) | `resolveFeatureId()` with branded `FeatureUUID` + Zod at API boundary |
| Yjs shared types in application code | Typed accessor wrappers with runtime validation |
| W3C Web Annotation in UI components | Derive simplified view types (`AnnotationSummary`); keep full model in store only |
| Cross-framework plugin system | Phase-prefixed hook registration (`init:`, `render:`, `destroy:`) |
| Coordinate system bridging | Bidirectional transform with explicit roundtrip invariant tests |
| Extensible annotation formats (W3C, IIIF, GeoJSON) | Deep-merge or separate extension API; never shallow-merge partial patches |
| Library ambient declaration conflicts | `skipLibCheck: true` + pin transitive dependency versions |
| Multiple coordinate worlds (pixel, W3C selector, WGS84) | Adapter layer with explicit conversion functions per pair |

## Anti-Patterns

- **`@ts-ignore` / `@ts-expect-error` instead of narrowing.** Suppressing GeoJSON geometry union errors hides real bugs. Narrow on `geometry.type` to get safe coordinate access.
- **`as T` direct cast between incompatible library types.** MapLibre's `MapGeoJSONFeature` and GeoJSON's `Feature` don't structurally overlap. Use `as unknown as T` with a `TYPE_DEBT` comment documenting why the cast is safe in context.
- **Shallow-merging extensible annotation formats.** `{ ...existing, ...patch }` silently drops extension data in nested paths. Use deep-merge with extension awareness or a separate extension update API.
- **Caching display coordinates as annotation positions.** Display coords change on zoom/pan; storage coords don't. This causes "annotations drift" bugs that only manifest during interaction.
- **Trusting `feat.id` across source types.** `feat.id` is a database UUID from GeoJSON sources but a tile-internal integer from vector tile sources. Always resolve through `properties` first, fall back to `feat.id`.
- **Exposing full W3C Web Annotation nesting to UI components.** Deep nesting (bodies, targets, selectors, agents) makes UI code unwieldy. Derive flattened view types for list/filter UI; keep the full model in the store layer.
- **Bundling all adapter types in a single package.** Forces installation of unused type dependencies (Google Maps, ArcGIS, OpenLayers). Split into per-adapter packages (Terra Draw pattern).
- **Skipping roundtrip invariant tests for coordinate transforms.** Floating point drift and rounding at zoom extremes break `displayToStorage(storageToDisplay(pos))` silently. Test the invariant explicitly.
