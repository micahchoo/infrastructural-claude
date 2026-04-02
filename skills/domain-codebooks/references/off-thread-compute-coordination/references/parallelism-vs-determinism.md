# Parallelism vs Determinism

## The Problem

When computation is parallelized across threads, the order in which results complete is nondeterministic. For image processing, canvas rendering, and tile-based systems, this means identical inputs can produce different outputs depending on thread scheduling -- pixel values may differ, tiles may be assembled in wrong order, or rendering artifacts appear intermittently. Users expect deterministic results: the same image processed twice must produce identical bytes. Debugging nondeterministic output is extremely difficult because failures are intermittent and environment-dependent.

## Competing Patterns

### Pattern A: Write-Buffer Assembly (libvips/Sharp)

**When to use:** Tile-based or scanline-based processing where output is a contiguous image/buffer. High parallelism needed but output must be byte-identical across runs.

**When NOT to use:** Streaming output where results are consumed incrementally (no final assembly step). Very small images where threading overhead exceeds compute cost.

**How it works:** Threads compute tiles independently and write results into a shared output buffer indexed by tile position. A separate background thread monitors each buffer region and, once all tiles in a scanline group are complete, flushes that group to disk/output. The key insight is that threads never coordinate with each other -- they only write to their assigned buffer slot. Ordering is enforced by the assembly step, not by thread scheduling.

In libvips, each thread runs a cheap copy of the pipeline's writeable state. The pipeline itself is immutable once constructed. This means threads execute with only 4 lock operations per output tile, regardless of pipeline length or complexity. The write-buffer thread waits for the last tile in each buffer to complete before writing that set of scanlines.

```
Thread 1: compute tile[0,0] → write to buffer[0,0]
Thread 2: compute tile[0,1] → write to buffer[0,1]
Thread 3: compute tile[1,0] → write to buffer[1,0]
Thread 1: compute tile[0,2] → write to buffer[0,2]
          ↓
Write thread: buffer row 0 complete → flush scanlines 0-63 to output
```

**Production example:** Sharp/libvips processes images with N threads (default = CPU cores) but produces byte-identical output regardless of N. The write buffer ensures deterministic scanline ordering. When concurrency is reduced to 1 (glibc fragmentation mitigation), output remains identical -- only throughput changes.

**Tradeoffs:** Requires output buffer sized to hold complete tile groups in memory. Not suitable for unbounded streaming. The assembly thread adds a small latency between last-tile-completion and flush.

### Pattern B: Sequence-Numbered Message Assembly (Web Workers)

**When to use:** Web Worker architectures where computation is distributed across workers via postMessage, and results must be reassembled in input order on the main thread.

**When NOT to use:** When workers process independent items with no ordering requirement. When SharedArrayBuffer is available and write-buffer pattern is feasible.

**How it works:** Each work unit sent to a worker carries a monotonic sequence number. Workers process units and return results tagged with their sequence number. The main thread maintains a reassembly buffer that emits results in sequence order, holding back any result whose predecessor hasn't arrived yet.

```javascript
// Dispatcher
let seq = 0;
function dispatch(worker, data) {
  worker.postMessage({ seq: seq++, payload: data });
}

// Reassembly on main thread
const pending = new Map();
let nextExpected = 0;
function onWorkerResult({ seq, result }) {
  pending.set(seq, result);
  while (pending.has(nextExpected)) {
    emit(pending.get(nextExpected));
    pending.delete(nextExpected);
    nextExpected++;
  }
}
```

**Production example:** Penpot's WASM rendering worker processes shape batches off the main thread. Results must be composited in layer order (z-index), not completion order. The main thread reassembles render fragments by their layer sequence before compositing to the final canvas.

**Tradeoffs:** Reassembly buffer can grow large if one worker is slow (head-of-line blocking). Sequence numbers add overhead to every message. Not zero-copy -- structured clone or Transferable required.

### Pattern C: Deterministic Scheduling (Static Partitioning)

**When to use:** When the work can be statically divided into equal partitions at dispatch time, and no dynamic load balancing is needed. Common in painting/drawing engines where tile grids are fixed.

**When NOT to use:** Variable-cost work units where some tiles are much more expensive than others (e.g., tiles with complex effects vs empty tiles). Dynamic scenes where the tile grid changes between frames.

**How it works:** The work is divided into N fixed partitions (one per thread) at dispatch time. Each thread processes its partition sequentially. Because partitions don't overlap and each thread's work order is predetermined, the output is deterministic by construction -- no reassembly step needed.

```
Tile grid 4x4, 4 threads:
Thread 0: tiles [0,0] [0,1] [0,2] [0,3]  (row 0)
Thread 1: tiles [1,0] [1,1] [1,2] [1,3]  (row 1)
Thread 2: tiles [2,0] [2,1] [2,2] [2,3]  (row 2)
Thread 3: tiles [3,0] [3,1] [3,2] [3,3]  (row 3)
```

**Production example:** Krita's tile engine assigns fixed tile regions to threads for paint stroke rendering. Each thread owns its tile range and processes sequentially within that range. Cross-tile effects (blur, smudge) require synchronization barriers between passes but within a pass, determinism is structural.

**Tradeoffs:** Poor load balancing when tile costs vary. Thread count changes require repartitioning. Synchronization barriers for cross-partition effects add complexity and latency.

### Pattern D: Sequential Fallback with Parallel Fast Path

**When to use:** When determinism is critical but most operations are cheap enough for single-thread execution. Parallel path activates only for expensive operations where the speedup justifies the complexity.

**When NOT to use:** When all operations are expensive (always needs parallelism) or when determinism is not required (just use full parallelism).

**How it works:** A cost estimator evaluates each operation before dispatch. Cheap operations run sequentially on the main/calling thread. Expensive operations (above a threshold) are dispatched to the parallel pipeline with deterministic assembly. The cost threshold is tunable -- Sharp's `concurrency(1)` is the extreme case of always-sequential.

**Production example:** Sharp on glibc-based Linux without jemalloc defaults to `concurrency(1)` -- sequential execution that avoids memory fragmentation at the cost of throughput. With jemalloc, it defaults to `concurrency(cores)` -- parallel execution with write-buffer assembly. The decision is made once at startup based on platform detection, not per-operation.

**Tradeoffs:** Cost estimation is imperfect -- may misroute operations. Two code paths (sequential + parallel) increase maintenance burden. Platform detection at startup may not account for runtime conditions.

## Decision Guide

- **Need byte-identical output from multi-threaded processing?** Use Pattern A (write-buffer) for buffer-based output, Pattern B (sequence-numbered) for message-based output.
- **Fixed tile grid with uniform cost?** Pattern C (static partitioning) is simplest and has lowest overhead.
- **Variable cost with most operations cheap?** Pattern D (sequential fallback) avoids parallel overhead for the common case.
- **Web Workers without SharedArrayBuffer?** Pattern B is your only option for deterministic reassembly.
- **Native code with shared memory?** Pattern A gives best throughput with minimal synchronization.

## Anti-Patterns

### Don't: Rely on Worker Completion Order
**What happens:** Results from `Promise.all([worker1.process(), worker2.process()])` arrive in completion order, not dispatch order. Images processed on a 4-core machine produce different pixel arrangements than on an 8-core machine. Tests pass locally, fail in CI.
**Instead:** Always tag results with position/sequence and reassemble explicitly (Patterns A or B).

### Don't: Lock Per-Pixel or Per-Tile-Pair
**What happens:** Fine-grained locking (mutex per tile, per scanline, or per pixel) serializes execution under contention. With N threads and N locks, throughput degrades to worse than single-threaded due to lock overhead and cache-line bouncing.
**Instead:** Copy writeable state per-thread and use coarse-grained assembly (Pattern A). Libvips achieves 4 locks per tile regardless of pipeline depth by copying writeable state, not by locking shared state.

### Don't: Hardcode Thread Count
**What happens:** `const THREADS = 8` works on a developer's machine but OOMs on a 2-core CI container, wastes resources on a 64-core server, and causes memory fragmentation on glibc systems. Docker CPU limits (--cpus=2) are invisible to `os.cpus().length`.
**Instead:** Probe at startup: CPU cores (respecting cgroup limits), allocator type, available memory. Default conservatively and allow runtime override.
