# Performance Debugging

## Diagnostic decision tree

```
UI feels slow →
  JS thread blocked? (DevTools Performance → long tasks)
  ├── YES → State mutation or rendering?
  │     ├── Mutation (store update, spatial index) → Mutation bottlenecks
  │     └── Rendering (DOM/canvas draw calls) → Render bottlenecks
  └── NO → Layout/paint? → DOM bottlenecks
        └── NO → GC pressure / memory
```

## Mutation bottlenecks

**Spatial index rebuild:** Most common. RBush `load()` is O(n log n) — if called on every
mutation instead of incremental `insert()`/`remove()`, that's the problem. Single
insert <1ms for 50K items. Full rebuild >5ms → use Web Worker.

**Store notification storms:** Batch mutation triggers N notifications instead of 1.
A "move 10 shapes" firing 30+ notifications needs transaction batching (tldraw's
`editor.run()`, Yjs transactions, Svelte 5 synchronous batching).

**Deep proxy overhead (Svelte 5):** `$state()` on large annotation collections (Maps with
1000+ entries) causes up to 5000x slowdown. Fix: `$state.raw()` + version counter.

## Render bottlenecks

**Too many re-renders:** Entire tree re-renders instead of affected annotation. Causes:
subscribing to whole store instead of individual IDs, computing derived values in render
instead of caching, re-creating objects every render.

**Canvas clear + redraw:** At >500 shapes becomes bottleneck. Fixes: dirty-region rendering,
layer separation (static vs active canvas), offscreen caching + blit.

## Circular reactive dependencies

Most insidious bug. Mutation → effect → derived state update → effect → mutation (repeat).

Common cycles in annotation editors:
- Selection → derived bounds → spatial index → selection invalidation
- Mutation → undo push → store notification → re-render → re-read → undo treats as new mutation
- Collab sync → local apply → sync notification → re-broadcast (echo)

Fixes: `untrack()` / `runWithoutNotifications()`, source discriminator tags (`local`/`remote`/`undo`),
one-way data flow (effects write to different atom than they read).

## DOM annotation rendering

Thresholds: <100 elements fine, 100-500 virtual rendering, 500+ switch to canvas/WebGL.
Watch for forced reflows: reading `getBoundingClientRect()` after DOM mutation, setting
`style.transform` then reading `offsetWidth`. Batch reads before writes.

## Memory and GC

Performance degrades over time. Common causes: unbounded undo stack (cap + use diffs),
orphaned cache entries (auto-evict on deletion), detached DOM nodes (cleanup listeners),
accumulating collaboration tombstones (TTL-based cleanup).

## Profiling checklist

1. Spatial index: incremental or rebuilding? Under reactive proxy?
2. Store notifications: how many per action? Batching working?
3. Render scope: only changed annotation, or everything?
4. Reactive cycles: effects firing more than once per mutation?
5. Memory: undo stack bounded? Caches cleaning up on deletion?
6. DOM nodes: how many? Off-screen virtualized?

Most bugs are in 1-3. Items 4-6 emerge at scale or over time.
