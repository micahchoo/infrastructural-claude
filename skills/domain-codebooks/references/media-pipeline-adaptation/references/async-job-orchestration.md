# Async Job Orchestration for Media Processing

## The Problem

Media processing is inherently multi-stage: an uploaded asset must be
metadata-extracted, thumbnailed, transcoded, ML-analyzed (CLIP, faces, OCR),
and potentially deduplicated. These stages have dependencies (thumbnails must
exist before ML inference), varying resource requirements (transcoding is
CPU/GPU-heavy, metadata extraction is I/O-bound), and different failure modes
(ML service down vs disk full vs corrupt file).

Without deliberate orchestration, these stages either run sequentially (slow),
run in uncontrolled parallelism (resource exhaustion), or silently drop work
on failure. The system must manage job dependency ordering, per-queue
concurrency, failure recovery, and progress visibility — all while the user
expects near-instant feedback after upload.

---

## Competing Patterns

### 1. Event-Driven Job DAG with BullMQ (Immich)

**How it works:** Jobs are organized into named queues backed by BullMQ (Redis).
Each job type maps to a handler function. On success, the handler's `onDone`
method enqueues follow-up jobs, forming an implicit DAG. Concurrency is
configurable per queue.

**Example — Immich:**

Key architecture:
- `JobRepository` — registers BullMQ `Worker` per queue, maps `JobName` to
  handler functions via decorator reflection (`@OnJob`)
- `JobService.onDone()` — switch statement that queues follow-up jobs based on
  completed job type, forming the processing DAG
- `QueueService` — manages pause/resume, concurrency updates, nightly job
  scheduling with cron expressions
- Event lifecycle: `JobStart` → handler → `JobSuccess`/`JobError` → `JobComplete`

The implicit DAG for an uploaded asset:
```
Upload
  └→ SidecarCheck
       └→ AssetExtractMetadata
            └→ StorageTemplateMigration
                 └→ AssetGenerateThumbnails
                      ├→ SmartSearch (CLIP)
                      │    └→ AssetDetectDuplicates
                      ├→ AssetDetectFaces
                      ├→ Ocr
                      └→ AssetEncodeVideo (if video)
```

Key evidence:
- `JobService.onDone()` — hardcoded switch on `JobName` queues follow-ups:
  `SidecarCheck` → `AssetExtractMetadata`, `StorageTemplateMigration` →
  `AssetGenerateThumbnails`, `AssetGenerateThumbnails` → `[SmartSearch,
  AssetDetectFaces, Ocr, AssetEncodeVideo]`
- `JobRepository.start()` — creates `Worker` per `QueueName`, wires
  `concurrency` from config, emits `JobRun` event
- `JobRepository.setConcurrency()` — dynamically adjusts `worker.concurrency`
  without restart
- `QueueService.updateConcurrency()` — reads `SystemConfig` to set per-queue
  concurrency (e.g., SmartSearch = 2, Thumbnails = 3)

```typescript
// Immich: onDone forms implicit job DAG
private async onDone(item: JobItem) {
  switch (item.name) {
    case JobName.SidecarCheck:
      await this.jobRepository.queue({
        name: JobName.AssetExtractMetadata, data: item.data
      });
      break;

    case JobName.AssetGenerateThumbnails:
      const jobs: JobItem[] = [
        { name: JobName.SmartSearch, data: item.data },
        { name: JobName.AssetDetectFaces, data: item.data },
        { name: JobName.Ocr, data: item.data },
      ];
      if (asset.type === AssetType.Video) {
        jobs.push({ name: JobName.AssetEncodeVideo, data: item.data });
      }
      await this.jobRepository.queueAll(jobs);
      break;

    case JobName.SmartSearch:
      if (item.data.source === 'upload') {
        await this.jobRepository.queue({
          name: JobName.AssetDetectDuplicates, data: item.data
        });
      }
      break;
  }
}
```

**Tradeoffs:**
- DAG is implicit in code — easy to understand per-edge but hard to visualize
  the full graph
- BullMQ provides built-in retry, delay, priority, and rate limiting
- Concurrency is per-queue, not per-job-type — all jobs in a queue share the
  concurrency limit
- Fan-out is explicit (`queueAll`) — after thumbnails, ML jobs dispatch in
  parallel
- No built-in DAG validation — a typo in `onDone` silently breaks the pipeline
- Source-conditional branching (e.g., `source === 'upload'` for dedup) adds
  complexity

**De-Factoring Evidence:**
- **If the DAG were flattened (all jobs independent):** SmartSearch runs before
  thumbnails exist, face detection processes the original 50MP image instead of
  the preview, deduplication runs on assets without embeddings.
  **Detection signal:** "Face detection is slow" (processing full-res);
  "duplicates not detected" (no embedding to compare).

- **If per-queue concurrency were removed:** All queues run at max parallelism.
  5 concurrent video transcodes + 3 CLIP inferences saturate both CPU and GPU.
  System becomes unresponsive.
  **Detection signal:** Load average spikes to 20+; OOM killer terminates
  workers; "server is unresponsive during library scan."

---

### 2. Time-Bounded Cron Indexing (Memories)

**How it works:** A `TimedJob` (cron) runs at fixed intervals, processes files
for a bounded duration, then yields. Progress is tracked via database state
(indexed files vs unindexed). No persistent queue — work is rediscovered each
run by querying the filesystem against the index.

**Example — Memories:**

Key architecture:
- `IndexJob` extends `TimedJob` — runs every 900s (15 min), limited to 300s
  (5 min) execution per run
- `continueCheck` closure — called before each file, returns `false` when
  `MAX_RUN_TIME` elapsed
- `Service\Index` — iterates user folders, queries DB for unindexed files
  (file in `filecache` but not in `memories` table), processes each file
- Chunked DB queries — files checked in batches of 250 (DB `IN` clause limit)
- `.nomedia` / `.nomemories` sentinel files skip entire directories

```php
// Memories: Time-bounded cron with progress via DB state
class IndexJob extends TimedJob {
    protected function run(mixed $argument): void {
        if ('0' === SystemConfig::get('memories.index.mode')) {
            return;
        }

        $startTime = microtime(true);
        $this->service->continueCheck = static function () use ($startTime): bool {
            return (microtime(true) - $startTime) < MAX_RUN_TIME;
        };

        // Index with static exiftool process
        $this->service->indexUsers($users);
    }
}
```

Index discovery:
```php
// Memories: Discover unindexed files via DB diff
$query->select('f.fileid')
    ->from('filecache', 'f')
    ->where($query->expr()->in('f.fileid', ...))
    ->andWhere($query->expr()->gt('f.size', ...));

// Filter out already-indexed files
$query->andWhere($getFilter('memories', true));      // not in memories table
$query->andWhere($getFilter('memories_livephoto', true)); // not in livephoto table
```

**Tradeoffs:**
- No queue infrastructure needed — pure DB + cron
- Naturally bounded — never runs longer than `MAX_RUN_TIME`, safe in shared
  hosting environments (Nextcloud)
- Idempotent — re-running picks up where it left off via DB state
- Slow convergence — large libraries take many 5-minute windows to fully index
- No priority — new uploads wait alongside old unindexed files
- No parallelism within a run — single-threaded PHP process
- No dependency ordering — assumes exiftool results are sufficient per-file

**De-Factoring Evidence:**
- **If the time bound were removed:** In shared Nextcloud hosting, a long-running
  PHP process gets killed by the webserver timeout (30-300s). Partial work is
  lost. Or the cron process blocks other Nextcloud background jobs.
  **Detection signal:** "Indexing never completes"; PHP `max_execution_time`
  errors in logs.

- **If DB-based progress were replaced with in-memory state:** Process restart
  (cron re-invocation) loses all progress. On a 100K-photo library, every run
  re-checks all files from scratch.
  **Detection signal:** "Indexing takes days"; each cron run processes the same
  files repeatedly.

---

### 3. Queue Lifecycle Management (Immich)

**How it works:** Queues are first-class entities with admin-visible status,
pausable/resumable, clearable, and with live job counts. Users can pause
specific processing types without stopping the entire system.

**Example — Immich:**

Key architecture:
- `QueueService` — exposes REST endpoints for queue management
- `JobRepository.pause(name)` / `resume(name)` — delegates to BullMQ queue
- `JobRepository.getJobCounts(name)` — returns active, completed, failed,
  delayed, waiting, paused counts
- `QueueService.empty(name)` — drains pending jobs via `queue.drain()`
- `QueueService.clear(name, type)` — cleans completed/failed jobs
- Nightly jobs — `asNightlyTasksCron()` generates cron expression from config;
  acquired via `DatabaseLock.NightlyJobs` to prevent duplicate scheduling

```typescript
// Immich: Queue lifecycle operations
async isPaused(name: QueueName): Promise<boolean> {
  return this.getQueue(name).isPaused();
}

pause(name: QueueName) {
  return this.getQueue(name).pause();
}

resume(name: QueueName) {
  return this.getQueue(name).resume();
}

getJobCounts(name: QueueName): Promise<JobCounts> {
  return this.getQueue(name).getJobCounts(
    'active', 'completed', 'failed', 'delayed', 'waiting', 'paused',
  );
}
```

**Tradeoffs:**
- Full observability — admin can see exactly what's processing, queued, failed
- Granular control — pause ML processing during peak hours, keep thumbnails
  running
- Requires Redis infrastructure (BullMQ dependency)
- Queue state is external (Redis) — adds operational complexity
- No automatic backpressure — admin must manually pause overloaded queues

**De-Factoring Evidence:**
- **If queue pause/resume were removed:** Users can't stop runaway transcoding
  jobs without restarting the entire server. A large library import that
  saturates the system has no graceful throttle.
  **Detection signal:** "Server is unresponsive during library scan, only fix
  is restart."

- **If job counts were not exposed:** Admin has no visibility into processing
  progress. "Is it still processing?" becomes unanswerable without checking
  logs.
  **Detection signal:** Support tickets asking "how do I know if indexing is
  done?"

---

### 4. Backend Registry Pattern for ML-Powered Features (Memories)

**How it works:** A static registry maps feature names to backend classes.
Each backend encapsulates a different ML integration (face recognition,
image classification, place detection). The media app queries backends
without knowing which ML system provides the data.

**Example — Memories:**

Key architecture:
- `Manager::$backends` — static array mapping name → class name
- `Manager::register()` — called during app bootstrap to register available
  backends
- Each backend implements `isEnabled()`, `transformDayQuery()`,
  `getClustersInternal()`, `getPhotos()`
- `FaceRecognitionBackend` wraps Nextcloud's `facerecognition` app
- `RecognizeBackend` wraps Nextcloud's `recognize` app
- Both provide face clustering but via completely different ML pipelines

```php
// Memories: Backend registry decouples features from ML providers
class FaceRecognitionBackend extends Backend {
    public function isEnabled(): bool {
        return Util::facerecognitionIsInstalled()
               && Util::facerecognitionIsEnabled();
    }

    public function getClustersInternal(int $fileid = 0): array {
        $faces = array_merge(
            $this->getFaceRecognitionPersons($fileid),
            $this->getFaceRecognitionClusters($fileid),
        );
        return $faces;
    }
}
```

**Tradeoffs:**
- Swappable ML backends — users choose their preferred face recognition system
- Feature availability degrades gracefully — disabled backends return empty
  results
- No unified ML pipeline — each backend has its own job scheduling, model
  management, and failure modes
- Query patterns differ per backend — SQL joins against different table schemas

**De-Factoring Evidence:**
- **If backends were hardcoded to one ML app:** Users of `facerecognition` app
  can't switch to `recognize` (or vice versa) without code changes. Supporting
  both simultaneously is impossible.
  **Detection signal:** "I installed recognize but memories still uses
  facerecognition"; feature requests to support alternative ML apps.

---

## Decision Guide

- **"We process assets through multiple dependent stages (thumbnail → ML → dedup)"**
  → Pattern 1 (Event-Driven DAG). Define the dependency chain in `onDone`,
  let the queue handle ordering and concurrency.

- **"We're in a shared hosting environment with execution time limits"**
  → Pattern 2 (Time-Bounded Cron). Bound each run, use DB state for progress,
  design for incremental convergence.

- **"Admins need to control processing — pause ML during backups, check progress"**
  → Pattern 3 (Queue Lifecycle). Expose queue status and controls via admin API.
  Requires persistent queue backend (Redis/BullMQ).

- **"Multiple ML providers can power the same feature"**
  → Pattern 4 (Backend Registry). Abstract the ML source behind a registry,
  let each backend own its integration details.

- **"We need all of the above"**
  → Combine: Pattern 1 for the DAG backbone, Pattern 3 for admin controls,
  Pattern 4 for pluggable ML backends at the leaf nodes.

---

## Anti-Patterns

### 1. Flat Queue Without Dependencies

**What happens:** All processing jobs (metadata, thumbnails, ML, transcode)
go into a single queue. Jobs execute in arrival order. ML inference runs on
raw uploads before thumbnails exist. Transcoding of a 4K video blocks
thumbnail generation for hundreds of photos behind it.

**Instead:** Separate queues per processing type (Pattern 1). Define explicit
ordering via `onDone` chains. Set per-queue concurrency limits.

### 2. Unbounded Processing Without Time Limits

**What happens:** Background job processes the entire library in one run.
On shared hosting, the process gets killed by timeout. On dedicated hardware,
it monopolizes resources for hours, making the application unresponsive.

**Instead:** Use time-bounded execution (Pattern 2) or configurable concurrency
(Pattern 3). Process incrementally with resumable progress.

### 3. In-Memory Queue Without Persistence

**What happens:** Jobs are queued in application memory. Server restart loses
all pending work. A 100K-asset library scan that's 80% complete starts over
from scratch.

**Instead:** Use persistent queue (BullMQ/Redis for Pattern 1) or DB-based
progress tracking (Pattern 2). Both survive restarts.

### 4. Silent Job Failure Without Retry or Visibility

**What happens:** A failed ML inference (model service down, OOM, corrupt file)
silently drops the job. The asset appears successfully processed but has no
face data, no CLIP embedding, no OCR text. User never knows.

**Instead:** Emit `JobError` events (Pattern 1), track failure state in DB
(Pattern 2), expose failed job counts (Pattern 3). Implement retry with
backoff for transient failures; mark-and-skip for permanent failures.

### 5. Processing Original Files Instead of Derivatives

**What happens:** ML inference runs on the original 50-megapixel RAW file
instead of the generated preview thumbnail. Inference takes 10x longer and
may OOM.

**Instead:** Wait for thumbnail generation to complete (Pattern 1 DAG ordering)
before dispatching ML jobs. Use the preview-resolution derivative as ML input.
