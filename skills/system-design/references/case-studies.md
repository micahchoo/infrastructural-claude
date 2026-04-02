# System Design Case Studies

## Interview Strategy

1. **Requirements clarification**: Functional, non-functional, extended
2. **Estimation & constraints**: Traffic, storage, bandwidth, cache
3. **Data model design**: Entities, relationships, DB choice
4. **API design**: Simple interfaces with parameters and return types
5. **High-level component design**: Identify components, draft first design
6. **Detailed design**: Deep dive on major components, trade-offs
7. **Identify and resolve bottlenecks**: SPOFs, scaling, resilience

---

## URL Shortener (Bitly, TinyURL)

**Requirements**: Generate unique short URLs, redirect to original, links expire.

**Scale**: 100M writes/month, 10B reads/month (100:1 ratio), ~40 writes/s, ~4K reads/s.
**Storage**: 6TB for 10 years. **Cache**: ~35GB/day (20% of reads).

**Encoding approaches**:
- Base62 (A-Z, a-z, 0-9): 7 chars = ~3.5 trillion URLs. Simple but collision risk.
- MD5 → Base62: Collision/duplication issues.
- Counter + Zookeeper: Distributed counter with ranges per server. Non-duplicate, collision-resistant.
- **Key Generation Service (KGS)**: Pre-generates keys, stores in separate DB. Two tables (used/unused) with locking.

**Architecture**: API Server → KGS for keys → NoSQL DB + Redis cache → LB in front.

---

## WhatsApp (Messaging)

**Requirements**: 1-on-1 chat, groups (100 people), file sharing. 50M DAU, 2B messages/day.

**Scale**: 24K RPS, ~10.2TB storage/day, ~38PB for 10 years, ~120MB/s bandwidth.

**Key decisions**:
- **WebSockets** for real-time push (not long polling)
- **Heartbeat mechanism** for last-seen (or lazy update on last action)
- **Message queue** (SQS/RabbitMQ) → FCM/APNS for notifications
- **ACK-based** read receipts (deliveredAt, seenAt timestamps)
- **Object storage** (S3) for media; CDN for delivery
- **API Gateway** supporting multiple protocols (HTTP, WebSocket, TCP)

**Services**: User, Chat (WebSocket), Notification, Presence, Media, each with own data.

---

## Twitter (Social Media)

**Requirements**: Post tweets, follow users, newsfeed, search. 200M DAU, 1B tweets/day.

**Scale**: 12K RPS, ~5.1TB/day, ~19PB for 10 years.

**Newsfeed strategies**:
- **Pull (Fan-out on load)**: Generate feed on request. Fewer writes, more reads.
- **Push (Fan-out on write)**: Push to all followers on tweet. More writes, instant feeds.
- **Hybrid**: Push for normal users, pull for celebrities (high follower count).

**Ranking**: Affinity x Weight x Decay (EdgeRank-style) or ML models.

**Search**: Elasticsearch for full-text. Trending = cache frequent queries, update via batch jobs.

**Retweets**: New tweet with type=tweet, content=original_tweet_id.

---

## Netflix (Video Streaming)

**Requirements**: Stream/share video, upload content, search, comments. 200M DAU, 5M uploads/day.

**Scale**: 12K RPS, ~500TB/day, ~1,825PB for 10 years, ~5.8GB/s bandwidth.

**Video processing pipeline**:
1. **File Chunker**: Split by scenes (not fixed time). Better streaming experience.
2. **Content Filter**: ML model for copyright, piracy, NSFW checks. Failed → DLQ.
3. **Transcoder**: Decode → re-encode with target codecs (FFmpeg, AWS MediaConvert).
4. **Quality Conversion**: Generate 4K, 1440p, 1080p, 720p, etc.

**Streaming**: Netflix Open Connect (custom CDN with ISP partnerships, 1000+ locations). Adaptive bitrate streaming (HLS). Resume via offset in views table.

**Geo-blocking**: IP/region-based. CloudFront geographic restrictions or Route53 geolocation routing.

**Recommendations**: Collaborative filtering + Netflix Recommendation Engine (user profile, browsing behavior, watch history, device, search terms).

---

## Uber (Ride-hailing)

**Requirements**: See nearby cabs with ETA/pricing, book rides, track driver, accept/deny rides. 100M DAU, 10M rides/day.

**Scale**: 12K RPS, ~400GB/day, ~1.4PB for 10 years.

**Location tracking**: WebSockets (push model) for real-time. Background GPS pinging.

**Ride matching approaches**:
- SQL with lat/long range query: Not scalable.
- **Geohashing**: Compare geohash prefixes for proximity. Index in memory for fast retrieval.
- **Quadtrees**: Efficient 2D range queries. Update on location changes. Cache in Redis. Hilbert curve for range queries.

**Race conditions**: Mutex around ride matching. Transactional operations.

**Best drivers**: Rank nearby drivers by ratings, relevance, feedback. Broadcast to best first.

**Surge pricing**: Dynamic pricing during high demand / limited supply.

**Payments**: Third-party processor (Stripe/PayPal) + webhooks.

**Common resilience patterns across all case studies**:
- Multiple service instances
- Load balancers between all layers
- Read replicas for databases
- Distributed cache with replicas
- Dedicated message brokers (Kafka/NATS) for notifications
- Media compression to reduce storage costs
