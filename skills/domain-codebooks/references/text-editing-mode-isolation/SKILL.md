---
name: text-editing-mode-isolation
description: >-
  Text editing within canvas/spatial context — isolating text input from canvas
  interaction, inline editing mode transitions, IME composition handling, focus
  handoff between canvas and text input, keyboard shortcut suppression during
  text editing.

  Triggers: "text editing on canvas", "inline text editing", "IME composition
  in canvas", "text tool focus", "keyboard shortcuts during text editing",
  "contenteditable in canvas context", "text editing state machine",
  "hidden textarea overlay on canvas", "rich text toolbar in canvas",
  "Tab key indent vs focus cycle in editor", "auto-resize text box on canvas",
  "double-click to edit shape text", "multi-line label editing".

  Brownfield triggers: "keyboard shortcuts fire while typing text on canvas",
  "IME composition breaks in the canvas", "clicking outside text doesn't
  deselect properly", "text cursor disappears", "canvas shortcuts interfere
  with text editing", "spacebar activates pan tool while typing in sticky note",
  "pressing Delete removes shape instead of text character", "CJK pinyin
  composition corrupts text in canvas labels", "Tab key cycles focus instead
  of indenting in text box", "clicking another text shape doesn't transition
  editing directly", "Enter key commits text instead of adding line break",
  "rich text formatting toolbar conflicts with canvas toolbar".

  Symptom triggers: "Delete key should delete text character not shape while
  editing", "spacebar types space instead of activating pan tool in sticky
  note", "CJK pinyin IME compositionstart compositionend events during canvas
  text editing", "clicking another text shape should transition editing directly
  without exiting first", "hidden contenteditable div and canvas rendering
  cursor position drift apart", "mode entry into text editing needs undo
  boundary and toolbar state update", "Enter should add newline not confirm
  edit in multi-line label", "clicking text formatting toolbar button causes
  focus to leave text field and breaks editing mode", "Tab should move to next
  text box like PowerPoint not insert tab character", "map annotation label
  typing triggers map keyboard shortcuts like plus for zoom".
---

# Text Editing Mode Isolation

The tension between canvas/spatial interaction and text editing — two fundamentally
different input modes that must coexist. Produces spaghetti when text editing
lifecycle doesn't cleanly separate from canvas event handling.

Evidence: 2 repos (tldraw, drafft-ink) + 1 absorb (Budibase inline editing).

## Patterns

- **Mode Isolation** (tldraw) — text editing state suppresses all canvas shortcuts, explicit enter/exit
- **Canvas-Embedded Input** (drafft-ink) — text editing within canvas context with IME handling
- **Inline Edit Transition** (Budibase) — grid cell editing with keyboard-triggered mode switch

### Code evidence: tldraw text editing state isolation

**Files:** `packages/tldraw/src/lib/tools/SelectTool/childStates/EditingShape.ts`,
`packages/editor/src/lib/hooks/useEditablePlainText.ts`, `packages/editor/src/lib/hooks/useEditableRichText.ts`,
`packages/tldraw/src/lib/shapes/shared/PlainTextArea.tsx`, `packages/tldraw/src/lib/shapes/shared/RichTextArea.tsx`

The `EditingShape` state node in the SelectTool statechart represents text-editing mode.
While active, keyboard events route to `<textarea>` or `<div contenteditable>` instead of
the canvas shortcut system. Separate hooks (`useEditablePlainText`, `useEditableRichText`)
manage focus acquisition, IME composition, and clipboard targeting for the text element.

The boundary crossing: pointer events must distinguish text selection from shape selection,
and clipboard operations must target the text element rather than the canvas. On exit,
focus returns to the canvas container.

- **If removed:** Keyboard shortcuts (Delete, Ctrl+A, arrow keys) fire canvas actions
  while the user is typing. IME composition breaks because keydown events get intercepted.
  Clipboard paste inserts shapes instead of text.
- **Detection signal:** `EditingShape` state in the tool statechart; `contenteditable` or
  `<textarea>` elements rendered inside shape components with their own event handlers.

### Code evidence: drafft-ink canvas-embedded text editing

**Files:** `crates/drafftink-render/src/text_editor.rs`, `crates/drafftink-core/src/shapes/mod.rs`
(Text/Math shapes), `crates/drafftink-render/src/rex_backend.rs` (LaTeX rendering)

Text shapes support multiple font families, per-character styling, and inline LaTeX math
(rendered via ReX). `text_editor.rs` handles text layout through Parley. The text cursor
must map through the camera transform (pan/zoom) to screen coordinates.

The modal challenge: typing must not trigger tool shortcuts (e.g., "r" for rectangle),
and the text input state must coexist with canvas gestures. This is the Rust/egui
equivalent of tldraw's statechart isolation, but without a formal state machine — tool
mode checks gate keyboard event handling in `app.rs`.

- **If removed:** Pressing "r" while editing text activates the rectangle tool. Canvas
  pan/zoom gestures interfere with text selection. LaTeX inline rendering loses its
  layout engine.
- **Detection signal:** Tool-mode guard on keyboard handling in `app.rs`; text layout
  engine (`text_editor.rs`) that maps through camera transform.

## Cross-codebook interactions

| With | Interaction |
|------|------------|
| gesture-disambiguation | Text selection gestures conflict with canvas gestures |
| focus-management-across-boundaries | Text input focus vs canvas focus handoff |
| interactive-spatial-editing | Text editing is a special mode within the spatial tool FSM |
| **userinterface-wiki** | `none-keyboard-navigation` (instant keyboard nav, no transition animation), `duration-press-hover` (120-180ms for press/hover feedback within text UI), `staging-one-focal-point` (one animation at a time during mode transition) |
