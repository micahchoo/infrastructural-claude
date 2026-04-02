# IME Composition Guard Patterns

Patterns for handling Input Method Editor (IME) composition events during text editing
within canvas/spatial contexts. IME composition (used for CJK languages, emoji input,
dictation) creates a transient state where keydown/keyup events must not trigger canvas
shortcuts or text commits.

Evidence: 3 repos (ProseMirror, Excalidraw, tldraw).

## The Problem

During IME composition, the browser fires `compositionstart`, `compositionupdate`, and
`compositionend` events. Between start and end, individual keydown events (Enter, Tab,
character keys) are part of the composition flow, not user intent to trigger shortcuts
or commit text. Canvas editors that intercept these events corrupt the composition,
producing garbled CJK text, premature commits, or ghost characters.

Symptoms: CJK pinyin/wubi composition corrupts text, pressing Enter during composition
commits the text instead of confirming the IME candidate, keyCode 229 events cause
double-input on Android, Safari compositionend fires before keydown causing phantom
newlines.

## Competing Patterns

### Pattern A: Composing Flag Guard

**When to use:** Rich text editors that manage their own event pipeline. When you need
fine-grained control over which events pass through during composition.

**When NOT to use:** Simple textarea-based editing where the browser handles composition
natively. When `event.isComposing` alone suffices.

**How it works:** Maintain a `composing` boolean flag set on `compositionstart` and
cleared on `compositionend`. All keyboard event handlers check this flag before
processing. A companion function (`inOrNearComposition`) adds timing-based guards for
browser-specific edge cases.

**Production example: ProseMirror** (`prosemirror-view/src/input.ts`)

```typescript
// InputState tracks composition lifecycle
class InputState {
  composing = false
  compositionEndedAt = -2e8
  compositionID = 1
  compositionPendingChanges = 0
  // ...
}

// Guard function checks both flag and timing
function inOrNearComposition(view: EditorView, event: Event) {
  if (view.composing) return true
  // Safari fires compositionend BEFORE keydown for Enter confirmation.
  // Without this timing guard, the Enter keydown would insert a newline.
  if (browser.safari && Math.abs(event.timeStamp - view.input.compositionEndedAt) < 500) {
    view.input.compositionEndedAt = -2e8  // consume once
    return true
  }
  return false
}

// Every edit handler checks the guard
editHandlers.keydown = (view, _event) => {
  let event = _event as KeyboardEvent
  if (inOrNearComposition(view, event)) return  // bail during composition
  // ... normal keydown handling
}

editHandlers.keypress = (view, _event) => {
  let event = _event as KeyboardEvent
  if (inOrNearComposition(view, event) || !event.charCode || ...) return
  // ... normal keypress handling
}
```

Key design decisions:
- **Timing window (500ms)** for Safari's out-of-order event firing
- **One-shot consumption** (`compositionEndedAt = -2e8`) prevents the guard from suppressing
  a *second* Enter press, which should insert a newline
- **Separate `composing` flag** rather than relying solely on `event.isComposing`, because
  ProseMirror needs to coordinate composition state with its DOM observer

**Tradeoffs:** Requires maintaining state across multiple event handlers. Browser-specific
timing windows are fragile and must be updated as browser behavior changes. More complex
than Pattern B but handles more edge cases.

### Pattern B: Inline `isComposing` / keyCode 229 Check

**When to use:** Canvas editors with textarea-based text editing (not contentEditable).
Simpler applications where browser-specific edge cases are less critical.

**When NOT to use:** When you need to coordinate composition with DOM mutation observers
or custom rendering pipelines.

**How it works:** Check `event.isComposing` or `event.keyCode === 229` at the top of
each keyboard handler. KeyCode 229 is the standard "composition in progress" signal
from mobile IME keyboards.

**Production example: Excalidraw** (`packages/excalidraw/wysiwyg/textWysiwyg.tsx`)

```typescript
editable.onkeydown = (event) => {
  // ... zoom and other meta-key handlers first ...

  // Ctrl+Enter to submit -- but NOT during composition
  if (event.key === KEYS.ENTER && event[KEYS.CTRL_OR_CMD]) {
    event.preventDefault();
    if (event.isComposing || event.keyCode === 229) {
      return;  // IME is composing, don't commit
    }
    submittedViaKeyboard = true;
    handleSubmit();
  }

  // Tab to indent -- but NOT during composition
  if (event.key === KEYS.TAB || ...) {
    event.preventDefault();
    if (event.isComposing) {
      return;  // IME is composing, don't indent
    }
    // ... indent/outdent logic
  }
};
```

Key design decisions:
- **Dual check** (`isComposing || keyCode === 229`) covers both desktop and mobile IME
- **Per-handler placement** rather than a centralized guard -- simpler but requires
  discipline to add the check to every handler
- **No timing window** -- relies on the browser's native `isComposing` property

**Tradeoffs:** Simpler to implement. May miss edge cases like Safari's out-of-order
compositionend/keydown. No coordination with external mutation observers.

### Pattern C: DOM Observer Composition Awareness

**When to use:** When text editing uses contentEditable with a custom rendering pipeline
that must reconcile DOM mutations. When the composition creates DOM nodes that must be
tracked separately from normal edits.

**When NOT to use:** Textarea-based editing. Applications that don't need to observe DOM
mutations during text input.

**How it works:** A MutationObserver watches the editable DOM subtree. During composition,
DOM mutations are queued rather than immediately processed. The observer coordinates with
the composition lifecycle to flush or defer mutations.

**Production example: ProseMirror** (`prosemirror-view/src/domobserver.ts`)

```typescript
class DOMObserver {
  suppressingSelectionUpdates = false

  constructor(readonly view: EditorView, readonly handleDOMChange: ...) {
    this.observer = new MutationObserver(mutations => {
      // Safari bug: composition in table cells creates misplaced nodes
      if (browser.safari && view.composing && mutations.some(
        m => m.type == "childList" && m.target.nodeName == "TR")) {
        view.input.badSafariComposition = true
        this.flushSoon()  // defer, don't flush immediately
      } else {
        this.flush()
      }
    })
  }

  // Force-flush pending mutations (called before handling keydown)
  forceFlush() {
    if (this.flushingSoon > -1) {
      window.clearTimeout(this.flushingSoon)
      this.flushingSoon = -1
      this.flush()
    }
  }

  setCursorWrapper() {
    this.suppressingSelectionUpdates = true
    setTimeout(() => this.suppressingSelectionUpdates = false, 50)
  }
}
```

Browser-specific workarounds within the observer:
- **Safari table cell composition bug** (`fixUpBadSafariComposition`): Safari moves composed
  text into the wrong table row; the observer detects and repositions it
- **Android composition timeout** (`timeoutComposition = 5000`): Android IME may leave
  composition state active indefinitely; ProseMirror drops it after 5 seconds of inactivity
- **Chrome Android Enter suppression**: `keyCode == 13` events on Chrome Android during
  composition are suppressed entirely because they're part of a "confused sequence"

**Tradeoffs:** High complexity. Requires deep understanding of browser-specific composition
behavior. Essential for contentEditable-based editors but overkill for textarea-based ones.

## Decision Guide

- "Am I using contentEditable with custom rendering?" -> Pattern C (DOM observer awareness)
  combined with Pattern A (composing flag guard)
- "Am I using a textarea for text input?" -> Pattern B (inline isComposing check)
- "Do I need to support CJK input on Safari?" -> Pattern A's timing window is essential;
  Pattern B alone will miss Safari's out-of-order events
- "Mobile-only or mobile-first?" -> Pattern B's `keyCode === 229` check is essential
- "Do I have a mutation observer?" -> Pattern C coordinates composition with DOM reconciliation

### Platform-Specific Edge Cases

| Browser/Platform | Issue | Mitigation |
|-----------------|-------|------------|
| Safari | `compositionend` fires before `keydown` for Enter | Timing window guard (500ms) in ProseMirror |
| Chrome Android | Enter keyCode 13 during composition corrupts input | Suppress entirely (`if (browser.android && browser.chrome && event.keyCode == 13) return`) |
| iOS | `preventDefault` on Enter confuses virtual keyboard | Use flag + fallback timeout (200ms) instead of preventDefault |
| Safari (table cells) | Composed text moves to wrong table row on compositionend | `fixUpBadSafariComposition` repositions DOM nodes |
| Android (general) | Composition may never end | Timeout after 5000ms of inactivity |

## Anti-Patterns

### Don't: Check Only `event.isComposing` Without `keyCode === 229`
**What happens:** Mobile IME input (especially on older Android WebViews) sends `keyCode: 229`
without setting `isComposing: true` on the event. Composition events fire but the property
check misses them.
**Instead:** Always check `event.isComposing || event.keyCode === 229`.

### Don't: Process Keydown Events During Composition for "Special Keys"
**What happens:** Treating Enter or Backspace as actionable during composition corrupts
the IME state. Enter is used to *confirm* the IME candidate, not to commit text.
Backspace navigates within the candidate list, not to delete characters.
**Instead:** Bail on ALL keydown processing when `inOrNearComposition` returns true.
The sole exceptions are meta-key combinations that the IME never uses (e.g., Ctrl+S).

### Don't: Rely on compositionend to Synchronously Commit Text
**What happens:** Browser event ordering between `compositionend` and subsequent `keydown`
varies. Processing compositionend synchronously may race with a keydown that should be
suppressed (Safari Enter issue).
**Instead:** Use a timing window or defer compositionend processing to the next microtask.
