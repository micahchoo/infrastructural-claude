# Seam Types

A seam is a point where behavior can be altered without editing surrounding code. Identifying seams reveals the actual dependency structure and coupling topology of a codebase. Term and taxonomy from Michael Feathers' *Working Effectively with Legacy Code*.

## Object Seams

**What**: Interfaces, abstract classes, dependency injection points — behavior changes by swapping implementations.

**Enabling point**: The binding site where the implementation is chosen. Constructor injection, factory method, configuration, service locator.

**Examples from real codebases:**
- **tldraw's ShapeUtil**: Abstract base class with implementations for Rectangle, Ellipse, Arrow, etc. Each ShapeUtil defines how a shape renders, hit-tests, and serializes. The enabling point is the shape type registry.
- **Raft's Transport interface**: `transport.go` defines the contract. `NetworkTransport` (TCP) and `InmemTransport` (testing) implement it. The enabling point is the Raft config.
- **PyTorch Lightning's Strategy**: DDP, FSDP, DeepSpeed as pluggable distributed training strategies. The enabling point is Trainer configuration.

**Pattern labels**: Strategy, Template Method, Abstract Factory, Dependency Injection.

## Link Seams

**What**: Module boundaries — behavior changes by swapping what's imported or linked.

**Enabling point**: The import statement, build configuration, or module resolution.

**Examples:**
- **chibicc's compiler passes**: Each pass (tokenize, preprocess, parse, codegen) is a separate file. Swapping `codegen.c` changes the target architecture. The enabling point is the build system.
- **ESLint's parser**: Default parser can be swapped for `@typescript-eslint/parser`. The enabling point is the eslint config file.
- **Yjs's provider**: `y-websocket`, `y-webrtc`, `y-indexeddb` are separate packages. The enabling point is the import and Y.Doc binding.

**Pattern labels**: Plugin, Module, Adapter, Provider.

## Extension Surfaces

**What**: Designed-in variation points — hooks, plugin registries, middleware chains, template methods, event systems.

**Enabling point**: The registration call, the override, or the event subscription.

**Examples:**
- **ESLint's rule system**: Rules register for AST node types. The Linter traverses and emits events. Rules respond. The enabling point is `module.exports = { create(context) { ... } }`.
- **PyTorch Lightning's 30+ hooks**: `on_train_start`, `on_before_backward`, `on_validation_epoch_end`. Each is independently implementable via Callback subclasses. The enabling point is `Trainer(callbacks=[...])`.
- **Matter.js's event system**: `Events.on(engine, 'collisionStart', callback)`. The enabling point is the `Events.on` call.
- **Tone.js's connect()**: Audio nodes chain via `oscillator.connect(filter).connect(gain)`. The enabling point is each `connect()` call.

**Pattern labels**: Observer, Hook/Callback, Middleware, Plugin Registry, Event Emitter.

## Using LSP to Detect Seams

| LSP Operation | Detects |
|---|---|
| `findReferences` on an interface | Object seams — who implements it? |
| `goToDefinition` on an abstract method | Where's the contract defined? |
| `findReferences` on an event name | Extension surfaces — who listens? |
| `documentSymbol` filtered to interfaces | All object seams in a file |
| `goToImplementation` | All concrete implementations of a seam |

The pattern: find the interface → find all implementations → trace who selects between them → that's the enabling point.
