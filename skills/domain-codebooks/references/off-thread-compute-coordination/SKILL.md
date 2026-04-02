---
name: off-thread-compute-coordination
description: >-
  Force tension: main-thread responsiveness vs compute correctness vs
  message-passing overhead. Systems that offload heavy computation to worker
  threads, Web Workers, or background processes must navigate three competing
  forces: parallelism (throughput) vs determinism (reproducible ordering),
  worker isolation (safety, no shared memory corruption) vs shared state
  (lower latency, less serialization), and eager offloading (always off-thread)
  vs lazy/demand-driven offloading (only when needed).

  Triggers: "worker thread", "Web Worker", "OffscreenCanvas", "SharedArrayBuffer",
  "postMessage overhead", "thread pool sizing", "background computation",
  "parallel image processing", "off-thread rendering", "worker isolation",
  "message serialization cost", "Transferable objects", "structured clone",
  "libuv thread pool", "glib thread pool", "tile-based parallel processing",
  "compute pipeline", "worker pool management", "concurrency limit".

  Diffused triggers: "UI freezes during heavy computation", "main thread blocked
  by processing", "worker communication is slow", "results come back in wrong
  order", "nondeterministic output from parallel pipeline", "memory usage spikes
  with workers", "thread count vs memory tradeoff", "when should I use a worker",
  "shared state between workers causes bugs", "operation cache shared across
  threads", "how many threads for image processing", "worker startup overhead",
  "message passing bottleneck".

  Libraries: sharp/libvips, penpot WASM workers, Krita's tile engine,
  Konva/canvas worker offload, Web Workers API, node:worker_threads,
  SharedArrayBuffer, Comlink, workerpool, piscina, OffscreenCanvas.

  Skip: general async/await patterns (not worker-based), Promise.all without
  workers, server-side job queues (use media-pipeline-adaptation), distributed
  computing across machines (not threads), GPU shader programming (use
  rendering-backend-heterogeneity), network request parallelism.

cross_codebook_triggers:
  - "off-thread rendering feeds renderer heterogeneity when workers use different backends (+ rendering-backend-heterogeneity)"
  - "worker compute results must reconcile with reactive state layer (+ state-to-render-bridge)"
  - "media pipeline stages run in workers with concurrency limits (+ media-pipeline-adaptation)"
  - "parallel tile processing under node graph evaluation (+ node-graph-evaluation-under-interactive-editing)"
---

# Off-Thread Compute Coordination

## Force Cluster

Three competing forces that produce spaghetti when unresolved:

1. **Parallelism vs Determinism** -- More threads = faster throughput, but parallel execution introduces ordering variance. Tile-based systems, image pipelines, and canvas renderers must guarantee that identical inputs produce identical outputs regardless of thread scheduling. The tension: you want N threads for speed but need results assembled as if computed sequentially.

2. **Worker Isolation vs Shared State** -- Isolated workers (separate memory, no shared mutation) are safe but pay serialization costs on every message. Shared memory (SharedArrayBuffer, shared caches) eliminates serialization but introduces data races, cache coherence problems, and memory fragmentation under concurrent allocation. The tension: you want zero-copy for speed but need isolation for correctness.

3. **Eager vs Lazy Offloading** -- Always offloading to workers adds startup overhead and message-passing latency for cheap operations. Never offloading blocks the main thread on expensive operations. The tension: you need a decision gate that routes work based on cost estimation, but cost is often unpredictable until execution begins.

## Triggers

Activate this codebook when the task involves:

- Worker thread architecture for CPU-intensive computation (image processing, rendering, physics)
- Thread pool sizing decisions (how many workers, dynamic vs static pools)
- Message passing overhead between main thread and workers
- Deterministic output from parallel pipelines (tile ordering, pixel-identical results)
- Shared memory vs message passing tradeoffs (SharedArrayBuffer vs postMessage)
- Worker lifecycle management (startup cost, recycling, warm pools)
- Operation caching across threads (shared result cache, invalidation)
- Demand-driven vs eager computation scheduling
- Memory fragmentation from multi-threaded allocation patterns
- OffscreenCanvas or WASM worker rendering pipelines

### Brownfield Triggers

- "Image processing blocks the UI for large files"
- "Worker results arrive out of order"
- "Memory grows unbounded with multiple workers"
- "Thread pool size doesn't match available cores in production"
- "Serializing large data to workers is slow"
- "Workers are idle most of the time but consume memory"
- "Results differ between single-threaded and multi-threaded runs"
- "SharedArrayBuffer requires cross-origin isolation headers"
- "Worker startup time adds latency to first operation"
- "glibc memory fragmentation in multi-threaded image processing"

## Classify

1. **Compute domain** -- image processing, rendering, physics, data transformation, or mixed?
2. **Threading model** -- Web Workers, node:worker_threads, native thread pool (glib/libuv), or WASM threads?
3. **Data transfer pattern** -- small messages, large buffers (Transferable), shared memory (SAB), or mixed?
4. **Determinism requirement** -- pixel-identical output required, ordering-only, or best-effort?
5. **Offloading granularity** -- per-operation, per-tile, per-frame, or per-pipeline?
6. **Pool lifecycle** -- static pool (fixed at startup), dynamic (resize on load), or ephemeral (spawn per task)?

## Reference Documents

Load as needed:

| Axis | File | Summary |
|------|------|---------|
| Parallelism vs Determinism | `references/parallelism-vs-determinism.md` | Tile-ordered assembly, write-buffer synchronization, lock-free pipeline copies, sequential fallback strategies |
| Worker Isolation vs Shared State | `references/worker-isolation-vs-shared-state.md` | Message-passing patterns, shared cache architectures, memory fragmentation mitigation, Transferable vs structured clone |

## Cross-Codebook Interactions

| With | Interaction |
|------|------------|
| rendering-backend-heterogeneity | Off-thread rendering may use different backends (OffscreenCanvas WebGL vs main-thread Canvas2D); worker capability detection mirrors renderer fallback |
| state-to-render-bridge | Worker compute results must be reconciled with reactive state; bridge must handle async worker responses without tearing |
| media-pipeline-adaptation | Media transcoding/thumbnail stages run in thread pools with concurrency limits; pipeline stage composition shares the eager-vs-lazy tension |
| node-graph-evaluation-under-interactive-editing | Node graph tile evaluation parallelizes across workers; dirty propagation must respect deterministic evaluation order |
| platform-adaptation-under-code-unity | Thread pool defaults and memory allocator behavior vary by platform (glibc vs jemalloc, libuv pool size, WASM thread support) |

## Principles

1. **Deterministic assembly over parallel emission.** Threads may compute in any order, but output must be assembled in a deterministic sequence. Use write-buffer or tile-index strategies, never rely on completion order.
2. **Copy the writeable state, share the read-only data.** Each thread gets a cheap copy of mutable pipeline state; immutable source data is shared without locks. This is the libvips insight that enables 4-lock-per-tile execution regardless of pipeline depth.
3. **Platform-adaptive concurrency defaults.** Never hardcode thread counts. Probe CPU cores, memory allocator characteristics (glibc fragmentation risk), and deployment context (container CPU limits, WASM thread availability) at startup.
4. **Demand-driven over eager offloading.** Compute pixels/tiles only when requested (pull model). Eager pre-computation wastes resources on work that may never be displayed. Exception: when latency requirements demand pre-warming.
5. **Pool recycling over pool creation.** Thread/worker startup is expensive. Recycle threads between tasks (libvips 8.14 pattern). Dynamic pool sizing responds to load without the cost of repeated creation/destruction.
6. **Serialization cost gates the offloading decision.** If serializing data to a worker costs more than computing inline, don't offload. Measure transfer overhead and use it as the decision gate for eager-vs-lazy routing.
7. **Shared caches need bounded eviction.** Operation caches shared across threads (Sharp's 50MB/100-item libvips cache) prevent redundant computation but must have size bounds and LRU eviction to prevent memory bloat under diverse workloads.

## Evidence Base

| Repo | Domain | Key Evidence |
|------|--------|-------------|
| penpot | Canvas editor (Clojure/WASM) | WASM worker for rendering, async hit-testing during pointer events, worker isolation from main UI thread |
| krita | Digital painting (C++/Qt) | Tile-based parallel rendering engine, OpenGL vs software compositor threading, lock management in paint operations |
| allmaps | Map georeferencing (TypeScript) | Konva canvas worker offloading, TerraDraw computation coordination with ShareDB state |
| recogito2 | Text annotation (Scala/JS) | Background NLP processing workers, annotation computation offloaded from UI thread |
| sharp/libvips | Image processing (C/Node.js) | Two-layer threading (libuv + glib pools), lock-free pipeline via writeable-state copies, tile-ordered deterministic output via write buffers, platform-adaptive concurrency (glibc=1, jemalloc=cores), demand-driven pixel computation, shared operation cache with bounded eviction |

## Skip

Do NOT use this codebook for:
- Server-side job queues / task orchestration (use media-pipeline-adaptation or async-job-graph patterns)
- GPU shader parallelism / compute shaders (use rendering-backend-heterogeneity)
- Distributed computing across network nodes
- Simple async/await or Promise.all patterns without workers
- Database connection pooling
- Network request parallelism / HTTP2 multiplexing
