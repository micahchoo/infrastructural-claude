# Architectural Patterns

## N-Tier Architecture

Divides application into logical layers and physical tiers.

| Type | Layers |
|------|--------|
| 3-Tier | Presentation → Business Logic → Data Access |
| 2-Tier | Client → Data Store (no business logic layer) |
| 1-Tier | Everything on one machine |

- **Closed layer**: Can only call next layer down
- **Open layer**: Can call any layer below

**Pros**: Availability, security (layers as firewall), independent scaling, separate maintenance.
**Cons**: Complexity, network latency, hardware cost, network security management.

---

## Monoliths

Single self-contained application handling all functionality.

**Pros**: Simple development/debugging, fast internal communication, easy monitoring/testing, ACID support.
**Cons**: Hard maintenance at scale, tight coupling, tech stack lock-in, full redeploy on updates, single bug can crash system.

### Modular Monolith
Single deployment but code organized into independent modules. Reduces coupling while keeping deployment simplicity.

---

## Microservices

Collection of small, autonomous services. Each implements a single business capability.

### Characteristics
Loosely coupled, focused scope ("does one thing well"), organized around business capabilities, resilient/fault-tolerant, highly maintainable.

**Pros**: Independent deployment, agile teams, fault/data isolation, independent scaling, no tech stack lock-in.
**Cons**: Distributed system complexity, harder testing, expensive infrastructure, inter-service communication challenges, data consistency issues.

### Best Practices
- Model around business domain
- Loose coupling, high cohesion
- Isolate failures with resiliency strategies
- Communicate through well-designed APIs only
- Private data storage per service
- Fail fast with circuit breakers
- Backward-compatible API changes

### Distributed Monolith Warning Signs
Requires low-latency communication, doesn't scale easily, service dependencies, shared databases, tight coupling.

### Microservices vs SOA
SOA: maximize service reusability via service interfaces. Microservices: team autonomy and decoupling. SOA is broader scope.

### When NOT to Use Microservices
Start with monolith. Only adopt microservices when team is too large for shared codebase, teams block each other, clear business value exists, business is mature enough, and communication overhead is limiting.

---

## Message Brokers

Software enabling applications to communicate and exchange information. Translates between messaging protocols.

**Models**: Point-to-Point (message queues), Publish-Subscribe (pub/sub).

**vs Event Streaming**: Brokers support both patterns + guaranteed delivery + message tracking. Streaming (e.g., Kafka) is pub/sub only, more scalable, less fault tolerance features.

**vs ESB**: Brokers are lightweight alternatives. ESBs are complex, expensive, hard to maintain and scale.

**Examples**: NATS, Apache Kafka, RabbitMQ, ActiveMQ.

---

## Enterprise Service Bus (ESB)

Centralized component performing integrations, transformations, routing, protocol conversion.

**Pros**: Improved developer productivity, independent scaling, greater resilience.
**Cons**: Changes destabilize other integrations, SPOF, testing overhead, centralized management limits collaboration.

**Examples**: Azure Service Bus, IBM App Connect, Apache Camel, Fuse ESB.
