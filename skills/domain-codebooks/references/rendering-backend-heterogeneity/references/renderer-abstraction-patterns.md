# Renderer Abstraction Patterns

## The Problem

When an application uses multiple rendering technologies (Canvas2D, WebGL, SVG,
OpenGL, wgpu, software rasterizer), each shape/element must be drawable by each
backend. Without an abstraction layer, every new shape type requires N
implementations (one per backend), and visual consistency between backends is
maintained by coincidence rather than design.

---

## Competing Patterns

### 1. Polymorphic Drawer Chain (OpenSeadragon)

**How it works:** A base drawer interface defines the rendering API. Concrete
drawers (WebGLDrawer, CanvasDrawer, HTMLDrawer) implement it. The application
selects a drawer at runtime based on capability detection, with automatic
fallback.

**Example — OpenSeadragon:**

Three drawer implementations with different capability sets:
- `WebGLDrawer` — hardware-accelerated, supports rotation and compositing
- `CanvasDrawer` — software fallback, supports rotation but not all composites
- `HTMLDrawer` — DOM-based, most compatible but no compositing

Capability query methods: `canRotate()`, `canComposite()`, image smoothing
support. WebGL falls back to Canvas2D for specific composite operations
mid-render — the fallback is per-operation, not per-session.

Key file: `openseadragon/openseadragon.js` (lines 702-726 for config,
8291-8386 for drawer selection)

**Tradeoffs:**
- Clean separation — each drawer is self-contained
- Runtime fallback handles GPU unavailability gracefully
- Per-operation fallback is powerful but complex
- Feature matrix grows with each new drawer

**De-Factoring Evidence:**
- **If the drawer chain were collapsed to a single backend:** Applications on
  older hardware or constrained environments (headless servers, CI) fail
  entirely instead of degrading. OpenSeadragon's three-tier fallback means it
  works on virtually any browser.
  **Detection signal:** "App crashes on WebGL context creation" with no fallback;
  users report blank canvas on older devices.

- **If capability queries were removed:** The application would attempt
  operations the drawer can't perform (e.g., compositing on HTMLDrawer),
  producing silent visual errors.
  **Detection signal:** "Rotation works but the overlays look wrong" — feature
  used on a drawer that reports it as supported but renders it differently.

---

### 2. Dual/Triple Pipeline Architecture (Penpot)

**How it works:** Multiple complete rendering pipelines coexist, each targeting
different use cases (editing, export, new renderer). The application switches
between them based on feature flags or context.

**Example — Penpot triple-text pipeline:**

Text renders through three entirely separate paths:
1. `fo_text.cljs` — foreignObject HTML text (editing)
2. `svg_text.cljs` — SVG native text (legacy display/export)
3. `wasm_text.cljs` → `render_wasm/api/texts.cljs` — WASM/WebGL text (new renderer)

Each path has its own font loading (`fontfaces.cljs` for browser, `render_wasm/api/fonts.cljs`
for WASM), layout engine, and CSS interpretation. The WASM renderer is gated behind
feature flags, running alongside the SVG renderer during transition.

Key files: `frontend/src/app/main/ui/shapes/text/*.cljs`,
`frontend/src/app/render_wasm/api/texts.cljs`

**Tradeoffs:**
- Allows gradual migration (SVG → WASM) without breaking existing users
- Each pipeline is independently optimizable
- Feature flags create configuration-dependent rendering differences
- Triple maintenance burden — same visual intent, three implementations
- Text fidelity between paths is the hardest invariant to maintain

**De-Factoring Evidence:**
- **If the legacy SVG pipeline were removed during WASM transition:** Users on
  browsers with poor WASM support or WebGL2 unavailability lose access. The
  feature flag exists precisely because WASM rendering isn't universally ready.
  **Detection signal:** "Text looks different in the new renderer" — divergence
  between pipelines that should produce identical output.

- **If font loading weren't separated per pipeline:** Browser font loading
  (`@font-face`) and WASM font loading (binary font data into WASM memory)
  have different APIs, timing, and failure modes. Sharing a font system would
  create an abstraction that satisfies neither.
  **Detection signal:** "Fonts load in the editor but not in export" or
  "WASM renderer shows fallback font."

---

### 3. Purpose-Split Backends (tldraw)

**How it works:** Different rendering backends serve different purposes within
the same application: DOM/SVG for interactive editing, WebGL for performance-
critical views, Canvas2D for export.

**Example — tldraw:**

- **Main canvas:** DOM/SVG rendering — rich interactive editing with CSS styling
- **Minimap:** WebGL rendering (`minimap-webgl-setup.ts`, `minimap-webgl-shapes.ts`)
  — shader-based shape rendering for performance
- **Export:** Canvas2D rasterization via SVG→foreignObject→data:URL pipeline
  (`getSvgAsImage.ts`, `StyleEmbedder.ts`)

The three backends are not abstracted behind a common interface — they are
architecturally separate systems that happen to render the same shapes. Visual
consistency is maintained by the export pipeline literally rendering the SVG
(which matches the editor) into a Canvas2D context.

**Tradeoffs:**
- Each backend optimized for its purpose (DOM for interaction, WebGL for speed)
- No lowest-common-denominator constraint
- Adding a new shape type requires updates in up to 3 places
- Visual divergence between minimap and editor is an expected tradeoff
- Export pipeline inherits browser-specific quirks (see below)

**De-Factoring Evidence:**
- **If the export pipeline used the same DOM renderer as editing:**
  SVG→Canvas2D rasterization introduces browser-specific bugs:
  Chrome taint bug with blob: URLs (issue 41054640), Safari font-loading
  timing requiring `sleep(250)`, browser-varying max canvas sizes.
  The export pipeline exists specifically to navigate these.
  **Detection signal:** "Export looks different from the editor" — the canonical
  rendering divergence bug in canvas editors.

---

### 4. Shader Version Adaptation (Krita)

**How it works:** A single rendering pipeline adapts its shader programs to the
available GPU capabilities, with runtime probing determining which features to
enable or disable.

**Example — Krita GPU adaptation:**

Key file: `libs/ui/opengl/kis_opengl.cpp`

Runtime GPU probing system (`KisOpenGLModeProber`):
- Detects DesktopGL vs OpenGLES vs Software renderer
- Vendor/driver string matching for known bugs
- ANGLE detection with forced texture buffer disabling (`g_forceDisableTextureBuffers`)
- GPU-specific fence workarounds (`g_needsFenceWorkaround`)

Shader adaptation (`kis_opengl_shader_loader.cpp`):
- Platform-conditional version strings: `#version 120` (GL2), `#version 130` (GL3),
  `#version 150` (GL3.2), `#version 300 es` (GLES)
- LOD support detection (`supportsLoD()`) — enables/disables texture sampling features
- macOS-specific shader paths (`#ifdef Q_OS_MACOS`)

**Tradeoffs:**
- Single pipeline — visual consistency by construction
- Runtime adaptation handles the long tail of GPU combinations
- Driver-specific workarounds accumulate over time (ANGLE, Mesa, macOS Metal)
- Testing matrix explodes with GPU combinations

**De-Factoring Evidence:**
- **If shader version adaptation were removed:** Application would require a
  minimum GPU version (e.g., OpenGL 3.2), excluding integrated GPUs, older
  hardware, and ANGLE (Windows fallback). Krita's user base includes artists
  on diverse hardware — excluding them isn't viable.
  **Detection signal:** "App crashes on startup" on specific GPU/driver combos;
  shader compilation errors in logs.

- **If the texture buffer workaround were removed:** ANGLE (DirectX-backed
  OpenGL on Windows) crashes or renders garbage when texture buffers are used.
  This affects a significant Windows user population.
  **Detection signal:** "Canvas is black/corrupted on Windows with Intel GPU."

---

## Decision Guide

**Choose Polymorphic Drawer Chain when:**
- You need graceful degradation across capability levels
- The rendering API is relatively uniform across backends
- Per-operation fallback is valuable (some features work, others degrade)

**Choose Dual/Triple Pipeline when:**
- You're migrating between rendering technologies
- Different contexts (edit vs export vs preview) have genuinely different needs
- Feature flags control which pipeline is active

**Choose Purpose-Split Backends when:**
- Different views have fundamentally different performance requirements
- Visual consistency between views is acceptable to approximate
- Adding a common abstraction would constrain all backends to the weakest

**Choose Shader Version Adaptation when:**
- The rendering algorithm is the same, only the GPU API differs
- You need to support a wide range of hardware
- Driver-specific workarounds are a known cost you're willing to maintain

---

## Anti-Patterns

### 1. Lowest-Common-Denominator Abstraction
An abstraction that only exposes features available in ALL backends. Reduces
every backend to the capability of the weakest. WebGL compositing disabled
because HTMLDrawer can't do it.
**Detection signal:** Backend-specific features wrapped in `if (supportsX)`
that are always false in practice; WebGL backend that only does what Canvas2D can.

### 2. Implicit Backend Selection
Backend chosen deep in initialization code without user/system visibility.
When rendering bugs appear, developers can't determine which backend is active.
**Detection signal:** "It works on my machine" where the difference is GPU
capability silently selecting a different backend.

### 3. Export-as-Afterthought
Export pipeline added after the editor is complete, using screen capture or
Canvas2D drawImage of the editor canvas. Resolution-dependent, misses
off-screen content, and breaks with scrolling/zooming.
**Detection signal:** "Export only captures what's visible"; exported resolution
tied to screen resolution; export fails with viewport transforms.
