# GPU Context Lifecycle

## The Problem

GPU contexts are not permanent resources. They can be lost due to browser
resource pressure, GPU driver crashes, tab backgrounding, page navigation, or
WASM module reinitialization. Applications that assume a stable GPU context
encounter blank canvases, stale texture reads, resource ID aliasing bugs, and
shader recompilation stalls. The tension: minimize GPU state for resilience vs
maximize GPU state for performance.

This reference extends the "Context Loss Recovery" section in
`fallback-and-feature-detection.md` with deeper lifecycle patterns covering
creation, multi-context coordination, loss detection, and recovery strategies.

---

## Competing Patterns

### 1. RAII Context Lock with Saved/Restored Previous Context (Krita)

**How it works:** When an operation needs a specific OpenGL context, acquire it
through an RAII lock that saves the currently-active context and surface,
switches to the target, performs work, then restores the previous context on
scope exit.

**Example -- Krita KisOpenGLContextSwitchLock:**

Key file: `libs/ui/opengl/KisOpenGLContextSwitchLock.h`

```cpp
class KisOpenGLContextSwitchLockAdapter {
    void lock();    // saves old context, calls makeCurrent on target
    void unlock();  // restores old context + surface
private:
    QOpenGLWidget *m_targetWidget;
    QOpenGLContext *m_oldContext;
    QSurface *m_oldSurface;
};
```

Usage throughout `kis_opengl_canvas2.cpp`:
```cpp
// Every method that touches GL state acquires the lock
void KisOpenGLCanvas2::setDisplayFilter(...) {
    KisOpenGLContextSwitchLockSkipOnQt5 contextLock(this);
    d->renderer->setDisplayFilter(displayFilter);
}

void KisOpenGLCanvas2::finishResizingImage(qint32 w, qint32 h) {
    KisOpenGLContextSwitchLockSkipOnQt5 contextLock(this);
    d->renderer->finishResizingImage(w, h);
}
```

**Critical evidence -- resource ID aliasing on destruction:**
```cpp
KisOpenGLCanvas2::~KisOpenGLCanvas2() {
    // Since we delete openGL resources, we should make sure the
    // context is initialized properly before they are deleted.
    // Otherwise resources from some other (current) context may be
    // deleted due to resource id aliasing.
    //
    // The main symptom of resources being deleted from wrong context,
    // the canvas being locked/backened-out after some other document
    // is closed.
    makeCurrent();
    delete d;
    doneCurrent();
}
```

**Tradeoffs:**
- Prevents cross-context resource corruption in multi-document apps
- RAII guarantees cleanup even on exception paths
- Adds overhead to every GL operation (context switch cost)
- Qt5 vs Qt6 behavioral differences require the `SkipOnQt5` variant

**De-Factoring Evidence:**
- **If the context lock were removed:** In a multi-document app, closing
  document B while document A's context is active deletes B's GL resources from
  A's context. GL resource IDs are integers that alias across contexts. The
  symptom: "canvas locked/blacked-out after closing another document."
  **Detection signal:** Closing one tab/document corrupts another's rendering.

---

### 2. Pixel Capture and Replay Across Context Recreation (Penpot)

**How it works:** Before destroying a GPU context (e.g., page navigation),
capture the current canvas pixels into CPU memory. After the new context is
created, replay those pixels as a texture to provide visual continuity during
the transition.

**Example -- Penpot page switch lifecycle:**

Key files: `frontend/src/app/render_wasm/wasm.cljs`,
`frontend/src/app/render_wasm/api/webgl.cljs`

State management:
```clojure
;; wasm.cljs -- module-level state
(defonce canvas nil)
(defonce canvas-pixels nil)        ;; captured ImageData for transition
(defonce gl-context-handle nil)    ;; Emscripten GL wrapper
(defonce gl-context nil)           ;; actual WebGL context
(defonce context-initialized? false)
(defonce context-lost? (atom false))
```

Capture before page switch:
```clojure
(defn capture-canvas-pixels []
  (when wasm/canvas
    (let [context wasm/gl-context
          width (.-width wasm/canvas)
          height (.-height wasm/canvas)
          buffer (js/Uint8ClampedArray. (* width height 4))
          _ (.readPixels context 0 0 width height
              (.-RGBA context) (.-UNSIGNED_BYTE context) buffer)
          image-data (js/ImageData. buffer width height)]
      (set! wasm/canvas-pixels image-data))))
```

Restore after new context:
```clojure
(defn restore-previous-canvas-pixels []
  (when-let [previous-canvas-pixels wasm/canvas-pixels]
    (when-let [gl wasm/gl-context]
      (draw-imagedata-to-webgl gl previous-canvas-pixels)
      (set! wasm/canvas-pixels nil))))
```

The `draw-imagedata-to-webgl` function creates a full-screen quad with inline
vertex/fragment shaders each time -- shaders are compiled from source on every
page switch because they cannot be cached across WebGL contexts.

```clojure
;; Comment from source:
;; Since we are only calling this function once (on page switch), we don't need
;; to cache the compiled shaders somewhere else (cannot be reused in a
;; different context).
```

**Tradeoffs:**
- Visual continuity during page transitions (no black flash)
- CPU memory cost: full-resolution RGBA pixel buffer per canvas
- Shader recompilation overhead on every page switch
- `readPixels` forces GPU→CPU sync, stalling the pipeline
- Known FIXME: ideally the canvas would persist across pages

**De-Factoring Evidence:**
- **If pixel capture were removed:** Every page switch produces a black canvas
  flash while the new context initializes and the scene re-renders. In a design
  tool where users switch between pages frequently, this creates a jarring
  "flicker to black" experience.
  **Detection signal:** "Canvas goes black for a moment when switching pages."

---

### 3. Fence-Based GPU/CPU Synchronization (Krita)

**How it works:** Insert a GPU fence after rendering operations to ensure the
GPU has completed work before the CPU reads results. Without fences, texture
reads can return stale or incomplete data.

**Example -- Krita fence workaround:**

Key file: `libs/ui/opengl/kis_opengl.cpp`

```cpp
// Detected at startup, stored in global
bool g_needsFenceWorkaround = false;

// Trigger condition: AMD on X11 or explicit config override
if ((isOnX11 && openGLCheckResult->rendererString().startsWith("AMD"))
    || cfg.forceOpenGLFenceWorkaround()) {
    g_needsFenceWorkaround = true;
}
```

The fence workaround exists because some AMD drivers on X11 lose
synchronization between CPU and GPU operations. The GPU may still be writing to
a texture when the CPU attempts to read it, producing torn or stale frames.

**Tradeoffs:**
- Prevents data races between GPU writes and CPU reads
- Adds latency (CPU waits for GPU completion)
- Only needed on specific GPU/driver/platform combinations
- Startup probe avoids runtime cost on unaffected hardware

**De-Factoring Evidence:**
- **If fences were removed:** On affected AMD/X11 systems, texture reads return
  partially-updated data. The symptom is subtle: occasional visual corruption
  that disappears on the next frame, making it hard to reproduce.
  **Detection signal:** "Occasional flickering artifacts on AMD GPU";
  "screenshot looks fine but display briefly corrupts."

---

### 4. Guard-and-Initialize State Machine (Web WASM apps)

**How it works:** All GPU operations are gated behind a state flag that tracks
whether the context is initialized. The context transitions through states:
uninitialized -> initialized -> lost -> reinitialized. Every GPU call checks the
flag before proceeding.

**Example -- Penpot WASM context guard:**

```clojure
(defonce context-initialized? false)
(defonce context-lost? (atom false))

(defn get-webgl-context []
  (when wasm/context-initialized?
    (let [gl-obj (unchecked-get wasm/internal-module "GL")]
      (when gl-obj
        (let [current-ctx (.-currentContext gl-obj)]
          (when current-ctx
            (.-GLctx current-ctx)))))))
```

The triple-guard pattern (module initialized? -> GL object exists? -> current
context exists?) handles the cascade of failures that can occur when Emscripten
owns the GL context lifecycle.

**Tradeoffs:**
- Prevents null-reference crashes from GL calls on lost contexts
- Simple to reason about -- one boolean guards all GPU paths
- Adds conditional overhead to every GL operation
- Does not distinguish between "never initialized" and "lost and pending
  recovery" -- both return nil

**De-Factoring Evidence:**
- **If the guard were removed:** Any GL call between context loss and context
  recreation produces a null reference error. In Emscripten apps, the GL module
  reference itself can be null if WASM hasn't finished loading.
  **Detection signal:** "TypeError: Cannot read property 'bindTexture' of null";
  "WASM module not ready" errors in console.

---

## Decision Guide

**Choose RAII Context Lock when:**
- Multiple GL contexts coexist (multi-document, multi-viewport)
- Operations mutate shared GL state from different code paths
- Desktop application with stable context lifecycle

**Choose Pixel Capture and Replay when:**
- Context must be destroyed and recreated (page navigation, WASM reload)
- Visual continuity during transitions is important
- Full scene re-render would cause visible latency

**Choose Fence-Based Synchronization when:**
- GPU→CPU data transfer is required (texture readback, screenshots)
- Target hardware includes GPUs with known sync bugs
- Startup probing can detect affected hardware

**Choose Guard-and-Initialize when:**
- Context lifecycle is owned by a framework (Emscripten, browser)
- Context can be lost at any time without warning
- Application must degrade gracefully rather than crash

---

## Anti-Patterns

### 1. Holding GL Object References Across Context Boundaries
Storing texture IDs, buffer handles, or program references in long-lived state
that survives context recreation. GL resource IDs are integers scoped to a
context -- they become dangling references after context loss and may alias to
different resources in a new context.
**Detection signal:** "Rendering corruption after switching tabs/pages";
`gl.deleteTexture()` called on handles from a previous context.

### 2. Synchronous Context Queries in Hot Paths
Calling `gl.getParameter()`, `gl.getError()`, or `gl.readPixels()` in the
render loop. These force GPU→CPU synchronization, stalling the pipeline.
**Detection signal:** Frame drops correlating with GL state queries;
`readPixels` called every frame instead of on-demand.

### 3. Assuming Context Loss is Recoverable In-Place
Attempting to restore GL state by replaying recorded GL calls rather than
rebuilding from application state. The GL state machine has too many dimensions
to reliably replay, and driver-specific behavior makes this fragile.
**Detection signal:** Complex "GL state tracker" that records all calls;
recovery works on Chrome but not Safari.

### 4. Platform-Blind Context Creation
Creating a WebGL2 context without checking availability, or requesting OpenGL
features without extension checks. The context creation itself can silently
return null or a lower version.
**Detection signal:** `getContext('webgl2')` without fallback;
`gl.getExtension()` results unchecked before use.
