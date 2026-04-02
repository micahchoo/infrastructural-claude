# Sharding, Partitioning, and Consistent Hashing

## Data Partitioning

Breaking a database into smaller parts for manageability, performance, and availability.

- **Horizontal Partitioning (Sharding)**: Split rows by partition key range
- **Vertical Partitioning**: Split columns into smaller tables

## Sharding

Each partition (shard) has same schema but unique subset of data. Cheaper to scale horizontally than vertically after a certain point.

### Partitioning Criteria

| Method | Description | Disadvantage |
|--------|-------------|--------------|
| Hash-Based | Hash algorithm determines partition | Adding/removing servers is expensive |
| List-Based | Partition by list of values on a column | - |
| Range-Based | Partition by contiguous value ranges | Uneven distribution possible |
| Composite | Combine two or more techniques | Complexity |

### Advantages
Availability (independent partitions), scalability, security (sensitive data isolation), query performance, data manageability.

### Disadvantages
Complexity, cross-shard joins (expensive), rebalancing needed for uneven distribution.

### When to Shard
- Leverage existing hardware over high-end machines
- Geographic data separation
- Quick scaling via more shards
- Need more concurrent connections

---

## Consistent Hashing

Solves the problem of traditional hash-based distribution where adding/removing nodes requires massive redistribution.

### Problem with Simple Hashing
`Hash(key) mod N` breaks when N changes — majority of keys need redistribution.

### How It Works
Assign nodes and keys positions on a hash ring. Route each key to the nearest node clockwise.

When adding/removing a node, only `K/N` keys need redistribution (K=total keys, N=total nodes).

### Virtual Nodes (VNodes)
Each physical node mapped to multiple positions on the ring. Ensures more even load distribution. Speeds up rebalancing. Reduces hotspot probability.

### Data Replication
Each item replicated on N nodes (replication factor). In eventually consistent systems, done asynchronously.

### Advantages
Predictable scaling, facilitates partitioning/replication, reduces hotspots.

### Disadvantages
Increased complexity, cascading failures, still possible uneven distribution, expensive key management during transient failures.

**Used in**: Apache Cassandra (partitioning), Amazon DynamoDB (load distribution).

---

## Database Federation

Functional partitioning: split databases by function. Multiple physical databases appear as one logical database via federal schemas.

### Characteristics
Transparency, heterogeneity, extensibility, autonomy, data integration.

### Disadvantages
More hardware/complexity, cross-database joins are complex, dependent on autonomous sources, query performance challenges.
