# Messaging and Event Patterns

## Message Queues

Asynchronous service-to-service communication. Messages stored until processed and deleted. Each message processed once by one consumer.

### Advantages
Scalability (no collision on peaks), decoupling, performance (async), reliability (persistent data).

### Key Features
- **Push/Pull delivery** (+ long-polling)
- **FIFO ordering**
- **Scheduled/delayed delivery**
- **At-least-once** or **exactly-once** delivery
- **Dead-letter queues** (failed messages set aside)
- **Poison-pill messages** (signal consumer to stop)
- **Task queues** (run compute-intensive jobs)

### Backpressure
Limit queue size to maintain throughput. Return HTTP 503 when full. Clients retry with exponential backoff.

**Examples**: Amazon SQS, RabbitMQ, ActiveMQ, ZeroMQ.

---

## Publish-Subscribe

Message published to topic is pushed immediately to all subscribers. Publisher doesn't know subscribers; subscribers don't know publisher.

### vs Message Queues
Queues batch until retrieved. Topics push immediately to all subscribers.

### Advantages
Eliminates polling, dynamic targeting (subscribers change freely), decoupled independent scaling, simplified communication (single topic connection).

### Features
Push delivery, multiple delivery protocols, fanout (replicate to multiple endpoints), filtering (subscriber message policies), durability (at-least-once via multi-server storage), security.

**Examples**: Amazon SNS, Google Pub/Sub.

---

## Event-Driven Architecture (EDA)

Events communicate state changes within a system. Publisher unaware of consumers; consumers unaware of each other. Achieves loose coupling.

**Components**: Event producers → Event routers (filter/push) → Event consumers.

**Implementation patterns**: Sagas, Pub/Sub, Event Sourcing, CQRS.

**Pros**: Decoupled, scalable, easy to add consumers.
**Cons**: Guaranteed delivery is hard, error handling difficult, complex, in-order processing is challenging.

**Examples**: NATS, Apache Kafka, Amazon EventBridge, Amazon SNS, Google PubSub.

---

## Event Sourcing

Store full series of actions (events) instead of just current state. Append-only store. Events can reconstruct domain objects.

**vs EDA**: EDA uses events for inter-service communication. Event sourcing uses events as state storage. Event sourcing is one pattern to implement EDA.

**Pros**: Real-time reporting, fail-safety (reconstitute from events), flexible, audit logs.
**Cons**: Requires efficient network, reliable schema registry, varying event payloads.

---

## CQRS (Command and Query Responsibility Segregation)

Separate commands (write, no return value) from queries (read, no side effects). Each can be optimized independently.

### With Event Sourcing
Event store = write model (source of truth). Read model = materialized views (denormalized).

**Pros**: Independent read/write scaling, closer to business logic, avoids complex joins, clear system boundaries.
**Cons**: More complex design, message failures/duplicates, eventual consistency challenges, increased maintenance.

**Use when**: Read/write performance must be tuned separately, system evolves with multiple model versions, integration with event sourcing, better write security needed.
