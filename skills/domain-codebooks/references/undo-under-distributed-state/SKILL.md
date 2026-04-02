---
name: undo-under-distributed-state
description: >-
  Architectural advisor for undo/redo systems operating on distributed, batched,
  and multi-scoped mutable state. The force tension: preserving the user's mental
  model of "undo" when state is shared across clients, mutations are batched,
  and undo scope varies by context.

  This is the compound spaghetti factory — where distributed state sync and
  interactive editing collide. Most undo bugs live at this intersection.

  NOT simple single-user undo (Cmd+Z on a text field), browser history
  navigation, version control (git), or database transaction rollback.

  Triggers: command pattern for undo, immutable snapshot undo, event sourcing
  undo, diff-based undo (reactive stores), CRDT-native undo (Yjs UndoManager),
  multiplayer undo (local-only vs shared history), undo scope taxonomy (document
  vs page vs selection vs mode), batch transaction semantics, inverse computation
  for batched operations, undo batching levels, nested undo contexts for
  sub-editing modes, per-mutation capture intent, multi-page/multi-canvas undo
  scope, selection invalidation on undo, group undo semantics.

  Brownfield triggers: "undo breaks when I add a new element type", "undo
  restores the parent but not its children", "undo stack corrupted after adding
  multiplayer sync", "batch undo undoes too much after refactoring mutations",
  "adding a sub-editor broke the undo scope", "undo leaves dangling references
  after adding delete cascades", "switching from snapshot to diff undo broke
  selection restore", "undo fights the CRDT after migrating to Yjs",
  "Ctrl+Z reverts someone else's changes in multiplayer", "undo takes multiple
  presses to reverse a group move", "text sub-mode undo scope is wrong",
  "undo doesn't restore selection after switching to diff-based undo",
  "undone element comes back at wrong z-index position", "undo does nothing
  because viewport state is in the undo stack", "undo on page 2 undoes action
  on page 1", "Zustand temporal middleware stores entire state on each change".

  Symptom triggers: "migrated canvas editor to Yjs for multiplayer undo worked fine
  before simple command stack now UndoManager undoes remote changes too Ctrl+Z
  reverts someone else's shape move how to scope undo to local-only",
  "whiteboard group select and move selects 5 shapes and drags each shape emits a
  position mutation undo should reverse entire drag as one step but takes 5
  Ctrl+Zs how to batch into single undo entry",
  "text-editing sub-mode double-click shape to edit text undo scope is wrong text
  edits should undo character-by-character in text mode once you exit entire text
  session should be one undo step on shape level nested undo contexts",
  "switched from snapshot-based undo to diff-based undo using Immer patches undo
  doesn't restore selection state old snapshot included selection patches only
  capture store diff should undo restore selection",
  "Excalidraw-style app flat element array undo a delete element comes back at
  wrong z-index position pushing to end of array instead of restoring original
  position undo system doesn't capture ordering intent",
  "undo does nothing press Ctrl+Z nothing visible changes undo stack includes
  viewport pan zoom changes invisible when viewport has since moved should we
  exclude viewport state from undo",
  "multi-page document editor undo on page 2 sometimes undoes action on page 1
  user forgot about should undo be scoped per-page or per-document tradeoffs".

  Cross-codebook triggers: "undo interacts with bindings/constraints" (+ constraint-graph),
  "undo breaks in embedded editor context" (+ embeddability).

  Diffused triggers: "undo doesn't work right in multiplayer", "how to scope
  undo per user in collaborative editing", "batch undo for multi-select
  operations", "undo stack corrupted after sync", "CRDT undo architecture",
  "should undo restore selection state", "nested undo for sub-editors",
  "undo across page boundaries", "whiteboard undo system", "why does undo break
  when I add [specific change]", "after adding [feature] undo is inconsistent",
  "the undo system is getting unmaintainable", "undo undoes the wrong amount
  after I changed the mutation layer".

  Libraries: Yjs UndoManager, Automerge, Immer (patches), Redux Undo, Zustand
  temporal middleware.

  Production examples: tldraw, Excalidraw, Figma, Google Docs, Notion,
  VS Code, Photoshop.

  Skip: simple Cmd+Z on text inputs, browser back/forward, git undo (revert/
  reset), database ROLLBACK, retry/compensation patterns in distributed systems
  (Saga pattern).
---

# Undo/Redo Under Distributed State

**Force tension:** Preserving the user's mental model of "undo" when state is
shared across clients, mutations are batched, and undo scope varies by context.

This force cluster sits at the intersection of distributed-state-sync and
interactive-spatial-editing. It's the compound spaghetti factory — most undo
bugs live where sync, batching, scope, and selection state interact.

## Step 1: Classify the undo problem

1. **Distribution model**: Single-user, local-first with sync, or real-time multiplayer?
2. **Undo scope**: Global document, per-page/canvas, per-selection, or per-mode?
3. **Multiplayer undo model**: Local-only (undo only my actions) or shared history?
4. **State representation**: Mutable objects, immutable snapshots, CRDT documents, or event log?
5. **Batch semantics**: Are multi-element operations one undo step or many?
6. **Selection interaction**: Does undo restore selection state or only data state?

## Step 2: Load reference

| Axis | File |
|------|------|
| Undo/redo patterns / batch transactions / scope / multiplayer | `get_docs("domain-codebooks", "undo-distributed-state undo-redo patterns")` |
| Multiplayer undo scope / conflict resolution / reconnection | `get_docs("domain-codebooks", "undo-distributed-state multiplayer scope")` |

## Step 3: Advise and scaffold

Present competing patterns with tradeoffs. The five main approaches:

1. **Command pattern** — explicit do/undo pairs, full control
2. **Immutable snapshots** — simple but memory-heavy
3. **Event sourcing** — replay from log, natural audit trail
4. **Diff-based** (reactive stores) — patches/inverse patches, works with Immer/Zustand
5. **CRDT-native** (Yjs UndoManager) — undo within CRDT, automatic conflict handling

### Cross-References (force interactions)

- For the sync/conflict layer that undo operates on → see **distributed-state-sync**
- For the selection/mode state that undo interacts with → see **interactive-spatial-editing**
- For annotation-specific undo concerns → see **annotation-state-advisor** (composite recipe)

## Principles

1. **Undo scope = portable tier only.** Undo document state, not workspace state (viewport, tool selection). Figma/Photoshop/VS Code consensus.
2. **Multiplayer undo is always local-scoped.** Users undo THEIR actions, not others'. Shared undo history is a UX trap.
3. **Batch boundaries must be explicit.** Implicit batching (by time window) causes "undo undid too much/too little" bugs.
4. **Selection invalidation after undo.** If undone mutation deletes a selected element, selection must update. This is where undo and selection spaghetti lives.
5. **CRDT-native undo changes everything.** If your state is in Yjs, use UndoManager — don't build a parallel undo stack that fights the CRDT.
