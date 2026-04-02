---
name: media-pipeline-adaptation
description: >-
  Force tension: quality fidelity vs processing latency vs resource budget
  across heterogeneous hardware and format landscapes. Every media system must
  transform assets (transcode, thumbnail, decode) to serve users quickly.
  This codebook addresses the transformation pipeline itself: how media enters,
  what processing stages it passes through, how the system adapts to available
  hardware, and how failures are handled.

  Triggers: "thumbnail generation pipeline", "video transcoding hardware
  acceleration", "codec negotiation browser compatibility", "progressive
  resolution delivery", "WASM vs native binary selection", "FFmpeg pipeline
  construction", "HDR tone-mapping color space conversion", "ML inference
  pipeline for media", "hardware capability probing", "format diversity
  handling HEIC RAW AVIF", "multi-tier resolution ladder", "GStreamer
  dynamic pipeline parameters", "ML model loading caching TTL eviction",
  "ONNX runtime GPU provider selection fallback", "inference batching
  dependency ordering", "media processing job queue DAG", "background job
  concurrency throttling", "job queue pause resume progress tracking",
  "multi-stage asset processing pipeline orchestration".

  Brownfield triggers: "need multi-size thumbnails from uploaded originals",
  "Safari supports HEVC but not VP9 codec negotiation across browsers",
  "pipeline ingests HEIC WebP AVIF TIFF RAW needs unified handling",
  "video annotation needs frame-accurate seeking browser element insufficient",
  "WebGL shader pipeline decode upload apply readback is slow",
  "transcode to adaptive bitrate HLS DASH multiple quality tiers",
  "200+ megapixel images need tiling and progressive deep zoom",
  "audio processing needs waveform spectrogram from long recordings",
  "live camera input simultaneous preview recording and analysis",
  "asset manager needs previews for images videos PDFs 3D models audio",
  "hardware acceleration silently falls back to software",
  "FFmpeg works locally but fails in Docker",
  "ML model loading spikes memory then idles for hours",
  "face detection works on NVIDIA but crashes on Intel",
  "background jobs process assets in wrong order thumbnails missing",
  "library scan makes server unresponsive need throttling",
  "job queue loses progress on restart",
  "no way to tell if ML indexing is complete".

  Symptom triggers: "thumbnail generation pipeline adapts to mobile GPU vs
  server libvips vs browser OffscreenCanvas", "Safari supports HEVC Chrome
  supports VP9 AV1 need codec negotiation and conditional transcoding",
  "various image formats HEIC WebP AVIF TIFF RAW each need different decode
  paths with fallback chains", "video seeking is imprecise need frame-accurate
  decode fallback", "WebGL shader readback step blocks UI on large 50MP images",
  "client-side vs server-side transcoding decision based on input complexity",
  "deep zoom tiling at ingest time with viewer requesting tiles at zoom level",
  "Web Audio API AudioWorklet progressively decode large audio files without
  loading everything into memory", "live camera input simultaneous display
  recording and ML analysis pipeline", "asset manager needs previews for mixed
  media types images videos PDFs 3D models audio".

cross_codebook_triggers:
  - "progressive resolution tiers feed virtualization — thumbnail grid needs low-res fast, detail view needs full-res on demand (+ virtualization-vs-interaction-fidelity)"
---

# Media Pipeline Adaptation

## Force Tension

**Quality fidelity** vs **processing latency** vs **resource budget** across heterogeneous hardware and format landscapes.

Every media system must transform assets (transcode, thumbnail, decode) to serve users quickly. Higher quality demands more compute and time (fidelity vs latency). Hardware acceleration reduces latency but varies wildly across deployments (latency vs resource budget). Supporting diverse input formats (HEIC, RAW, HDR video, legacy codecs) multiplies the transformation matrix. Optimizing any axis — quality, speed, or resource cost — degrades the other two, and the optimal balance shifts per-device, per-deployment, and per-asset.

This codebook addresses the **transformation pipeline itself**: how media enters, what processing stages it passes through, how the system adapts to available hardware, and how failures are handled. It also covers **ML inference lifecycle** (model loading, caching, GPU memory management, multi-runtime abstraction) and **async job orchestration** (processing DAGs, queue management, concurrency control) as they manifest specifically in media pipelines. It does NOT address media playback UI, storage backends, or content delivery networks.

---

## Triggers

Activate this codebook when the task involves:

- Thumbnail generation pipelines (single-tier or multi-tier)
- Video transcoding with hardware acceleration (VA-API, NVENC, QSV, VideoToolbox, Mali OpenCL)
- Codec negotiation — choosing output format based on client capabilities or hardware
- Progressive resolution delivery (thumbnail → preview → full-size)
- WASM vs native binary selection for media processing
- External binary orchestration (FFmpeg, ImageMagick, exiftool, go-vod as subprocess)
- HDR-aware media transformation (tone-mapping, color space conversion)
- GStreamer or FFmpeg pipeline construction with dynamic parameters
- ML inference pipelines for media (face detection, CLIP embeddings, object recognition, OCR)
- ML model lifecycle — loading, caching with TTL, GPU memory management, multi-runtime abstraction
- Hardware capability probing at bootstrap
- Format diversity handling (HEIC, RAW, AVIF, WebP, legacy video codecs)
- Media processing job orchestration — DAG ordering, per-queue concurrency, failure recovery
- Background job lifecycle — queue pause/resume, progress tracking, time-bounded execution

### Brownfield Triggers

Phrases that signal existing systems hitting media pipeline walls:

- "Thumbnails take forever on large libraries"
- "Transcoding works on my machine but not in production"
- "Hardware acceleration silently falls back to software"
- "HEIC/RAW/HDR files produce broken thumbnails"
- "Video processing OOMs on large files"
- "Can't tell if VA-API/NVENC is actually being used"
- "FFmpeg command works locally but fails in Docker"
- "Thumbnail quality is inconsistent across formats"
- "Mobile uploads stall during processing"
- "External binary version mismatch breaks the pipeline"
- "WASM FFmpeg is too slow for video but we need browser processing"
- "ML model loading spikes memory then idles"
- "Background processing jobs run in wrong order"
- "No way to tell if ML indexing finished"
- "Server unresponsive during library scan"
- "Job queue loses progress on restart"

---

## Skip

Do NOT use this codebook for:

- **Media playback UI** — seeking, buffering indicators, adaptive bitrate streaming players. Those are client-side concerns, not pipeline architecture.
- **Content delivery / CDN** — edge caching, signed URLs, bandwidth optimization. Different problem domain.
- **Storage backend selection** — S3 vs local filesystem vs object store. Orthogonal to transformation.
- **General image manipulation** — cropping, filters, drawing. Those are editing operations, not pipeline transformations.
- **Audio-only processing** — podcast transcription, music analysis. This codebook focuses on visual media pipelines.
- **DRM / encryption at rest** — use encryption-specific guidance. This codebook assumes cleartext input to the pipeline (though see cross-ref to platform-adaptation for decrypt-then-process flows).

---

## Cross-References

| Codebook | Relationship |
|---|---|
| `virtualization-vs-interaction-fidelity` | Progressive resolution tiers feed virtualization — thumbnail grid needs low-res fast, detail view needs full-res on demand. Pipeline tier design directly shapes what the virtualizer can offer. |
| `platform-adaptation-under-code-unity` | Native binary orchestration (FFmpeg, go-vod, ImageMagick) is a special case of platform adaptation. WASM-vs-native selection is the same force as NativeX bridge design. |
| `spec-conformance-under-creative-editing` | Media format specs (EXIF, ICC profiles, HDR metadata) must survive transformation round-trips. Thumbnail generation that strips metadata violates spec conformance. |

---

## Evidence Base

Patterns in this codebook are grounded in analysis of:

| Source | Pipeline Type | Key Observations |
|---|---|---|
| Immich | Server-side TS/Python microservices | 3-tier thumbnails (preview/thumbnail/fullsize), hardware probing at bootstrap (VA-API, Mali OpenCL), separate image vs video codec paths, ML inference microservice with ModelCache + TTL eviction, multi-runtime inference (ONNX/ARMNN/RKNN) with provider fallback chain, BullMQ job DAG (upload → metadata → thumbnails → ML fan-out), per-queue concurrency, dependency-aware inference batching |
| Ente | Client-side encrypted photos | Decrypt→transform flow, WASM FFmpeg (web) vs native FFmpeg (desktop), HDR-aware thumbnail commands, Web Worker isolation for crypto+transform |
| Memories | Nextcloud PHP + Go subprocess | External binary orchestration (exiftool, go-vod, ImageMagick), strict version pinning, dual execution modes (bundled vs system), NativeX localhost HTTP bridge for mobile, time-bounded cron indexing (300s max per run), DB-based progress tracking, ML delegation via ClustersBackend registry (FaceRecognition, Recognize, Tags backends) |
| Neko | Go/GStreamer realtime capture | GStreamer pipeline with `gval` expression-evaluated parameters, dynamic resolution/fps, StreamSelector for quality tiers, BroadcastManager for RTMP alongside WebRTC |

---

## Reference Documents

- `get_docs("domain-codebooks", "media-pipeline progressive thumbnail")` — Multi-tier thumbnail generation, resolution ladder design, pipeline stage composition, failure recovery
- `get_docs("domain-codebooks", "media-pipeline codec negotiation")` — Hardware probing, codec selection logic, WASM-vs-native decision gates, format fallback chains
- `get_docs("domain-codebooks", "media-pipeline ML inference")` — ML model loading/caching with TTL, multi-runtime abstraction (ONNX/ARMNN/RKNN), GPU provider selection, dependency-aware inference batching
- `get_docs("domain-codebooks", "media-pipeline async job orchestration")` — Media processing job DAGs, BullMQ queue management, time-bounded cron indexing, per-queue concurrency, failure recovery
