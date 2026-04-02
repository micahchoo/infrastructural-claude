---
name: rendering-backend-heterogeneity
description: >-
  Architectural advisor for applications where multiple rendering technologies
  (Canvas2D, WebGL, SVG, OpenGL, wgpu, software rasterizer) coexist within a
  single product. The force tension: visual consistency vs performance vs
  portability when backends have fundamentally different capabilities, failure
  modes, and API surfaces.

  NOT single-backend rendering optimization, game engine selection, CSS layout,
  or general GPU programming tutorials.

  Triggers: "renderer abstraction layer", "fallback chain between GPU and
  software rendering", "dual/triple rendering pipelines", "shader version
  adaptation across GPU generations", "Canvas2D/WebGL context coexistence",
  "capability negotiation at startup", "export pipeline using different
  renderer than editor", "WebGL context loss recovery", "WASM-owned GPU
  context lifecycle", "DrawerBase polymorphism", "two-canvas architecture
  interactive plus static", "per-backend batching optimization",
  "OffscreenCanvas worker thread rendering", "screen vs print render paths",
  "headless rendering for visual regression testing".

  Brownfield triggers: "shapes render differently in the minimap vs main
  canvas", "export looks different from what's on screen", "app crashes on
  integrated GPU but works on discrete", "WebGL context lost and canvas goes
  black", "switching pages causes shader recompilation stutter", "fallback
  renderer silently drops features", "new shape type works in one backend but
  not another", "ANGLE on Windows renders differently than native OpenGL",
  "text renders differently across rendering paths", "added a new drawer but
  it doesn't support rotation", "Canvas 2D fallback path is 10x slower than
  WebGL", "need headless software renderer for CI visual regression tests",
  "OffscreenCanvas worker rendering with fallback for unsupported browsers",
  "screen vs print rendering needs different resolution and anti-aliasing",
  "instanced drawing in WebGL has no Canvas 2D equivalent",
  "cursor layer updates at 60fps on top of document canvas".

  Symptom triggers: "how to abstract rendering backend so drawing code
  doesnt know which renderer is active", "WebGPU fallback to WebGL 2 then
  WebGL 1 then Canvas 2D with different blend modes and shaders",
  "DrawingContext interface leaks because some features only work in WebGL",
  "export to SVG and PDF needs different effect implementations than GPU
  shaders", "Canvas 2D fallback draws each shape individually and is 10x
  slower than WebGL batching", "OffscreenCanvas with Web Workers but not
  available everywhere and main thread cant touch it", "same shapes need
  different resolution and anti-aliasing for screen vs print", "headless
  rendering for visual regression testing on CI server with no GPU",
  "instanced drawing in WebGL has no Canvas 2D equivalent so we duplicate
  draw logic", "live collaboration cursor layer on top of document canvas
  uses separate framebuffers in WebGL vs layered canvases in Canvas 2D".

  Diffused triggers: "which rendering backend should we use", "how to support
  both WebGL and Canvas2D", "our WASM renderer loses GPU context", "how does
  Krita handle so many GPU backends", "should we have a renderer abstraction
  layer", "the SVG export doesn't match the canvas", "how to detect GPU
  capabilities at runtime", "our WebGL fallback path is broken", "after adding
  the new renderer things look different", "some users see visual glitches we
  can't reproduce".

  Libraries/APIs: WebGL/WebGL2, Canvas2D, SVG DOM, OpenGL 2.x/3.x/ES,
  ANGLE, wgpu, Emscripten, OffscreenCanvas, WebGPU.

  Production examples: tldraw (DOM/SVG + WebGL minimap + Canvas2D export),
  Excalidraw (dual Canvas2D interactive/static), Penpot (SVG + WASM/WebGL
  transition), Krita (OpenGL 2/3/ES/ANGLE/Software), OpenSeadragon
  (WebGL/Canvas/HTML drawer chain), drafft-ink (wgpu).

  Skip: single-backend performance tuning, shader authoring, 3D engine
  architecture, CSS rendering, browser compositor internals, color science
  (unless it intersects backend differences).
---

# Rendering Backend Heterogeneity

**Force tension:** Visual consistency vs performance vs portability when
multiple rendering backends coexist within a single application.

This tension emerges whenever an application must render through more than one
technology — whether that is Canvas2D for interaction and SVG for export,
WebGL for performance and Canvas2D as fallback, or OpenGL across five GPU
driver generations. The spaghetti comes from code that leaks backend-specific
assumptions across module boundaries.

## Step 1: Classify the rendering heterogeneity problem

1. **Backend topology**: Single backend with export divergence, dual pipeline
   (e.g. interactive + static), or N-way fallback chain?
2. **Capability variance**: Do all backends support the same features, or does
   feature availability silently vary by renderer?
3. **Lifecycle coupling**: Is the GPU context owned by the application, a WASM
   module, or the browser? Can it be lost/recreated?
4. **Platform spread**: Single OS/browser, or must support multiple GPU
   generations/drivers/platforms?
5. **Consistency requirement**: Pixel-perfect match across backends, or
   "close enough" acceptable?
6. **Export pipeline**: Same backend as editor, or separate rendering path?

## Step 2: Load reference

| Axis | File |
|------|------|
| Renderer abstraction layer / polymorphic drawers / backend isolation | `get_docs("domain-codebooks", "rendering-backend renderer abstraction")` |
| Fallback chains / feature detection / context loss / GPU probing | `get_docs("domain-codebooks", "rendering-backend fallback detection")` |
| GPU context creation / loss / recovery / multi-context coordination | `get_docs("domain-codebooks", "rendering-backend gpu context lifecycle")` |
| Export vs interactive rendering divergence / fidelity maintenance | `get_docs("domain-codebooks", "rendering-backend export render divergence")` |

## Step 3: Advise and scaffold

Present 2-3 competing patterns with tradeoffs. Match existing framework
conventions. Key decision axes:

- **Thin abstraction vs thick abstraction**: OpenSeadragon's DrawerBase
  (thin, each drawer implements full pipeline) vs Krita's shader loader
  (thick, adapts one pipeline to multiple backends).
- **Fallback chain vs parallel pipelines**: OpenSeadragon iterates an ordered
  candidate list vs Penpot maintaining dual SVG+WASM renderers simultaneously.
- **Proactive detection vs reactive recovery**: Krita's startup GPU probing
  vs WebGL's contextlost/contextrestored event handling.
- **Context isolation vs context sharing**: Krita's RAII context-switch lock
  (multi-document safety) vs Penpot's pixel-capture-and-replay (visual
  continuity across context recreation).
- **Shared renderer with export flag vs separate export pipeline**: Excalidraw's
  `isExporting` flag (less duplication, more coupling) vs tldraw's SVG-as-IR
  rasterization (inherits editor fidelity, browser-specific quirks).

### Cross-References (force interactions)

- When different clients in a collaborative session use different renderers
  (e.g. mobile Canvas2D vs desktop WebGL) → see **distributed-state-sync**
  (state must be renderer-agnostic; rendering hints must not leak into
  shared document model)
- When hit-testing must work across backends with different coordinate
  systems or precision → see **gesture-disambiguation** (hit-test geometry
  must be backend-independent)
- When export pipeline uses a different renderer than the editor → see
  this codebook's **export-render-divergence** reference (dual static
  renderers, SVG-as-IR, isExporting flag, per-pipeline asset loading)
- When GPU context lifecycle intersects with page/tab lifecycle → see
  this codebook's **gpu-context-lifecycle** reference (RAII context locks,
  pixel capture/replay, fence synchronization, guard-and-initialize)

## Principles

1. **Backend-specific code must not leak past the abstraction boundary.**
   Shape definitions, document model, and hit-test geometry must be
   renderer-agnostic. If adding a new shape requires changes in N backend
   files, the abstraction is too thin.
2. **Capability queries replace feature assumptions.** Never assume a backend
   supports rotation, compositing, or image smoothing — query it
   (`drawer.canRotate()`, `gl.getExtension()`). Silent feature degradation
   causes bugs that only appear on specific hardware.
3. **Context loss is not an error — it is a lifecycle event.** GPU contexts
   will be lost (tab backgrounding, driver crash, page switch). Design for
   recovery, not prevention. Guard all GL access behind initialization
   checks (`context-initialized?`).
4. **Shader adaptation belongs in a loader, not inline.** Version strings,
   extension checks, and platform conditionals belong in one place (Krita's
   `kis_opengl_shader_loader.cpp` pattern), not scattered through rendering
   code.
5. **Test visual consistency across backends explicitly.** If you have N
   backends, you need N-way visual regression tests. "It works in WebGL"
   does not mean it works in Canvas2D fallback.
