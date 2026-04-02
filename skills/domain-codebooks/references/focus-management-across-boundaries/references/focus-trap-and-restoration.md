# Focus Trap and Restoration Patterns

## The Problem

Focus is a global singleton — one element has it at a time — but UI components are local. When modals, popovers, dropdowns, and panels open, they must capture focus, constrain it within their boundaries, and restore it to the previous location on dismiss. Without coordination, each component reimplements this logic differently, creating inconsistent behavior and focus leaks.

Symptoms: focus escapes modal into background content, focus doesn't return after dialog closes, nested modals fight over focus trapping, Tab cycles through invisible background elements.

## Competing Patterns

### Pattern A: Shared FocusTrap Action/Directive

**When to use:** Component library with consistent modal/overlay patterns. Framework supports directives or actions (Svelte, Vue, Angular).

**When NOT to use:** Highly custom focus flows (e.g., keyboard capture for remote desktop). Components with fundamentally different trapping semantics.

**How it works:** A reusable action/directive wraps any container, finds tabbable elements, intercepts Tab/Shift+Tab to cycle within them, auto-focuses the first element on mount, and restores focus to the triggering element on destroy.

**Production example:** Immich `focus-trap.ts` — Svelte action that finds all tabbable elements via `getTabbable()`, handles Tab/Shift+Tab cycling, stores `document.activeElement` on mount and restores it on destroy. Complemented by `focus-outside.ts` for dismiss-on-blur and `list-navigation.ts` for arrow-key nav within lists.

**Tradeoffs:** Assumes standard Tab-based navigation. Doesn't handle cases where focus needs to leave the trap temporarily (e.g., tooltip triggered from within modal).

### Pattern B: Focus-as-Keyboard-Capture

**When to use:** Applications where focus determines keyboard event routing to a non-DOM target (remote desktop, canvas, terminal emulator).

**When NOT to use:** Standard form/dialog focus management. Applications without keyboard capture requirements.

**How it works:** A hidden or overlay element (textarea, div) holds browser focus to receive keyboard events, which are forwarded to a non-DOM target. Focus acquisition is spatial (mouse enter/leave) rather than Tab-based. Modifier state must be synced on focus transitions.

**Production example:** neko `video.vue` — overlay textarea holds focus for remote desktop keyboard forwarding. `onMouseEnter` calls `this._overlay.focus()` and syncs CapsLock/NumLock/ScrollLock state. `onMouseLeave` calls `keyboard.reset()` to prevent stuck keys. Clipboard component steals focus when opened, disabling keyboard capture — canonical "focus as shared global resource" conflict.

**Tradeoffs:** Focus is invisible to the user (no visible focus ring). Other components stealing focus silently breaks keyboard capture. Requires explicit modifier state management.

### Pattern C: Focus Scope Stack (LIFO)

**When to use:** Applications with nested overlays (modal → confirmation dialog → tooltip). Multiple focus traps that must compose without conflicting.

**When NOT to use:** Single-level modals. Applications where overlays don't nest.

**How it works:** A stack tracks active focus scopes. When a new scope opens, it pushes onto the stack, traps focus within itself, and stores the previous scope's active element. When it closes, it pops from the stack and restores focus to the stored element. The top of the stack always owns focus trapping.

**Production example:** React Aria's `FocusScope` component implements this pattern. VS Code's workbench uses a focus tracker that manages keyboard shortcut contexts based on which panel/editor has focus, with LIFO restoration when panels close.

**Tradeoffs:** Stack ordering must be strictly maintained. Programmatic focus changes that bypass the stack can leave it in an inconsistent state. Stack depth increases memory usage for deeply nested overlays.

### Pattern D: Roving Tabindex

**When to use:** Groups of related controls (toolbars, menus, tab lists, tree views) where individual Tab stops would be excessive.

**When NOT to use:** Forms with sequential fields. Flat lists without group semantics.

**How it works:** The group has a single Tab stop. Only one element in the group has `tabindex="0"`; all others have `tabindex="-1"`. Arrow keys move `tabindex="0"` between elements and call `.focus()`. Tab exits the group entirely to the next focusable element.

**Production example:** Immich `list-navigation.ts` — ArrowUp/ArrowDown handlers move `.focus()` through child elements by index. Used for dropdown menus and search results. WAI-ARIA practices recommend this for toolbars, menubars, tablists, and tree views.

**Tradeoffs:** Requires JavaScript to manage tabindex attributes. Users must know to use arrow keys (not Tab) within the group — discoverability concern.

## Decision Guide

- "Do I need to trap focus in a modal/overlay?" → Pattern A (shared FocusTrap) or Pattern C (scope stack) if nesting
- "Does focus control keyboard event routing to a non-DOM target?" → Pattern B (keyboard capture)
- "Do I have nested overlays that each need their own focus trap?" → Pattern C (focus scope stack)
- "Do I have a toolbar/menu/tree with many items?" → Pattern D (roving tabindex)
- "Multiple of the above?" → Combine: roving tabindex inside a focus-trapped modal, with scope stacking for nested overlays

## Anti-Patterns

### Don't: Per-Component Ad-Hoc Focus Management
**What happens:** Each modal/dialog implements its own Tab cycling, focus restoration, and escape handling. Behaviors diverge — some modals trap focus, some don't, some restore focus, some don't. Users can't predict focus behavior.
**Instead:** Use Pattern A (shared FocusTrap) with consistent behavior across all overlays.

### Don't: Focus Trapping Without Restoration
**What happens:** Modal traps focus correctly, but when dismissed, focus goes to `<body>` or the top of the page instead of the element that opened the modal. Screen reader users lose their position in the document.
**Instead:** Store `document.activeElement` before trapping, restore it on destroy.

### Don't: Blocking Focus with `pointer-events: none` on Background
**What happens:** Background content can still be focused via Tab key even though pointer events are disabled. Focus escapes the modal into invisible/unreachable elements.
**Instead:** Use a proper focus trap that intercepts Tab/Shift+Tab, not just pointer events.
