# Eval Set: node-graph-evaluation-under-interactive-editing

## Should Trigger (10)

1. "My node graph is slow to update when I drag sliders — how should I cache results?"
2. "Should I recompile the entire shader graph on every change or do incremental compilation?"
3. "What's the best dirty propagation strategy for a visual programming editor?"
4. "How does Graphite evaluate its procedural node graph?"
5. "I'm building a Substance Designer-like tool — eager or lazy evaluation?"
6. "My computation graph uses Box<dyn> for type erasure — is there a better approach?"
7. "How to avoid redundant graph evaluations during a mouse drag operation?"
8. "What's the tradeoff between MemoNetwork-style hashing vs fine-grained dirty flags?"
9. "Should I use tagged union values or full type erasure for node I/O types?"
10. "How do Houdini and Nuke handle incremental cooking of their node graphs?"

## Should NOT Trigger (10)

1. "How do I set up a Webpack build pipeline?" (build system, not interactive graph)
2. "What's the best way to schedule DAG tasks in Airflow?" (ETL pipeline)
3. "How should I structure my Redux store?" (UI state, not computation graph)
4. "My React component re-renders too often" (reactive UI, use state-to-render-bridge)
5. "How to implement A* pathfinding on a graph?" (algorithm, not evaluation architecture)
6. "What database should I use for a knowledge graph?" (graph DB, not computation graph)
7. "How to train a neural network with a computation graph?" (ML training)
8. "What's the best CI/CD pipeline for my project?" (build pipeline)
9. "How to implement undo/redo in my editor?" (undo, use undo-under-distributed-state)
10. "How should I dispatch messages in my editor?" (message dispatch, use message-dispatch)
