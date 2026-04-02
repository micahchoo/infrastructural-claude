# Cross-Version Sync: Clients on Different Schema Versions

## The Problem

In a multiplayer document editor, Client A is on app version 2.3 (schema v5) and
Client B is on version 2.1 (schema v3). Both are editing the same document in real time.

Three things must be true simultaneously:

1. **Client A's writes must be intelligible to Client B** — even though B doesn't know
   about fields added in schema v4 and v5.
2. **Client B's writes must be intelligible to Client A** — even though B's data is
   missing fields that A expects.
3. **Neither client's writes may corrupt the other's state** — a round-trip through
   both clients must not lose data, even data that one client doesn't understand.

This is harder than standard API versioning because both clients are writing to the same
shared mutable state. There is no request/response boundary where a server can translate
between versions — operations interleave in real time.

## Competing Patterns

### 1. Server Normalizes to Latest (tldraw)

**How it works:** The sync server (`TLSyncRoom`) maintains the document in the latest
schema version. When a client connects, the server checks the client's schema version.
If the client is behind, the server uses `down` migrations to translate records into the
client's expected schema before sending them. When the client sends updates, the server
uses `up` migrations to translate them to the latest version before applying.

**Production example:**
```
// tldraw: packages/sync/src/lib/TLSyncRoom.ts
// On client connect:
//   1. Determine client's schema version from handshake
//   2. For each record in the document:
//      - Apply down-migrations from server version to client version
//      - Send migrated record to client
// On client update:
//   1. Apply up-migrations from client version to server version
//   2. Apply to canonical store
//   3. Broadcast to other clients (each gets their version-appropriate translation)
```

The server is the translation layer. It holds the canonical state at the latest version
and translates on the fly for each client. This requires bidirectional migrations for
every version step.

**When to use:** Server-mediated sync with a central room/document model. The server
has enough context to translate between versions.

**Tradeoff:** The server does O(clients x records) translation work on every change.
Migration functions must be fast and pure. Any bug in a `down` migration corrupts every
old client's view.

### 2. Clients Self-Migrate (Excalidraw approach)

**How it works:** Each client is responsible for understanding the data it receives. The
sync layer transmits elements as-is, with their version metadata. When a client receives
an element with unknown fields, it preserves them as opaque data. When a client receives
an element missing expected fields, it fills in defaults.

**Production example:**
```
// excalidraw: collaboration via element-level version tracking
// Each element carries: { version, versionNonce, ... }
// Client receives element:
//   - Known fields → use directly
//   - Unknown fields → preserve in object, do not render
//   - Missing fields → fill from defaults
// Client sends element:
//   - Includes all fields (including opaque ones received from newer clients)
```

The key invariant: clients never strip unknown fields. An element round-tripping through
an old client retains all fields added by a newer client. This is "pass-through
preservation."

**When to use:** Systems where the element schema is flat (no cross-type references that
change shape), additive-only evolution is enforced, and the sync protocol treats elements
as opaque blobs with metadata.

**Tradeoff:** Cannot handle structural changes (field renames, type changes, field
removal). The schema can only grow, never shrink. Works well for years until the
accumulated schema debt becomes unmanageable.

### 3. Dual-Write with Version Negotiation

**How it works:** During a transition period, the system writes data in both old and new
schema formats. Clients declare their supported version range during connection. The
server sends whichever format the client supports. Once all clients have upgraded past
the old version, the old format is retired.

**When to use:** Large deployments where you control the client rollout (e.g., managed
enterprise apps) and can track which versions are still active.

**Tradeoff:** Storage doubles during the transition. Write paths are complex (must
produce both formats atomically). Retirement of old formats requires tracking active
client versions — one stale client blocks cleanup.

## Decision Guide

```
Do you control the sync server?
├── Yes
│   ├── Can you require bidirectional migrations?
│   │   ├── Yes → Server Normalizes to Latest (tldraw pattern)
│   │   │         Best correctness guarantees. Server is single translation point.
│   │   └── No → Dual-Write with Version Negotiation
│   │             Trades storage for simpler migration code.
│   └── Is the schema additive-only?
│       ├── Yes → Clients Self-Migrate (excalidraw pattern)
│       │         Simplest. No server translation. But constrains evolution.
│       └── No → Server Normalizes to Latest (only safe option)
└── No (peer-to-peer)
    ├── Is the schema additive-only?
    │   ├── Yes → Clients Self-Migrate with pass-through preservation
    │   └── No → Each peer must carry full bidirectional migration stack
    │             (equivalent to every peer being a "server" in the tldraw pattern)
    └── Done
```

## Protocol Design Considerations

### Handshake Version Declaration

Every sync connection must begin with a version handshake. The client declares its schema
version; the server (or peer) determines whether it can serve that version.

```
Client → Server: { protocolVersion: 5, schemaVersion: 3 }
Server → Client: { status: "compatible", effectiveVersion: 3 }
  OR
Server → Client: { status: "incompatible", minimumVersion: 4, upgradeUrl: "..." }
```

Refusing to connect is always safer than silently degrading. If the server cannot
translate to the client's version (because a migration is not reversible), the correct
response is to reject the connection with an upgrade prompt.

### Change Propagation with Version Context

When broadcasting a change to multiple clients on different versions:

1. Apply the change to the canonical (latest-version) store.
2. For each connected client, translate the changed records to that client's version.
3. Send only the translated diff, not the full document.

This means the server must track per-client schema version for the lifetime of the
connection.

### Conflict Resolution Across Versions

When two clients on different versions edit the same record:

- The server must up-migrate the old client's change before conflict resolution.
- Conflict resolution always happens at the latest schema version.
- The resolved result is then down-migrated for each client.

Never attempt conflict resolution between two different schema versions — the field
semantics may have changed, making comparison meaningless.

## Anti-Patterns

### Version-Blind Broadcasting
Sending the same record bytes to all clients regardless of their schema version. Old
clients silently misparse new fields; new clients crash on missing fields. This is the
most common cause of "phantom data loss" in collaborative apps.

### Schema Negotiation to Lowest Common Denominator
Downgrading the entire document to the oldest connected client's version. Penalizes all
users for one stale client. New features become unusable until every client upgrades.

### Optimistic Version Tolerance Without Pass-Through
Clients that ignore unknown fields AND drop them on write-back. A single edit by an old
client strips all fields added by newer clients. Data loss is silent and permanent.

### Migrating the Sync Stream Instead of the Store
Applying migrations to the stream of operations rather than to the stored records.
Operations are context-dependent (they reference the state at the time of creation);
migrating them in isolation produces nonsensical results. Always migrate the materialized
state, not the operation log.
