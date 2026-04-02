# APIs and Communication Patterns

## REST

Conforms to REST architectural constraints. Fundamental unit: **resource**.

### Constraints
Uniform Interface, Client-Server, Stateless, Cacheable, Layered System, Code on Demand (optional).

### HTTP Verbs
GET, HEAD, POST, PUT, DELETE, PATCH.

### Response Codes
1xx (informational), 2xx (success), 3xx (redirect), 4xx (client error), 5xx (server error).

**Pros**: Simple, flexible, good caching, decoupled.
**Cons**: Over-fetching, multiple round trips.

---

## GraphQL

Query language giving clients exactly the data they request. Fundamental unit: **query**.

- **Schema**: Describes available functionality
- **Queries/Mutations**: Client requests with specific fields
- **Resolvers**: Functions generating responses

**Pros**: No over-fetching, strong schema, code generation, payload optimization.
**Cons**: Server-side complexity, hard caching, ambiguous versioning, N+1 problem.

**Best for**: Reducing bandwidth, rapid prototyping, graph-like data models.

---

## gRPC

High-performance RPC framework using Protocol Buffers for serialization.

- **Protocol Buffers**: Language-neutral, smaller/faster than JSON, generates native bindings
- **Service Definition**: IDL-based, specifies remote methods with params and return types

**Pros**: Lightweight, high performance, built-in codegen, bi-directional streaming.
**Cons**: Relatively new, limited browser support, steeper learning curve, not human-readable.

**Best for**: Real-time bi-directional streaming, efficient microservice communication, low-latency needs, polyglot environments.

---

## Comparison

| Aspect | REST | GraphQL | gRPC |
|--------|------|---------|------|
| Coupling | Low | Medium | High |
| Chattiness | High | Low | Medium |
| Performance | Good | Good | Great |
| Complexity | Medium | High | Low |
| Caching | Great | Custom | Custom |
| Codegen | Bad | Good | Great |
| Discoverability | Good | Good | Bad |
| Versioning | Easy | Custom | Hard |

No silver bullet — choose based on domain and requirements.

---

## API Gateway

Single entry point encapsulating internal architecture. Sits between clients and backend services.

**Features**: Auth, service discovery, reverse proxy, caching, security, circuit breaking, load balancing, logging, rate limiting, versioning, routing.

**Pros**: Encapsulates internals, centralized view, simpler client code, monitoring.
**Cons**: Possible SPOF, performance impact, bottleneck risk, complex configuration.

### Backend For Frontend (BFF)
Separate backends per frontend type. Avoids customizing one backend for multiple interfaces. GraphQL works well as BFF.

**Examples**: Amazon API Gateway, Apigee, Azure API Gateway, Kong.

---

## Long Polling, WebSockets, SSE

### Long Polling
Server holds connection until new data or timeout. Client immediately reconnects after response.
- **Pro**: Easy to implement, universal support
- **Con**: Not scalable, new connection each time, ordering issues, increased latency

### WebSockets
Full-duplex persistent TCP connection. Both parties can send data anytime.
- **Pro**: Full-duplex async, lightweight, better security
- **Con**: No auto-recovery on disconnect

### Server-Sent Events (SSE)
Server pushes data to client over persistent connection. Unidirectional only.
- **Pro**: Simple, browser support, firewall-friendly
- **Con**: One-way only, limited connections, no binary data
