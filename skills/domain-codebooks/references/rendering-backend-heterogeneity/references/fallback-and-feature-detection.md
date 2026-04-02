# Fallback and Feature Detection

## The Problem

GPU rendering is fragile: context loss, driver bugs, missing extensions, and
capability variance across devices. Applications must detect available features
at startup, adapt their rendering paths, and recover gracefully when GPU state
is lost — all while keeping the experience invisible to users.

---

## Competing Patterns

### 1. Probe-and-Configure at Startup (Krita)

**How it works:** At application startup, probe the GPU for capabilities, match
against a known-issues database, and configure rendering parameters for the
session.

**Example — Krita KisOpenGLModeProber:**

Key file: `libs/ui/opengl/kis_opengl.cpp`

Startup sequence:
1. Create a probe GL context (`KisOpenGLModeProber`)
2. Query renderer string, vendor, driver version
3. Match against known-bug database:
   - ANGLE detected → `g_forceDisableTextureBuffers = true`
   - Specific GPU → `g_needsFenceWorkaround = true`
   - Software renderer detected → route to CPU rendering path
4. Select rendering mode: DesktopGL, OpenGLES, or Software
5. Configure shader version strings based on detected GL version

The probe runs once; results are cached for the session. No runtime re-probing.

**Tradeoffs:**
- Predictable — rendering path is determined once at startup
- Known-issues database is maintainable (add entries as bugs are reported)
- No adaptation to mid-session capability changes (new monitor, driver update)
- Database maintenance is ongoing — every new GPU/driver combo may need entries

**De-Factoring Evidence:**
- **If the probe were removed:** Application would assume a capable GPU,
  crash on ANGLE texture buffer bugs, produce corrupted output with fence
  timing bugs. Each bug would appear as a user-reported crash with no
  diagnostic information.
  **Detection signal:** Random crashes on startup for a subset of users;
  "works on NVIDIA, crashes on Intel" pattern.

- **If the known-issues database were inlined into rendering code:** Every
  rendering function would have `if (isAngle) { ... }` branches. The
  workarounds would be scattered across the codebase instead of centralized
  at startup.
  **Detection signal:** `if (renderer.contains("ANGLE"))` in 10+ files;
  driver-specific branches in shader code.

---

### 2. Progressive Fallback Chain (OpenSeadragon)

**How it works:** Try the best renderer; if it fails, fall back to the next
best; repeat until a working renderer is found.

**Example — OpenSeadragon drawer selection:**

Fallback chain: WebGL → Canvas2D → HTML

```
1. Try WebGLDrawer — if context creation fails, fall back
2. Try CanvasDrawer — always succeeds (no GPU required)
3. HTMLDrawer — DOM-based, last resort
```

Additionally, WebGL performs per-operation fallback: if a specific composite
mode isn't supported in WebGL, that operation falls back to Canvas2D while the
rest continues in WebGL.

Key methods: `canRotate()`, `canComposite()` — per-drawer capability queries
that the application checks before calling render operations.

**Tradeoffs:**
- Maximizes device compatibility — something always renders
- Per-operation fallback preserves quality where possible
- Users may not realize they're on a degraded path
- Testing must cover all fallback levels
- Mixed rendering (some WebGL, some Canvas2D) can produce subtle visual
  inconsistencies at blend boundaries

**De-Factoring Evidence:**
- **If per-operation fallback were removed (all-or-nothing per drawer):**
  A single unsupported composite mode forces the entire view to Canvas2D,
  losing WebGL performance for everything. The per-operation approach means
  95% of rendering stays on WebGL with graceful degradation for edge cases.
  **Detection signal:** "Enabling this overlay makes the entire viewer slow"
  — whole-drawer fallback triggered by one unsupported operation.

---

### 3. Feature-Flag-Gated Backend (Penpot)

**How it works:** New rendering backends are introduced behind feature flags.
Both old and new backends run in production; the flag controls which users see.

**Example — Penpot WASM renderer:**

The WASM/WebGL renderer runs alongside the SVG renderer:
- Feature flag controls which renderer is active per user/instance
- `wasm/context-initialized?` guard prevents GL calls before WASM init
- WebGL context recreation on page switch (each page switch destroys canvas)
- Shader compilation happens inline per context creation — not cached
  (`FIXME: temporary function until we are able to keep the same <canvas> across pages`)

Key file: `frontend/src/app/render_wasm/api/webgl.cljs`

**Tradeoffs:**
- Safe rollout — users on broken paths can be switched back
- Both backends must be maintained simultaneously
- Feature flag explosion if multiple rendering features are independently flagged
- Known FIXME: shader recompilation per page switch is a performance bug

**De-Factoring Evidence:**
- **If the feature flag were removed (WASM-only):** Users on browsers with
  poor WASM/WebGL2 support lose access entirely. The flag exists because
  WASM rendering isn't universally ready.
  **Detection signal:** "App doesn't load on Safari 14" — old browser without
  WebGL2 support.

---

### 4. Context Loss Recovery (Web apps)

**How it works:** GPU contexts can be lost at any time (browser resource
pressure, GPU driver crash, tab backgrounding). The application must detect
loss and restore state.

**Evidence across repos:**

**Penpot:** WebGL context loss forces full shader recompilation. Comment in
`webgl.cljs` acknowledges inability to maintain canvas across page switches,
meaning every switch is effectively a context loss event. Shader compilation
is not cached — each recreation starts from source.

**Krita:** OpenGL fence workaround (`g_needsFenceWorkaround`) exists because
some GPUs lose sync between CPU and GPU operations. The fence ensures GPU
operations complete before CPU reads results. Without it, texture reads return
stale data.

**OpenSeadragon:** Falls back to Canvas2D drawer when WebGL context is lost,
preserving the viewing session at reduced quality.

**Key Recovery Strategies:**
1. **State checkpoint + rebuild** — Save high-level state, recreate GPU resources
   from checkpoint on context restore (most web apps)
2. **Graceful degradation** — Fall back to software rendering on context loss
   (OpenSeadragon)
3. **Prevention** — Minimize GPU state to reduce loss impact; use CPU for
   anything that can't be cheaply recreated (Krita's approach to color pipeline)

**De-Factoring Evidence:**
- **If context loss handling were removed:** In web apps, backgrounding a tab
  for long enough triggers context loss. On restore, the canvas is blank or
  corrupted. Users see "black canvas after switching tabs" — one of the most
  common WebGL bugs.
  **Detection signal:** "Canvas goes black when I switch back to the tab";
  "shader compilation errors in console after resuming."

---

## Decision Guide

**Choose Probe-and-Configure when:**
- You control the application lifecycle (desktop apps)
- GPU capability is stable for the session
- You have a database of known GPU issues to match against

**Choose Progressive Fallback when:**
- You serve diverse unknown hardware (public web apps)
- Partial degradation is acceptable
- You need the widest possible compatibility

**Choose Feature-Flag-Gated Backend when:**
- You're migrating rendering technologies
- You need A/B testing of rendering quality
- Both backends will coexist for an extended period

**Always implement Context Loss Recovery for web apps:**
- WebGL context loss is guaranteed to happen eventually
- The question is not if, but how gracefully you recover

---

## Anti-Patterns

### 1. Silent Degradation Without Telemetry
Falling back to a lower-quality renderer without logging. When visual bugs are
reported, developers can't determine which renderer was active.
**Detection signal:** No logging in fallback paths; "screenshot looks fine on
my machine" because developer has WebGL but user fell back to Canvas2D.

### 2. GPU Feature Detection by User-Agent String
Checking browser/OS strings instead of probing actual GPU capabilities. String
matching breaks with every browser update and misses the long tail of GPU/driver
combinations.
**Detection signal:** `if (navigator.userAgent.includes('Safari'))` in rendering
code; rendering bugs that only affect specific browser versions.

### 3. Shared State Across Context Recreation
Holding references to GPU objects (textures, buffers, programs) across context
loss/recreation. Old references become invalid; using them produces undefined
behavior.
**Detection signal:** "Works after first load, breaks after context loss";
`gl.isContextLost()` checks scattered throughout rendering code instead of
centralized recovery.

### 4. Eager GPU Resource Allocation
Allocating all textures, buffers, and framebuffers at startup regardless of
whether they'll be used. Consumes GPU memory, increases context loss risk,
and wastes startup time on resources for features the user may never invoke.
**Detection signal:** High GPU memory usage on app start; "app is slow to
load but I haven't done anything yet."
