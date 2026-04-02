# Eval Set: message-dispatch-in-stateful-editors

## Should Trigger (10)

1. "How should I structure the command/action dispatch system for my vector editor?"
2. "Messages pile up during drag operations and the UI flickers — how to batch them?"
3. "Adding a new message type requires changes in 3 places — how to reduce this?"
4. "My editor handler needs state from another handler — what's the best DI pattern?"
5. "Should I use a flat action registry like Excalidraw or hierarchical dispatch like Graphite?"
6. "How does Penpot's Potok event bus compare to typed enum dispatch?"
7. "What's the right dedup strategy to prevent redundant renders in my editor?"
8. "How to handle deferred messages that depend on async results like font loading?"
9. "Should frontend UI updates be sent immediately or batched per frame?"
10. "How does Krita's stroke priority queue work compared to Graphite's message dispatch?"

## Should NOT Trigger (10)

1. "How to set up Kafka for microservice event streaming?" (microservice messaging)
2. "What's the best Redux middleware for my React app?" (web app state, not editor)
3. "How to implement the actor model in Erlang?" (concurrency pattern)
4. "How should I structure my REST API endpoints?" (API design)
5. "What message queue should I use for background job processing?" (job queue)
6. "How to implement pub/sub with Redis?" (pub/sub system)
7. "My node graph evaluates slowly" (graph evaluation, use node-graph-evaluation)
8. "How to implement undo in my graph editor?" (undo, use undo-under-distributed-state)
9. "How should I handle WebSocket messages from the server?" (network protocol)
10. "What's the best event sourcing pattern for my database?" (event sourcing)
