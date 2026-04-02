# Databases

## Components
- **Schema**: Shape of data structure, enforcement varies
- **Table**: Rows and columns storing entity data
- **Column**: Set of values of a particular type
- **Row**: Single record/entity

## SQL (Relational) Databases

Tables with columns and rows. Primary keys identify rows, foreign keys create relationships. Follow ACID.

### Materialized Views
Pre-computed query results stored for reuse. Faster than base table queries. Good for complex/frequent queries.

### N+1 Query Problem
Data layer executes N extra queries instead of one. Common in GraphQL/ORMs. Fix with query optimization or dataloaders.

### Advantages
Simple, accessible, consistent, flexible.

### Disadvantages
Expensive maintenance, difficult schema evolution, performance hits (joins), poor horizontal scalability.

**Examples**: PostgreSQL, MySQL, MariaDB, Amazon Aurora.

---

## NoSQL Databases

No fixed schema. Follow BASE consistency.

### Document
Stores data in documents (JSON-like). Flexible, easy horizontal scaling, schemaless.
**Examples**: MongoDB, Amazon DocumentDB, CouchDB.

### Key-Value
Simple key-value pairs. Fast lookups, highly scalable. Limited querying.
**Examples**: Redis, Memcached, Amazon DynamoDB, Aerospike.

### Graph
Nodes, edges, properties. Fast relationship queries. No standardized query language.
**Use cases**: Fraud detection, recommendations, social networks.
**Examples**: Neo4j, ArangoDB, Amazon Neptune.

### Time Series
Optimized for timestamped data. Fast insertion/retrieval.
**Use cases**: IoT, metrics, monitoring, financial trends.
**Examples**: InfluxDB, Apache Druid.

### Wide Column
Schema-agnostic, column families. Handles petabytes.
**Use cases**: Analytics, attribute-based storage.
**Examples**: BigTable, Apache Cassandra, ScyllaDB.

### Multi-model
Combines relational, graph, key-value, document in one backend.
**Examples**: ArangoDB, Azure Cosmos DB, Couchbase.

---

## SQL vs NoSQL

| Dimension | SQL | NoSQL |
|-----------|-----|-------|
| Storage | Tables | Various (document, KV, graph, etc.) |
| Schema | Fixed, predefined | Dynamic, flexible |
| Querying | SQL (powerful, standardized) | Varies by database |
| Scalability | Vertical (expensive) | Horizontal (commodity hardware) |
| Reliability | ACID compliant | Often sacrifice ACID for performance |

**Choose SQL for**: Structured data, relational data, complex joins, transactions, fast index lookups.
**Choose NoSQL for**: Flexible schema, non-relational data, no complex joins, data-intensive workloads, high IOPS throughput.
