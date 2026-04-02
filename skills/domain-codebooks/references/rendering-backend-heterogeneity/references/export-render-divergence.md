# Export-Render Divergence

## The Problem

Interactive rendering and export rendering serve fundamentally different
purposes with different constraints: interactive rendering optimizes for
responsiveness, frame rate, and user interaction; export rendering optimizes
for fidelity, portability, and offline correctness. When these use different
rendering backends -- which they almost always do -- visual divergence between
"what you see" and "what you get" becomes the canonical fidelity bug of canvas
editors.

The tension: use the same renderer for both (risking export limitations) vs
use separate renderers (risking visual divergence).

---

## Competing Patterns

### 1. Dual Static Renderers: Canvas2D + SVG (Excalidraw)

**How it works:** The application maintains two complete static rendering
pipelines -- one targeting Canvas2D for bitmap export (`renderStaticScene`) and
one targeting SVG for vector export (`renderSceneToSvg`). Both take the same
element data but produce output through fundamentally different APIs.

**Example -- Excalidraw dual export pipeline:**

Key files: `packages/excalidraw/renderer/staticScene.ts`,
`packages/excalidraw/renderer/staticSvgScene.ts`,
`packages/excalidraw/scene/export.ts`

Canvas2D export path:
```typescript
// export.ts -- exportToCanvas
const { canvas, scale } = createCanvas(width, height);
renderStaticScene({
  canvas,
  rc: rough.canvas(canvas),
  elementsMap,
  visibleElements: elementsForRender,
  scale,
  renderConfig: {
    isExporting: true,            // disables interactive-only features
    renderGrid: false,            // grid is editor-only
    embedsValidationStatus: new Map(), // disables embeddable rendering
    elementsPendingErasure: new Set(),
  },
});
```

SVG export path:
```typescript
// export.ts -- exportToSvg
const svgRoot = document.createElementNS(SVG_NS, "svg");
// ... setup viewBox, dimensions, defs, metadata
renderSceneToSvg(elementsForRender, {
  root: svgRoot,
  elementsMap,
  files,
  exportingFrame,
  renderEmbeddables: opts?.renderEmbeddables,
});
```

The `renderStaticScene` uses rough.js Canvas2D drawing while
`renderSceneToSvg` uses rough.js SVG drawing -- same library, different output
targets. Shape generation uses `ShapeCache.generateElementShape()` shared
between both paths, ensuring geometric consistency.

**Key divergence points:**
- Frame labels are DOM elements in the editor but must be synthesized as text
  elements for export (the `addFrameLabelsAsTextElements` hack)
- The `isExporting` flag disables grid, embeddable rendering, and pending
  erasure visualization
- Font loading must be explicitly awaited before canvas export
  (`Fonts.loadElementsFonts`) but is handled differently for SVG (inlined)
- SVG precision is explicitly capped (`MAX_DECIMALS_FOR_SVG_EXPORT`) to avoid
  floating-point noise in SVG path data
- Embeddable elements (iframes) render as placeholder rectangles with links in
  SVG but as live content in the editor
- Selection rendering explicitly throws in SVG: `"Selection rendering is not
  supported for SVG"`

**Tradeoffs:**
- Each pipeline is optimized for its output format
- Shared shape generation (`ShapeCache`) reduces geometric divergence
- Frame labels require a separate synthesis path for export
- Two renderers to maintain, test, and keep visually consistent
- SVG export produces portable, editable vector output
- Canvas2D export handles browser-specific rasterization quirks

**De-Factoring Evidence:**
- **If a single renderer were used for both:** Canvas2D cannot produce
  editable SVG output. SVG DOM manipulation is too slow for interactive
  rendering. The dual pipeline is forced by the output format requirements.
  **Detection signal:** "Can't copy-paste exported shapes into Illustrator"
  (if only bitmap export existed).

- **If frame label synthesis were removed:** Exported images would lack frame
  labels entirely, since they exist only as DOM overlays in the editor.
  **Detection signal:** "Frame names visible in editor but missing in export."

---

### 2. SVG-as-Intermediate-Representation Export (tldraw)

**How it works:** The editor renders interactively using DOM/SVG. For image
export, the same SVG representation is serialized, then rasterized to
Canvas2D via the browser's SVG rendering engine. The export pipeline reuses
the editor's rendering output rather than maintaining a separate renderer.

**Example -- tldraw export pipeline:**

Key files: `packages/tldraw/src/lib/utils/export/export.ts`,
`packages/tldraw/src/lib/utils/export/exportAs.ts`,
`packages/editor/` (Editor.getSvgString, Editor.toImage)

```typescript
// export.ts
async function getSvgString(editor, ids, opts) {
  const svg = await editor.getSvgString(ids, opts);
  if (!svg) throw new Error('Could not construct SVG.');
  return svg;
}

// For image export: SVG string -> browser rasterization -> blob
export function exportToImagePromiseForClipboard(editor, ids, opts) {
  return {
    blobPromise: editor
      .toImage(idsToUse, opts)
      .then((result) =>
        FileHelpers.rewriteMimeType(result.blob, clipboardMimeTypesByFormat[format])
      ),
    mimeType: clipboardMimeTypesByFormat[format],
  };
}
```

The pipeline is: Editor state -> SVG string -> (for PNG/JPEG) browser
rasterization via foreignObject/data URL -> Canvas2D -> Blob.

**Known browser-specific divergence points** (from codebook extraction notes):
- Chrome blob: URL taint bug (Chromium issue 41054640) prevents certain SVG
  content from being drawn to canvas
- Safari font-loading timing requires empirical `sleep(250)` before
  rasterization
- Browser-varying maximum canvas sizes cause silent truncation on large exports
- CSS style embedding must be inlined into the SVG (StyleEmbedder) because
  external stylesheets are not available during rasterization

The minimap uses a completely separate WebGL renderer
(`minimap-webgl-setup.ts`, `minimap-webgl-shapes.ts`) that intentionally
diverges from the editor for performance -- visual fidelity between minimap
and editor is explicitly not a goal.

**Tradeoffs:**
- SVG export is inherently faithful to editor (same rendering representation)
- Image export reuses SVG, reducing renderer duplication
- Browser rasterization introduces platform-specific bugs
- CSS/font inlining is fragile and adds export latency
- Minimap divergence is accepted (different purpose, different fidelity bar)

**De-Factoring Evidence:**
- **If the SVG intermediate step were skipped for image export:** Would need a
  separate Canvas2D renderer that reimplements all shapes. The SVG-as-IR
  approach avoids this entirely at the cost of browser rasterization quirks.
  **Detection signal:** "Export doesn't match editor" would become a per-shape
  problem rather than a per-browser problem.

---

### 3. Parallel Pipeline with Per-Pipeline Asset Loading (Penpot)

**How it works:** Multiple complete rendering pipelines coexist (SVG for
legacy/export, WASM/WebGL for new interactive renderer), each with their own
asset loading, font handling, and layout engines. Export uses the SVG pipeline
regardless of which pipeline is active for editing.

**Example -- Penpot text rendering divergence:**

Text renders through three separate paths:
1. `fo_text.cljs` -- foreignObject HTML (interactive editing)
2. `svg_text.cljs` -- SVG native text (display/export)
3. `wasm_text.cljs` -> `render_wasm/api/texts.cljs` -- WASM/WebGL (new renderer)

Each path has independent font loading:
- Browser pipeline: `fontfaces.cljs` using `@font-face` CSS API
- WASM pipeline: `render_wasm/api/fonts.cljs` loading binary font data into
  WASM linear memory

**Tradeoffs:**
- Each pipeline is optimized for its platform (browser DOM vs WASM)
- Font loading cannot be shared -- APIs are fundamentally different
- Triple maintenance burden for text (the hardest element to render consistently)
- Feature flags create configuration-dependent rendering differences
- Export always uses the stable SVG pipeline, avoiding WASM instability

**De-Factoring Evidence:**
- **If font loading were unified:** Browser `@font-face` and WASM binary font
  loading have different APIs, timing, and failure modes. A shared abstraction
  would satisfy neither.
  **Detection signal:** "Fonts load in editor but not in export" or
  "WASM renderer shows fallback font."

- **If export switched to WASM pipeline:** Users would lose export access when
  WebGL2 is unavailable. The SVG export path works everywhere.
  **Detection signal:** "Export broken on Safari 14" -- old browser without
  WebGL2 support.

---

### 4. isExporting Flag Pattern (Excalidraw, tldraw)

**How it works:** Rather than maintaining fully separate renderers, a single
renderer accepts an `isExporting` flag that toggles export-specific behavior:
disabling interactive-only features, adjusting precision, changing asset
resolution, and suppressing UI elements.

**Example -- Excalidraw static scene:**

```typescript
renderStaticScene({
  renderConfig: {
    isExporting: true,
    renderGrid: false,              // grid is editor-only
    embedsValidationStatus: new Map(), // disables embeddable preview
    elementsPendingErasure: new Set(), // no in-progress erasure viz
    pendingFlowchartNodes: null,    // no in-progress flowchart viz
  },
});
```

The flag propagates through the render tree, and each element type checks it
to decide what to render. This is simpler than full pipeline duplication but
creates coupling between interactive and export concerns within the same
rendering code.

**Tradeoffs:**
- Single renderer codebase -- less duplication
- Export-specific logic is scattered across element renderers
- Adding new interactive-only features requires remembering to check the flag
- Easy to miss a flag check, causing interactive-only artifacts in export

**De-Factoring Evidence:**
- **If the flag were removed:** Grid lines, selection handles, pending erasure
  indicators, and embeddable previews would appear in exported images.
  **Detection signal:** "Why does my exported PNG have grid dots?" or "selection
  box visible in the export."

---

## Decision Guide

**Choose Dual Static Renderers when:**
- You need both vector (SVG) and raster (PNG) export
- Interactive rendering uses a technology unsuitable for export (WebGL, DOM)
- Shape geometry can be shared via a common intermediate representation

**Choose SVG-as-IR Export when:**
- Your editor already renders to SVG/DOM
- Image export can tolerate browser rasterization quirks
- You want to minimize renderer duplication

**Choose Parallel Pipelines when:**
- You're migrating rendering technologies mid-product
- Export must remain stable while the interactive renderer changes
- Asset loading (fonts, images) has fundamentally different APIs per pipeline

**Choose isExporting Flag when:**
- Interactive and export rendering share most logic
- Export divergence is limited to suppressing interactive overlays
- You can maintain discipline about checking the flag for new features

---

## Anti-Patterns

### 1. Export-as-Afterthought
Building the interactive renderer first, then bolting on export by
screenshotting the canvas. This produces exports that include cursors,
selection handles, scroll positions, and other interactive artifacts. Every
interactive feature becomes a potential export bug.
**Detection signal:** Export contains grid lines, selection boxes, or
collaboration cursors; export dimensions match viewport rather than content.

### 2. Assuming Browser Rasterization is Deterministic
Expecting SVG-to-Canvas2D rasterization to produce identical results across
browsers. Chrome, Safari, and Firefox all handle font rendering, SVG filter
effects, and foreignObject differently. Text positioning varies by sub-pixel
amounts; certain CSS properties are ignored.
**Detection signal:** "Export looks correct on Chrome but text is misaligned on
Safari"; pixel-level visual regression tests that only pass on one browser.

### 3. Shared Font Loading Across Incompatible Pipelines
Attempting to use a single font loading system for browser (CSS @font-face)
and non-browser (WASM, Node.js, headless) rendering. The APIs, timing models,
and failure modes are fundamentally different.
**Detection signal:** "Fonts work in editor but show fallback in export";
"headless export renders all text in Arial."

### 4. Unbounded Export Resolution
Allowing export at arbitrary scale without checking platform limits. Browsers
have maximum canvas dimensions (varies by browser: ~16384px Chrome, ~32767px
Safari, varies on mobile). Exceeding the limit silently produces a truncated
or blank image.
**Detection signal:** "Large artboard exports as blank image"; "export works
at 1x but fails at 4x scale."

### 5. Ignoring the isExporting Flag for New Features
Adding interactive features (hover effects, animation, real-time collaboration
indicators) without gating them behind the export flag. Each ungated feature
becomes an export fidelity bug that may not be caught until a user reports it.
**Detection signal:** Gradual accumulation of "artifact in export" bug reports
after adding new interactive features.
