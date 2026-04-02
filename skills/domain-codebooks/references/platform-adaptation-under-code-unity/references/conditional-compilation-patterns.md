# Conditional Compilation Patterns

## The Problem

A single codebase must produce different behavior on different platforms. The
simplest approach — inline conditional compilation (#[cfg], #ifdef, if/else on
platform detection) — works at first but accumulates into a maintenance burden
as the codebase grows. Each conditional is a fork in the code that must be
understood, tested, and maintained independently.

---

## Competing Patterns

### 1. Scattered Inline Conditionals (drafft-ink anti-pattern)

**How it works:** Platform-specific code is placed inline wherever needed, using
the language's conditional compilation facility.

**Example — drafft-ink app.rs:**

40+ `#[cfg(target_arch = "wasm32")]` / `#[cfg(not(target_arch = "wasm32"))]`
blocks scattered throughout a single file:
- Lines 9, 22, 32 — different imports per platform
- Lines 226+ — different initialization paths
- Lines 1039+ — different file dialog implementations
  (`rfd::FileDialog` native vs JS interop for WASM)
- Lines 1162+ — different persistence paths
  (filesystem native vs IndexedDB for WASM)
- Lines 1471-1831+ — large blocks of platform-specific code

Additionally, `text_editor.rs` has `cfg!(target_os = "macos")` for OS-specific
text editing behavior.

Key files: `crates/drafftink-app/src/app.rs`, `crates/drafftink-render/src/text_editor.rs`

**Tradeoffs:**
- Zero abstraction overhead — compiler eliminates dead branches
- Easy to add one-off platform checks
- Grows into unmaintainable spaghetti as conditions multiply
- No way to test that all cfg combinations compile without per-target CI
- Reading the "normal" flow requires mentally filtering out cfg blocks

**De-Factoring Evidence:**
- **If these cfg blocks were consolidated behind a PlatformIO trait:**
  `app.rs` would shrink substantially, each platform path would be testable
  in isolation, and adding a third platform (e.g., iOS) would mean
  implementing the trait, not scattering new cfg blocks throughout the file.
  **Detection signal:** A file with 40+ cfg blocks; platform-specific
  logic mixed with business logic; "I changed the save function and broke
  WASM but didn't notice because I only tested native."

---

### 2. Platform Trait/Interface Abstraction (recommended)

**How it works:** Define a trait or interface for platform-varying operations.
Provide concrete implementations per platform. Select the implementation at
module boundary (compile-time or runtime).

**Example structure:**
```rust
// platform/mod.rs
pub trait PlatformIO {
    fn save_file(&self, data: &[u8], name: &str) -> Result<()>;
    fn load_file(&self, name: &str) -> Result<Vec<u8>>;
    fn show_file_dialog(&self) -> Result<PathBuf>;
}

// platform/native.rs
pub struct NativeIO;
impl PlatformIO for NativeIO {
    fn save_file(&self, data: &[u8], name: &str) -> Result<()> {
        std::fs::write(name, data)?;
        Ok(())
    }
    // ...
}

// platform/wasm.rs
pub struct WasmIO;
impl PlatformIO for WasmIO {
    fn save_file(&self, data: &[u8], name: &str) -> Result<()> {
        indexed_db_write(name, data).await?;
        Ok(())
    }
    // ...
}
```

The application code takes `impl PlatformIO` and is platform-agnostic.

**Tradeoffs:**
- Clean separation — business logic doesn't know about platforms
- Each platform implementation is independently testable
- Adding a new platform means adding an implementation, not modifying existing code
- Slight abstraction overhead (trait objects if dynamic dispatch)
- Requires upfront design of the platform interface

---

### 3. Browser/OS Detection at Runtime (tldraw)

**How it works:** Runtime detection of browser, OS, or device capabilities,
with conditional behavior based on detected environment.

**Example — tldraw browser-specific workarounds:**

- `getSvgAsImage.ts`: Uses `data:` URLs instead of `blob:` URLs to work around
  Chrome canvas taint bug (chromium issue 41054640)
- Safari-specific `sleep(250)` hack for font-loading timing in SVG export
  (WebKit bug 219770)
- `clampToBrowserMaxCanvasSize` negotiates per-browser canvas size limits

These are runtime checks, not compile-time — the same code runs in all browsers
but adapts behavior based on detection.

**Tradeoffs:**
- Single deployment artifact — no per-browser builds
- Workarounds are co-located with the feature they fix
- Browser-specific hacks are fragile — browser updates can fix or break them
- No way to know when a workaround is no longer needed
- Testing requires all target browsers

**De-Factoring Evidence:**
- **If browser workarounds were centralized in a compatibility layer:**
  Export code would be simpler (`exportImage(svg)` without inline browser
  checks). Browser-specific fixes would be in one place, reviewable as a unit,
  and removable when the browser bug is fixed.
  **Detection signal:** `if (isSafari)` / `if (isChrome)` scattered in
  rendering and export code; workaround comments referencing browser bug URLs.

---

### 4. GPU Driver Workaround Database (Krita)

**How it works:** A centralized startup probe builds a configuration based on
detected GPU, driver, and OS. The rest of the application reads this config
without platform-specific branching.

**Example — Krita KisOpenGL:**

Key file: `libs/ui/opengl/kis_opengl.cpp`

Centralized detection:
- `KisOpenGLModeProber` — creates probe GL context, queries capabilities
- `g_forceDisableTextureBuffers` — set for ANGLE (DirectX-backed OpenGL on Windows)
- `g_needsFenceWorkaround` — set for specific GPU bugs
- Renderer string matching: vendor, driver version, known-bad combinations
- Result: a set of boolean flags that the rendering code queries

The rendering code (`kis_canvas2.cpp`, `kis_opengl_shader_loader.cpp`) reads
these flags but doesn't contain detection logic itself.

**Tradeoffs:**
- Centralized — all platform knowledge in one place
- Rendering code is clean — queries capability flags, doesn't detect them
- Database maintenance is ongoing — new GPU/driver combos may need entries
- Testing requires the actual hardware (can't mock GPU probing effectively)

---

## Decision Guide

**Choose Trait Abstraction when:**
- Platform divergence is at I/O or service boundaries
- You have 3+ platform operations that vary together
- Clean testability matters
- You might add a new platform later

**Choose Inline cfg/ifdef when:**
- One or two isolated platform checks
- The divergence is truly trivial (a constant value, an import path)
- Consolidation would be over-engineering

**Choose Runtime Detection when:**
- Targeting browsers where compile-time branching isn't possible
- Workarounds are tied to specific browser bugs (temporary)
- Same deployment serves all platforms

**Choose Centralized Probe when:**
- Platform adaptation is based on hardware capabilities
- The set of adaptations is large (10+ flags)
- Detection should happen once, not per-operation

---

## Anti-Patterns

### 1. Duplicated Platform Logic
Same business logic reimplemented per-platform instead of shared with only
the platform-specific parts abstracted.
**Detection signal:** Near-identical functions under `#[cfg(wasm32)]` and
`#[cfg(not(wasm32))]` differing only in I/O calls.

### 2. Platform Leak into Domain Types
Domain types that contain platform-specific fields (`webgl_context: Option<...>`,
`native_handle: *mut c_void`) instead of being platform-agnostic.
**Detection signal:** `#[cfg]` attributes on struct fields; domain types that
only compile on one platform.

### 3. Undocumented Browser Workarounds
Browser-specific hacks without comments linking to the bug tracker. When the
bug is fixed, nobody knows the workaround can be removed.
**Detection signal:** `sleep(250)` without a comment explaining why; platform
checks with no bug URL reference.
