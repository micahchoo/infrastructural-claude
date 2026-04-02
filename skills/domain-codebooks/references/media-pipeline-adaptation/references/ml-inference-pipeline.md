# ML Inference Pipeline

## The Problem

Media applications increasingly embed ML inference — face detection, CLIP
embeddings, OCR, object recognition — as pipeline stages alongside traditional
transcoding and thumbnailing. ML models are expensive: loading a model into
GPU/CPU memory takes seconds, inference consumes significant compute, and
multiple models must coexist without exhausting memory. The system must balance
**model availability** (loaded and ready) against **resource budget** (GPU VRAM,
system RAM), while adapting to heterogeneous inference hardware (CUDA, OpenVINO,
RKNN, ARM NN, CoreML, CPU fallback).

Without deliberate lifecycle management, models either stay loaded forever
(wasting memory during idle periods) or reload on every request (adding seconds
of latency per inference). Without hardware abstraction, the inference layer
is tightly coupled to a single accelerator, breaking on deployment changes.

---

## Competing Patterns

### 1. TTL-Cached Model with Lazy Loading (Immich)

**How it works:** Models are loaded on first request and cached in memory with
a configurable TTL. The cache revalidates (resets TTL) on each access, so
active models stay loaded while idle models are evicted.

**Example — Immich ML microservice:**

Key architecture:
- `ModelCache` wraps `aiocache.SimpleMemoryCache` with TTL and `OptimisticLock`
- `InferenceModel.load()` is lazy — called on first `predict()`, tracks
  `load_attempts` for retry logic
- `InferenceModel.download()` pulls from HuggingFace Hub (`snapshot_download`)
  if not locally cached
- `model_ttl` (default 300s) controls eviction; `model_ttl_poll_s` (10s) polls
  for idle shutdown

Key evidence:
- `ModelCache.get()` — acquires `OptimisticLock`, instantiates model on miss,
  calls `revalidate()` (TTL reset) on hit
- `main.py` lifespan — on shutdown, iterates `model_cache.cache._cache.values()`
  and deletes all models, then calls `gc.collect()`
- `idle_shutdown_task()` — background coroutine checks `last_called` timestamp;
  if no requests for `model_ttl` seconds, sends `SIGINT` to self-terminate
  the ML worker process entirely
- `load()` function — catches `OSError`, `InvalidProtobuf`, `BadZipFile`;
  clears cache and retries once on corruption

```python
# Immich: ModelCache with TTL revalidation
class ModelCache:
    def __init__(self, revalidate: bool = False, timeout: int | None = None):
        self.cache = SimpleMemoryCache(timeout=timeout)
        self.should_revalidate = revalidate

    async def get(self, model_name, model_type, model_task, **kwargs):
        key = f"{model_name}{model_type}{model_task}"
        async with OptimisticLock(self.cache, key) as lock:
            model = await self.cache.get(key)
            if model is None:
                model = from_model_type(model_name, model_type, model_task, **kwargs)
                await lock.cas(model, ttl=kwargs.get("ttl", None))
            elif self.should_revalidate:
                await self.revalidate(key, kwargs.get("ttl", None))
        return model
```

**Tradeoffs:**
- Active models stay loaded — no per-request load penalty
- Idle models automatically evicted — memory reclaimed after TTL
- TTL tuning is deployment-specific: too short = frequent reloads; too long =
  wasted memory during idle periods
- Process-level idle shutdown is aggressive — entire ML worker restarts cold
  after inactivity, adding first-request latency

**De-Factoring Evidence:**
- **If the TTL cache were removed (always-loaded):** Every model stays in memory
  permanently. With 4+ models (CLIP textual, CLIP visual, face detection, face
  recognition, OCR detection, OCR recognition), GPU memory is exhausted on
  modest hardware.
  **Detection signal:** OOM kills on the ML worker; `nvidia-smi` shows all VRAM
  consumed even with no active requests.

- **If lazy loading were removed (eager-only):** Startup time balloons as every
  configured model downloads and loads. Users see a long "starting up" phase,
  and models they never use still consume memory.
  **Detection signal:** "ML service takes 5 minutes to start"; configured models
  for unused features (OCR, face recognition) consume resources.

---

### 2. Delegated ML via External App (Memories/Nextcloud)

**How it works:** The media application does not run ML inference itself.
Instead, it delegates to separate Nextcloud apps (`facerecognition`, `recognize`)
that handle model lifecycle independently. The media app queries results via
database joins.

**Example — Memories:**

Key architecture:
- `ClustersBackend\Manager` — static registry of cluster backends
  (`FaceRecognitionBackend`, `RecognizeBackend`, `TagsBackend`, etc.)
- Each backend wraps a separate Nextcloud app that owns its ML models
- `FaceRecognitionBackend.isEnabled()` checks if `facerecognition` app is
  installed AND enabled — graceful degradation if ML apps are absent
- `RecognizeBackend` — wraps Nextcloud `recognize` app for image classification
- Results are read via SQL joins against the ML app's tables, not via API calls

```php
// Memories: Manager registers available ML backends
class Manager {
    public static array $backends = [];

    public static function get(string $name): Backend {
        if ($className = self::$backends[$name] ?? null) {
            return \OC::$server->get($className);
        }
        throw new \Exception("Invalid clusters backend '{$name}'");
    }

    public static function register(string $name, string $className): void {
        self::$backends[$name] = $className;
    }
}
```

**Tradeoffs:**
- Zero ML infrastructure burden on the media app — model lifecycle is someone
  else's problem
- Graceful degradation — if ML apps aren't installed, features simply disable
- No control over inference scheduling, batching, or hardware selection
- Coupled to external app's database schema and versioning
- Cannot customize model parameters (min score, model variant) per-request

**De-Factoring Evidence:**
- **If Memories ran its own ML:** Would need to ship Python/ONNX dependencies
  inside a PHP Nextcloud app — enormous packaging burden, version conflicts
  with host system libraries, and duplicate ML infrastructure if `recognize`
  is also installed.
  **Detection signal:** Plugin size balloons from ~5MB to 500MB+; conflicts
  with system Python packages.

- **If the backend registry were removed:** Each feature (faces, places, tags)
  would need hardcoded checks for specific apps, with no way to add new ML
  backends without modifying core code.
  **Detection signal:** Every new clustering feature requires changes to
  multiple controllers and views.

---

### 3. Multi-Runtime Session Abstraction (Immich)

**How it works:** A unified `InferenceModel` base class abstracts over multiple
inference runtimes. Model format is auto-detected based on hardware availability,
with a fallback chain from specialized to general runtimes.

**Example — Immich:**

Key architecture:
- `InferenceModel._make_session()` — dispatches on file extension:
  `.armnn` → `AnnSession`, `.onnx` → `OrtSession`, `.rknn` → `RknnSession`
- `_model_format_default` property — auto-selects format:
  RKNN if available → ARMNN if available and enabled → ONNX (universal fallback)
- `OrtSession` — wraps ONNX Runtime with provider chain:
  CUDA → ROCm (MIGraphX) → OpenVINO → CoreML → CPU
- `RknnPoolExecutor` — thread-pool of RKNN Lite instances for Rockchip NPU,
  round-robin dispatching across NPU cores

```python
# Immich: Runtime format auto-selection with fallback
@property
def _model_format_default(self) -> ModelFormat:
    if rknn.is_available:
        return ModelFormat.RKNN
    elif ann.loader.is_available and settings.ann:
        return ModelFormat.ARMNN
    else:
        return ModelFormat.ONNX

# ORT provider chain with per-provider options
@property
def _provider_options_default(self) -> list[dict[str, Any]]:
    provider_options = []
    for provider in self.providers:
        match provider:
            case "CUDAExecutionProvider":
                options = {"arena_extend_strategy": "kSameAsRequested",
                           "device_id": settings.device_id}
            case "OpenVINOExecutionProvider":
                gpu_devices = [d for d in device_ids if d.startswith("GPU")]
                device_type = f"GPU.{settings.device_id}" if gpu_devices else "CPU"
                options = {"device_type": device_type,
                           "precision": settings.openvino_precision.value}
            case "CoreMLExecutionProvider":
                options = {"ModelFormat": "MLProgram",
                           "MLComputeUnits": "ALL"}
            # ...
```

**Tradeoffs:**
- Single model file set works across NVIDIA, Intel, AMD, ARM, Rockchip, Apple
- Format-specific optimizations are preserved (FP16 on RKNN, MLProgram on CoreML)
- Complexity: every model must be exported to all supported formats
- Fallback from specialized to ONNX adds "silent degradation" — user may not
  know inference is running on CPU instead of NPU
- Thread configuration differs per runtime: GPU providers bottleneck with
  high `inter_op_threads`, CPU providers need them

**De-Factoring Evidence:**
- **If runtime abstraction were removed (ONNX-only):** Users with Rockchip
  boards (common in home server setups) get CPU-only inference when an NPU
  is available. ARM NN users lose 2-3x performance advantage.
  **Detection signal:** "ML is slow on my RK3588" — NPU sits idle while CPU
  struggles with inference.

- **If provider fallback were removed:** Application crashes on systems without
  CUDA when CUDAExecutionProvider is configured. Every deployment would need
  manual provider configuration.
  **Detection signal:** "ML service won't start" on non-NVIDIA hardware.

---

### 4. Dependency-Aware Inference Batching (Immich)

**How it works:** Multiple ML models are invoked per asset, some with
dependencies on others' outputs. Independent models run concurrently; dependent
models wait for prerequisites.

**Example — Immich:**

Key architecture:
- `get_entries()` parses the request into `(without_deps, with_deps)` tuples
- `run_inference()` — first `asyncio.gather` for independent models, then
  second `asyncio.gather` for dependent models
- `InferenceModel.depends` class variable declares output dependencies
  (e.g., face recognition depends on face detection output)
- Thread pool (`ThreadPoolExecutor`) offloads blocking inference from async loop

```python
# Immich: Two-phase inference with dependency resolution
async def run_inference(payload, entries):
    outputs: dict[ModelIdentity, Any] = {}
    response: InferenceResponse = {}

    async def _run_inference(entry):
        model = await model_cache.get(entry["name"], entry["type"], entry["task"],
                                       ttl=settings.model_ttl, **entry["options"])
        inputs = [payload]
        for dep in model.depends:
            inputs.append(outputs[dep])  # raises if dep not yet computed
        model = await load(model)
        output = await run(model.predict, *inputs, **entry["options"])
        outputs[model.identity] = output
        response[entry["task"]] = output

    without_deps, with_deps = entries
    await asyncio.gather(*[_run_inference(e) for e in without_deps])
    if with_deps:
        await asyncio.gather(*[_run_inference(e) for e in with_deps])
```

**Tradeoffs:**
- Independent models (CLIP + face detection + OCR) run concurrently — faster
  than sequential
- Two-phase is simple but inflexible — only supports depth-1 dependency graphs
- Thread pool size (`request_threads`, default = CPU count) limits parallelism
- No batching across assets — each request processes one image through all models

**De-Factoring Evidence:**
- **If all models ran sequentially:** Processing time = sum of all model
  inference times. For a typical asset: CLIP (~100ms) + face detection (~150ms)
  + OCR (~200ms) = 450ms sequential vs ~200ms concurrent.
  **Detection signal:** "Smart search indexing is slow" — queue grows faster
  than processing.

- **If dependency ordering were removed:** Face recognition runs before face
  detection, gets no bounding boxes, produces empty results.
  **Detection signal:** "Face recognition finds no faces" despite faces being
  clearly visible in assets.

---

## Decision Guide

- **"We need ML features in a media app but don't control the ML stack"**
  → Pattern 2 (Delegated ML). Let dedicated ML apps own model lifecycle.
  Common in plugin ecosystems (Nextcloud, WordPress).

- **"We run our own ML models and need to support diverse hardware"**
  → Pattern 3 (Multi-Runtime Abstraction). Export models to multiple formats,
  auto-detect available hardware at startup.

- **"ML models spike memory then idle for hours"**
  → Pattern 1 (TTL-Cached). Set `model_ttl` to match your usage pattern.
  Consider idle process shutdown for serverless-like cost optimization.

- **"Multiple ML models per asset, some depend on others"**
  → Pattern 4 (Dependency-Aware Batching). Declare model dependencies,
  run independent models concurrently.

- **"We need ML but can't afford GPU hardware"**
  → Pattern 3 with CPU fallback. ONNX Runtime's CPU provider is always
  available. Consider ARM NN or RKNN for SBC deployments.

---

## Anti-Patterns

### 1. Always-Loaded Models Without Eviction

**What happens:** All configured models stay in GPU/CPU memory permanently.
With 6+ models (2 CLIP + 2 face + 2 OCR), a typical 8GB GPU is exhausted.
System swaps to disk, inference becomes slower than CPU-only.

**Instead:** Use TTL-based caching (Pattern 1). Set TTL based on expected
request frequency — 300s for active servers, shorter for batch processing.

### 2. Hardcoded Inference Runtime

**What happens:** Code assumes CUDA/ONNX Runtime only. Breaks on Intel
(OpenVINO), Apple Silicon (CoreML), Rockchip (RKNN), ARM (ARMNN). Each
hardware variant requires code changes.

**Instead:** Use runtime abstraction (Pattern 3). Auto-detect available
providers with fallback chain.

### 3. Synchronous Model Loading in Request Path

**What happens:** First request to a model downloads (potentially hundreds of
MB from HuggingFace) and loads the model synchronously. Request times out.
Subsequent requests pile up behind the loading request.

**Instead:** Use `OptimisticLock` (Pattern 1) so only one request triggers
loading while others wait. Consider preloading critical models at startup
for predictable first-request latency.

### 4. No Retry on Model Corruption

**What happens:** A partially downloaded or corrupted model file causes
permanent inference failure. The corrupted file is cached, so restarting
doesn't help.

**Instead:** Catch load errors, `clear_cache()`, retry once (Immich's
`load()` function pattern). Track `load_attempts` to avoid infinite retry
loops.
