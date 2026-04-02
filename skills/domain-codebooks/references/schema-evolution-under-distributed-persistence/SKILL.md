---
name: schema-evolution-under-distributed-persistence
description: >-
  Force tension: ensuring migration correctness while maintaining live cross-version
  compatibility in multiplayer systems where clients may be on different schema versions
  simultaneously. Migrations must be safe, ordered, and reversible — yet the system must
  keep serving heterogeneous clients without downtime.

  Triggers: "bidirectional migration sequences", "cross-version sync protocol",
  "migration dependency ordering", "schema version negotiation", "idempotent
  distributed migrations", "version-tagged record persistence", "migration
  interaction with undo history", "collaborative document schema versioning",
  "MigrationSequence dependsOn pattern", "lazy per-record migration".

  Brownfield triggers: "old client crashes after new schema deploy",
  "multiplayer migration corrupts document when clients on different versions",
  "undo after migration crashes because history references old format",
  "migration must be idempotent across multiple devices opening same document",
  "need downgrade path when users roll back to older app version",
  "v5 client and v3 client on same document and v3 crashes",
  "client B's old edits applied on top of client A's migrated state",
  "new annotation type needs backfilling with defaults in old documents".

  Symptom triggers: "shipping v5 of collaborative editor document schema some users
  still on v3 v5 client and v3 client connect to same document v3 crashes doesn't
  understand new fields cross-version sync without forcing all clients to update",
  "schema migration runs on document open converts v2 shapes to v3 shapes in
  multiplayer client A migrates client B hasn't yet client B v2 edits applied on
  top of client A v3 state corrupt the document migrations work in distributed",
  "tldraw uses bidirectional migrations up and down we only have up migrations
  need to support downgrading when users roll back to older app version
  bidirectional migration pattern implementation tradeoffs",
  "added new annotation type in schema v4 old documents need new type backfilled
  default values migration must be idempotent might run multiple times user opens
  document on different devices idempotent schema migrations distributed documents",
  "after schema migration undo history references old schema format undoing
  pre-migration action tries to restore shape in old format crashes renderer
  schema migration interact with undo history".

triggers:
  - schema migration in collaborative or multiplayer app
  - version skew between connected clients
  - bidirectional or reversible migrations
  - migration sequences with dependency ordering
  - backward compatibility for persisted collaborative data
  - forward compatibility / unknown-field tolerance
  - data shape changes in documents shared across clients
  - migration ordering and dependency declaration
  - "old clients crash after deploy"
  - "migration corrupts multiplayer sessions"
  - "can't add a field without breaking existing documents"
  - "existing migration chain has gaps or ordering bugs"
  - "renaming a field broke all persisted documents"
  - "version skew causes silent data loss in production"
  - "lazy migration left mixed-version records in the store"
  - "adding a new record type requires touching every migration"

cross_codebook_triggers:
  - "migration breaks bindings/constraints (+ constraint-graph)"
  - "schema change breaks embedded consumers (+ embeddability)"

diffused_triggers:
  - adding a new optional field (no migration tension — additive-only is safe)
  - single-user local persistence with no sync (standard migration tooling suffices)
  - server-only schema change with no client-visible shape change
  - "we need to migrate but can't break existing sessions"
  - "after deploying the schema change, old clients see corrupted data"
  - "the migration system is getting unmaintainable"
  - "how do we add a required field without a breaking change"
  - "our migration tests pass but production data breaks"
  - "clients on different versions produce conflicting shapes"

skip:
  - pure API versioning with no persisted shared state
  - database migrations in request/response systems with deploy-gate (use standard tooling)

libraries:
  - "@tldraw/store (migration sequences, dependsOn, retroactive migrations)"
  - "@tldraw/sync (TLSyncRoom cross-version protocol)"
  - "Excalidraw element versioning (version + versionNonce fields)"
  - "Penpot change algebra (versioned operations, .cljc cross-platform schemas)"
  - "Ente MagicMetadata (encrypted extensible metadata escape hatch, multi-surface migrations)"
  - "Allmaps annotation/iiif-parser (3-layer independent versioning with Zod union schemas)"

production_examples:
  - "tldraw: packages/store/src/migrate.ts — MigrationSequence with dependsOn ordering"
  - "tldraw: packages/sync/src/lib/TLSyncRoom.ts — cross-version client handling"
  - "excalidraw: packages/excalidraw/element/types.ts — version/versionNonce on every element"
  - "penpot: common/src/app/common/types/ — .cljc schema definitions shared across JVM and JS"
  - "ente: server/migrations/ — 117 numbered SQL migrations with up/down pairs + MagicMetadata escape hatch"
  - "allmaps: packages/annotation/src/ — 3-layer independent versioning (IIIF spec, annotation format, DB schema)"
---

# Schema Evolution Under Distributed Persistence

## Step 1: Classify the Migration Context

Answer these questions before choosing a strategy:

1. **Client heterogeneity** — Can multiple schema versions be active simultaneously?
   If yes, you need cross-version compatibility, not just forward migration.

2. **Migration direction** — Do you need to migrate data backward (new-to-old) as well
   as forward (old-to-new)? Bidirectional migrations are required when old clients must
   read data written by new clients.

3. **Migration atomicity** — Can you gate deployment so all clients upgrade together, or
   must migration be gradual/lazy? Multiplayer systems almost never get atomic upgrades.

4. **Dependency ordering** — Do migrations have cross-type dependencies (e.g., migrating
   a shape record requires the parent document record to already be migrated)?

5. **Persistence topology** — Is the source of truth a central server, or is state
   replicated across peers? Server-authoritative systems can migrate on write; peer
   systems must migrate on read.

6. **Undo/history interaction** — Must undo replay operations across schema boundaries?
   If yes, operations in the history log must either be version-tagged or
   version-independent.

## Step 2: Load Reference

| Situation | Primary Pattern | Reference | Risk |
|---|---|---|---|
| Multiplayer with heterogeneous clients, complex schema graph | Bidirectional migration sequences with `dependsOn` ordering | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | High — migration bugs cause data loss across all connected clients |
| Multiplayer with informal versioning, element-level schema | Version-gated compatibility with additive-only changes | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | Medium — no formal rollback path; old clients silently drop unknown fields |
| Server-authoritative with persistent store | Server-side migration + client adaptation layer | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | Medium — server must handle in-flight operations from pre-migration clients |
| Clients on different versions sharing a live document | Server normalizes to latest OR clients self-migrate | `get_docs("domain-codebooks", "schema-evolution cross-version sync")` | High — version mismatch during sync can corrupt shared state |
| Lazy migration (migrate records on read, not on deploy) | Per-record version tag + migrate-up-on-access | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | Low-medium — simple but creates mixed-version stores |
| E2EE system where server cannot inspect data | Encrypted extensible metadata escape hatch (ente MagicMetadata pattern) | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | Medium — client-only schema governance with no server-side validation |
| System at intersection of external specs and internal models | Multi-layer independent versioning with explicit converters (allmaps pattern) | `get_docs("domain-codebooks", "schema-evolution migration strategies")` | Medium — converter combinatorics grow; heuristic version detection is fragile |

## Step 3: Advise

### Principles

1. **Migrations are code, not data.** Define migrations as pure functions
   `(oldShape) => newShape` (and the reverse). Register them in a declared sequence with
   explicit version identifiers. Never store migration logic in the database.

2. **Bidirectional by default in multiplayer.** If any client can be behind, every
   migration must have a `down` path. A migration that cannot be reversed is a breaking
   change — treat it as one (version gate, not silent upgrade).

3. **Depend on types, not time.** Migration ordering should declare explicit
   `dependsOn` relationships between record types, not rely on execution order. tldraw's
   `MigrationSequence` pattern is the gold standard here.

4. **Additive changes are always safe; destructive changes never are.** Adding an
   optional field with a default is the only zero-risk schema change. Renaming, removing,
   or changing field semantics all require migration paths and cross-version negotiation.

5. **Version-tag everything that crosses a boundary.** Every record persisted or sent
   over the wire must carry its schema version. Without an explicit version tag, you
   cannot distinguish "old data" from "corrupt data."

6. **Test migrations against production snapshots.** Unit-testing a migration against a
   hand-crafted fixture tells you nothing about the shapes that actually exist in the
   wild. Snapshot-based migration tests are non-negotiable for production systems.

### Cross-References

- **[distributed-state-sync](../distributed-state-sync/)** — Migrations must compose with
  the sync protocol. A migration that changes record shape must also update sync
  serialization, conflict resolution, and presence handling.
- **[undo-under-distributed-state](../undo-under-distributed-state/)** — Undo across
  schema versions requires either version-tagged operations in the history stack or
  version-independent operation representations.
