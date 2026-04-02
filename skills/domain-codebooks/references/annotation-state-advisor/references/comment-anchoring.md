# Comment Anchoring

## The Problem

Comment threads in annotation tools must stay connected to the thing they reference — but that thing moves, transforms, gets deleted, or gets edited by other users concurrently. A comment anchored to an annotation's position breaks when the annotation is dragged. A comment anchored to an annotation's ID becomes orphaned when the annotation is deleted (possibly by another collaborator, possibly temporarily via undo). The anchoring strategy determines whether comments survive mutations, and the wrong choice produces ghost comments pointing at nothing or comments that silently detach from their context.

Beyond anchoring, comment systems in spatial editors face unique UX challenges that text-based comment systems don't. At low zoom levels, dozens of comment bubbles overlap into an unreadable cluster. Deep-linking to a comment requires a multi-step async sequence (navigate to page, load content, activate comment mode, zoom to separate cluster, center viewport, open thread) where any step can fail or race. And the boundary between document state (the comment itself) and presence state (who's currently typing) must be drawn correctly or comments either fail to persist or flood the sync layer with ephemeral keystrokes.

## Competing Patterns

Comment threads anchored to mutable annotations on maps, canvases, and timelines.

## Anchor strategies

**By feature ID (recommended default):** Comment stores annotation's stable ID. Position
resolved at render time from feature geometry. No position bookkeeping. Felt, Figma use this.

**By position:** Stores coordinates (or time offset). For "pin drop" comments on empty space
with no underlying feature. Miro, Figma support both alongside feature-anchored.

**By selector (W3C Web Annotation):** Fragment/CSS/SVG selectors per W3C spec. IIIF and
Annotorious use this. Most flexible, most complex. Overkill for single-app use.

## Orphan handling (when anchor annotation is deleted)

- **Tombstone** (Figma): Keep comment, show "attached to deleted element". Safest for
  collaborative tools where deletion might be undone.
- **Cascade delete**: Delete comments with annotation. Only for single-user tools.
- **Detach and float** (Frame.io): Convert to positional comment at last known location.
- **Archive** (Upwelling): Move to resolved/archived state on merge.

## Thread model

**Flat threads (recommended):** Single reply level, `parentId` → root. Figma, Felt use this.
Deep nesting doesn't work in sidebar UIs beside a canvas/map.

**State machine:** OPEN → RESOLVED → ARCHIVED. Resolution can be manual or workflow-triggered.

## Position update on feature mutation

- **ID-anchored:** No update needed — position resolved at render time.
- **Position-anchored:** Must update. Either transform-with-feature (apply same affine
  transform — tldraw does this for grouped shapes) or snap-to-nearest on the new geometry.

## Navigate-to-comment deep linking

Sequential state machine — ordering matters to avoid race conditions:
1. Navigate to page (if multi-page)
2. Wait for initialization (content must load)
3. Activate comment mode (if required)
4. Zoom to separate (if target is in a cluster)
5. Center viewport on comment position
6. Open thread panel

Each step may be async. Penpot chains these as potok events.

## Viewport density and clustering

At low zoom, comment bubbles overlap. Proximity clustering: compute pairwise distances
scaled by zoom, cluster within pixel threshold, render aggregate badges. On click, zoom
to separate. Penpot and Figma both use this. Resolved comments get lower priority or hide.

## Collaboration

- Comments are **document state** (persist, sync via CRDT/sync layer), not presence
- "Currently typing" is **presence** (ephemeral, LWW, don't persist)
- Ordering: server timestamps for collaborative, local for single-user
- Optimistic creation with temp client ID, replaced by server ID on confirm
- Conflicts rare (append-only); resolution state is main conflict vector (LWW)

## Decision guide

| Constraint | Approach |
|---|---|
| Features have stable IDs | Anchor by ID |
| Pin drops on empty space | Anchor by position |
| W3C/IIIF interop | Anchor by selector |
| Collaborative, undo possible | Tombstone orphans |
| Single-user | Cascade delete |
| Sidebar UI | Flat threads |
| Mixed features + empty space | Discriminated union (ID + positional) |

## Anti-Patterns

- **Anchoring by position to a mutable feature.** When the feature moves, the comment stays behind pointing at empty space. Use ID-based anchoring for any comment attached to a feature; reserve positional anchoring for "pin drop" comments on empty canvas.
- **Cascade-deleting comments in collaborative tools.** If User A deletes a feature that User B commented on, cascade delete destroys User B's feedback with no recovery. Use tombstoning (Figma pattern) in any collaborative context so comments survive deletion and potential undo.
- **Deep-nested thread replies in sidebar UI.** Deeply nested threads don't fit in the constrained sidebar panels typical of canvas/map editors. Use flat threads (single reply level with `parentId` to root).
- **Synchronous deep-link navigation.** Navigate-to-comment requires multiple async steps (load page, wait for init, activate mode, zoom to separate, center, open panel). Executing these synchronously or without ordering produces race conditions where the viewport centers before content loads.
- **Treating "currently typing" as document state.** Typing indicators are ephemeral presence, not persistent document state. Syncing them through the document CRDT pollutes undo history and wastes bandwidth. Use the presence/awareness channel.
- **Rendering all comment bubbles at low zoom.** Dozens of overlapping bubbles at low zoom are unreadable. Use proximity clustering with zoom-scaled distance thresholds, rendering aggregate badges that zoom-to-separate on click.
