---
name: message-dispatch-advisor
description: >-
  Architectural advisor for message-passing as the sole mutation API in stateful editors and creative tools. NOT for microservice messaging, event sourcing for analytics, or pub/sub systems.

  Triggers: message dispatch editor, command pattern editor, action dispatch system, message batching dedup, editor mutation API, message handler architecture, frontend message bridge, message queue priority, editor command system, dispatch loop architecture, message deduplication strategy, handler context dependencies

  Diffused triggers: "how to structure editor commands", "messages pile up during drag", "UI flickers during batch updates", "adding a new message type requires changes everywhere", "handler needs state from another handler", "dedup redundant renders", "message cascade debugging"

  Libraries: Graphite, VS Code, Figma, Excalidraw, tldraw, Penpot, Krita

  Skip: microservice event buses (Kafka, RabbitMQ), Redux for web apps (unless editor-like), actor model concurrency (Erlang/Akka), database event sourcing, pub/sub notification systems
---

# Message Dispatch in Stateful Editors

Advisor for the tension between using messages as the sole mutation API (for decoupling, undo, replay) and the performance, debuggability, and ergonomics costs this introduces.

## Step 1: Classify

1. **Mutation model** — typed message enums (Graphite), record diffs (tldraw), action objects (Excalidraw), or event streams (Penpot)?
2. **Concurrency** — single-threaded dispatch (web), multi-threaded with priorities (Krita), or async event chains?
3. **Undo model** — messages are the undo unit, or undo is separate from dispatch?
4. **Frontend coupling** — messages cross a serialization boundary (WASM, IPC), or same-process?
5. **Scale** — dozens of message types (small editor) or hundreds (full creative suite)?

## Step 2: Identify Active Forces

| Force | Active when... | Reference |
|-------|---------------|-----------|
| Routing topology | >10 message types with different handlers | **dispatch-topology** |
| Redundant update performance | Interactive operations (drag, paint) generate high-frequency mutations | **batching-and-dedup** |
| Handler interdependencies | Handlers need state from other handlers to process messages | **context-and-dependencies** |

## Step 3: Cross-References

| Related Codebook | Interaction |
|-----------------|-------------|
| **node-graph-evaluation-under-interactive-editing** | Graph evaluation runs are dispatched messages; dedup controls evaluation frequency |
| **graph-as-document-model** | Document operations are expressed as dispatched messages (GraphOperationMessage) |
| **interactive-spatial-editing** | Tool state machine events become dispatched messages |
| **undo-under-distributed-state** | Messages may be the undo unit; batching affects undo granularity |

## Principles

1. **Messages are the mutation API, not an optimization.** If anything can bypass the message system and mutate state directly, the entire architecture's guarantees (undo, replay, logging) collapse. The message system must be the only path.

2. **Dedup and batching are separate concerns.** Dedup removes redundant messages (same effect, last one wins). Batching delays messages until a sync point (frame boundary). Graphite uses both: `SIDE_EFFECT_FREE_MESSAGES` for dedup, `FRONTEND_UPDATE_MESSAGES` for batching.

3. **Context construction is the hidden coupling.** Graphite's manual context construction (`DeferMessageContext`, `DialogMessageContext`, etc.) makes dependencies explicit but creates a maintenance burden. Every new handler dependency requires modifying the dispatcher.

4. **Hierarchical dispatch reduces cognitive load.** Graphite's `Message::Portfolio(PortfolioMessage::Document(DocumentMessage::NodeGraph(...)))` hierarchy means you only need to understand one level at a time. Flat dispatch (Excalidraw) is simpler for small systems but doesn't scale.

5. **The serialization boundary is a natural batching point.** WASM bridge, IPC, network — any serialization boundary is an opportunity to batch. Graphite's `FrontendMessage` outbox naturally batches all UI updates per dispatch cycle.
