---
name: distributed-state-sync
description: >-
  Architectural advisor for keeping mutable state consistent across distributed
  clients with real-time synchronization, conflict resolution, and durable
  persistence. The force tension: consistency vs responsiveness vs durability
  when multiple clients mutate shared state concurrently.

  NOT generic state management, single-user CRUD apps, static content delivery,
  database administration, or message queue design.

  Triggers: optimistic updates with rollback, mutation-to-UI sync, conflict
  resolution (CRDT/LWW/OT), real-time collaboration sync, three-tier persistence
  (CRDT WAL + client cache + canonical DB), schema migration across distributed
  clients, mutation reducer for live editing + replay, ephemeral modifier layers,
  presence vs document state separation, client-side rebase, adaptive sync
  throttling, fractional indexing for conflict-free ordering, pessimistic locking
  via awareness channels, silent mutation failures, stale UI after mutations.

  Brownfield triggers: "mutations fire but UI doesn't update", "sync drops
  changes after reconnect", "stale data after tab switch", "existing sync layer
  silently swallows errors", "adding a new mutation type breaks the reducer",
  "presence ghosts after disconnect", "refactoring the store broke optimistic
  updates", "rebase logic produces duplicate elements", "migrating from polling
  to WebSocket breaks offline queue", "naive last-write-wins drops one user's
  concurrent change", "offline edits create duplicate shapes on reconnect",
  "array merge causes z-order jumps on simultaneous insert", "UI re-renders
  mid-batch when moving grouped shapes", "remote WebSocket action triggers
  local middleware as if user did it", "cursor positions visible to
  collaborators but not persisted or in undo".

  Symptom triggers: "collaborative diagram editor concurrent mutations merge cleanly",
  "user A moves a shape and user B changes its color simultaneously",
  "persists to IndexedDB and syncs via WebSocket offline edits create duplicates",
  "going offline and making edits reconnecting creates duplicate shapes",
  "persistence layer interact with the sync protocol",
  "flat array index simultaneous insert z-order jumps fractional indexing",
  "two users simultaneously insert annotations array merge",
  "mutation system fires change events synchronously UI re-renders mid-batch",
  "single user action produces 10 mutations moving grouped shapes batch defer rendering",
  "ephemeral state cursor positions selection highlights visible to collaborators not persisted not in undo",
  "split between durable document state and ephemeral presence state",
  "collaborative editor Redux store remote change via WebSocket dispatches action triggers middleware",
  "remote mutations distinguished from local mutations in the state layer",
  "how do canvas editors batch mutations and defer rendering",
  "both changes to merge cleanly what sync patterns handle concurrent mutations".

  Diffused triggers: "multiplayer sync architecture", "how to handle conflicts
  in real-time editing", "optimistic updates keep reverting", "CRDT vs OT vs LWW
  which should I use", "how to persist collaborative state to database",
  "schema migration breaks multiplayer", "mutations fire but UI doesn't update",
  "offline-first sync strategy", "how does Figma handle conflicts",
  "after adding [feature] the sync is broken", "why do changes disappear on
  reconnect", "the mutation pipeline is getting unmaintainable", "we switched
  sync providers and everything broke", "production users report stale state
  after backgrounding the tab".

  Libraries: Yjs, Automerge, cr-sqlite, Electric SQL, PowerSync, Liveblocks,
  Partykit, Durable Objects, Supabase Realtime.

  Production examples: Felt, Figma, tldraw, Excalidraw, Penpot, Google Docs,
  Notion, Linear.

  Skip: single-user state management (Redux, Zustand, Jotai), REST API design,
  database query optimization, pub-sub message brokers, file synchronization
  (Dropbox/rsync), version control (git).
---

# Distributed State Synchronization

**Force tension:** Consistency vs responsiveness vs durability when multiple
clients mutate shared state concurrently.

This is the "mother sauce" force cluster — it appears in every real-time
collaborative system. Canvas editors, collaborative docs, multiplayer games,
shared databases, and form builders all face these same forces.

## Step 1: Classify the synchronization problem

1. **Client topology**: Server-authoritative, peer-to-peer, or hybrid?
2. **Latency tolerance**: Optimistic (show immediately, reconcile later) or pessimistic (wait for confirmation)?
3. **Conflict semantics**: Last-write-wins sufficient, or do you need intent-preserving merge?
4. **Offline requirement**: Must work offline, or always-connected?
5. **State shape**: Flat key-value, tree/document, or graph?
6. **Mutation frequency**: Low (form saves), medium (document editing), high (cursor/drawing)?

## Step 2: Load reference

| Axis | File |
|------|------|
| Mutation-to-UI sync / ephemeral modifiers / mutation reducer | `get_docs("domain-codebooks", "distributed-state-sync mutation reducer")` |
| Collaboration & conflict resolution (CRDT/LWW/OT) | `get_docs("domain-codebooks", "distributed-state-sync conflict resolution")` |
| Persistence / schema migration / three-tier / snapshots | `get_docs("domain-codebooks", "distributed-state-sync persistence migration")` |
| Element ordering / z-index convergence / fractional indexing | `get_docs("domain-codebooks", "distributed-state-sync element ordering")` |

## Step 3: Advise and scaffold

Present 2-3 competing patterns with tradeoffs. Match existing framework conventions.

### Cross-References (force interactions)

- When undo/redo is needed on distributed state → see **undo-under-distributed-state**
- When state is spatial (canvas/map) with mode-based editing → see **interactive-spatial-editing**
- When building annotation/canvas tools specifically → see **annotation-state-advisor** (composite recipe)
- When optimistic local mutations conflict with authoritative server state and the UI must decide what to show → see **optimistic-ui-vs-data-consistency**

## Principles

1. **LWW at property level suffices** for most spatial annotation conflicts. CRDTs only for rich text, concurrent vertex editing, or offline-first.
2. **Separate presence from document state.** Presence is ephemeral (cursors, selections); document state is durable. Different sync strategies for each.
3. **Never silently swallow mutation failures.** `Result<T,E>` or throw — silent no-ops cause "mutated but nothing happened" bugs.
4. **Batch mutations must be transactional.** Validate all before mutating any.
5. **Schema migration is first-class.** Bidirectional (tldraw style) for multiplayer version skew.

`[eval: approach]` Recommended sync strategy matches the actual consistency requirements (eventual vs strong vs causal).
`[eval: depth]` Considered at least 2 competing patterns from this codebook before recommending one.
