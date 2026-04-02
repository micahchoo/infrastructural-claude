# Focus Handoff and Shortcut Isolation Patterns

Patterns for transferring keyboard focus between canvas and text input elements, and for
isolating keyboard shortcuts so canvas actions don't fire during text editing. The focus
handoff is bidirectional: entering text editing must capture focus, and exiting must
restore it.

Evidence: 3 repos (tldraw, Excalidraw, ProseMirror).

## The Problem

Canvas editors bind keyboard shortcuts at the document or container level (Delete to
remove shapes, arrow keys to nudge, letter keys to activate tools). When a user enters
text editing mode, these shortcuts must be suppressed -- but not ALL shortcuts, only
canvas-specific ones. Meta-shortcuts like Escape (exit editing), Ctrl+Z (undo), and
Ctrl+S (save) must still work, potentially with different routing (undo should undo
the text edit, not the last canvas action).

Focus handoff has a second dimension: toolbar interactions. Clicking a formatting button
blurs the text input, potentially triggering an unwanted submit. The editor must
distinguish "blur because user clicked away" (commit text) from "blur because user
clicked a toolbar button" (preserve editing mode and restore focus).

Symptoms: Delete key removes shape instead of text character, spacebar activates pan
tool while typing, clicking formatting toolbar exits text editing, focus lost after
programmatic DOM updates, Escape doesn't exit text editing because events are swallowed.

## Competing Patterns

### Pattern A: Element-Type Key Capture Query

**When to use:** Canvas editors where keyboard shortcut routing is centralized. When
multiple UI elements (inputs, textareas, selects, contentEditable) all need to capture
keys in different contexts.

**When NOT to use:** Applications with a single text input scenario. When shortcuts are
handled in individual components rather than a central dispatcher.

**How it works:** Before dispatching a keyboard shortcut, query whether the currently
focused element should "capture" keyboard events. If yes, skip the canvas shortcut.
The query inspects the active element's tag name and properties.

**Production example: tldraw** (`packages/editor/src/lib/utils/dom.ts`)

```typescript
export function elementShouldCaptureKeys(
  el: Element | null,
  includeButtonsAndMenus = true
) {
  if (!el) return false
  const tagName = el.tagName.toLowerCase()
  return (
    (el as HTMLElement).isContentEditable ||
    tagName === 'input' ||
    tagName === 'textarea' ||
    (includeButtonsAndMenus && tagName === 'select') ||
    (includeButtonsAndMenus && tagName === 'button') ||
    el.classList.contains('tlui-slider__thumb')
  )
}

export function activeElementShouldCaptureKeys(
  includeButtonsAndMenus = true,
  doc?: Document
) {
  return elementShouldCaptureKeys(
    (doc ?? getGlobalDocument()).activeElement,
    includeButtonsAndMenus
  )
}
```

Used in `EditingShape` state node (`packages/tldraw/src/lib/tools/SelectTool/childStates/EditingShape.ts`):

```typescript
private isTextInputFocused(): boolean {
  const container = this.editor.getContainer()
  const doc = this.editor.getContainerDocument()
  return container.contains(doc.activeElement) &&
    activeElementShouldCaptureKeys(false, doc)
}
```

Key design decisions:
- **Tag-based detection** rather than flag-based -- works with any DOM element without
  needing to register/unregister editing state
- **`includeButtonsAndMenus` parameter** allows different capture levels: during text
  editing, buttons should NOT capture keys (so Escape still exits), but in general UI,
  buttons should capture keys (so Enter activates the button, not a canvas shortcut)
- **Container-scoped document** (`editor.getContainerDocument()`) supports shadow DOM
  and iframe embedding

**Tradeoffs:** Relies on DOM state queries, which can be stale if called at the wrong
time. No explicit enter/exit lifecycle -- the system is reactive rather than imperative.

### Pattern B: Imperative Cleanup-on-Exit with Event Nullification

**When to use:** When text editing is managed via a dynamically created DOM element
(not a React component lifecycle). When the blur/submit boundary must be carefully
controlled to prevent infinite loops.

**When NOT to use:** When text editing uses stable React components with proper
mount/unmount lifecycle. When the framework handles event cleanup.

**How it works:** On entering text editing, event handlers are imperatively assigned
to the text element. On exit, ALL handlers are nullified before the submit callback
runs, preventing re-entrant blur events. A cleanup function removes all listeners.

**Production example: Excalidraw** (`packages/excalidraw/wysiwyg/textWysiwyg.tsx`)

```typescript
const handleSubmit = () => {
  if (isDestroyed) return;  // prevent double submit
  isDestroyed = true;

  // CRITICAL: cleanup BEFORE onSubmit, otherwise blur->onSubmit loop
  cleanup();

  const updateElement = app.scene.getElement(element.id);
  // ... commit text to element ...
  onSubmit({ viaKeyboard: submittedViaKeyboard, nextOriginalText });
};

const cleanup = () => {
  // Remove events to ensure they don't late-fire
  editable.onblur = null;
  editable.oninput = null;
  editable.onkeydown = null;

  if (observer) observer.disconnect();

  window.removeEventListener("resize", updateWysiwygStyle);
  window.removeEventListener("wheel", stopEvent, true);
  window.removeEventListener("pointerdown", onPointerDown);
  window.removeEventListener("blur", handleSubmit);
  window.removeEventListener("beforeunload", handleSubmit);
  unbindUpdate();
  unsubOnChange();
};
```

Focus restoration and caret management (`packages/excalidraw/hooks/useTextEditorFocus.ts`):

```typescript
export const restoreCaretPosition = (position: CaretPosition | null): void => {
  setTimeout(() => {  // deferred to next tick for DOM stability
    const textEditor = getTextEditor();
    if (textEditor) {
      textEditor.focus();
      if (position) {
        textEditor.selectionStart = position.start;
        textEditor.selectionEnd = position.end;
      }
    }
  }, 0);
};

// Temporarily suppress blur when clicking toolbar buttons
export const temporarilyDisableTextEditorBlur = (duration = 100): void => {
  const textEditor = getTextEditor();
  if (textEditor) {
    const originalOnBlur = textEditor.onblur;
    textEditor.onblur = null;
    setTimeout(() => { textEditor.onblur = originalOnBlur; }, duration);
  }
};
```

Key design decisions:
- **Cleanup-before-submit ordering** prevents the blur->submit infinite loop
- **`isDestroyed` flag** prevents double-submit from racing event handlers
- **`temporarilyDisableTextEditorBlur`** allows toolbar clicks without exiting edit mode
- **Deferred focus restoration** (`setTimeout(0)`) ensures DOM is stable before refocusing
- **Window-level listeners** (`blur`, `beforeunload`) ensure text is committed even when
  the browser tab loses focus

**Tradeoffs:** Imperative event management is error-prone (forgetting to remove a listener).
The `temporarilyDisableTextEditorBlur` with a fixed 100ms timeout is fragile -- slow
machines or complex UI may exceed the window. The `isDestroyed` flag is a manual guard
against a race condition that wouldn't exist with proper lifecycle management.

### Pattern C: Statechart-Driven Focus Lifecycle

**When to use:** Canvas editors with a formal state machine (statechart) for tool modes.
When enter/exit transitions need to coordinate multiple concerns (focus, selection,
toolbar, undo boundaries).

**When NOT to use:** Simple editors without a statechart. When the overhead of a full
state machine is not justified.

**How it works:** Text editing is a state node in the tool statechart. The `onEnter`
method acquires focus and sets up the editing context. The `onExit` method commits text
and restores canvas focus. Pointer events within the state distinguish text selection
from shape interaction.

**Production example: tldraw** (`EditingShape.ts`)

```typescript
export class EditingShape extends StateNode {
  static override id = 'editing_shape'
  private didPointerDownOnEditingShape = false

  override onEnter(info: EditingShapeInfo) {
    const editingShape = this.editor.getEditingShape()
    if (!editingShape) throw Error('Entered editing state without an editing shape')
    this.editor.select(editingShape)
    // Focus is acquired by the text component (PlainTextArea/RichTextArea)
    // mounting in response to editingShapeId being set
  }

  override onExit() {
    this.editor.setEditingShape(null)
    // Setting editingShape to null unmounts text component,
    // which returns focus to canvas container
  }

  override onPointerDown(info: TLPointerEventInfo) {
    // Complex routing: click on same shape's label vs different shape vs canvas
    switch (info.target) {
      case 'shape': {
        const selectingShape = ...
        if (selectingShape.id === editingShape.id) {
          this.didPointerDownOnEditingShape = true
          return  // stay in editing, user is clicking within text
        } else {
          // Click on different shape: check if it has a label
          // If yes, transition editing to that shape
          // If no, exit editing and enter pointing_shape
          this.hitLabelOnShapeForPointerUp = selectingShape
        }
      }
    }
    // Default: exit editing
    this.parent.transition('idle', info)
    this.editor.root.handleEvent(info)  // re-dispatch to new state
  }

  override onPointerUp(info: TLPointerEventInfo) {
    if (this.didPointerDownOnEditingShape) {
      this.didPointerDownOnEditingShape = false
      if (!this.isTextInputFocused()) {
        // Clicked label but input blurred -- refocus and select all
        this.editor.getRichTextEditor()?.commands.focus('all')
        return
      }
    }
    // If hit another shape's label, begin editing that shape
    const hitShape = this.hitLabelOnShapeForPointerUp
    if (hitShape) { /* transition to editing hitShape */ }
  }

  override onPointerMove(info: TLPointerEventInfo) {
    // Distinguish text selection drag from shape move drag
    if (this.didPointerDownOnEditingShape && this.editor.inputs.isDragging) {
      if (!this.isTextInputFocused()) {
        // Input blurred during drag: exit edit, start translating
        this.parent.transition('translating', info)
        return
      }
      // Input still focused: user is selecting text, stay in edit mode
    }
  }
}
```

Key design decisions:
- **Editing-to-editing transition** (clicking another text shape while editing) is handled
  as a pointer-up event with deferred shape switching, not as exit-then-enter
- **Drag disambiguation**: if the user pointer-downs on the text label and drags, the
  system checks whether the text input is focused. If focused, it's text selection; if
  blurred (e.g., clicked a non-text area of the shape), it's a shape translate
- **Re-dispatch pattern**: when exiting to idle, the pointer-down event is re-dispatched
  (`this.editor.root.handleEvent(info)`) so the canvas processes it as if it happened
  in the idle state -- no lost clicks

**Tradeoffs:** Tight coupling to the statechart architecture. Every shape type that
supports text must integrate with the `EditingShape` state. The pointer-up deferred
editing transition adds latency but prevents premature commits.

## Decision Guide

- "Do I have a centralized shortcut dispatcher?" -> Pattern A (element-type query) as
  the first line of defense
- "Is my text input a dynamically created element (not a React component)?" -> Pattern B
  (imperative cleanup) for lifecycle management
- "Do I have a tool state machine?" -> Pattern C (statechart-driven) for enter/exit
  coordination, combined with Pattern A for shortcut filtering
- "Do toolbar clicks blur my text input?" -> Pattern B's `temporarilyDisableTextEditorBlur`
  or a focus-trap approach
- "Can users click between text shapes without exiting edit mode?" -> Pattern C's
  editing-to-editing transition via pointer-up

### Shortcut Classification During Text Editing

Not all shortcuts should be suppressed. Classify shortcuts into three tiers:

| Tier | Examples | During text editing |
|------|----------|-------------------|
| Canvas-only | Delete shape, R for rectangle, spacebar pan, arrow nudge | **Suppress** |
| Meta/global | Ctrl+Z undo, Ctrl+S save, Ctrl+C copy | **Route to text context** (undo text edit, copy selected text) |
| Mode-exit | Escape, click-outside | **Handle specially** (commit text, exit editing mode) |

Excalidraw example -- some shortcuts pass through during text editing:

```typescript
editable.onkeydown = (event) => {
  // Zoom shortcuts work during text editing
  if (!event.shiftKey && actionZoomIn.keyTest(event)) {
    event.preventDefault();
    app.actionManager.executeAction(actionZoomIn);
    updateWysiwygStyle();  // re-position text after zoom
  }
  // Save shortcut commits text then saves
  if (actionSaveToActiveFile.keyTest(event)) {
    event.preventDefault();
    handleSubmit();
    app.actionManager.executeAction(actionSaveToActiveFile);
  }
};
```

## Anti-Patterns

### Don't: Use `stopPropagation()` as the Only Shortcut Isolation Mechanism
**What happens:** Events that need to reach parent handlers (Escape to exit editing,
click-outside to commit) are silently swallowed. The editing mode becomes a trap with
no keyboard exit.
**Instead:** Use selective event handling (Pattern A) or explicit key routing within
the text handler. Only `stopPropagation()` for events you've fully handled.
[Confirmed in codebook SKILL.md anti-pattern section]

### Don't: Commit Text on Every Blur Event Without Distinguishing Blur Cause
**What happens:** Clicking a formatting toolbar button blurs the text input, committing
half-written text. Programmatic focus changes (e.g., dialog opening) also commit text.
**Instead:** Distinguish blur causes: toolbar click (suppress via `temporarilyDisableTextEditorBlur`),
click-outside (commit), programmatic (defer decision). Excalidraw uses an `isDestroyed`
flag + cleanup-before-submit ordering to handle this.

### Don't: Restore Focus Synchronously After DOM Mutations
**What happens:** Calling `.focus()` immediately after modifying the DOM (e.g., updating
text content, resizing the text box) may fail silently because the browser hasn't
completed layout. The focus call succeeds but the caret position is wrong or the
element is not yet visible.
**Instead:** Defer focus restoration to the next tick (`setTimeout(0)`) as Excalidraw
does in `restoreCaretPosition`. This ensures the DOM is stable before focusing.
