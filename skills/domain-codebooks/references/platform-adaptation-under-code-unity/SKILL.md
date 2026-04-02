---
name: platform-adaptation-under-code-unity
description: >-
  Force tension: feature parity vs platform idiom vs maintenance cost when a
  single logical codebase must run across fundamentally different platforms
  (native/WASM, mobile/desktop/web, different OS APIs).

  The three-way tension: code sharing vs platform-native experience vs
  sustainable maintenance as platform-conditional branches accumulate.

  Triggers: "cross-platform FFI boundary generation", "conditional compilation
  isolation patterns", "platform abstraction trait design", "native bridge
  error propagation", "WASM dependency substitution", "UniFFI binding
  generation", "Kotlin Multiplatform expect/actual", "SIMD intrinsics
  per-architecture", "platform-specific persistent storage", "shared core
  with platform UI layer".

  Brownfield triggers: "cfg blocks scattered throughout the code and getting
  unmaintainable", "platform integration layer growing larger than shared
  core", "bridge code is brittle and crashes cross native boundary",
  "Rust crates use system libraries not available in WASM", "platform-specific
  TLS requirements break shared networking", "UniFFI generated APIs feel
  unidiomatic in target language", "SIMD code paths interleaved with algorithm
  logic", "persistent storage differs per platform Core Data vs Room vs
  IndexedDB", "stack traces cross the native boundary hard to debug",
  "same feature needs different async paradigm per platform".

  Symptom triggers: "Rust shared core needs Swift Kotlin and TypeScript
  bindings with different FFI conventions C headers JNI and WASM bindgen",
  "cfg target_os blocks scattered throughout the code getting unmaintainable",
  "platform integration layer for PhotoKit and MediaStore growing larger
  than the shared C++ core", "porting Electron app to native iOS Android
  with Kotlin Multiplatform expect actual bridging Node.js APIs",
  "native bridge crashes are hard to debug because stack traces cross the
  native boundary Objective-C JNI", "Rust crates use OpenSSL SQLite not
  available in WASM need web-compatible substitution", "iOS App Transport
  Security and Android certificate pinning and browser TLS all different
  in shared networking layer", "UniFFI generated Swift and Kotlin bindings
  feel unidiomatic no suspend functions or async await", "SIMD intrinsics
  SSE AVX on x86 NEON on ARM no SIMD in WASM interleaved with algorithm
  logic", "persistent storage differs per platform Core Data vs Room vs
  IndexedDB with shared data model and repository interfaces".

triggers:
  - conditional compilation
  - platform adaptation
  - cross-platform code sharing
  - cfg blocks
  - feature flags for platforms
  - native vs WASM bifurcation
  - platform-specific rendering
  - FFI bridge
  - UniFFI
  - Comlink worker bridge
  - CGo native bridge
  - Dart FFI
  - Electron IPC
  - "40 cfg blocks and growing"
  - "same feature implemented differently per platform"
  - "native binary works but WASM version fails"
  - "platform-specific bug that only reproduces on one target"
  - "filesystem code doesn't work in the browser"
  - "need to call native API from web context"

cross_codebook_triggers:
  - "GPU workaround only needed on one platform (+ rendering-backend-heterogeneity)"
  - "input handling differs per platform (+ input-device-adaptation)"
  - "native crypto vs WASM crypto performance gap (+ media-pipeline-adaptation)"

diffused_triggers:
  - "how do I share code between native and web"
  - "Rust codebase needs to run in browser via WASM"
  - "Flutter app needs native Rust for performance"
  - "desktop app wrapping web app in Electron/Tauri"
  - "PHP app needs to call native binary"
  - "same operation, different API per platform"
  - "conditional compilation is getting unmaintainable"

skip:
  - Pure web apps (no native/platform concerns)
  - Single-platform applications
  - Build system configuration without code-level platform branching

libraries:
  - drafft-ink (Rust native + WASM via cfg blocks)
  - ente (Flutter + Web + Tauri + Rust via multi-runtime bridging)
  - krita (C++ cross-platform via Qt + GPU driver workarounds)
  - memories (PHP + external native binaries)
  - neko (Go + CGo for X11/GStreamer)

production_examples:
  - "drafft-ink app.rs — 40+ #[cfg(target_arch)] blocks splitting native/WASM I/O paths"
  - "ente — same crypto in Rust/WASM, Dart/libsodium, Go, and Electron"
  - "krita kis_opengl.cpp — GPU driver detection with per-vendor workarounds"
  - "memories — PHP exec() to exiftool/govod/ImageMagick with version pinning"
---

# Platform Adaptation Under Code Unity

When a single logical codebase must run across platforms with different APIs,
capabilities, and constraints, every cross-platform operation becomes a decision
point: share code and accept platform leakage, or fork per-platform and accept
maintenance cost. This codebook covers how to structure those decisions.

---

## Step 1: Classify

Answer these questions to determine which patterns apply:

1. **What is the platform boundary?** Native/WASM, mobile/desktop/web,
   OS-level (Windows/macOS/Linux), or runtime-level (browser engines)?

2. **What diverges across platforms?** I/O (filesystem vs IndexedDB), rendering
   (GPU APIs), crypto (native vs WASM), process management (fork vs Worker),
   or UI framework?

3. **How many platform-specific paths exist?** Two (native/WASM), three
   (mobile/desktop/web), or N (per-OS + per-browser)?

4. **Is the divergence compile-time or runtime?** Conditional compilation
   (#[cfg], #ifdef) vs runtime detection (user-agent, capability probing)?

5. **Are native binaries involved?** FFI to shared libraries, exec() to CLI
   tools, or WASM modules loaded at runtime?

6. **What is the parity requirement?** Identical features everywhere, or
   progressive enhancement (base features + platform-specific extras)?

---

## Step 2: Load Reference

| Scenario | Reference | Key Pattern |
|---|---|---|
| #[cfg] blocks, #ifdef, feature flags for platform branching | `get_docs("domain-codebooks", "platform-adaptation conditional compilation")` | Platform trait abstraction, cfg consolidation |
| FFI, Comlink, CGo, exec() bridges to native code | `get_docs("domain-codebooks", "platform-adaptation native bridge")` | Bridge typing, error translation, lifecycle management |
| GPU varies by platform | **cross-ref:** rendering-backend-heterogeneity | Probe-and-configure, shader adaptation |
| Input devices differ by platform | **cross-ref:** input-device-adaptation | Pointer type detection, capability probing |
| Media processing uses platform-specific tools | **cross-ref:** media-pipeline-adaptation | Native binary orchestration |

---

## Step 3: Advise

### When the platform boundary is compile-time (Rust cfg, C++ ifdef):

Consolidate platform branches behind trait/interface abstractions. Instead of
40 scattered #[cfg] blocks, define a `PlatformIO` trait with `save_file()`,
`load_file()`, `show_dialog()` methods, and provide native and WASM
implementations. Drafft-ink's 40+ cfg blocks in `app.rs` are the anti-pattern
— each represents an unabstracted platform decision.

### When the platform boundary is runtime (browser detection, GPU probing):

Probe capabilities at startup and configure for the session. Don't re-probe
per operation. Krita's `KisOpenGLModeProber` runs once, determines the GPU
path, and caches the result. Runtime detection should produce a capability
object that the rest of the code queries.

### When native binaries are involved (exec, FFI):

Version-pin native dependencies, probe availability at startup, and design
graceful degradation when binaries are missing. Memories orchestrates exiftool,
go-vod, and ImageMagick — each with version detection and fallback behavior
when a binary isn't installed.

### When the same logic exists in multiple languages:

This is a maintenance time bomb. Ente implements the same crypto in Rust/WASM,
Dart/libsodium, Go, and Electron — four implementations that must produce
identical output. Consider a single implementation language with bridges
(Rust + UniFFI to generate bindings for all targets) rather than N
reimplementations.

### When progressive enhancement is acceptable:

Define a base feature set that works everywhere, then add platform-specific
enhancements. Web gets WASM crypto, desktop gets native binary acceleration,
mobile gets camera access. The key is making the base set explicit — don't
let it be "whatever accidentally works on all platforms."

---

## Cross-References

- **rendering-backend-heterogeneity** — Platform determines available renderers
  (WebGL on web, OpenGL/Vulkan on desktop, Metal on macOS). Rendering adaptation
  is a special case of platform adaptation.
- **input-device-adaptation** — Platform determines input devices (touch on
  mobile, pen on tablets, mouse on desktop). Input adaptation patterns parallel
  rendering adaptation.
- **media-pipeline-adaptation** — Native binary orchestration for media
  processing is a platform adaptation concern.
- **embeddability-and-api-surface** — Platform adaptation creates API surface
  challenges when the same library must expose different interfaces per platform.

---

## Principles

1. **Consolidate platform branches behind interfaces.** Every scattered #[cfg]
   or #ifdef is a future merge conflict. Move platform decisions to module
   boundaries where native and portable implementations can be swapped.

2. **Probe once, configure for session.** Don't re-detect capabilities per
   operation. Build a capability object at startup and query it throughout.

3. **Single implementation + N bridges beats N implementations.** If you must
   have the same logic on multiple platforms, write it once in a bridgeable
   language (Rust, C) and generate bindings (UniFFI, wasm-bindgen, CGo). Each
   reimplementation is a consistency risk.

4. **Version-pin native dependencies.** When shelling out to native binaries,
   pin versions and test against them. A system-installed binary can change
   without warning. Memories pins exiftool to known-working versions.

5. **Make the platform abstraction explicit.** Don't let platform code leak
   into business logic. If a function needs platform-specific behavior, take
   it as a parameter or trait implementation, not an inline #[cfg] block.

6. **Test on all target platforms.** Conditional compilation means code paths
   that only execute on one platform. Without CI on all targets, dead code
   and platform-specific regressions accumulate silently.
