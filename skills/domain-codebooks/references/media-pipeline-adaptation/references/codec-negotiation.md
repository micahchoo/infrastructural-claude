# Codec Negotiation

## The Problem

Media applications must handle diverse input formats (HEIC, RAW, H.265, VP9,
AV1, ProRes) and produce output consumable by diverse clients (browsers with
varying codec support, mobile devices with hardware decoders, desktop players).
The negotiation between input format, available hardware, target client, and
quality/size constraints is where pipeline complexity concentrates.

---

## Competing Patterns

### 1. Hardware-Probed Transcoding (Immich)

**How it works:** At startup, probe available hardware acceleration (GPU,
dedicated decode/encode ASICs), then select the transcoding strategy based on
what's available.

**Example — Immich MediaService.onBootstrap():**

Hardware probing:
- `getDevices()` — scans DRI devices for VA-API support (Intel/AMD GPU decode/encode)
- `hasMaliOpenCL()` — detects ARM Mali GPU for OpenCL acceleration
- Result determines: VA-API transcoding, software fallback, or hybrid

Codec strategy:
- Video: H.264 is the safe default (universal browser support); H.265 for
  storage efficiency when hardware encode is available; VP9/AV1 for web-first
- Thumbnail: Extract keyframe → scale → encode to WebP/JPEG
- Separate paths for `generateVideoThumbnails()` vs `generateImageThumbnails()`

Key decision: hardware-accelerated H.265 encoding saves ~40% storage vs H.264
at equivalent quality, but only if the GPU supports it. Without hardware
acceleration, H.265 encoding is 10x slower than H.264.

**Tradeoffs:**
- Optimal use of available hardware
- Probe once, use cached result for session
- Hardware diversity makes testing difficult
- Probe failures (driver bugs, container limitations) need graceful fallback

**De-Factoring Evidence:**
- **If hardware probing were removed (always software):** Server with NVIDIA
  GPU wastes hardware acceleration. Transcoding queue backs up. Users wait
  hours instead of minutes for video processing.
  **Detection signal:** "Video processing is very slow" on a server with GPU;
  GPU utilization at 0% during transcoding.

- **If codec selection were hardcoded (always H.264):** Storage cost increases
  40% for video. Users with H.265 capable devices (most modern phones) don't
  benefit from native playback of their own recorded format.
  **Detection signal:** "Storage usage for videos is much higher than
  expected"; H.265 source videos re-encoded to H.264 unnecessarily.

---

### 2. Platform-Conditional Codec Strategy (ente)

**How it works:** Different platforms use different codec paths based on
available APIs and runtime constraints.

**Example — ente multi-platform codec handling:**

- **Web (WASM FFmpeg):** `ffmpeg/web.ts` — WASM-compiled FFmpeg runs in
  browser. Limited codec support (no hardware acceleration). H.264 encode
  only. Frame extraction via `ffmpeg -ss <time> -i <input> -frames:v 1`.

- **Desktop (native FFmpeg):** `electron.ffmpegExec` — bundled native binary.
  Full codec support including hardware acceleration. HDR-aware thumbnail
  commands with tonemapping (`-vf zscale=t=linear,tonemap=hable,zscale=t=bt709`).

- **Mobile (Dart):** Platform-native APIs for image processing. Video
  thumbnails via platform thumbnail generation APIs.

Key divergence: HDR→SDR tonemapping. Desktop FFmpeg supports the full
zscale/tonemap filter chain. WASM FFmpeg doesn't have these filters compiled
in — HDR thumbnails on web are either washed out or missing.

**Tradeoffs:**
- Each platform uses its best available tools
- Feature parity is impossible (WASM can't match native FFmpeg)
- Three implementations to maintain
- HDR handling diverges across platforms

**De-Factoring Evidence:**
- **If WASM FFmpeg were replaced with native-only processing:** Web users
  can't generate video thumbnails at all. The entire web photo management
  experience degrades.
  **Detection signal:** "Web app shows blank thumbnails for videos."

---

### 3. Adaptive Streaming via Transcoding (memories go-vod)

**How it works:** Transcode video into adaptive bitrate segments (HLS/DASH) so
clients can select appropriate quality based on bandwidth.

**Example — memories go-vod:**

Custom Go binary purpose-built for video transcoding:
- Input: any video format supported by FFmpeg (which go-vod wraps)
- Output: HLS segments at multiple quality levels
- Client-side: browser's native HLS player selects quality based on bandwidth
- Fallback: if transcoding fails, serve original file (degraded — no adaptive
  streaming, may not play in all browsers)

PHP orchestration:
- Version-pinned go-vod binary
- Health check at startup (binary present + correct version)
- Request flow: PHP validates input → exec() go-vod → go-vod produces HLS
  manifest + segments → PHP serves manifest URL to client

**Tradeoffs:**
- Users get smooth playback even on slow connections
- Storage cost: multiple quality levels per video
- Transcoding is CPU/GPU intensive (batch processing overnight)
- HLS format has browser compatibility considerations (Safari native, others
  need hls.js)

**De-Factoring Evidence:**
- **If adaptive streaming were removed:** Users on slow connections buffer
  indefinitely on high-resolution videos. Users on fast connections get
  unnecessary quality reduction from a single-bitrate stream.
  **Detection signal:** "Videos buffer constantly on mobile data"; "video
  quality is always low even on fiber."

---

### 4. Expression-Evaluated Pipeline (neko)

**How it works:** Codec parameters are not hardcoded but computed from
expressions evaluated against runtime state (screen resolution, CPU load,
network bandwidth).

**Example — neko GStreamer pipeline:**

`VideoConfig.GetPipeline` uses `gval` expression evaluation:
- Width/height derived from screen dimensions: `{width}`, `{height}`
- FPS based on display refresh rate
- Bitrate computed from resolution × quality target
- Codec selected from configured priority list

`StreamSelectorType` enables quality switching mid-session without
re-negotiation — the encoder adjusts parameters while streaming.

**Tradeoffs:**
- Adapts to runtime conditions without restart
- Expressions are flexible but hard to debug
- GStreamer dependency for pipeline construction
- Realtime constraints: expression evaluation must be fast

---

## Decision Guide

**Choose Hardware-Probed Transcoding when:**
- Server-side processing with potentially capable hardware
- Multiple codec outputs needed (H.264 + H.265 + thumbnails)
- Throughput matters (batch processing many assets)

**Choose Platform-Conditional when:**
- Multi-platform application with different native capabilities
- Feature parity is acceptable to approximate
- Each platform has its own "best available" media tooling

**Choose Adaptive Streaming when:**
- Video serving to diverse bandwidth environments
- Smooth playback is more important than storage cost
- HLS/DASH infrastructure is available

**Choose Expression-Evaluated when:**
- Real-time streaming with dynamic conditions
- Codec parameters must change during operation
- GStreamer or equivalent framework is available

---

## Anti-Patterns

### 1. Universal Transcoding
Transcoding every asset to a single codec regardless of source format and
target capabilities. H.264 → H.264 transcoding wastes CPU and loses quality.
If source and target codec match, copy stream instead of re-encoding.
**Detection signal:** `ffmpeg` invocations without `-c copy`; identical
codec in source and output; CPU usage during "transcoding" of already-
compatible files.

### 2. Client-Side Codec Detection by Filename Extension
Assuming codec from file extension (.mp4 = H.264, .webm = VP9). Containers
can hold various codecs — .mp4 can contain H.265, VP9, or AV1.
**Detection signal:** "Some MP4 files don't play" — H.265 in MP4 container
on a browser without H.265 support.

### 3. Blocking Pipeline Without Queue
Processing media synchronously in the request path. A single large video
blocks all other requests. Media processing should be queued and processed
asynchronously.
**Detection signal:** "Upload appears stuck" — the server is synchronously
transcoding before responding; request timeout on large uploads.

### 4. Ignoring EXIF Orientation
Processing images without respecting EXIF orientation metadata. Thumbnails
appear rotated relative to the original.
**Detection signal:** "Thumbnails are sideways" — common with phone photos
where EXIF rotation is set but the pixel data isn't rotated.
