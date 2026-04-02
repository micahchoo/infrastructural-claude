# Cross-Panel Focus Delegation

## Force Cluster Resolved

**Component encapsulation vs Global focus state** — at the application level. Individual panels (sidebar, editor, terminal, notification area) each manage their own internal focus, but the application must coordinate focus transitions between them. A "Focus Sidebar" command must know which pane inside the sidebar to focus, and dismissing a notification must know whether to return focus to the editor or to where it came from.

## Competing Patterns

### Pattern A: Hierarchical Focus Delegation Chain

**When to use:** Applications with nested container hierarchy (app → part → pane container → pane → widget). Each level owns a `.focus()` method that delegates to the most appropriate child.

**When NOT to use:** Flat UIs without nesting. Single-panel applications. Cases where focus target is always a specific known element.

**How it works:**

1. Each level in the hierarchy implements a `focus()` method.
2. The top level (e.g., workbench layout) calls `part.focus()` on the target part.
3. Each part delegates to its active/last-focused child: `paneContainer.focus()` → `lastFocusedPane.focus()` → `tree.focus()` → `domNode.focus()`.
4. "Last focused" memory at each level ensures re-entry lands where the user left off — not at the first child.
5. `trackFocus()` observers at each level maintain context keys (e.g., `paneFocusContextKey`) that inform the keybinding system which shortcuts are active.

**Production example: VS Code workbench focus hierarchy**

Source: `src/vs/workbench/browser/parts/views/viewPaneContainer.ts`

```
focus(): void {
    let paneToFocus: ViewPane | undefined = undefined;
    if (this.lastFocusedPane) {
        paneToFocus = this.lastFocusedPane;
    } else if (this.paneItems.length > 0) {
        for (const { pane } of this.paneItems) {
            // ... find first visible pane
        }
    }
    paneToFocus.focus();
}
```

Source: `src/vs/workbench/browser/parts/paneCompositePart.ts`

Focus tracking drives context keys for keybinding scoping:
```
const focusTracker = this._register(trackFocus(parent));
this._register(focusTracker.onDidFocus(() => this.paneFocusContextKey.set(true)));
this._register(focusTracker.onDidBlur(() => this.paneFocusContextKey.set(false)));
```

The `openPaneComposite(id, focus?)` method threads a `focus` boolean through the hierarchy — opening a pane doesn't automatically steal focus unless explicitly requested:
```
async openPaneComposite(id?: string, focus?: boolean): Promise<PaneComposite | undefined> {
    // ...
    return this.doOpenPaneComposite(id, focus);
}
```

Source: `src/vs/workbench/browser/parts/views/treeView.ts`

Tree views track focus independently via their own `trackFocus`:
```
const focusTracker = this._register(DOM.trackFocus(this.domNode));
this._register(focusTracker.onDidFocus(() => this.focused = true));
this._register(focusTracker.onDidBlur(() => this.focused = false));
```

The `focus()` method reveals the selected item before focusing the container:
```
focus(reveal: boolean = true, revealItem?: ITreeItem): void {
    if (this.tree && this.root.children && this.root.children.length > 0) {
        const element = revealItem ?? this.tree.getSelection()[0];
        if (element && reveal) {
            this.tree.reveal(element, 0.5);
        }
    }
    this.domNode.focus();
}
```

**Tradeoffs:** Deep hierarchies add indirection — debugging "why did focus go there?" requires tracing through 4-5 `.focus()` calls. `lastFocusedPane` can reference a disposed pane if lifecycle isn't carefully managed.

### Pattern B: Fallback-Chain Focus Restoration on Dismiss

**When to use:** Transient UI elements (notifications, toasts, quick picks) that steal focus temporarily and must return it to a sensible location on dismiss.

**When NOT to use:** Persistent panels that don't dismiss. Cases where the focus source is always known (use direct restoration instead).

**How it works:**

1. Before opening, store `document.activeElement` as `focusToReturn`.
2. On dismiss, attempt to restore to `focusToReturn`.
3. If `focusToReturn` is no longer in DOM or no longer focusable, fall back to a logical alternative (e.g., the editor group).
4. For stackable elements (multiple toasts), try `focusNext() || focusPrevious()` among siblings before falling back to the editor.

**Production example: VS Code Dialog**

Source: `src/vs/base/browser/ui/dialog/dialog.ts`

Save-and-restore with `focusToReturn`:
```
async show(): Promise<IDialogResult> {
    this.focusToReturn = this.container.ownerDocument.activeElement as HTMLElement;
    // ... show dialog, focus first input or button ...
}
```

Focus-out interception prevents focus from escaping the dialog:
```
this._register(addDisposableListener(this.element, 'focusout', e => {
    if (!!e.relatedTarget && !!this.element) {
        if (!isAncestor(e.relatedTarget as HTMLElement, this.element)) {
            this.focusToReturn = e.relatedTarget as HTMLElement;
            if (e.target) {
                (e.target as HTMLElement).focus();
                EventHelper.stop(e, true);
            }
        }
    }
}));
```

Note the subtle design: when focus leaves the dialog to an element outside it, the dialog (a) updates `focusToReturn` to that external element (so dismissal restores there, not to the original opener), and (b) pulls focus back into the dialog.

**Production example: VS Code Notification Toasts**

Source: `src/vs/workbench/browser/parts/notifications/notificationsToasts.ts`

Fallback chain on toast removal:
```
let focusEditor = false;
const notificationToast = this.mapNotificationToToast.get(item);
if (notificationToast) {
    const toastHasDOMFocus = isAncestorOfActiveElement(notificationToast.container);
    if (toastHasDOMFocus) {
        focusEditor = !(this.focusNext() || this.focusPrevious());
        // focus next toast if any, otherwise focus editor
    }
}
// ...
if (focusEditor) {
    this.editorGroupService.activeGroup.focus();
}
```

Key insight: notifications pause auto-dismiss when they have focus (`notificationList.hasFocus()`) — focus state directly controls component lifecycle.

**Tradeoffs:** `focusToReturn` can become stale if the original element is removed from DOM during the overlay's lifetime. The fallback chain must be maintained as new "default focus targets" are added.

### Pattern C: Focus-as-Context-Key (Keybinding Scoping)

**When to use:** Applications where keyboard shortcuts must change based on which panel has focus. The same key (e.g., `Delete`) should do different things in the file tree vs the editor vs the terminal.

**When NOT to use:** Applications with a single focus context. Simple forms.

**How it works:**

1. Each panel registers a `trackFocus()` observer that sets a context key (e.g., `sideBarFocus`, `editorFocus`, `terminalFocus`).
2. Keybinding definitions include a `when` clause that references these context keys.
3. Focus transitions automatically enable/disable shortcut sets — no manual registration/deregistration needed.
4. The context key service provides a declarative bridge between DOM focus state and command availability.

**Production example: VS Code PaneCompositePart**

Source: `src/vs/workbench/browser/parts/paneCompositePart.ts`

```
const focusTracker = this._register(trackFocus(parent));
this._register(focusTracker.onDidFocus(() => this.paneFocusContextKey.set(true)));
this._register(focusTracker.onDidBlur(() => this.paneFocusContextKey.set(false)));
```

This pattern is used consistently across all major parts — sidebar, panel, editor, activity bar — creating a matrix of focus context keys that the keybinding resolver evaluates.

**Tradeoffs:** Context keys add a layer of indirection. Debugging why a shortcut doesn't fire requires checking both focus state AND context key values. Race conditions between blur/focus events can briefly leave multiple keys as `true`.

## Decision Guide

- "Focus needs to flow to the right child in a nested container" → Pattern A (hierarchical delegation with `lastFocusedPane` memory)
- "A transient overlay must return focus on dismiss" → Pattern B (save/restore with fallback chain)
- "Keyboard shortcuts must change based on which panel is focused" → Pattern C (focus-as-context-key)
- "All three?" → Combine: Pattern A for delegation, Pattern B for overlay restoration, Pattern C for shortcut scoping. VS Code uses all three simultaneously.

## Anti-Patterns

### Don't: Delegate Focus Without "Last Focused" Memory
**What happens:** User is editing in a tree view, switches to editor, switches back to sidebar — focus lands on the first pane instead of the tree they were working in. Disrupts workflow.
**Instead:** Each delegation level stores its `lastFocusedChild` and prefers it on re-entry.

### Don't: Auto-Focus on Open Without a `focus` Parameter
**What happens:** Opening a panel in the background (e.g., loading search results) steals focus from the editor. User was typing and suddenly their keystrokes go to the wrong panel.
**Instead:** Thread a `focus?: boolean` parameter through the open chain. Only call `.focus()` when explicitly requested.

### Don't: Restore Focus to a Detached Element
**What happens:** Dialog stores `focusToReturn`, the element is removed from DOM during the dialog's lifetime, dialog closes and calls `.focus()` on a detached node — focus goes to `<body>` or nowhere.
**Instead:** Verify `focusToReturn` is still in the document before restoring. Fall back to a known-good target (e.g., editor group).
