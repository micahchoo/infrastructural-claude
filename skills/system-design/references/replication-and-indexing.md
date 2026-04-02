# Replication, Indexing, and Normalization

## Database Replication

### Master-Slave
Master serves reads/writes, replicates writes to slaves (read-only). Slaves can replicate to more slaves.
- **Pro**: Backups don't impact master, read scaling, slaves can resync without downtime
- **Con**: More hardware, master failure = downtime/data loss, all writes go to master, replication lag

### Master-Master
Both masters serve reads/writes and coordinate. Either can fail without total downtime.
- **Pro**: Read from both, distributed writes, quick failover
- **Con**: Complex setup, loose consistency or higher write latency, conflict resolution needed

### Sync vs Async Replication
- **Synchronous**: Written to primary and replica simultaneously. Always in sync. Higher latency.
- **Asynchronous**: Written to replica after primary. Near-real-time or scheduled. More cost-effective.

---

## Indexes

Trade slower writes + more storage for faster reads. Data structure pointing to actual data location.

### Dense Index
Entry for every row. Fast binary search. More maintenance and memory. No ordering required.

### Sparse Index
Entry for only some records. Less maintenance, less memory. Slower (scan after binary search). Requires ordered data.

---

## Normalization

Organizing data to eliminate redundancy and inconsistent dependencies.

### Database Anomalies (solved by normalization)
- **Insertion**: Can't insert without other attributes present
- **Update**: Redundant data causes partial update issues
- **Deletion**: Deleting data removes unrelated information

### Normal Forms
- **1NF**: No repeating groups, primary key, no mixed types
- **2NF**: 1NF + no partial dependencies
- **3NF**: 2NF + no transitive functional dependencies
- **BCNF**: 3NF + every functional dependency X→Y has X as super key

### Key Types
Primary, Composite, Super, Candidate, Foreign, Alternate, Surrogate.

---

## Denormalization

Add redundant data to avoid costly joins. Improves read performance at expense of write performance.

- **Pro**: Faster retrieval, simpler queries, fewer tables
- **Con**: Expensive inserts/updates, more complexity, data redundancy, inconsistency risk

Note: Denormalization ≠ reversing normalization.
