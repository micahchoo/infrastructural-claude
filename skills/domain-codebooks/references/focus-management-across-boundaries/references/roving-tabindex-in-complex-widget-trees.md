# Roving Tabindex in Complex Widget Trees

## Force Cluster Resolved

**Component encapsulation vs Global focus state** and **Keyboard accessibility vs Custom widget complexity**.

A toolbar with 15 buttons should not generate 15 Tab stops — this destroys keyboard efficiency for sequential navigation. But each button must remain individually reachable. Roving tabindex resolves this by making the group a single Tab stop while using arrow keys for internal navigation.

## Competing Patterns

### Pattern A: Centralized ActionBar with Lazy Tabindex Assignment

**When to use:** Toolbars, menubars, action groups — any horizontal or vertical strip of discrete actions where the set of items changes dynamically (add/remove actions, enable/disable items).

**When NOT to use:** Static button groups that never change. Groups where items have complex internal focus needs (e.g., a toolbar button that opens an inline editor).

**How it works:**

1. The container (`ActionBar`) owns a `focusedItem` index and a `focusTracker` (DOM focus/blur observer).
2. On initialization, exactly ONE item gets `tabIndex=0` (the first enabled item); all others get `tabIndex=-1`.
3. Arrow keys (Left/Right for horizontal, Up/Down for vertical) call `focusNext()`/`focusPrevious()` which cycle through items, skipping disabled items and separators.
4. **Lazy tabindex**: `tabIndex=0` is only set on an element at the moment it receives focus — not before. This prevents the element from being a Tab stop when it's not the active roving target.
5. On blur, the previously focused item gets `tabIndex=-1` and a `previouslyFocusedItem` index is stored for re-entry.
6. `setFocusable(boolean)` toggles the entire group in/out of the tab order — when `false`, ALL items get `tabIndex=-1`.

**Production example: VS Code `ActionBar` + `BaseActionViewItem`**

Source: `src/vs/base/browser/ui/actionbar/actionbar.ts` and `src/vs/base/browser/ui/actionbar/actionViewItems.ts`

```
// ActionBar tracks focused item index and uses DOM.trackFocus for blur/focus events
private previouslyFocusedItem?: number;
protected focusedItem?: number;
private focusTracker: DOM.IFocusTracker;
```

Key mechanism — orientation-dependent arrow key binding:
```
case ActionsOrientation.HORIZONTAL:
    previousKeys = [KeyCode.LeftArrow];
    nextKeys = [KeyCode.RightArrow];
    break;
case ActionsOrientation.VERTICAL:
    previousKeys = [KeyCode.UpArrow];
    nextKeys = [KeyCode.DownArrow];
    break;
```

Lazy tabindex in `BaseActionViewItem`:
```
// Only set the tabIndex on the element once it is about to get focused
// That way this element wont be a tab stop when it is not needed #106441
focus(): void {
    if (this.element) {
        this.element.tabIndex = 0;
        this.element.focus();
        this.element.classList.add('focused');
    }
}

blur(): void {
    if (this.element) {
        this.element.tabIndex = -1;
        this.element.classList.remove('focused');
    }
}
```

Group-level focusability toggle:
```
setFocusable(focusable: boolean): void {
    this.focusable = focusable;
    if (this.focusable) {
        const firstEnabled = this.viewItems.find(vi => vi instanceof BaseActionViewItem && vi.isEnabled());
        if (firstEnabled instanceof BaseActionViewItem) {
            firstEnabled.setFocusable(true);
        }
    } else {
        this.viewItems.forEach(vi => {
            if (vi instanceof BaseActionViewItem) {
                vi.setFocusable(false);
            }
        });
    }
}
```

The `trapsArrowNavigation` getter on `BaseActionViewItem` defaults to `false` but can be overridden by subclasses that need internal arrow key handling (e.g., a dropdown within a toolbar). When `true`, the ActionBar uses Tab instead of arrow keys to escape that item.

**Tradeoffs:** Focus index must be recalculated when items are added/removed mid-session. The `previouslyFocusedItem` memory can go stale if the item set changes between blur and re-focus.

### Pattern B: Trait-Based Virtual Focus (Data-Driven)

**When to use:** Virtualized lists/trees where the focused item may not be in the DOM. Large collections (1000+ items) where DOM-based focus tracking is insufficient.

**When NOT to use:** Small, static groups where DOM focus is sufficient. Widgets without virtualization.

**How it works:**

1. A `Trait<T>` class maintains an array of indexes that have a given trait (e.g., "focused", "selected").
2. Focus is tracked as data — `this.focus = new Trait<T>('focused')` — independent of which items are rendered.
3. When the user navigates, `setFocus([newIndex])` updates the trait. The renderer applies/removes a CSS class on the DOM element if it's currently rendered.
4. The container DOM node holds actual browser focus (`this.view.domNode.focus()`); individual items receive visual focus styling via CSS class, not `tabIndex`.
5. When a focused item has an interactive child (e.g., a button inside a list row), `querySelector('[tabIndex]')` finds and focuses it.

**Production example: VS Code `List` widget**

Source: `src/vs/base/browser/ui/list/listWidget.ts`

```
class Trait<T> implements ISpliceable<boolean>, IDisposable {
    protected indexes: number[] = [];
    protected sortedIndexes: number[] = [];
    private readonly _onChange = new Emitter<ITraitChangeEvent>();
    // ...
    constructor(private _trait: string) { }
}

// In the List class:
private focus = new Trait<T>('focused');
```

Container-level focus with delegation to interactive children:
```
const focusedDomElement = this.view.domElement(focus[0]);
const tabIndexElement = focusedDomElement.querySelector('[tabIndex]');
if (!tabIndexElement || tabIndexElement.tabIndex === -1) { return; }
tabIndexElement.focus();
```

Tree view hides its HTML element to remove it from the tab order when empty:
```
DOM.hide(this.tree.getHTMLElement()); // make sure the tree goes out of the tabindex world by hiding it
```

**Tradeoffs:** Requires a rendering layer that can apply/remove CSS classes when items scroll into/out of view. More complex than pure DOM focus. Focus changes are asynchronous when they trigger scroll-into-view.

## Decision Guide

- "I have a toolbar/menubar/action strip with dynamic items" → Pattern A (ActionBar with lazy tabindex)
- "I have a virtualized list/tree with thousands of items" → Pattern B (Trait-based virtual focus)
- "I have a toolbar INSIDE a virtualized list row" → Combine: Pattern B manages list-level focus, Pattern A manages toolbar-level focus within the row
- "I need to temporarily remove a group from Tab order" → `setFocusable(false)` pattern from Pattern A
- "An item inside the group needs to trap arrow keys" → `trapsArrowNavigation` escape hatch, fall back to Tab for group navigation

## Anti-Patterns

### Don't: Set tabIndex=0 on All Items at Render Time
**What happens:** Every item becomes a Tab stop. A toolbar with 20 buttons requires 20 Tab presses to pass through. Screen reader users announce "button 1 of... button 2 of..." for each item during Tab navigation.
**Instead:** Use lazy tabindex — only the active roving target gets `tabIndex=0`. All others are `tabIndex=-1`.

### Don't: Forget to Skip Disabled Items and Separators
**What happens:** Arrow key navigation lands on disabled buttons or separator elements that provide no interaction. Users must press arrow keys multiple times to reach the next actionable item.
**Instead:** `focusNext()` should loop past items where `!item.isEnabled()` or `item.action.id === Separator.ID`.

### Don't: Lose Focus Memory When Items Change
**What happens:** User focuses item 5, the set changes (item removed/added), user returns — focus lands on item 0 instead of the nearest valid item to where they were.
**Instead:** Store focused item identity (not just index). On item set change, find the nearest match. VS Code recalculates via `updateFocusedItem()` after action list changes.
