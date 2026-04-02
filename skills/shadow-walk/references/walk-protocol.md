# Walk Protocol

Core tracing instructions for shadow walk agents. Load this before walking any flow.

## The Rule

You are the user. Trace what they experience. Every claim needs file:line evidence.

## Tracing Order

For each flow in your scope:

1. **What renders first?** Find the component, read its template. Note loading states, skeleton screens, empty states.
2. **What can the user do?** Enumerate every interactive element (buttons, inputs, links, gestures).
3. **Trace the handler.** Click/input -> event handler -> state mutation -> API call -> response handling -> re-render.
4. **What if they wait?** Loading indicators, timeouts, stale data.
5. **What if they leave?** Navigate away mid-operation, back button, refresh.
6. **What if they do it wrong?** Invalid input, double-click, empty submit, wrong order.

## Path Order

Walk paths in this order — do not skip to weird paths without completing happy:

1. **Happy path** — intended use, everything works
2. **Sad path** — errors, network failures, permission denied, empty data
3. **Weird paths** — back button, refresh, double-click, slow network, race conditions, role/flag variants

## Branch Coverage

When you encounter conditional behavior:
- Role-based: walk each role variant
- Feature flags: walk enabled and disabled
- State-dependent: walk each reachable state
- Platform/viewport: note breakpoint-dependent behavior

## Evidence Rules

**Every claim requires `file:line`.** Not "in handleCreate" — specify `AnnotationPanel.svelte:142`.

**Every flag requires a Catchable? answer:** Can a test, lint rule, or automated check prevent this permanently? If yes, describe the check. If no, say "manual review only".

## Flag Taxonomy

Use exactly these flags. Do not invent new ones.

| Flag | When to Use |
|---|---|
| DEAD END | User has no obvious next action — stuck |
| SILENT FAIL | Error caught in code but never shown to user |
| NO FEEDBACK | State changes with no visible indication to user |
| ASSUMPTION | UI requires domain knowledge, jargon, or unlabeled inputs |
| RACE | Stale data, flash states, timing-dependent behavior |
| NAV TRAP | Navigation loses user state or context |
| HIDDEN REQ | Validation only surfaces on submit, not inline |

## Severity

- **Critical:** Blocks the user — cannot complete the flow
- **Major:** Confusing — user can proceed but may not understand what happened
- **Minor:** Rough edge — suboptimal but functional

## Output Format

For each finding:

```
Flag: <FLAG>
Severity: <critical|major|minor>
File: <path:line>
Flow: <flow name> > <step>
Description: <what the user experiences, not what the code does>
Catchable?: <yes: description of check | no: manual review only>
```

Group findings by flow, then by severity within each flow.

## What NOT to Report

- Code style issues (that's code review)
- Performance without user-visible impact (that's benchmarking)
- Internal logging gaps (that's observability)
- Test coverage gaps (that's characterization testing)

Focus exclusively on: what does the user see, feel, and understand?
