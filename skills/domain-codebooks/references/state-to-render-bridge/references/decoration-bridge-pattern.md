# Decoration Bridge Pattern

## The Problem

Rich-text editors (ProseMirror, Slate, CodeMirror) represent documents as tree
structures with positions defined by node hierarchy. CRDTs (Automerge, Yjs)
represent text as flat character sequences with positions defined by indices or
unique character IDs. Bridging between these requires:

1. **Position mapping** — converting flat CRDT indices to tree positions and back
2. **Transaction translation** — expressing CRDT ops as editor transactions and
   editor transactions as CRDT ops
3. **Decoration preservation** — maintaining editor-local visual state (cursors,
   selections, highlights) across remote CRDT updates

---

## Competing Patterns

### 1. Bidirectional Transaction Translation (upwelling)

**How it works:** Two translator modules convert between CRDT operations and
editor transactions in both directions. A position mapper handles coordinate
translation between the two models.

**Example — upwelling Automerge↔ProseMirror:**

Three key files form the bridge:
- `app/src/prosemirror/utils/PositionMapper.ts` — walks document structure,
  converting Automerge flat indices to ProseMirror tree positions by accounting
  for block-element offsets (+1 per block boundary)
- `app/src/prosemirror/utils/AutomergeToProsemirrorTransaction.ts` — converts
  Automerge patches (splice, put) into ProseMirror transactions (insert, delete,
  replaceWith)
- `app/src/prosemirror/utils/ProsemirrorTransactionToAutomerge.ts` — converts
  ProseMirror transactions (steps) into Automerge change operations

Position mapping arithmetic:
- Each block element (paragraph, heading) adds +1 to the ProseMirror position
  relative to the Automerge index
- `PositionMapper` walks the document counting block boundaries to compute the
  offset at any given Automerge index
- Schema is intentionally restricted to paragraph/heading only — lists,
  blockquotes, and code blocks are explicitly deferred to "V3+" because they
  would break the +1-per-block assumption

**Tradeoffs:**
- Bidirectional — supports both local and remote changes
- Position mapping is fragile — adding any structural element type requires
  updating the offset arithmetic
- Schema restriction is a deliberate engineering decision, not a limitation
- Two separate translator modules that must stay in sync

**De-Factoring Evidence:**
- **If the PositionMapper were removed:** Every character insertion would need
  to scan the document to compute the offset between Automerge and ProseMirror
  positions inline. Each translator would duplicate the walk logic. Off-by-one
  errors would appear at every block boundary.
  **Detection signal:** `+ 1` adjustments scattered throughout transaction
  translation code with comments like "account for paragraph opening tag."

- **If the schema were expanded without updating PositionMapper:** Nested block
  elements (list items inside lists) introduce variable offsets — some boundaries
  add +1, nested ones add +2 or more. The flat +1-per-block assumption breaks.
  **Detection signal:** "cursor jumps to wrong position after remote edit in a
  list"; "inserting text into a blockquote puts it in the wrong paragraph."

- **If either translator were removed (making it one-directional):** Local
  changes wouldn't propagate to the CRDT (no ProseMirror→Automerge) or remote
  changes wouldn't render (no Automerge→ProseMirror). Both directions are
  required for collaboration.
  **Detection signal:** "local edits don't appear for remote users" or "remote
  edits don't render locally."

---

### 2. Decoration Overlay (ProseMirror pattern)

**How it works:** Instead of modifying the document to show collaboration state
(remote cursors, pending highlights, conflict markers), use the editor's
decoration system to overlay visual state on top of the document.

**ProseMirror's decoration model:**
- Decorations are visual annotations that don't modify the document
- They survive transaction application — the editor remaps decoration positions
  when the document changes
- Three types: inline (wrap text), node (wrap a node), widget (insert element)

**How upwelling uses decorations for collaboration:**
- Remote peer cursors rendered as widget decorations
- Pending changes highlighted with inline decorations
- Conflict regions shown as node decorations with action buttons

This approach is critical because it decouples collaboration UI from document
state. Remote cursor positions don't need to be in the CRDT — they're local
decorations updated from the awareness channel.

**Tradeoffs:**
- Clean separation: document state in CRDT, display state in decorations
- Decorations survive remote document changes (editor handles remapping)
- Decoration updates are cheap (no document transaction needed)
- Decoration position remapping can be incorrect when combined with complex
  CRDT merges
- Performance degrades with many decorations (>1000) on large documents

**De-Factoring Evidence:**
- **If decorations were replaced with document-embedded collaboration state:**
  Remote cursor positions stored in the CRDT would create write conflicts —
  every cursor move by any peer conflicts with every other peer's cursor move.
  Document size grows linearly with peer count. Undo would affect cursor state.
  **Detection signal:** CRDT document contains `remoteCursors` array or
  `peerSelections` map; cursor moves appear in undo history.

---

### 3. Full Document Replacement (naive approach)

**How it works:** On any CRDT change, serialize the entire CRDT document to the
editor's format and replace the editor's content wholesale.

**Why it exists:** Some initial integrations start here because it's simple and
correct. Automerge's `doc.text` → ProseMirror `setContent()` is a one-liner.

**Why it fails in production:**
- Destroys all ephemeral state: cursor position, selection, scroll, undo history
- Causes visible flicker as content is removed and re-inserted
- O(n) for every change regardless of change size
- Composition input (IME) breaks because the editor loses input context

**When it's acceptable:**
- Initial document load (loading the document for the first time)
- Recovery from desync (detected via checksum mismatch)
- Document-level operations (branch switch, version restore)

---

## Decision Guide

**Choose Bidirectional Translation when:**
- The editor has its own operation/transaction model (ProseMirror, Slate)
- You need true collaborative editing (multiple concurrent editors)
- You can restrict the schema to keep position mapping tractable
- You're willing to invest in maintaining two translator modules

**Choose Decoration Overlay when:**
- You need to show collaboration UI (cursors, presence, highlights)
- The collaboration state shouldn't be in the document model
- The editor supports a decoration/annotation layer
- You're already using bidirectional translation for document changes

**Choose Full Replacement only for:**
- Initial load
- Recovery from detected desync
- Contexts where ephemeral state doesn't matter

---

## Cross-Pattern Interactions

### Translation + Decoration Together

The most robust rich-text collaborative editing stack uses both:
1. **Bidirectional translation** for document changes (text inserts, formatting)
2. **Decoration overlay** for collaboration UI (cursors, selections, highlights)

This mirrors upwelling's architecture. The translation layer handles the hard
part (position mapping, operation conversion). The decoration layer handles the
visual part (showing who's where) without polluting the document model.

### Translation Complexity vs Schema Complexity

There is a direct relationship between schema complexity and position mapping
difficulty:

| Schema Level | Block Types | Position Mapping |
|---|---|---|
| Minimal | paragraph, heading | +1 per block (linear) |
| Moderate | + lists, blockquotes | +N per nesting level (tree walk) |
| Rich | + tables, figures, embeds | Custom per-type offset rules |

Upwelling chose minimal schema deliberately. Each additional block type doesn't
just add code — it adds a new class of position mapping edge cases. The advice:
start minimal, expand only when position mapping for each new type is proven
correct with tests.

---

## Anti-Patterns

### 1. Shared Mutable Position Cache
Caching position mappings between CRDT and editor and reusing across transactions.
CRDT operations can invalidate any cached position — inserts shift everything after.
**Detection signal:** "cursor jumps to wrong position after rapid remote edits";
position cache with manual invalidation logic.

### 2. Editor-Side CRDT Awareness
Making the editor aware of CRDT semantics (checking CRDT timestamps, reading
tombstones). The bridge should fully encapsulate CRDT details — the editor sees
normal transactions.
**Detection signal:** `import { Automerge } from ...` in editor plugin code;
CRDT types in editor state interfaces.

### 3. Decoration-Document Coupling
Decorations that reference CRDT-internal data (character IDs, operation
timestamps) rather than document positions. When the CRDT compacts or the
mapping changes, decorations break.
**Detection signal:** Decorations positioned by CRDT character ID rather than
editor position; decorations break after CRDT garbage collection.
