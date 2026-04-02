# Caching

Increases data retrieval performance by reducing access to slower storage. Trades capacity for speed. Exploits locality of reference: "recently requested data is likely requested again."

## Cache Hit vs Miss
- **Hit**: Data found in cache. Hot (L1, fastest), Warm (L2/L3), Cold (lower levels, slowest hit).
- **Miss**: Data not in cache. Written into cache for next retrieval.

## Cache Invalidation Strategies

### Write-Through
Data written to cache AND database simultaneously.
- Pro: Fast retrieval, complete consistency
- Con: Higher write latency

### Write-Around
Writes go directly to database, bypassing cache.
- Pro: Reduces cache pollution
- Con: Higher read latency on cache miss (must fetch from DB)

### Write-Back
Writes only to cache, async sync to database.
- Pro: Low write latency, high throughput
- Con: Risk of data loss if cache crashes. Mitigate with replicas.

## Eviction Policies

| Policy | Description |
|--------|-------------|
| FIFO | Evicts first block accessed first |
| LIFO | Evicts most recently accessed first |
| LRU | Evicts least recently used (most common) |
| MRU | Evicts most recently used |
| LFU | Evicts least frequently used |
| Random | Random eviction |

## Cache Types

### Distributed Cache
Pools RAM across multiple networked computers. Grows beyond single machine memory limits.

### Global Cache
Single shared cache for all application nodes. Cache is responsible for fetching missing data.

## When NOT to Cache
- Access time same as primary store
- Low request repetition (high randomness)
- Data changes frequently (constant invalidation)
- Never use cache as permanent storage (volatile memory)

## Advantages
Improved performance, reduced latency, reduced DB load, reduced network cost, increased read throughput.

**Examples**: Redis, Memcached, Amazon ElastiCache, Aerospike.
