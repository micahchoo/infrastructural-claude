# Text Editing Mode Transition Patterns

## The Problem

Canvas/spatial editors must support text editing within shapes, labels, and notes. Text editing requires keyboard events (Delete, arrow keys, Ctrl+A, Tab) that conflict with canvas shortcuts (Delete shape, pan with arrows, select all shapes). Without clean mode isolation, keyboard events reach the wrong handler, IME composition breaks, clipboard targets the wrong layer, and focus doesn't transfer cleanly between canvas and text input.

Symptoms: pressing Delete removes the shape instead of a text character, spacebar activates pan tool while typing, CJK IME composition corrupts text, Tab cycles focus instead of indenting, Enter commits text instead of adding a line break.

## Competing Patterns

### Pattern A: Statechart Mode Isolation

**When to use:** Canvas editors with a formal tool state machine. Multiple text-capable shape types. Complex enter/exit transitions (double-click to edit, Escape to exit, click-outside to commit).

**When NOT to use:** Simple single-field inline editing. Applications without a tool state machine.

**How it works:** Text editing is a distinct state in the tool statechart (e.g., `SelectTool → EditingShape`). While in this state, the keyboard event pipeline routes to the text element (textarea or contentEditable div) instead of the canvas shortcut system. Pointer events must distinguish text selection from shape selection. On exit, focus returns to the canvas container.

**Production example:** tldraw `EditingShape.ts` — a child state of SelectTool in the StateNode hierarchy. While active, keyboard events route to `<textarea>` (PlainTextArea) or `<div contenteditable>` (RichTextArea) via hooks (`useEditablePlainText`, `useEditableRichText`). These hooks manage focus acquisition, IME composition tracking, and clipboard targeting. Exit via Escape or click-outside commits text and restores canvas focus.

**Tradeoffs:** Requires a statechart architecture. Every text-capable shape type must integrate with the editing state. Complex transitions (click one text shape while editing another) need explicit handling.

### Pattern B: Tool Mode Guard

**When to use:** Applications without a formal statechart but with distinct tool modes. Simpler state management (boolean flag or enum).

**When NOT to use:** Applications with complex nested modes. When guard checks would need to be added to many disparate handlers.

**How it works:** A mode flag (`isEditingText`, `activeToolMode`) gates keyboard event handling in the main event loop. When text editing is active, keyboard handlers check the flag and skip canvas shortcuts. The text input element receives events normally through DOM bubbling.

**Production example:** drafft-ink — tool-mode checks in `app.rs` gate keyboard event handling. When editing text, pressing "r" doesn't activate the rectangle tool. The text editor (`text_editor.rs`) handles text layout through Parley, mapping cursor positions through the camera transform (pan/zoom) to screen coordinates. No formal state machine — just conditional checks.

**Tradeoffs:** Guard checks can proliferate across many handlers. Easy to miss adding the guard to a new shortcut. No explicit state transition lifecycle (enter/exit hooks).

### Pattern C: Embedded Rich Text Editor

**When to use:** When text editing needs full rich-text capabilities (bold, italic, lists, links) within canvas shapes. When the text editing experience should match a document editor.

**When NOT to use:** Simple plain-text labels. Performance-sensitive contexts where a full editor is too heavy.

**How it works:** Embed a rich text editor (ProseMirror, Slate, Tiptap, Lexical) inside shape components. The editor manages its own focus, keyboard handling, and IME support. The canvas must: (1) mount/unmount the editor on enter/exit, (2) prevent canvas shortcuts from reaching the editor, (3) handle click-outside to dismiss, (4) sync editor content back to the shape data model.

**Production example:** tldraw's RichTextArea uses a contentEditable div with `useEditableRichText` hook managing the integration. The boundary crossing requires careful event handling — pointer events must distinguish text selection drags from shape move drags.

**Tradeoffs:** Heavy dependency. Performance overhead for mounting/unmounting editors. Style isolation between editor and canvas. Editor's own keyboard shortcuts may conflict with remaining canvas shortcuts (e.g., Ctrl+B for bold vs canvas bookmark).

## Decision Guide

- "Do I have a tool state machine?" → Pattern A (statechart mode isolation)
- "Simple tool modes, boolean flag sufficient?" → Pattern B (tool mode guard)
- "Need rich text (bold, lists, links) in shapes?" → Pattern C (embedded rich text editor) within Pattern A or B
- "Just plain text labels?" → Pattern A or B with a simple textarea, no need for Pattern C

### IME Composition Handling

Regardless of pattern chosen, IME (Input Method Editor) support requires:
1. **Don't intercept during composition** — check `event.isComposing` or track `compositionstart`/`compositionend` events. Canvas shortcuts must not fire during IME composition.
2. **Commit on compositionend** — update the shape's text data when composition completes, not on each keystroke.
3. **Preserve composition UI** — the browser's IME candidate window must remain visible and correctly positioned relative to the text input element.

### Focus Handoff Checklist

When entering text editing mode:
1. Store current `document.activeElement` (for restoration)
2. Mount or reveal the text input element
3. Call `.focus()` on the text input
4. Suppress canvas keyboard shortcuts
5. Position cursor at click location (not start of text)

When exiting text editing mode:
1. Commit text changes to shape data
2. Unmount or hide the text input element
3. Restore focus to canvas container
4. Re-enable canvas keyboard shortcuts
5. Update shape rendering with committed text

## Anti-Patterns

### Don't: Suppress Keyboard Events Globally During Text Editing
**What happens:** ALL keyboard shortcuts stop working — including legitimate ones like Ctrl+Z (undo the text edit), Ctrl+S (save), or Escape (exit text editing mode). User is trapped in text editing with no way out via keyboard.
**Instead:** Suppress only canvas-specific shortcuts (tool activation, shape manipulation). Allow meta-shortcuts (undo, save, escape) to pass through with appropriate routing.

### Don't: Use `stopPropagation()` on Text Input Without Re-dispatching Needed Events
**What happens:** Events that should reach the canvas (Escape to exit, click-outside to commit) are silently swallowed. The text editing mode has no keyboard exit path.
**Instead:** Explicitly handle Escape/Enter/Tab in the text input handler. Use `stopPropagation()` selectively, not blanket.

### Don't: Mount Text Input in a Different DOM Subtree Than the Shape
**What happens:** The text cursor doesn't align with the shape position. Zoom/pan causes the input to drift from its shape. Click targeting fails because the input and shape occupy different coordinate spaces.
**Instead:** Mount the text input as a child of the shape's DOM element or position it using the same transform pipeline as the shape.
