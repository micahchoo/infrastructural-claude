# Infrastructure Patterns

## Geohashing

Encodes lat/long into short alphanumeric strings. Hierarchical spatial index using Base-32.

- Points with longer shared prefix are spatially closer
- Provides anonymity (area vs exact location)
- Geohash length 6 ≈ 1.22km x 0.61km cell

**Used in**: MySQL, Redis, DynamoDB, Cloud Firestore.

## Quadtrees

Tree where each internal node has exactly 4 children. Recursively subdivides 2D space.

- Efficient 2D range queries
- Can threshold subdivision (only split after N points)
- Hilbert curve mapping improves range query performance

**Use cases**: Image processing, spatial indexing, location services (Google Maps, Uber), mesh generation.

---

## Circuit Breaker

Wraps protected calls to detect and prevent recurring failures.

### States
- **Closed**: Normal operation, requests pass through. Trips to Open if failures exceed threshold.
- **Open**: Returns errors immediately without making calls. After timeout → Half-open.
- **Half-open**: Allows limited requests. Success → Closed. Failure → Open.

---

## Rate Limiting

Prevents operation frequency from exceeding a defined limit.

### Why
Prevent DoS, control costs (auto-scaling caps), defense against attacks, control data flow.

### Algorithms

| Algorithm | Description |
|-----------|-------------|
| Leaky Bucket | Queue-based, FIFO processing at fixed rate, overflow discarded |
| Token Bucket | Tokens consumed per request, bucket refills over time |
| Fixed Window | Counter per time window, discard if threshold exceeded |
| Sliding Log | Timestamped log per request, sum within window |
| Sliding Window | Hybrid: fixed window counter + weighted previous window |

### Distributed Challenges
- **Inconsistencies**: Per-node limits allow global limit bypass. Solutions: sticky sessions or centralized store (Redis).
- **Race conditions**: Get-then-set allows burst bypass. Solution: set-then-get (atomic operations).

---

## Service Discovery

Detecting services in a network. Needed because microservice instances change dynamically.

### Patterns
- **Client-side**: Client queries service registry directly
- **Server-side**: Client → Load balancer → Service instance

### Service Registration
- **Self-registration**: Service registers/deregisters itself + heartbeats
- **Third-party**: Registry polls deployment environment or subscribes to events

### Service Mesh
Managed, observable, secure service-to-service communication. **Examples**: Istio, Envoy.

**Discovery tools**: etcd, Consul, Apache Thrift, Apache Zookeeper.

---

## SLA / SLO / SLI
- **SLA** (Service Level Agreement): Company promise to users (business/legal)
- **SLO** (Service Level Objective): Specific metric goals within SLA
- **SLI** (Service Level Indicator): Measured value determining if SLO is met

---

## Disaster Recovery

### Key Metrics
- **RTO** (Recovery Time Objective): Max acceptable downtime
- **RPO** (Recovery Point Objective): Max acceptable data loss since last recovery

### Strategies
- **Backup**: Store data off-site/removable drive
- **Cold Site**: Basic infrastructure at second site
- **Hot Site**: Up-to-date data copies at all times (expensive, minimal downtime)

---

## VMs vs Containers

| Aspect | VMs | Containers |
|--------|-----|------------|
| Virtualization | Hardware (hypervisor) | OS-level |
| Includes | Guest OS + app | App + dependencies only |
| Size | Heavy | Lightweight |
| Isolation | Full OS isolation | Process-level isolation |
| Portability | Less portable | Highly portable |

---

## OAuth 2.0 & OpenID Connect

### OAuth 2.0 (Authorization)
Grants access to resources on behalf of user without sharing credentials.

**Entities**: Resource Owner, Client, Authorization Server, Resource Server, Scopes, Access Token.

**Flow**: Client requests auth → Server authenticates → Owner grants → Token issued → Client accesses resources.

### OpenID Connect (Authentication)
Thin layer on OAuth 2.0 adding login/profile info. Uses JWT tokens.

---

## Single Sign-On (SSO)

One set of credentials for multiple applications.

**Components**: Identity Provider (IdP), Service Provider, Identity Broker.

**SAML**: XML-based, enterprise-focused, session cookies.
**OAuth/OIDC**: JSON-based, RESTful, developer-friendly, mobile-friendly.

**Examples**: Okta, Google, Auth0, OneLogin.

---

## SSL / TLS / mTLS

- **SSL**: Deprecated encryption protocol (1995)
- **TLS**: Successor. Encryption + Authentication + Integrity.
- **mTLS**: Mutual authentication. Both client and server verify each other. Used in zero-trust microservices.
