# Known False Positives

Patterns that look like UX issues but aren't. Check before flagging.

## SvelteKit

| Pattern | Looks Like | Why It's Not |
|---|---|---|
| `goto()` after form action | NAV TRAP | Intentional redirect — user expects navigation after submit |
| `invalidateAll()` without toast | NO FEEDBACK | Cache refresh triggers reactive UI update — list/table visibly changes |
| `fail()` returning `{ error }` | SILENT FAIL | SvelteKit surfaces this via `form` prop in the component — check if component reads it |

## MapLibre

| Pattern | Looks Like | Why It's Not |
|---|---|---|
| `map.on('error', ...)` with only console.log | SILENT FAIL | Map tile errors are internal — user sees missing tiles as visual gap, not an actionable error |
| `map.fire('moveend')` programmatic | RACE | Programmatic events are synchronous in the same frame — no user-visible race |

## tRPC

| Pattern | Looks Like | Why It's Not |
|---|---|---|
| `onError` in middleware | SILENT FAIL | Server-side logging; client receives typed TRPCClientError with message |
| Mutation without `onSuccess` toast | NO FEEDBACK | Check if the query cache invalidation causes a visible list update — that IS feedback |

## Terra Draw

| Pattern | Looks Like | Why It's Not |
|---|---|---|
| `instance.stop()` in try/catch | SILENT FAIL | Defensive teardown — Terra Draw may already be stopped; user sees mode exit regardless |
| `getModeState()` check before operation | ASSUMPTION | Internal guard — user never sees the check, only the guarded behavior |

## General

| Pattern | Looks Like | Why It's Not |
|---|---|---|
| Error boundary with generic message | SILENT FAIL | Error IS shown — check if the boundary renders user-visible text |
| `finally` block resetting loading state | NO FEEDBACK | The loading state change (spinner disappearing) IS feedback that operation completed |
| Abort controller on unmount | RACE | Intentional cleanup — prevents state updates on unmounted components |

---

**Adding entries:** When a walk identifies a false positive, add it here with: pattern, framework, looks-like flag, and why it's not an issue. Entries are only added, never removed.
