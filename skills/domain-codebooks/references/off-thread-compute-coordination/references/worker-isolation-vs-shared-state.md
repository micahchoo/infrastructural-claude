# Worker Isolation vs Shared State

## The Problem

Off-thread computation requires data to move between the main thread and workers. Full isolation (each worker has its own copy of everything) is safe but expensive: serialization, deserialization, and memory duplication scale with data size. Shared state (workers access the same memory) eliminates copying but introduces data races, cache coherence problems, and -- critically in long-running processes -- memory fragmentation from concurrent allocation patterns. The choice between isolation and sharing cascades into architectural decisions about caching, error recovery, and platform deployment.

## Competing Patterns

### Pattern A: Structured Clone Isolation (Safest, Slowest)

**When to use:** Small to medium payloads (<1MB). Workers process independent units with no shared context. Correctness is paramount and performance overhead is acceptable.

**When NOT to use:** Large buffers (images, audio) where clone overhead dominates. High-frequency messaging (>1000 messages/sec) where serialization becomes the bottleneck.

**How it works:** Every `postMessage` call serializes the payload via the structured clone algorithm. The worker receives a deep copy -- mutations on either side are invisible to the other. This is the default Web Worker communication model and the safest pattern.

```javascript
// Main thread
const imageData = ctx.getImageData(0, 0, width, height);
worker.postMessage({ cmd: 'process', data: imageData });
// imageData is cloned -- worker gets independent copy
// Main thread can safely continue using imageData

// Worker
self.onmessage = ({ data: { cmd, data } }) => {
  const result = processImage(data); // operates on clone
  self.postMessage({ cmd: 'result', data: result }); // result is cloned back
};
```

**Production example:** Recogito2's NLP annotation workers receive text segments via postMessage. Each segment is small (<10KB typically) and independently processable. The structured clone overhead is negligible compared to NLP computation time. Workers are fully isolated -- a crash in one worker cannot corrupt the main thread's annotation state.

**Tradeoffs:** Memory doubles for every message in flight (one copy per side). For a 50MP image (200MB raw), each postMessage allocates 200MB. High-frequency small messages pay serialization overhead per message.

### Pattern B: Transferable Zero-Copy (Fast, One-Way)

**When to use:** Large ArrayBuffers (images, audio, video frames) where cloning is prohibitively expensive. The sender can give up ownership -- it won't need the data after transfer.

**When NOT to use:** When the sender needs to retain the data after sending. When the data isn't an ArrayBuffer (DOM objects, complex objects with methods). When bidirectional access to the same buffer is needed.

**How it works:** `postMessage(data, [transfer])` moves ownership of ArrayBuffers from sender to receiver in O(1) time -- no copying. The sender's reference becomes detached (zero-length). This is a move semantic, not a share.

```javascript
// Main thread -- zero-copy transfer to worker
const buffer = new ArrayBuffer(width * height * 4);
const pixels = new Uint8Array(buffer);
// ... fill pixels ...
worker.postMessage({ cmd: 'process', buffer }, [buffer]);
// buffer.byteLength === 0 now -- ownership transferred

// Worker -- process and transfer back
self.onmessage = ({ data: { cmd, buffer } }) => {
  const pixels = new Uint8Array(buffer);
  applyFilter(pixels);
  self.postMessage({ cmd: 'result', buffer }, [buffer]);
  // buffer detached in worker, ownership returned to main
};
```

**Production example:** Penpot's WASM rendering worker receives shape geometry as transferred ArrayBuffers. The main thread builds the geometry, transfers ownership to the WASM worker for rendering, and the worker transfers the rendered pixel buffer back. No image data is ever copied -- only ownership moves. This enables real-time canvas updates for complex documents.

**Tradeoffs:** One-way ownership -- sender loses access immediately. Cannot share a buffer between main thread and worker simultaneously. Requires careful lifecycle management to avoid using detached buffers (common bug: accessing buffer after transfer throws).

### Pattern C: SharedArrayBuffer with Atomics (Fastest, Most Dangerous)

**When to use:** Extremely high-throughput requirements where even Transferable overhead is too high. Multiple threads need simultaneous read/write access to the same buffer. Real-time rendering or physics where frame budgets are <16ms.

**When NOT to use:** Most applications. Requires cross-origin isolation headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`). Not available in all browsers/contexts. Data race bugs are extremely difficult to debug.

**How it works:** A `SharedArrayBuffer` is accessible from both the main thread and workers simultaneously. `Atomics` operations (load, store, add, compareExchange, wait, notify) provide synchronization primitives. The buffer is never copied -- all threads see the same memory.

```javascript
// Main thread
const shared = new SharedArrayBuffer(width * height * 4);
const view = new Int32Array(shared);
worker.postMessage({ shared }); // shared, not transferred

// Worker -- concurrent access to same memory
self.onmessage = ({ data: { shared } }) => {
  const view = new Int32Array(shared);
  // Atomic operations for synchronization
  for (let i = 0; i < view.length; i++) {
    Atomics.store(view, i, computePixel(i));
  }
  Atomics.notify(view, 0); // signal main thread
};

// Main thread waits for completion
Atomics.wait(view, 0, 0); // blocks until notified
```

**Production example:** Allmaps uses shared canvas state between TerraDraw's computation layer and the Konva rendering layer. While not using literal SharedArrayBuffer (browser compatibility), the architectural pattern is the same: a shared coordinate/transform buffer that both the computation and rendering paths read from, with careful sequencing to avoid tearing during map transformations.

**Tradeoffs:** Requires COOP/COEP headers (breaks many third-party embeds). Data races are silent corruption, not crashes. Debugging tools for shared memory are primitive compared to single-threaded debugging. Memory model semantics vary subtly across browsers.

### Pattern D: Shared Cache with Thread-Local Copies (libvips Hybrid)

**When to use:** Long-running processes with repeated similar operations. The cache amortizes computation cost across operations while thread-local copies maintain isolation during execution.

**When NOT to use:** Short-lived processes where cache warmup doesn't pay off. Workloads with no operation repetition (every input is unique).

**How it works:** A shared operation cache (keyed by operation + parameters) stores recent results. Before computing, each thread checks the cache. Cache hits avoid recomputation. Cache misses trigger computation using a thread-local copy of the pipeline's writeable state. The cache itself is shared (with locking), but pipeline execution is lock-free because each thread operates on its own state copy.

This is libvips's architecture: a shared cache (default 50MB, 100 items) with LRU eviction sits above a lock-free execution pipeline. Each thread gets a cheap copy of the writeable pipeline state at dispatch time. The read-only parts (source image data, operation graph) are shared without locks. Only the cache and the output write-buffer require synchronization.

```
Shared:  [Operation Cache (50MB, 100 items, LRU)]  ←  lock on lookup/insert
         [Source Image Data (read-only)]            ←  no lock needed
         [Pipeline Graph (immutable)]               ←  no lock needed
         [Output Write Buffer]                      ←  lock on flush

Per-Thread: [Writeable Pipeline State (cheap copy)] ←  no lock needed
            [Tile Computation Workspace]            ←  no lock needed
```

**Production example:** Sharp's libvips backend maintains this hybrid architecture. When processing a batch of images with similar operations (e.g., thumbnail generation at the same size), the operation cache prevents redundant computation. Meanwhile, each thread's state copy means pipeline execution needs only 4 lock operations per output tile -- cache lookup, cache insert (on miss), write-buffer claim, write-buffer flush.

**Tradeoffs:** Cache sizing is critical -- too small wastes computation, too large wastes memory. Cache invalidation on parameter changes must be correct. The shared cache is a contention point under high concurrency (mitigated by the low lock count). Memory fragmentation risk from concurrent allocation of thread-local state copies (the glibc problem Sharp addresses by defaulting to concurrency=1 on glibc without jemalloc).

## Decision Guide

- **Payloads < 1MB, independent work units?** Pattern A (structured clone). Simplicity wins.
- **Large buffers, sender can give up ownership?** Pattern B (Transferable). Zero-copy with clear ownership semantics.
- **Sub-millisecond shared access, can deploy COOP/COEP?** Pattern C (SharedArrayBuffer). Only when the performance requirement is proven by measurement.
- **Long-running process, repeated operations?** Pattern D (shared cache + thread-local). Best throughput-per-watt for server-side processing.
- **Default choice when uncertain?** Pattern B. Transferable gives near-zero-copy performance with clear ownership semantics and no shared-memory hazards.

## Memory Fragmentation: The Hidden Shared-State Cost

Multi-threaded allocation creates a specific pathology with glibc's default malloc: each thread gets its own memory arena, and small allocations/deallocations across arenas fragment the heap. This manifests as:
- RSS grows monotonically even as live allocations stay constant
- OOM kills on long-running servers processing many images
- Memory usage is 2-5x higher than expected from allocation sizes

**Mitigations (ordered by invasiveness):**
1. Reduce concurrency to 1 (Sharp's glibc default) -- eliminates multi-arena fragmentation
2. Set `MALLOC_ARENA_MAX=2` -- limits arena count, trades some throughput
3. Use jemalloc or mimalloc (alternative allocators designed for threaded workloads)
4. Pre-allocate thread-local buffers and reuse them (pool pattern)

This is not a theoretical concern -- Sharp explicitly detects glibc-without-jemalloc at startup and defaults to single-threaded execution specifically because of this fragmentation behavior.

## Anti-Patterns

### Don't: Share Mutable State Without Atomics
**What happens:** Two threads write to the same buffer index without synchronization. Reads see torn values (partially written from each thread). Image output has single-pixel corruption that appears randomly and is nearly impossible to reproduce.
**Instead:** Use Atomics for shared writes, or don't share writeable state at all (Pattern D's thread-local copies).

### Don't: Transfer and Then Access
**What happens:** `postMessage(data, [buffer])` followed by `buffer[0]` throws `TypeError: Cannot perform Construct on a detached ArrayBuffer`. Common when transfer is added as an optimization to existing clone-based code without updating all access sites.
**Instead:** Treat transfer as a move. After transfer, null out the local reference. Use TypeScript's branded types or wrapper classes that track ownership state.

### Don't: Unbounded Operation Caches
**What happens:** Cache grows without eviction. In long-running image processing servers, the cache accumulates entries for every unique operation+parameter combination. Memory grows until OOM. Worse: the cache itself fragments memory as entries are inserted and evicted.
**Instead:** Bounded LRU with configurable size limits (Sharp: `sharp.cache({ memory: 50, items: 100 })`). Monitor cache hit rates -- a cache with <10% hit rate is just wasting memory.

### Don't: One Worker Per Request
**What happens:** Spawning a new worker for each operation pays startup cost (parsing, JIT warmup) every time. Under load, hundreds of workers compete for CPU and memory. Each worker's memory is isolated, so no cache sharing.
**Instead:** Pool with recycling (Pattern D). libvips 8.14 introduced thread recycling: rather than killing and recreating threads, it maintains a set and recycles them between threadpools. Worker pools (piscina, workerpool) provide the same pattern for Web Workers.
