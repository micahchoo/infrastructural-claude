# Clustering and Availability

## Clustering

A group of nodes running in parallel to achieve a common goal. Combines memory and processing power.

### Types
- **Highly available / fail-over**
- **Load balancing**
- **High-performance computing**

### Configurations
- **Active-Active**: All nodes serve traffic simultaneously. Achieves load balancing + throughput improvement.
- **Active-Passive**: Only active nodes serve. Passive nodes on standby for failover.

### Advantages
High availability, scalability, performance, cost-effective.

### Load Balancing vs Clustering
Clustering: servers are aware of each other, work together. Load balancing: servers are independent, react to LB requests. Can be used together.

### Challenges
Complex installation/maintenance, non-homogeneous nodes, storage management (shared storage conflicts, distributed sync), log aggregation.

**Examples**: Kubernetes, Amazon ECS, Cassandra, MongoDB, Redis Cluster.

---

## Availability

Percentage of time a system remains operational.

$$Availability = Uptime / (Uptime + Downtime)$$

### The Nines

| Availability | Downtime/Year | Downtime/Month | Downtime/Week |
|-------------|---------------|----------------|---------------|
| 90% (one 9) | 36.53 days | 72 hours | 16.8 hours |
| 99% (two 9s) | 3.65 days | 7.20 hours | 1.68 hours |
| 99.9% (three 9s) | 8.77 hours | 43.8 min | 10.1 min |
| 99.99% (four 9s) | 52.6 min | 4.32 min | 1.01 min |
| 99.999% (five 9s) | 5.25 min | 25.9 sec | 6.05 sec |

### Sequence vs Parallel
- **Sequence**: Total = A(Foo) * A(Bar) — availability decreases
- **Parallel**: Total = 1 - (1-A(Foo)) * (1-A(Bar)) — availability increases

### Availability vs Reliability
Reliable → available. Available does NOT mean reliable.

### High Availability vs Fault Tolerance
- **HA**: Minimal service interruption, lower cost
- **Fault Tolerance**: Zero interruption, full hardware redundancy, significantly higher cost

---

## Scalability

### Vertical Scaling (Scale Up)
Add more power to existing machine. Simple, consistent, but risks SPOF and downtime.

### Horizontal Scaling (Scale Out)
Add more machines. Better fault tolerance, flexible, but increases complexity and potential data inconsistency.

---

## Storage Types

| Type | Description | Example |
|------|-------------|---------|
| RAID 0 | Striping, no redundancy | - |
| RAID 1 | Mirroring | - |
| RAID 5 | Striping + parity (3+ drives) | - |
| RAID 10 | Striping + mirroring | - |
| File Storage | Hierarchical directories | Amazon EFS, Azure Files |
| Block Storage | Data in chunks with unique IDs | Amazon EBS |
| Object Storage | Objects in distributed repository | Amazon S3, Azure Blob |
| NAS | Network-attached, central location | - |
| HDFS | Distributed file system, fault-tolerant | Hadoop |
