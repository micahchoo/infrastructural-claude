---
name: seam-identification
description: >-
  Map the architectural joints of an unfamiliar codebase — where behavior can be
  altered without editing surrounding code. Produces a seam map showing dependency
  structure, coupling topology, and which code is structural vs incidental.
  Triggers: "map this codebase", "where are the extension points", "what's
  structural here", "find the seams", understanding unfamiliar architecture,
  or before pattern-extraction-pipeline when you need to orient first.
  Distinguishing test: do you want to understand the shape of a codebase
  (this) or extract reusable patterns from it (pattern-extraction-pipeline)?
---

# Seam Identification

Find where a codebase bends without breaking. A seam is a point where behavior
can be altered without editing surrounding code. Mapping seams reveals what's
load-bearing architecture vs what's feature-specific detail.

## When to use

- Entering an unfamiliar codebase and need to understand its shape
- Before modifying code — know what's structural before you touch it
- As input to pattern-extraction-pipeline (feeds Stage 2)
- When characterization-testing reveals unexpected coupling

## The Protocol

### 1. Survey

Run the project. Read the README. Get the directory structure. Identify the
main entry points — where does execution start, where does data flow?

Foxhound `search_references` for the architecture concept — reference projects reveal seam patterns you might not recognize from code alone.

### 2. Find seams

For seam taxonomy (object/link/extension) and LSP detection patterns, load `pattern-extraction-pipeline/references/seam-types.md`.

Three types, in order of architectural significance:

**Object seams** — interfaces, abstract classes, DI points. Behavior changes
by swapping implementations. The enabling point is where the implementation
is chosen (constructor, factory, config).

**Link seams** — module boundaries. Behavior changes by swapping imports.
The enabling point is the import statement or build config.

**Extension surfaces** — hooks, plugin registries, middleware chains, event
systems. Behavior changes by registering new handlers. The enabling point
is the registration call.

For each seam type, check implementation completeness — not just whether
the seam exists, but whether it delivers behavior. An interface with ten
methods where seven throw `NotImplementedError` is a seam with 30%
completion, not a working joint. A middleware slot that's filled with a
passthrough (`(req, res, next) => next()`) is wired but empty. A plugin
hook registered to a function that ignores its arguments and returns a
constant is structurally present but behaviorally absent. These incomplete
seams are both architectural joints AND implementation gaps — the seam map
must distinguish them from complete seams.

Use LSP when available: `findReferences` on interfaces to find object seams,
`goToImplementation` for concrete implementations, `findReferences` on event
names for extension surfaces.

### 3. Label each seam

For each seam, record:
- **Location**: file and symbol
- **Type**: object / link / extension
- **Enabling point**: where behavior is selected
- **Completeness**: full / partial / stub — does the implementation fulfill the contract, partially deliver, or exist as a no-op? Partial: note which methods/paths are real vs stubbed. Check for dead parameters (accepted but never read), constant returns regardless of input, identity passthroughs, and silent error swallowing. These signals are invisible to lexical scanning — the code compiles and runs, but does nothing.
- **Pattern**: Strategy, Observer, Plugin, Middleware, etc. (if recognizable)
- **What varies**: what concrete implementations exist

### 4. Trace the structural skeleton

For multi-frame diagnostic lenses that reveal cross-cutting risks, load `codebase-diagnostics/references/diagnostic-frames.md`.

With seams mapped, identify what's **structural** (shared by multiple features,
would break many things if removed) vs **incidental** (specific to one feature,
removable without wider impact).

Heuristic: count inbound references. High fan-in = structural. Low fan-in =
incidental. Seams themselves are almost always structural — they're the joints
the architecture was designed around.

Follow stub propagation across seam boundaries: if a seam's implementation
delegates to another component that is itself a stub, the seam is transitively
incomplete regardless of its own code. A facade with high fan-in over stub
implementations is architecturally load-bearing but behaviorally hollow —
the most dangerous kind of incompleteness because many consumers assume
it works.

### 5. Produce a seam map

Output a concise map: the key seams, their types, what varies at each, and
which are load-bearing. This is the artifact — a structural sketch of the
codebase's architecture.

`bias:wysiati` — After mapping seams, ask: what seams might exist that you haven't found? Consider: seams hidden behind indirection (dependency injection, config files, environment variables), seams that only activate under specific conditions (feature flags, error paths), and seams in build/deploy tooling. Are there domains this codebase touches that you haven't explored?

## What this is NOT

- Not pattern extraction — you're mapping joints, not building a codebook
- Not a full architecture document — focus on seams and coupling, skip everything else
- Not exhaustive — find the 5-10 seams that matter, not every interface in the codebase

`[eval: seam-map-produced]` Output includes seam type (object/link/extension), coupling direction (who depends on whom), and test strategy per seam.
`[eval: coupling-signal]` When characterization-testing has run, incorporate test-failure evidence into the seam map — a failing boundary test is a stronger seam signal than static analysis alone.
