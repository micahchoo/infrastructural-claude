# Forces Analysis Guide

Forces are the tensions that make a pattern necessary. Documenting forces through de-factoring — not assumption — is what separates a useful codebook from a pattern catalog.

## The De-factoring Protocol

1. **Pick a pattern** you've identified during seam mapping.
2. **Mentally or actually remove it.** Replace the Strategy with a switch statement. Remove the Observer and use direct calls. Flatten the Pipeline into a single function.
3. **Feel the pain.** What becomes harder? What breaks? What can't be extended?
4. **If nothing hurts** — the pattern is cargo-culted. Document this. Kerievsky: "I'd immediately race toward implementing the Strategy pattern, when a simple conditional would have been simpler."
5. **If it hurts** — those pain points are the forces. Document them precisely.

## Common Force Pairs

Patterns resolve tensions between competing concerns:

| Force Pair | Pattern resolves by... | Example |
|---|---|---|
| **Flexibility vs Performance** | Indirection costs cycles but enables swapping | Strategy pattern: interface dispatch vs inline code |
| **Coupling vs Cohesion** | Decoupling modules while keeping related code together | Observer: publisher doesn't know subscribers |
| **Consistency vs Autonomy** | Coordinating distributed state while allowing local decisions | CRDT: eventual consistency without central authority |
| **Simplicity vs Power** | Simple API hiding complex implementation | Pipeline: compose simple steps into complex transforms |
| **Safety vs Speed** | Preventing errors while allowing rapid development | Type boundaries: validation at system edges |
| **Extensibility vs Stability** | Adding behavior without modifying core | Plugin architecture: extension points are stable, plugins are volatile |

## Documenting Forces

For each pattern in your codebook, write:

```
**Forces this pattern resolves:**
- [Tension A vs Tension B]: [How this pattern resolves it]
- [Tension C vs Tension D]: [How this pattern resolves it]

**De-factoring evidence:**
- Removed [pattern]. [What became painful]. [Specific code/test that broke or became unwieldy].

**When the forces don't apply:**
- [Condition where this pattern is over-engineering]
```

## Distinguishing Structural Forces from Ergonomic Forces

- **Structural forces** cause bugs if unresolved: race conditions, data corruption, invariant violations. These are hard requirements for the pattern.
- **Ergonomic forces** cause developer pain: boilerplate, hard-to-read code, difficult testing. These are soft preferences — a different team might tolerate the pain.

Both are valid forces, but structural forces are stronger justification. A codebook should distinguish them: "This pattern prevents data corruption (structural) and reduces boilerplate (ergonomic)."

## The Kerievsky Test

Before documenting a pattern, ask: "Would a simpler approach have worked?" A conditional instead of Strategy. A direct call instead of Observer. A flat function instead of Pipeline.

If the simpler approach works for the project's actual scale and requirements — the pattern is over-engineering. Document the simpler approach as a competing pattern in your reference file.
