# Shadow DOM and Focus Boundary Piercing

## Force Cluster Resolved

**Component encapsulation vs Global focus state** — at the DOM boundary level. Shadow DOM encapsulates styles and DOM structure, but `document.activeElement` stops at the shadow boundary. If a component inside a shadow root has focus, the host document only sees the shadow host as focused — not the actual element. This breaks focus tracking, focus traps, `isAncestor()` checks, and keyboard shortcut scoping.

## Competing Patterns

### Pattern A: Shadow-Aware Active Element Resolution

**When to use:** Any application that uses Shadow DOM components AND needs to track which specific element has focus (for focus traps, keyboard shortcut scoping, or focus restoration).

**When NOT to use:** Applications that never use Shadow DOM or Web Components. Cases where knowing the shadow host is focused is sufficient.

**How it works:**

1. Instead of reading `document.activeElement` directly, use a utility that recursively pierces shadow boundaries.
2. Start from `document.activeElement`. If it has a `.shadowRoot`, read `.shadowRoot.activeElement`. Repeat until no more shadow roots.
3. For ancestor checks (`isAncestor`), account for shadow boundaries by walking through shadow roots.
4. For `getShadowRoot()`, walk up the parent chain from a node — if the root is a `ShadowRoot`, return it.

**Production example: VS Code `dom.ts` utilities**

Source: `src/vs/base/browser/dom.ts`

Shadow root detection:
```
export function getShadowRoot(domNode: Node): ShadowRoot | null {
    while (domNode.parentNode) {
        if (domNode === domNode.ownerDocument?.body) {
            // reached the body
            return null;
        }
        domNode = domNode.parentNode;
    }
    return isShadowRoot(domNode) ? domNode : null;
}

export function isInShadowDOM(domNode: Node): boolean {
    return !!getShadowRoot(domNode);
}
```

Recursive active element resolution through shadow boundaries:
```
// getActiveElement() pierces shadow DOM:
let result = getActiveDocument().activeElement;

while (result?.shadowRoot) {
    result = result.shadowRoot.activeElement;
}

return result;
```

Shadow-aware `FocusTracker.hasFocusWithin()`:
```
private static hasFocusWithin(element: HTMLElement | Window): boolean {
    if (isHTMLElement(element)) {
        const shadowRoot = getShadowRoot(element);
        const activeElement = (shadowRoot
            ? shadowRoot.activeElement
            : element.ownerDocument.activeElement);
        return isAncestor(activeElement, element);
    } else {
        const window = element;
        return isAncestor(window.document.activeElement, window.document);
    }
}
```

Key design decision: `hasFocusWithin` checks from the shadow root level, not the document level. If the element being tracked is inside a shadow DOM, it reads `shadowRoot.activeElement` instead of `document.activeElement`. This ensures focus tracking works correctly regardless of where in the shadow DOM hierarchy the tracked element lives.

**Tradeoffs:** Every focus check must go through these utilities — a single raw `document.activeElement` access bypasses shadow awareness and can produce incorrect results. This is a "pit of failure" design; developers must know to use the utility, not the native API.

### Pattern B: Focus Event Delegation Across Shadow Boundaries

**When to use:** When you need to react to focus/blur within shadow DOM subtrees — for focus tracking, context key updates, or dismiss-on-blur behavior.

**When NOT to use:** When you only need to know if a specific known element has focus.

**How it works:**

1. `focusin`/`focusout` events DO cross shadow DOM boundaries (they bubble). Use these instead of `focus`/`blur` (which don't bubble).
2. Attach listeners to the shadow host or a parent outside the shadow boundary.
3. Use `e.composedPath()` to get the full path through shadow boundaries if you need to know exactly which element inside the shadow root triggered the event.
4. For focus traps containing shadow DOM children, the trap must be aware that `e.relatedTarget` in `focusout` might be inside a shadow root — use `isAncestor()` with shadow-aware logic.

**Production example: VS Code `FocusTracker` class**

Source: `src/vs/base/browser/dom.ts`

The `FocusTracker` uses a focus/blur debounce pattern with `hasFocusWithin()`:
```
class FocusTracker extends Disposable implements IFocusTracker {
    constructor(element: HTMLElement | Window) {
        super();
        let hasFocus = FocusTracker.hasFocusWithin(element);
        let loosingFocus = false;

        const onFocus = () => {
            loosingFocus = false;
            if (!hasFocus) {
                hasFocus = true;
                this._onDidFocus.fire();
            }
        };
        // ... onBlur is debounced to handle focus transitions within the element
    }
}
```

This tracker is used pervasively across VS Code's workbench — every pane, every tree view, every composite part creates one:
```
// In treeView.ts:
const focusTracker = this._register(DOM.trackFocus(this.domNode));
this._register(focusTracker.onDidFocus(() => this.focused = true));
this._register(focusTracker.onDidBlur(() => this.focused = false));

// In paneCompositePart.ts:
const focusTracker = this._register(trackFocus(parent));
this._register(focusTracker.onDidFocus(() => this.paneFocusContextKey.set(true)));
this._register(focusTracker.onDidBlur(() => this.paneFocusContextKey.set(false)));
```

**Tradeoffs:** The blur debounce can cause brief incorrect state during focus transitions (focus moves from child A to child B within the same tracked element — blur fires before focus). VS Code handles this with the `loosingFocus` flag.

### Pattern C: Hiding Elements from Tab Order Across Boundaries

**When to use:** When a component should be entirely removed from keyboard navigation — not just visually hidden, but unreachable via Tab.

**When NOT to use:** When the component needs to remain in the tab order but is visually hidden (use `tabIndex=-1` with explicit `.focus()` instead).

**How it works:**

1. Hide the entire element (`display: none` or the element's `hide()` method), which removes it and all descendants from the tab order.
2. For shadow DOM components, hiding the shadow host removes the entire shadow tree from tab navigation.
3. On re-show, the element re-enters the tab order naturally.

**Production example: VS Code TreeView**

Source: `src/vs/workbench/browser/parts/views/treeView.ts`

```
DOM.hide(this.tree.getHTMLElement());
// make sure the tree goes out of the tabindex world by hiding it
```

This is used when a tree has no content — rather than leaving an empty container in the tab order, the entire element is hidden. The comment explicitly calls out the tab-order implication, indicating this is a deliberate focus management decision, not just a visual concern.

**Tradeoffs:** Binary — the element is either fully in or fully out of the tab order. No partial participation. If the element is hidden while it has focus, focus will jump to the nearest focusable ancestor or `<body>`.

## Decision Guide

- "I need to check which element has focus, and my app uses Shadow DOM" → Pattern A (shadow-aware `getActiveElement()`)
- "I need to track when a subtree gains/loses focus, and it may contain shadow DOM" → Pattern B (`FocusTracker` with `hasFocusWithin()`)
- "I need to remove a component from the tab order entirely" → Pattern C (hide the element)
- "I'm building a focus trap around a container that includes Web Components" → Combine Pattern A (for active element detection) + Pattern B (for escape detection via focusout)

## Anti-Patterns

### Don't: Use Raw `document.activeElement` in Shadow DOM Contexts
**What happens:** `document.activeElement` returns the shadow host element, not the actual focused element inside the shadow root. Focus traps think focus has left the trap (because the active element isn't a descendant of the trap container in the light DOM). Focus restoration saves the shadow host instead of the actual focused element.
**Instead:** Use a recursive `getActiveElement()` that pierces shadow roots via `.shadowRoot.activeElement`.

### Don't: Use `focus`/`blur` Events for Cross-Boundary Tracking
**What happens:** `focus` and `blur` events don't bubble. If a child element inside a shadow root gains focus, the parent outside the shadow boundary never receives the `focus` event. Focus trackers appear to never detect focus.
**Instead:** Use `focusin`/`focusout` which DO bubble and cross shadow boundaries. Use `composedPath()` for the full event path.

### Don't: Assume `e.relatedTarget` in focusout Is in the Same DOM Tree
**What happens:** When focus moves from inside a shadow root to outside it (or vice versa), `e.relatedTarget` may be `null` or may reference an element in a different shadow tree. Focus traps that check `isAncestor(e.relatedTarget, trapElement)` get false negatives.
**Instead:** Use shadow-aware ancestor checks, or use the `hasFocusWithin()` pattern with a microtask delay to let focus settle before checking.

## Contradictions with Existing Codebook

The existing `focus-trap-and-restoration.md` Pattern A describes `getTabbable()` to find tabbable elements within a container. This approach **does not account for Shadow DOM** — `querySelectorAll` doesn't pierce shadow boundaries, so tabbable elements inside shadow roots are invisible to the trap. This is not a fundamental contradiction but a scope limitation: Pattern A works for light DOM containers; shadow-aware traps need the additional utilities documented here (Pattern A + B from this file) layered on top.

**Discriminating factor:** If the focus trap container only contains light DOM elements, the existing Pattern A is sufficient. If the container includes Web Components with shadow roots, the shadow-aware utilities from this file must be integrated into the trap's element discovery and focus tracking logic.
