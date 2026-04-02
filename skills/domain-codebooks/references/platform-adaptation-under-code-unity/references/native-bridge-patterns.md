# Native Bridge Patterns

## The Problem

Applications frequently need capabilities only available through native code:
hardware-accelerated crypto, media transcoding, GPU access, OS-level APIs. The
bridge between the application runtime (JavaScript, PHP, Dart, Python) and
native code (Rust, C, C++, Go) is where complexity concentrates — type
translation, error propagation, lifecycle management, and memory safety all
converge at this boundary.

---

## Competing Patterns

### 1. Rust→WASM via wasm-bindgen (drafft-ink, ente)

**How it works:** Rust code compiled to WASM, exposed to JavaScript via
wasm-bindgen. The Rust code runs in the browser's WASM sandbox with access
to browser APIs through web-sys.

**Example — drafft-ink:**

Single Rust codebase compiled to both native (via winit/wgpu) and WASM (via
web-sys/wasm-bindgen). The WASM target uses:
- `web-sys` for DOM access, canvas, file input
- `wasm-bindgen` for JS↔Rust type conversion
- IndexedDB for persistence (replacing filesystem)
- JS interop for file dialogs (replacing rfd::FileDialog)

Key file: `crates/drafftink-app/src/app.rs`

**Example — ente web crypto:**

Rust crypto library compiled to WASM for web client:
- `accounts-rs/services/wasm.ts` — TypeScript wrapper calling WASM-exported functions
- `enteWasm()` — initializes WASM module, exposes crypto operations
- Handles `insufficient_memory` errors (WASM linear memory is constrained)
- Same crypto operations also exist in Dart/libsodium (mobile) and Go (CLI)

**Tradeoffs:**
- Near-native performance in browser
- Shares code between native and web targets
- WASM linear memory constraints (can't match native memory management)
- Async operations require special handling (wasm-bindgen-futures)
- Binary size matters for web — Rust WASM can be large

**De-Factoring Evidence:**
- **If WASM crypto were replaced with JS crypto:** Performance drops for
  key derivation (argon2id). More critically, the JS implementation would
  be a reimplementation with potential for subtle correctness divergence.
  **Detection signal:** "Key derived on web doesn't match key derived on
  mobile" — crypto implementation divergence.

---

### 2. Dart FFI to Native Libraries (ente mobile)

**How it works:** Dart's FFI calls into native shared libraries (.so/.dylib)
for performance-critical operations.

**Example — ente mobile crypto:**

`mobile/packages/ente_crypto_api/` — Dart FFI to libsodium:
- Native libsodium compiled per-platform (Android .so, iOS .dylib)
- Dart FFI declarations mirror C function signatures
- Memory management: Dart allocates, passes pointer to native, native fills,
  Dart reads and frees
- Same crypto operations as Rust/WASM (web) and Go (CLI)

**Tradeoffs:**
- Direct native performance — no WASM overhead
- Per-platform native binary compilation required
- Memory management crosses Dart GC / native boundary
- Must declare FFI signatures that exactly match C ABI
- Library loading failures are runtime, not compile-time

**De-Factoring Evidence:**
- **If Dart FFI were replaced with pure Dart crypto:** Performance-sensitive
  operations (key derivation, large file encryption) become unacceptably slow.
  Dart's crypto libraries don't expose hardware acceleration.
  **Detection signal:** "Decrypting a large video takes 10x longer on mobile."

---

### 3. External Binary Orchestration via exec() (memories)

**How it works:** The application shells out to native CLI tools for processing,
managing their lifecycle, versioning, and output parsing.

**Example — memories (Nextcloud Photos):**

PHP orchestrates three external binaries:
- **exiftool** — metadata extraction from photos/videos
- **go-vod** — video transcoding (custom Go binary)
- **ImageMagick** — image processing and thumbnail generation

Orchestration concerns:
- Version pinning — each binary tested against specific versions
- Availability probing — startup checks for binary presence and version
- Output parsing — stdout/stderr capture and structured parsing
- Error handling — binary crash/timeout must not crash PHP process
- Resource management — concurrent exec() can exhaust process limits

The `NativeX` bridge pattern in memories wraps exec() calls with:
- Input validation before shell-out
- Timeout enforcement
- Output format verification
- Graceful degradation when binary is missing

**Tradeoffs:**
- Zero language bridge overhead — each tool is a standalone process
- Easy to upgrade independently
- Every call pays process creation overhead
- Security: exec() is a command injection risk without careful sanitization
- Platform-dependent binary availability (Linux package managers)
- Debugging crosses process boundaries

**De-Factoring Evidence:**
- **If exec() were replaced with native PHP extensions:** Installation
  complexity increases (compiled extensions per PHP version). The standalone
  binary approach means "install go-vod" works on any system regardless of
  PHP version.
  **Detection signal:** "Can't install the PHP extension on this hosting
  provider" — the PHP extension model is more restrictive than standalone binaries.

- **If version pinning were removed:** A system update to ImageMagick could
  change output format, break thumbnail generation, or introduce security
  vulnerabilities. Version pinning isolates the application from system-level
  changes.
  **Detection signal:** "Thumbnails look different after system update" — the
  native binary changed behavior between versions.

---

### 4. CGo for OS-Level Access (neko)

**How it works:** Go code calls C libraries via CGo for system-level operations
that Go's standard library doesn't expose.

**Example — neko (remote desktop):**

- `Go→CGo→X11` for input injection (sending keyboard/mouse events to X server)
- `Go→CGo→GStreamer` for media capture pipeline
- GStreamer pipeline dynamically constructed from expression-evaluated parameters
  (`capture.go`, `VideoConfig.GetPipeline`)
- Pipeline segments: framerate filter → videoscale → encoder with configurable
  settings per codec

**Tradeoffs:**
- Access to any C library from Go
- CGo calls are expensive (goroutine→C transition overhead)
- Cross-compilation becomes difficult (needs C toolchain for target)
- Memory management crosses Go GC / C manual boundary
- CGo builds are slower than pure Go

---

### 5. UniFFI / Generated Bindings (ente cross-platform)

**How it works:** A single Rust implementation generates bindings for multiple
target languages automatically.

**Example — ente's multi-platform strategy:**

The same crypto must work on web (WASM), mobile (Dart FFI), desktop (Electron),
and CLI (Go). Rather than 4 reimplementations, the ideal is:
1. Single Rust crypto library
2. WASM target for web (wasm-bindgen)
3. UniFFI-generated Kotlin/Swift bindings for mobile
4. C ABI for Dart FFI
5. Generated Go bindings for CLI

In practice, ente has partial convergence — Rust/WASM for web is done, but
mobile still uses Dart/libsodium and CLI uses Go crypto. This represents
the migration path: consolidate implementations over time, starting with
the most critical (web crypto) and working outward.

**Tradeoffs:**
- Single source of truth for correctness
- Generated bindings reduce hand-written FFI declarations
- UniFFI adds a build step and limits API expressiveness
- Not all language features translate across bindings
- Migration from N implementations to 1+N bridges is gradual

---

## Decision Guide

**Choose Rust→WASM when:**
- Performance-critical code must run in browsers
- You have existing Rust code to share
- Binary size is manageable for your use case

**Choose Dart FFI when:**
- Flutter app needs native-speed operations
- Native library is well-established (libsodium, SQLite)
- You control the build pipeline for all target platforms

**Choose External Binary Orchestration when:**
- Mature CLI tools already exist for the operation
- The overhead of process creation is acceptable
- You don't control the host language's extension model (e.g., PHP)
- Security review of direct FFI is too expensive

**Choose CGo when:**
- Go application needs OS-level C API access
- The C library has no Go equivalent
- Build complexity is acceptable

**Choose UniFFI / Generated Bindings when:**
- The same logic is needed on 3+ platforms
- Correctness (identical behavior) is more important than platform-native feel
- You can accept the initial investment in binding generation

---

## Anti-Patterns

### 1. N Reimplementations of Critical Logic
Same algorithm in N languages without automated correctness checking. Each
diverges subtly — especially for crypto, where a one-bit difference is a
security vulnerability.
**Detection signal:** Same function name in Rust, Dart, Go, and TypeScript
with no cross-language test suite.

### 2. Unvalidated exec() Input
Passing user-controlled data to exec() without sanitization. Classic command
injection vulnerability.
**Detection signal:** String concatenation in exec() arguments; no allowlist
of permitted parameters.

### 3. Leaked Native Handles
Passing raw pointers or file descriptors across the bridge without lifecycle
management. The native side frees the resource; the managed side uses the
stale handle.
**Detection signal:** Segfaults or "invalid handle" errors in production;
native resource leaks in long-running processes.
