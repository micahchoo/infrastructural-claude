# Migration Strategies for Distributed Persistent State

## The Problem

When schema evolves in a distributed system, three things break simultaneously:

1. **Persisted data becomes stale.** Documents saved under schema v1 must be readable
   under schema v2 — and in multiplayer, under v1 again when an old client reconnects.

2. **In-flight operations become ambiguous.** A client on v1 sends an operation that
   references a field renamed in v2. The server (or other peers) must interpret it
   correctly despite the version mismatch.

3. **Migration ordering becomes a DAG, not a list.** When multiple record types evolve
   independently but have cross-type references, migrations must respect dependency
   order. Migrating a child record before its parent can produce dangling references or
   shape mismatches.

The fundamental tension: you want schema evolution to be fast (ship new features, fix data
model mistakes) but you cannot force all clients to upgrade atomically. Every migration is
a commitment to support at least two schema versions simultaneously.

## Competing Patterns

### 1. Bidirectional Migration Sequences (tldraw)

**How it works:** Each record type declares a `MigrationSequence` — an ordered list of
migration functions, each with a unique version identifier. Each migration has both an
`up` function (old-to-new) and a `down` function (new-to-old). Sequences declare
`dependsOn` to specify cross-type ordering.

**Production example:**
```
// tldraw: packages/store/src/migrate.ts
MigrationSequence {
  sequenceId: 'com.tldraw.shape',
  retroactive: true,
  sequence: [
    { id: 'com.tldraw.shape/1', up: (r) => ..., down: (r) => ... },
    { id: 'com.tldraw.shape/2', up: (r) => ..., down: (r) => ... },
  ],
  dependsOn: ['com.tldraw.document'],
}
```

The `retroactive` flag allows migrations to be inserted into existing sequences without
breaking stores that were created before the migration existed — critical for long-lived
documents.

**When to use:** Complex multiplayer systems with many record types, long-lived documents,
and clients that may be multiple versions behind.

**Tradeoff:** High implementation cost. Every migration must have a correct `down` path.
Dependency DAG must be acyclic and complete. But it is the only pattern that provides
full cross-version safety.

### 2. Version-Gated Compatibility (Excalidraw)

**How it works:** Every element carries `version` and `versionNonce` fields. The
`version` counter increments on every mutation. Schema changes are designed to be
backward-compatible: new fields are optional with defaults, old fields are never removed.
When a client encounters an unknown field, it preserves it (pass-through) rather than
dropping it.

**Production example:**
```
// excalidraw: packages/excalidraw/element/types.ts
type ExcalidrawElement = {
  version: number;
  versionNonce: number;
  // ... all fields optional or with defaults
}
```

Old clients seeing data from new clients simply ignore unknown properties. New clients
seeing data from old clients fill in defaults. No explicit migration functions exist —
the schema is designed so that migration is implicit in the type system.

**When to use:** Simpler schemas where additive-only evolution is feasible. Works well
when the element model is relatively flat (no deep cross-type dependencies).

**Tradeoff:** Low implementation cost but constrains schema evolution severely. You can
never rename or remove a field. Over time, the schema accumulates legacy fields that
cannot be cleaned up without a breaking version gate.

### 3. Server-Side Migration with Client Adaptation (Penpot)

**How it works:** The server is the source of truth and runs migrations on persistent
state during deployment. Clients receive data in the latest schema version. A change
algebra layer translates client operations into version-appropriate mutations.

**Production example:**
```
;; penpot: common/src/app/common/types/*.cljc
;; Schema definitions in .cljc files compile to both JVM (server) and JS (client).
;; Server runs migrations on the canonical store.
;; Client-side code uses the same type definitions for validation.
```

The `.cljc` (cross-platform Clojure) files ensure that schema definitions are identical
on server and client. Migrations run server-side; the client adapts to whatever the
server sends.

**When to use:** Server-authoritative architectures where the server can run migrations
during a maintenance window or rolling deploy. The server can handle in-flight operations
from old clients via an adaptation layer.

**Tradeoff:** Requires a server. Does not work for peer-to-peer or offline-first
architectures. Migration downtime (even if brief) is unavoidable during deploys.

### 4. Lazy Migration on Read

**How it works:** Records carry a version tag. When a record is read, the reader checks
the version and applies migrations up to the current version before using the data. The
migrated record may or may not be written back.

**When to use:** Systems with large stores where migrating everything at deploy time is
too expensive. Common in document databases and event-sourced systems.

**Tradeoff:** Simple to implement but creates mixed-version stores. Every read path must
handle every historical version. Performance cost is paid on every read (unless
write-back is enabled, which creates write amplification).

## Decision Guide

```
Is the system multiplayer with heterogeneous client versions?
├── Yes
│   ├── Are there cross-type migration dependencies?
│   │   ├── Yes → Bidirectional Migration Sequences (tldraw pattern)
│   │   └── No → Version-Gated Compatibility (excalidraw pattern)
│   └── Is there a single authoritative server?
│       ├── Yes → Server-Side Migration + Adaptation (penpot pattern)
│       └── No → Bidirectional Migration Sequences (only safe option for P2P)
└── No (single-client or atomic-deploy)
    ├── Is the data store very large?
    │   ├── Yes → Lazy Migration on Read
    │   └── No → Standard forward-only migration (Rails/Django style)
    └── Done
```

### 5. Encrypted Extensible Metadata Escape Hatch (Ente)

**How it works:** Rather than evolving the server schema for every new client-side
feature, the system defines a generic `MagicMetadata` field — an encrypted JSON blob
that the server stores but cannot read. Clients encrypt arbitrary key-value metadata
into this field, avoiding server schema changes entirely. The server schema only knows
that `MagicMetadata` exists; it never parses its contents.

Meanwhile, the server itself has 117 numbered SQL migrations with up/down pairs
(PostgreSQL). Each client surface maintains independent migration infrastructure:
web uses KV-based integer migration levels (0-5) with prunable steps, mobile uses
versioned SQLite schemas (`schema.dart`, `ml_versions.dart`), and the Rust `ensu-db`
has its own `migrations.rs` and `attachments_migrations.rs`.

**Production example:**
```
-- Server: 117 migrations in server/migrations/ (e.g., 63_add_kex_store.up.sql)
-- Each has .up.sql and .down.sql

-- Collection model (server/ente/collection.go):
type Collection struct {
    EncryptedKey   string
    EncryptedName  string
    MagicMetadata  *MagicMetadata  // encrypted extensible JSON — no server schema change needed
}

// Web client: migration.ts with numbered levels
// Mobile: schema.dart with SQLite versioned schemas
// Rust: ensu-db/src/migrations.rs
```

**When to use:** End-to-end encrypted systems where the server cannot inspect data,
or any system where server deploys are expensive but client-side feature iteration is
fast. The escape hatch lets clients evolve their data model without coordinating server
schema changes.

**Tradeoff:** The server loses all ability to query, index, or validate the contents
of `MagicMetadata`. Schema evolution of the encrypted payload is entirely the client's
responsibility — clients must handle unknown keys, version detection within the blob,
and backward compatibility with no server-side safety net. Multi-surface coordination
(Flutter, web, Rust, CLI) of the blob's internal schema becomes an implicit contract
with no central enforcement.

### 6. Multi-Layer Independent Versioning (Allmaps)

**How it works:** Three versioning layers evolve independently, each with its own
version numbers and conversion logic:

1. **External spec versions** — IIIF Presentation API v1/v2/v3 and Image API v1/v2/v3.
   Detected via heuristics (`@context` and `@id` field presence). Parsed into a unified
   internal model using Zod union schemas.
2. **Application annotation format versions** — Allmaps Annotation v0/v1 and
   GeoreferencedMap v1/v2. `convert.ts` provides explicit conversion functions
   (`toGeoreferencedMap2()`, `toAnnotation1()`) via round-trip parse-then-generate.
3. **Editor DB schema versions** — DbMap v1/v2/v3, the internal persistence format used
   by the collaborative editor (backed by ShareDB + JSON1 OT).

**Production example:**
```
// packages/annotation/src/schemas/ — versioned Zod schemas
//   georeferenced-map/georeferenced-map-1.ts
//   georeferenced-map/georeferenced-map-2.ts
//   annotation/annotation-0.ts, annotation-1.ts

// packages/annotation/src/convert.ts
toGeoreferencedMap2(map: GeoreferencedMap1): GeoreferencedMap2
toAnnotation1(annotation: Annotation0): Annotation1

// apps/editor/src/lib/schemas/maps.ts — DbMap1, DbMap2, DbMap3
// packages/iiif-parser/src/classes/iiif.ts — IIIF.parse() with version detection
```

**When to use:** Systems that sit at the intersection of external standards and
internal data models, especially when the external standards evolve on their own
cadence (controlled by a standards body, not by you). Each layer can version
independently because the conversion boundaries are explicit.

**Tradeoff:** Conversion functions multiply combinatorially — each layer pairing
requires explicit converters. Version detection for external specs relies on heuristics
rather than explicit version tags, which is fragile when specs have ambiguous overlaps.
The system must maintain parsers for every historical version of every layer
indefinitely, since external documents in the wild are never migrated.

## Anti-Patterns

### Big-Bang Migration
Running a single migration that transforms all data at once, requiring all clients to be
offline. Fails in any system with real-time collaboration because you cannot guarantee all
clients disconnect.

### Breaking Changes Without Version Gates
Removing or renaming a field without a migration path. Old clients crash or silently
corrupt data. This is the most common source of data loss in collaborative apps.

### Migration Logic in the Database
Storing migration functions as data (e.g., in a migrations table) rather than as code.
Makes testing impossible and creates a circular dependency: you need the database to know
how to migrate, but you need to migrate to read the database.

### Implicit Version Detection
Inferring the schema version from the shape of the data ("if it has field X, it must be
v2"). Fragile, untestable, and fails on any record that happens to match multiple version
shapes.

### One-Way Migrations in Multiplayer
Writing only `up` migrations in a system where clients can be behind. The first time an
old client connects, the server cannot translate data back, and the client either crashes
or shows corrupt state.
