---
name: product-design
description: Guided product design pipeline — vision, design tokens, section specs, data shapes, and implementation handoff. Use when designing a new product/app from scratch, adding a major new area to an existing product, or creating a design handoff for implementation agents. Triggers on "design a product", "product vision", "plan a new app", "design system tokens", "create a handoff", "what should we build". Also triggers from brainstorming when the task is greenfield product design rather than a feature in an existing codebase. Do NOT trigger for: single component/page design (use frontend-design), debugging, code review, implementation planning without product design (use writing-plans), or refactoring existing code.
---

# Product Design Pipeline

Structured pipeline for turning product ideas into implementation-ready specs. Framework-agnostic — outputs specs, data shapes, design tokens, and handoff docs, not framework-specific components.

## When This Skill Fires

- **Greenfield**: "I want to build a new app/product/tool"
- **Major new area**: "We need a whole new section for X" (not a feature within an existing section)
- **Design handoff**: "Create specs an implementation agent can follow"
- **Brownfield redesign**: "Rethink how the X area works" (when scope is product-level, not code-level)
- **Routed from brainstorming**: brainstorming's design doc seeds Phase 1; its Locked Decisions constrain all phases
- **From product-strategy**: strategic brief at `product/strategy/briefs/` feeds Phase 1 (don't re-derive personas/positioning); success metrics become section-level acceptance criteria. The brief is a Locked Decision

## When This Skill Does NOT Fire

- Single component or page → `frontend-design`
- Bug fix or debugging → `systematic-debugging`
- Implementation planning for an already-specced product → `writing-plans`
- Architectural pattern decisions → `pattern-advisor` or `domain-codebooks`

**Dependencies:** userinterface-wiki (Phase 3 UI rules), domain-codebooks (Phase 3 architectural forces).

## Pipeline Overview

```
Phase 1: Vision     → product overview, roadmap, data shape
Phase 2: Tokens     → color palette, typography, spacing philosophy
Phase 3: Sections   → per-section specs, user flows, sample data, types
Phase 4: Handoff    → implementation instructions, test specs, prompts
```

Each phase produces files. Later phases read earlier files. The user can enter at any phase if earlier artifacts exist.

## Checklist

Create a task for each and complete in order:

1. **Check for existing product artifacts** — scan for `product/` or `docs/product/` directory
2. **Phase 1: Vision** — define product, roadmap, data shape
3. **Phase 2: Tokens** — choose design system foundations
4. **Phase 3: Sections** — spec each section with flows, data, types
5. **Phase 4: Handoff** — generate implementation package
6. **Transition** — invoke `writing-plans` with `product-plan/instructions/` as requirements, `sections/*/types.ts` for interface extraction, and `sections/*/tests.md` for TDD structure

---

## Phase 1: Vision

**Goal**: Define what the product is, its sections, and its core entities.

### 1a: Gather product context

Search foxhound for prior art and ecosystem patterns relevant to the product domain before asking questions.

Ask the user to share raw notes, ideas, or thoughts. Be warm and open-ended:

> "Tell me about the product you're building — what problem does it solve, who is it for? Don't worry about structure, just share what's on your mind."

### 1b: Clarifying questions (one at a time)

**Product definition:**
- Product name (short, memorable)
- Core description (1-3 sentences)
- Key problems solved (1-5 pain points)
- How the product solves each problem
- Main features

**Roadmap:**
- Main areas/sections of the product (3-7)
- Priority order for building
- Which areas are independent vs. dependent

**Data shape:**
- Core entities ("nouns") users create, view, or manage
- How entities relate to each other

### 1c: Write artifacts (auto-proceed after gathering enough info)

Proceed at >80% confidence on Vision fields. 5+ vague answers → surface ambiguity explicitly.

**`product/product-overview.md`**:
```markdown
# [Product Name]

## Description
[1-3 sentence description]

## Problems & Solutions
### Problem 1: [Title]
[How the product solves it]
[... up to 5]

## Key Features
- [Feature 1]
- [Feature 2]
[...]
```

**`product/product-roadmap.md`**:
```markdown
# Product Roadmap

## Sections
### 1. [Section Title]
[One sentence description]
[... ordered by priority, 3-7 sections]
```

**`product/data-shape/data-shape.md`**:
```markdown
# Data Shape

## Entities
### [EntityName]
[What this entity represents and its purpose]
[... singular names: User, Invoice, Project]

## Relationships
- [Entity1] has many [Entity2]
- [Entity2] belongs to [Entity1]
[...]
```

---

`bias:substitution` — Before proceeding to design tokens: are you designing the product the user asked for, or a simpler/more familiar product? Compare the vision doc against the original request. If scope was narrowed, was that a conscious decision or drift?

## Phase 2: Design Tokens

**Goal**: Establish visual identity foundations — colors, typography, spacing.

**Prerequisite**: `product/product-overview.md` exists.

### 2a: Understand the product's tone

Load `frontend-design/references/visual-design-thinking.md` before this step. Use the Decomposition Method to translate the user's vibe words into concrete design properties — don't stop at adjectives.

> "What vibe are you going for? Professional, playful, modern, minimal, bold, refined?"

Also ask:
- Existing brand colors or fonts?
- Light mode, dark mode, or both?
- Colors to avoid?

After gathering tone, apply the visual-design-thinking decomposition: map the user's words to a style archetype (Clean/Corporate, Bold/Editorial, Warm/Organic) or a hybrid. Write a one-sentence design rationale before choosing colors or typography. Every token decision should trace back to this rationale.

### 2b: Choose colors

These tokens set constraints that `frontend-design` will work within at the component level — product-design owns the palette, frontend-design owns the implementation.

Present contextual suggestions based on the product type and the design rationale from 2a. Offer 3 roles:
- **Primary** — main accent, buttons, links, key actions
- **Secondary** — tags, highlights, complementary elements
- **Neutral** — backgrounds, text, borders

Use the visual-design-thinking Material and Surface dimension: choose shadow tint colors that match the palette (warm shadows for warm palettes, neutral for corporate). Define an elevation model (2-4 levels) alongside the color tokens — shadows are part of the color system.

**Framework-agnostic**: Record color names/values that work across CSS frameworks. If the project uses Tailwind, use palette names. If not, use HSL or hex values. Check the project's actual tech stack before recommending.

### 2c: Choose typography

Suggest font pairings based on the product's tone and style archetype:
- **Heading font** — display/title use
- **Body font** — paragraphs, UI text
- **Mono font** — code, technical content (if applicable)

Consult `frontend-design` skill principles: avoid generic defaults (Inter, Roboto, Arial). Choose distinctive, characterful fonts that match the product's personality. Use visual-design-thinking archetype guidance for letter-spacing, line-height, and size contrast ratios.

### 2d: Write artifacts

**`product/design-system/colors.json`**:
```json
{
  "primary": { "name": "[color]", "value": "[hex/hsl]", "usage": "buttons, links, key accents" },
  "secondary": { "name": "[color]", "value": "[hex/hsl]", "usage": "tags, highlights, secondary" },
  "neutral": { "name": "[color]", "value": "[hex/hsl]", "usage": "backgrounds, text, borders" },
  "mode": "light|dark|both"
}
```

**`product/design-system/typography.json`**:
```json
{
  "heading": { "family": "[Font Name]", "source": "google|system|custom", "rationale": "[why]" },
  "body": { "family": "[Font Name]", "source": "google|system|custom", "rationale": "[why]" },
  "mono": { "family": "[Font Name]", "source": "google|system|custom", "rationale": "[why]" }
}
```

---

## Phase 3: Section Specification

**Goal**: For each section in the roadmap, define specs, user flows, sample data, and types.

**Prerequisite**: `product/product-roadmap.md` exists.

Repeat for each section (or the user's chosen section):

### 3a: Identify target section

If multiple sections exist, ask which to work on. If only one, auto-select.

### 3b: Gather section requirements (one question at a time)

- Main user actions/tasks in this section
- Information to display (what data, what content)
- Key user flows (step-by-step interactions)
- UI patterns (tables, cards, modals, lists, dashboards)
- Scope boundaries (what's explicitly excluded)
- Multiple views needed? (list + detail, dashboard + settings)

Focus on UX and UI — no backend or database details at this point.

When specs touch known architectural domains (spatial editing, undo/redo, sync, annotation), pull the relevant `domain-codebooks` entry so specs account for forces that shape the implementation. Reference `userinterface-wiki` for animation principles, typography rules (tabular nums, text-wrap), and UX laws (Fitts's, Hick's) — these catch spec gaps that surface late during build.

### 3c: Write artifacts (auto-proceed)

**`product/sections/[section-id]/spec.md`**:
```markdown
# [Section Title] Specification

## Overview
[2-3 sentence summary]

## User Flows
- [Flow 1: step-by-step]
- [Flow 2: step-by-step]

## UI Requirements
- [Requirement 1]
- [Requirement 2]

## Views
- [View 1]: [description]
- [View 2]: [description]

## Out of Scope
- [Explicit exclusion 1]
```

**`product/sections/[section-id]/data.json`**: Sample data with:
- `_meta` section describing entities and relationships
- 5-10 realistic records per main entity (not "Lorem ipsum")
- Varied content: mix short/long, different statuses
- Edge cases: at least one empty array, one long value

**`product/sections/[section-id]/types.ts`**: TypeScript interfaces with:
- Data interfaces inferred from sample data
- Union types for status/enum fields
- A `Props` interface with data props + optional callback props for each action
- JSDoc comments on callbacks

`[eval: operationalize]` Section specs must include specific layout constraints, interaction behaviors, and data requirements — "user-friendly" or "clean design" is not a spec. Every requirement must be verifiable by reading the implementation.
`[eval: propagation]` When a section spec reveals a conflict with Phase 1 vision or Phase 2 tokens (e.g., a user flow that doesn't fit the data shape, or a UI pattern that clashes with the chosen tone), propagate the conflict back and resolve it before continuing to the next section.

---

## Phase 4: Handoff

**Goal**: Generate an implementation-ready package that any coding agent can follow.

**Prerequisite**: At least one section with spec + data + types.

### 4a: Generate handoff structure

```
product-plan/
  README.md                     # Quick start guide
  product-overview.md           # Product summary
  design-system/
    tokens.css                  # CSS custom properties
    usage.md                    # How to apply tokens
  data-shapes/
    overview.ts                 # All entity types combined
    README.md                   # Data contract explanation
  sections/[section-id]/
    README.md                   # Section overview
    spec.md                     # Requirements
    types.ts                    # TypeScript interfaces
    sample-data.json            # Test data
    tests.md                    # UI behavior test specs
  instructions/
    one-shot.md                 # All milestones combined
    incremental/
      01-foundation.md          # Tokens + shell
      02-[section].md           # Per-section instructions
  prompts/
    implementation-prompt.md    # Ready-to-paste prompt for coding agents
```

### 4b: Generate test specs per section

For each section, create `tests.md` with:
- **User flow tests** — success + failure paths with specific UI text
- **Empty state tests** — first-time experience, no-data states
- **Component interaction tests** — clicks, hovers, keyboard
- **Edge cases** — long content, boundary conditions, state transitions
- **Accessibility checks** — keyboard nav, labels, screen reader announcements

Tests are framework-agnostic: describe WHAT to test, not HOW.

### 4c: Generate implementation instructions

Each milestone instruction includes:
- Goal and prerequisites
- What to implement (specific components, integrations)
- Data shapes the UI expects (reference types.ts)
- Callback props to wire up
- User flows to verify
- "Done when" checklist

**Preamble for all instructions:**
> What you're receiving: UI specifications, data shapes, design tokens, test specs.
> Your job: Build the backend, wire up data, implement the flows.
> The specs define the frontend contract. Backend architecture is your decision.

---

## Brownfield Mode

When the user is redesigning an existing area (not building from scratch):

1. **Audit current state** — read existing code for the area being redesigned
2. **Identify what stays** — existing data models, APIs, integrations to preserve
3. **Skip Phase 1** if the product vision already exists
4. **Constrain Phase 3** — section specs must respect existing data contracts
5. **Phase 4 handoff** includes migration notes: what changes, what's preserved, what's deprecated

Brownfield signals: "redesign the dashboard", "rethink how settings works", "the X area needs a complete overhaul"

---

## Key Principles

- **One question at a time** — people think better without a wall of questions
- **Auto-proceed after gathering** — writing artifacts is cheap; waiting for approval breaks flow
- **Revision cycles:** Phases 2-4 only. Phase 1 vision rarely changes, and re-asking erodes trust
- **Framework-agnostic** — output specs and types so any implementation stack can consume them
- **Respect existing tech** — check the project's stack first, because suggesting tokens that don't fit the toolchain wastes a round-trip
- **YAGNI** — spec only what the user described; invented features dilute focus and create maintenance debt
- **Conversational** — be a thinking partner, not a form to fill out

`[eval: design-token-coverage]` Phase 2 tokens cover all sections in the roadmap — every section spec can reference concrete color, typography, and spacing tokens.
`[eval: handoff-completeness]` Phase 4 handoff includes data shapes, test specs, and implementation instructions for every specified section.
