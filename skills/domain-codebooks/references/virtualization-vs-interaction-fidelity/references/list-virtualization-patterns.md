# List Virtualization Patterns

## The Problem

Large lists (thousands to millions of items) cannot render all DOM nodes simultaneously without destroying performance. But virtualizing — only rendering visible items — breaks interaction contracts that users and developers assume: keyboard navigation skips offscreen items, selection state evaporates when items scroll out, search highlighting fails on unrendered content, drag targets disappear mid-gesture, and focus jumps unpredictably when DOM nodes recycle.

The spaghetti emerges when virtualization logic (scroll position, viewport calculation, DOM recycling) and interaction logic (selection state, keyboard focus, range operations) are built independently then forced to cooperate. Each system assumes it owns the DOM, and their assumptions conflict.

## Competing Patterns

### Bucket-Based Windowing (Immich pattern)

**When to use**: Date-grouped or category-grouped media grids with tens of thousands of items. Selection must work across groups.

**When NOT to use**: Flat homogeneous lists where simpler windowed approaches suffice, or lists under ~500 items where virtualization overhead exceeds benefit.

**How it works**: Items are grouped into "buckets" (e.g., by date). A `visibleWindow` derived from `scrollTop + viewportHeight` determines which buckets render. Buckets outside the window unload, replaced by placeholder elements with estimated heights.

**Immich implementation** (`asset-store.svelte.ts`, ~500+ lines):
- `visibleWindow` derived from `#scrollTop` + `viewportHeight`
- Buckets (date-grouped) load/unload based on intersection with visible window
- `intersection-observer.ts` action wraps IntersectionObserver for lazy bucket loading
- Placeholder heights: buckets have estimated heights before data loads, replaced with actual heights after
- `scroll-memory.ts` action preserves scroll position across navigation

**Selection across virtual boundaries**: Multi-select (`asset-grid.svelte:560-680`) iterates across **all buckets** for shift-range selection, not just visible ones. `assetInteraction.assetSelectionCandidates` accumulates candidates across virtual boundaries. Date group selection updates traverse full bucket list to maintain selection state for off-screen assets.

**Scroll compensation**: `scrollCompensation: { heightDelta, scrollTop }` tracks height changes from bucket load/unload to prevent scroll jumps. Without this, loading a bucket above the viewport shifts everything down, causing visible content to jump.

**Key files**: `asset-store.svelte.ts`, `asset-bucket.svelte.ts`, `asset-grid.svelte`, `intersection-observer.ts`, `scroll-memory.ts`

### Fixed-Size Windowed Rendering (react-window / TanStack Virtual)

**When to use**: Flat lists with uniform or measurable row heights, moderate interaction requirements (click selection, basic keyboard nav).

**When NOT to use**: Variable-height items with complex measurement needs, grouped/sectioned lists, or when full keyboard navigation and multi-select across offscreen items is required.

**How it works**: Render a fixed "window" of items based on scroll position. Items outside the window are not in the DOM. A sentinel element (or CSS transform) maintains correct scroll height.

**Core tradeoff**: Simplest to implement but interaction fidelity is lowest. Focus management requires manual `scrollToIndex` calls. Selection state must be maintained in a separate data structure keyed by index/id, not by DOM presence. Search highlighting on offscreen items requires either: (a) maintaining a parallel search index, or (b) scrolling to matches programmatically.

**Interaction breakdowns**:
- `aria-setsize` and `aria-posinset` must be manually set for screen readers since the full list is not in the DOM
- Tab order is broken — tabbing past the last visible item has nowhere to go
- Ctrl+A "select all" requires the selection system to know about all items, not just rendered ones
- Drag-to-select rubber-band gestures need coordinate translation between scroll position and data indices

### Infinite Scroll / Paginated Append

**When to use**: Content feeds, paginated API results, "load more" patterns where users consume sequentially.

**When NOT to use**: When users need random access (jump to item N), full-list operations (select all, sort), or when memory accumulation over long sessions is a concern.

**How it works**: Append new pages of content as the user scrolls down. Older content remains in DOM (no recycling). IntersectionObserver on a sentinel element triggers next page load.

**Immich example**: `PeopleInfiniteScroll` component for paginated people lists — simpler than the bucket virtualizer because people lists are smaller and don't need cross-boundary selection.

**Memory concern**: Unlike windowed approaches, DOM nodes accumulate. After scrolling through thousands of items, memory usage grows linearly. Some implementations add "virtualization on top" — removing items that scroll far above the viewport — but this reintroduces all the recycling problems.

### Sticky Headers in Virtual Lists (memories pattern)

**When to use**: Chronological or categorized lists where section context (date headers, category dividers) must remain visible during scroll for spatial orientation.

**When NOT to use**: Flat lists without meaningful grouping, or when the number of sticky elements would itself become a performance problem.

**How it works**: Override virtualization for structural elements. Day headers, section dividers, and navigation landmarks are exempted from recycling — they always render regardless of viewport position.

**memories implementation**: `virtualSticky` flag on header elements overrides the recycler. Dual-scroll sync keeps the timeline scrubber aligned with the virtual list position.

**Tradeoff**: Breaks pure virtualization. The number of sticky elements is bounded by the number of sections (typically manageable), but each sticky element is an exception to the recycling contract that must be tracked separately.

## Decision Guide

| Constraint | Approach |
|-----------|----------|
| Grouped items, cross-group selection needed | Bucket-based windowing (Immich) |
| Flat list, uniform heights, simple interaction | Fixed-size windowed (react-window) |
| Sequential consumption, no random access | Infinite scroll |
| Section context must persist during scroll | Sticky headers override |
| Full keyboard nav + screen reader support | Windowed + manual ARIA + scrollToIndex |
| Shift-range select across offscreen items | Selection state for ALL items, not just rendered |

## Anti-Patterns

### Coupling selection state to DOM presence

**What happens**: Selection is tracked via DOM attributes (`.selected` class, `aria-selected`) on rendered elements. When an item scrolls out and its DOM node is recycled, the selection state vanishes. Scrolling back creates a new DOM node without the selection.

**Why it's tempting**: DOM-based selection is the natural pattern — click handler adds a class. Works perfectly without virtualization.

**What to do instead**: Maintain selection state in a data structure keyed by item ID, independent of DOM. Derive DOM attributes from this state when items render. Immich's `assetInteraction.assetSelectionCandidates` is the canonical example.

### Estimating heights without correction

**What happens**: Placeholder heights are estimated (e.g., "each bucket is ~300px") but never corrected after actual content loads. Scroll position drifts progressively — the scrollbar thumb position lies about where you are in the list. Programmatic `scrollToIndex` lands in the wrong place.

**Why it's tempting**: Height estimation is simpler than measurement. "Close enough" works for small lists.

**What to do instead**: Measure actual heights after render, update the scroll model, and apply scroll compensation (Immich's `scrollCompensation: { heightDelta, scrollTop }`) to prevent visible jumps.

### Virtualizing without scroll position preservation

**What happens**: User navigates away (detail view, modal, different route) and returns to find the list scrolled back to the top. Context is lost.

**Why it's tempting**: Saving and restoring scroll position across navigation requires explicit state management outside the virtualizer.

**What to do instead**: Persist scroll position on navigation (Immich's `scroll-memory.ts` action). Restore both scroll offset and the bucket/item that was at the viewport top, since heights may have changed.
