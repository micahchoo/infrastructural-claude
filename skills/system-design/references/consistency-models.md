# Consistency Models and Theorems

## ACID (SQL/Relational)

- **Atomic**: All operations succeed or all roll back
- **Consistent**: Database structurally sound after transaction
- **Isolated**: Transactions don't contend; appear sequential
- **Durable**: Completed writes persist through system failure

## BASE (NoSQL)

- **Basic Availability**: Database appears to work most of the time
- **Soft-state**: Stores don't have to be write-consistent; replicas don't need mutual consistency
- **Eventual consistency**: Data becomes consistent eventually; reads may return stale data

## ACID vs BASE
No universal right answer. ACID = simplicity and reliability. BASE = scale and resilience but requires developer knowledge of consistency constraints.

---

## CAP Theorem

A distributed system can deliver only 2 of 3: **Consistency**, **Availability**, **Partition tolerance**.

Since network partitions are inevitable, the real choice is C vs A:

| Type | Delivers | Sacrifices | Examples |
|------|----------|------------|----------|
| CA | Consistency + Availability | Partition tolerance | PostgreSQL, MariaDB |
| CP | Consistency + Partition tolerance | Availability | MongoDB, Apache HBase |
| AP | Availability + Partition tolerance | Consistency | Cassandra, CouchDB |

---

## PACELC Theorem

Extends CAP: during **P**artition, choose **A** or **C**; **E**lse (normal operation), choose **L**atency or **C**onsistency.

Addresses CAP's limitation: no provision for performance/latency. A database returning a response after 30 days is technically "available" under CAP but useless in practice.

---

## Transactions

A series of operations treated as a single unit of work. All succeed or all fail.

### States
Active → Partially Committed → Committed → Terminated
Active → Failed → Aborted → (Restart or Kill)

---

## Distributed Transactions

Operations across 2+ databases. All nodes must commit or all must abort.

### Two-Phase Commit (2PC)
1. **Prepare**: Coordinator asks all participants if ready. Abort unless all say yes.
2. **Commit**: If all prepared, coordinator tells all to commit. Rollback on failure.

Problems: Node crashes, coordinator crashes, blocking protocol.

### Three-Phase Commit (3PC)
Splits commit into pre-commit + commit. Pre-commit ensures all completed prepare phase. Each phase can timeout (avoids indefinite waits).

### Sagas
Sequence of local transactions. Each publishes event triggering the next. Failures trigger compensating transactions (undo).

**Coordination**:
- **Choreography**: Events trigger next steps across services
- **Orchestration**: Central orchestrator directs participants

**Challenges**: Hard to debug, cyclic dependency risk, no participant data isolation, testing requires all services running.
