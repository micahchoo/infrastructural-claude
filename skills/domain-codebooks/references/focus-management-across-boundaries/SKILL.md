---
name: focus-management-across-boundaries
description: >-
  Focus state is global but component state is local — creating coupling between
  otherwise independent components. Focus traps in modals/popovers, keyboard nav
  across custom widgets, focus restoration after overlay dismissal, roving
  tabindex, keyboard capture toggle, shadow DOM focus delegation.

  Triggers: "focus trap", "keyboard navigation", "roving tabindex", "focus
  restoration", "keyboard capture", "ARIA keyboard patterns", "modal focus",
  "overlay focus management", "tab order across components", "shadow DOM focus
  delegation", "nested focus traps", "split-pane keyboard shortcut scoping",
  "focus handoff between embedded blocks", "command palette focus save/restore".

  Brownfield triggers: "focus escapes the modal", "tab order is wrong after
  opening a dialog", "keyboard shortcuts fire when typing in an input",
  "focus doesn't return after closing overlay", "keyboard nav doesn't work
  in custom dropdown", "losing track of where focus came from when panel opens",
  "tab navigation trapped inside shadow DOM won't exit", "canvas swallows Tab
  key so users can't reach sidebar", "too many tab stops on grouped toolbar
  buttons", "nested modal focus traps conflict with each other", "Escape in
  embedded block doesn't return focus to document", "command palette close
  doesn't restore previous focus context", "canvas shortcuts fire when form
  input is focused", "context menu in different DOM subtree breaks logical
  focus continuity".

  Symptom triggers: "floating properties panel opens but pressing Escape
  doesn't return focus to canvas", "Web Component shadow DOM traps tab
  navigation won't exit", "arrow keys move shapes but can't Tab to sidebar
  because canvas captures all keyboard input", "toolbar with 40 plus tab
  stops needs roving tabindex between groups", "confirmation dialog inside
  settings modal focus traps conflict", "Escape inside embedded content block
  should return focus to document flow", "command palette Ctrl+K should
  capture input and restore previous focus on close", "Delete key in split
  pane should scope to focused pane without global listeners fighting",
  "context menu rendered in portal breaks keyboard arrow navigation",
  "pressing V for tool shortcut fires while typing in sidebar form field".
---

# Focus Management Across Boundaries

Focus state is inherently global (one element has focus at a time) but components
are local — creating coupling whenever focus must cross component boundaries.
Produces spaghetti when each component implements its own focus trap/restoration
logic without coordination.

Evidence: 2/18 STRONG (neko, Immich) + 10 MODERATE. Ubiquitous but often contained.

## Force tensions

| Force A | vs | Force B |
|---------|-----|---------|
| Component encapsulation | vs | Global focus state |
| Keyboard accessibility | vs | Custom widget complexity |
| Focus trapping (modal) | vs | Focus restoration (on dismiss) |
| Keyboard capture (remote desktop) | vs | Local shortcut handling |

## Patterns

- **Custom FocusTrap** (Immich) — focusTrap with restore, list-navigation action
- **Focus-as-Keyboard-Capture** (neko) — overlay focus toggles keyboard capture to remote
- **Per-Widget Focus** (anti-pattern) — each dialog implements own trap, no shared abstraction
- **Roving Tabindex** — single tab stop, arrow keys move within group

### Code evidence: Immich focusTrap + list-navigation

**Files:** `web/src/lib/actions/focus-trap.ts`, `web/src/lib/actions/list-navigation.ts`, `web/src/lib/actions/focus-outside.ts`

`focus-trap.ts` is a Svelte action implementing Tab/Shift+Tab cycling within a container,
auto-focus on mount, and **focus restoration** to the triggering element on destroy.
`list-navigation.ts` provides Arrow Up/Down keyboard nav that moves `.focus()` through
child elements by index — used for dropdown menus and search results.

Complementary actions: `focus-outside.ts` detects focus leaving a container (dismiss-on-blur),
`context-menu-navigation.ts` handles context-menu-specific keyboard nav,
`focus-util.ts` provides `getTabbable()` and `focusNext()` helpers.

- **If removed:** Every modal/dropdown reimplements its own Tab-cycling and restoration logic.
  List navigation degrades to tab-only traversal (O(n) tab presses instead of single arrow key).
- **Detection signal:** `use:focusTrap` directive on modal containers; ArrowUp/ArrowDown
  handlers on list containers calling `.focus()` on children by index.

### Code evidence: neko keyboard-capture-via-focus

**File:** `video.vue` (overlay textarea + focus watchers)

A `<textarea>` overlay must hold browser focus to receive keyboard events for forwarding to
the remote desktop. `onMouseEnter` triggers `this._overlay.focus()` and syncs modifier state
(CapsLock/NumLock/ScrollLock). `onMouseLeave` calls `this.keyboard.reset()` — releasing
all pressed keys to prevent stuck keys on the remote.

The clipboard component (`clipboard.vue`) **steals focus** from the overlay when opened —
its `open()` calls `this._textarea.focus()`, which disables keyboard capture. This is the
canonical "focus as shared global resource" conflict.

- **If removed:** Keyboard events stop reaching the remote desktop whenever any
  sibling component (clipboard, chat, settings) takes focus. No modifier-state sync
  means stuck Ctrl/Shift on the remote after alt-tabbing.
- **Detection signal:** `.focus()` calls gated on `hosting && !locked`; `onMouseEnter`/
  `onMouseLeave` handlers that couple focus to spatial cursor position.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| gesture-disambiguation | Drag operations crossing focus boundaries |
| virtualization-vs-interaction-fidelity | Keyboard nav across virtual items not in DOM |
| embeddability-and-api-surface | Embedded editors negotiate focus with host app |
| text-editing-mode-isolation | Text editing focus handoff between canvas and input |
| **userinterface-wiki** | `none-keyboard-navigation` (keyboard nav must be instant, no animation), `pseudo-hit-target-expansion` (expand hit areas for focus targets), `ux-fitts-target-size` + `ux-fitts-hit-area` (minimum target sizing for keyboard-reachable elements) |
