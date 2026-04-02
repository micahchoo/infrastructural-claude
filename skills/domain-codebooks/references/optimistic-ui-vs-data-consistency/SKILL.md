---
name: optimistic-ui-vs-data-consistency
description: >-
  Showing UI changes before the server/sync layer confirms them, vs maintaining
  consistent display when rollback, conflict, or stale data occurs. The tension:
  users expect instant feedback, but data may be wrong until confirmed.

  Triggers: "optimistic update rollback", "stale while revalidate", "dual source
  of truth display", "sync indicator UX", "CaptureUpdateAction", "rebase on commit",
  "pending mutation display", "upload progress UX", "undo display vs undo data",
  "conflict resolution UI", "loading state design", "offline edits merge on reconnect",
  "server-authoritative vs local-first display", "mutation queue ordering".

  Brownfield triggers: "UI shows stale data after sync", "undo doesn't match what
  the user sees", "optimistic update causes flicker on rollback", "deletion shows
  then reappears", "upload succeeds but gallery doesn't update", "collaborative
  editing shows wrong state briefly", "server rejects move but shape already
  moved visually", "saving indicator flickers with frequent auto-save",
  "Ctrl+Z undoes a change the user never saw on screen", "form shows outdated
  values after background sync", "offline edits need merge indicator on reconnect",
  "server reorders operations in collaborative editing", "visual jump when
  optimistic position rolls back".

  Symptom triggers: "cascading rollbacks when optimistic updates get rejected",
  "saving indicator feels disconnected from optimistic changes",
  "CaptureUpdateAction boilerplate makes simple operations verbose",
  "remote operation arrives before the create causing shape not found error",
  "derived computations differ between optimistic and server state",
  "sync queue flush causes visible flash on reconnect",
  "partial batch rejection should we rollback entire batch or just failed property",
  "presence state becomes stale after optimistic edit is rejected",
  "temporary ID remapping when optimistic creates are confirmed",
  "how to model saving synced conflict progression states in UI".
---

# Optimistic UI vs Data Consistency

The tension between instant UI feedback and data correctness. Produces spaghetti
when unresolved because every mutation site must decide independently whether to
show optimistic state, how to handle rollback, and how to reconcile with
authoritative data.

Evidence: 7/18 repos STRONG + 6 MODERATE. Second most universal UX cluster.

## Evidence repos
- **excalidraw** — CaptureUpdateAction annotation burden spread across every mutation site
- **allmaps** — Dual source of truth (TerraDraw GeoJSON + ShareDB ot-json1), no rollback
- **penpot** — Rebase-on-commit with triple-state sync
- **iiif-manifest-editor** — All edits in-memory Vault, no undo/redo, no dirty tracking
- **drafft-ink** — Loro CRDT + UndoManager + WebSocket sync state machine
- **ente** — Pending mutation sets, phased upload status, dual-layer synced-vs-UI state
- **upwelling** — Bidirectional ProseMirror-Automerge bridge, merge visualization
- **yjs** — The optimistic layer itself: Doc.on('sync'), transaction.origin discrimination

## Classify

1. **Sync model** — local-first (CRDT), server-authoritative, or hybrid?
2. **Mutation granularity** — per-keystroke, per-action, or per-save?
3. **Conflict visibility** — hidden (auto-merge), surfaced (diff), or manual?
4. **Rollback requirement** — can mutations be reverted, or are they fire-and-forget?
5. **Loading states** — skeleton, spinner, stale-while-revalidate, or block-until-ready?

## Patterns

### Mutation Annotation (excalidraw pattern)
Every mutation site wraps changes with metadata (CaptureUpdateAction) that tags
whether the change is user-initiated, undo, or sync-driven. UI behavior differs
per tag.

**Tradeoff**: Complete control but annotation burden on every mutation call site.

### Dual-Layer State (ente pattern)
Separate confirmed-state and optimistic-state in the store. UI reads optimistic.
On server confirm, promote. On failure, discard optimistic layer.

**Tradeoff**: Clean separation but memory overhead and merge complexity.

### Rebase-on-Commit (penpot pattern)
Client applies changes optimistically, server may rebase. Client replays local
changes on top of server state when sync arrives.

**Tradeoff**: Complex rebase logic but natural for collaborative editing.

### Block-and-Await (anti-pattern for perceived speed)
Disable UI until server confirms. Simple but users perceive lag.

**Detection signal**: Loading spinners on every action, disabled buttons during save.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| distributed-state-sync | Optimistic display depends on sync conflict resolution strategy |
| undo-under-distributed-state | Undo must understand which optimistic changes to revert |
| virtualization-vs-interaction-fidelity | Virtual items may be stale while optimistic mutations in-flight |
| gesture-disambiguation | Gesture in-progress state displayed before sync confirms |
| **userinterface-wiki** | `ux-doherty-under-400ms` + `ux-doherty-perceived-speed` (skeleton/progress for sync lifecycle), `presence-disable-interactions` (disable exiting elements during rollback), `easing-for-state-change` (easing for loading→synced→conflict transitions) |

## References

Load as needed:
- `get_docs("domain-codebooks", "optimistic-ui sync lifecycle states")` — Explicit state machines (Penpot queue), doc sync events (Yjs), implicit dual-truth (Allmaps); transition logic, anti-patterns, metrics
- `get_docs("domain-codebooks", "optimistic-ui mutation annotation")` — CaptureUpdateAction enum burden (Excalidraw), transaction.origin tagging (Yjs), binary local/remote (Allmaps); ephemeral-to-committed transitions
- `get_docs("domain-codebooks", "optimistic-ui rollback strategies")` — Rebase-on-commit (Penpot triple-state), version-nonce reconciliation (Excalidraw), fire-and-forget (Allmaps), dual-layer (Ente), CRDT auto-merge
