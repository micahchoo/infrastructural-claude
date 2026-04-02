# Progressive Pipeline Patterns

## The Problem

Media applications must transform assets (photos, videos) through multi-stage
pipelines: ingestion → thumbnail → preview → full resolution. Each stage trades
quality against latency and resource consumption. The pipeline must adapt to
heterogeneous hardware (GPU acceleration, CPU fallback), diverse input formats
(HEIC, RAW, H.265, VP9), and varying resource budgets (mobile vs server vs
embedded).

---

## Competing Patterns

### 1. Three-Tier Thumbnail Pipeline (Immich)

**How it works:** Generate multiple resolution tiers at ingestion time, serve
the appropriate tier based on viewing context.

**Example — Immich:**

Three configured thumbnail tiers:
- **preview** — large, for full-screen viewing
- **thumbnail** — medium, for grid/timeline display
- **fullsize** — original resolution (optional, may be transcoded)

Key evidence:
- `MediaService.onBootstrap()` — probes hardware at startup: DRI devices for
  VA-API, Mali for OpenCL, to determine which acceleration is available
- `generateVideoThumbnails()` vs `generateImageThumbnails()` — separate codec
  pipelines per media type
- `moveAssetImage()` — handles format changes across tiers (e.g., migrating
  thumbnail format from JPEG to WebP)
- Configurable format per tier — WebP for thumbnails, JPEG for preview

**Tradeoffs:**
- Predictable latency — thumbnails are pre-generated
- Storage cost — each tier multiplies storage per asset
- Ingestion is slower (must generate all tiers upfront)
- Format migration across tiers requires asset re-processing

**De-Factoring Evidence:**
- **If thumbnail tiers were collapsed to one size:** Grid views load
  full-resolution images, killing scroll performance. Or, preview views
  show thumbnail-resolution images, producing blurry full-screen display.
  **Detection signal:** "Timeline scrolls slowly" (loading full-res) or
  "full-screen view is blurry" (showing thumbnail-res).

- **If hardware probing were removed:** Thumbnail generation falls back to
  CPU-only transcoding. On a server with VA-API capable GPU, this wastes
  available hardware acceleration — thumbnail generation is 5-10x slower.
  **Detection signal:** "Thumbnail generation queue keeps growing";
  `ffmpeg` processes using 100% CPU while GPU is idle.

---

### 2. Decrypt-Then-Progressive (ente)

**How it works:** E2E encrypted assets cannot be processed server-side. The
client must decrypt first, then generate progressive representations locally.

**Example — ente:**

Pipeline: encrypted blob → client decrypt → generate thumbnail → cache locally →
display progressive resolution.

Platform-specific thumbnail generation:
- **Web:** WASM FFmpeg (`ffmpeg/web.ts`) for video thumbnails;
  Canvas API for image thumbnails
- **Desktop:** Bundled native FFmpeg (`electron.ffmpegExec`) with HDR-aware
  thumbnail commands
- **Mobile:** Dart image processing with libsodium decrypt

HDR handling: Desktop FFmpeg commands include tonemapping for HDR→SDR
thumbnails, which WASM FFmpeg doesn't support.

ML under encryption: Face detection runs client-side in web workers
(`web/packages/new/photos/services/ml/worker.ts`) because the server
never sees plaintext images.

**Tradeoffs:**
- Security: server never sees plaintext — zero-knowledge guarantee
- Client CPU/memory burden — all processing happens on user's device
- Platform parity challenge — same pipeline in 3+ implementations
- Cannot do server-side ML, batch processing, or smart thumbnails

**De-Factoring Evidence:**
- **If client-side thumbnail generation were removed:** Users would see
  encrypted blobs until they tap to decrypt and view full-res. No grid
  browsing, no timeline — the app becomes unusable for photo management.
  **Detection signal:** "Grid view shows placeholder icons instead of
  thumbnails" — missing client-side generation.

- **If WASM FFmpeg were replaced with JS-only processing:** Video
  thumbnail extraction becomes impossible in the browser — no JS API
  extracts video frames without a media element. WASM FFmpeg enables
  frame extraction from arbitrary video codecs.
  **Detection signal:** "Can't generate video thumbnails on web."

---

### 3. External Binary Orchestration (memories)

**How it works:** A host application (PHP) orchestrates external native binaries
for each pipeline stage, managing their availability, versioning, and output.

**Example — memories (Nextcloud Photos):**

Three external binaries, each handling a pipeline stage:
- **exiftool** — metadata extraction (EXIF, IPTC, XMP from any format)
- **go-vod** — video transcoding (HLS adaptive streaming)
- **ImageMagick** — image processing (thumbnails, format conversion)

Orchestration pattern (`NativeX` bridge):
- Startup: probe binary availability and version
- Per-request: validate input → exec() with timeout → parse stdout →
  verify output format → return or degrade gracefully
- Version pinning: each binary tested against specific versions
- Host environment adaptation: different Linux distros have different
  binary paths and capabilities

go-vod specifically:
- Custom Go binary for video transcoding to HLS
- Produces adaptive bitrate segments
- Must handle diverse input codecs (H.264, H.265, VP9, AV1)
- Failure recovery: if transcoding fails, serve original (degraded experience)

**Tradeoffs:**
- Leverages mature, battle-tested tools
- No language-binding complexity
- Process creation overhead per operation
- Host environment dependency (binary must be installed)
- Debugging crosses process boundaries
- Security: exec() requires careful input sanitization

**De-Factoring Evidence:**
- **If go-vod were removed:** Video playback falls back to browser-native
  codec support. Users with H.265 videos on browsers without H.265 support
  see nothing. Adaptive streaming disappears — bandwidth waste on mobile.
  **Detection signal:** "Videos don't play on Firefox" (no H.265 support
  without transcoding).

- **If version pinning were removed:** A system update to ImageMagick could
  change output format (JPEG quality defaults, color profile handling),
  producing inconsistent thumbnails across the library.
  **Detection signal:** "Some thumbnails have different colors/quality" —
  generated across ImageMagick versions.

---

### 4. GStreamer Dynamic Pipeline (neko)

**How it works:** Media pipeline is constructed dynamically from parameterized
pipeline descriptions, with expression-evaluated configuration.

**Example — neko (remote desktop):**

Key file: `capture.go`, `VideoConfig.GetPipeline`

GStreamer pipeline dynamically constructed:
- Width/height/fps are `gval` expressions evaluated against screen size
- Pipeline segments: framerate filter → videoscale → encoder
- Multiple codec options with per-codec parameter tuning
- `StreamSelectorType` for choosing video quality level
- `BroadcastManager` for RTMP output alongside WebRTC

Realtime constraints: encoding must keep up with screen capture rate.
If encoder falls behind, frames are dropped rather than queued (latency
over quality for remote desktop use case).

**Tradeoffs:**
- Flexible — pipeline adapts to runtime conditions
- GStreamer handles codec negotiation, format conversion, hardware detection
- Complex — dynamic pipeline construction is hard to debug
- GStreamer dependency is heavy (large native library)
- Expression evaluation adds indirection to configuration

---

## Decision Guide

**Choose Pre-Generated Tiers when:**
- Assets are ingested once, viewed many times
- Server-side processing is available
- Storage cost is acceptable
- Consistent thumbnail quality matters

**Choose Client-Side Progressive when:**
- E2E encryption prevents server-side processing
- Client hardware is capable (modern phones/desktops)
- Platform-specific implementations are maintainable

**Choose External Binary Orchestration when:**
- Mature CLI tools exist for the media operations
- Host environment is controlled (server deployment)
- The integration language (PHP, Python) lacks native media capabilities

**Choose Dynamic Pipeline when:**
- Real-time media processing (streaming, screen capture)
- Pipeline parameters must adapt to runtime conditions
- GStreamer or equivalent framework is available

---

## Anti-Patterns

### 1. Synchronous Thumbnail Generation on Request
Generating thumbnails when a user requests them, blocking the response.
Users see loading spinners; concurrent requests overwhelm CPU.
**Detection signal:** "Timeline takes 30 seconds to load the first time";
thumbnail endpoints with >1s response time.

### 2. Single-Format Pipeline
Hardcoding one output format (e.g., JPEG for all thumbnails). WebP is
30% smaller at equivalent quality; AVIF is better still. Format should
be configurable per tier.
**Detection signal:** Thumbnail storage is 3x larger than necessary;
all thumbnails are JPEG regardless of content type.

### 3. No Hardware Probe at Startup
Attempting hardware acceleration on every operation without checking
availability. Failed acceleration attempts add latency before CPU fallback.
**Detection signal:** Log spam with "hardware acceleration failed, falling
back to software" on every media operation.
