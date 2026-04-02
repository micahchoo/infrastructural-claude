# Questioning Techniques for Intent Exploration

Reference for brainstorming skill — techniques for eliciting clear requirements from users with fuzzy ideas. Adapted from GSD's questioning philosophy.

## Philosophy

You are a thinking partner, not an interviewer. The user often has a fuzzy idea. Your job is to help them sharpen it. Ask questions that make them think "oh, I hadn't considered that" or "yes, that's exactly what I mean."

Don't interrogate. Collaborate. Don't follow a script. Follow the thread.

## Techniques

**Start open.** Let them dump their mental model. Don't interrupt with structure.

**Follow energy.** Whatever they emphasized, dig into that. What excited them? What problem sparked this?

**Challenge vagueness.** Never accept fuzzy answers. "Good" means what? "Users" means who? "Simple" means how?

**Make the abstract concrete.** "Walk me through using this." "What does that actually look like?" "Give me an example."

**Clarify ambiguity.** "When you say Z, do you mean A or B?" "You mentioned X — tell me more."

**Know when to stop.** When you understand what they want, why they want it, who it's for, and what done looks like — offer to proceed.

## Question Types

Use as inspiration, not a checklist. Pick what's relevant to the thread.

**Motivation — why this exists:**
- "What prompted this?"
- "What are you doing today that this replaces?"
- "What would you do if this existed?"

**Concreteness — what it actually is:**
- "Walk me through using this"
- "You said X — what does that actually look like?"
- "Give me an example"

**Clarification — what they mean:**
- "When you say Z, do you mean A or B?"
- "You mentioned X — tell me more about that"

**Success — how you'll know it's working:**
- "How will you know this is working?"
- "What does done look like?"

## Context Checklist (Background — Not Conversation Structure)

Check these mentally as you go. If gaps remain, weave questions naturally. Never switch to checklist mode.

- [ ] What they're building (concrete enough to explain to a stranger)
- [ ] Why it needs to exist (the problem or desire driving it)
- [ ] Who it's for (even if just themselves)
- [ ] What "done" looks like (observable outcomes)

Four things. If they volunteer more, capture it.

## Freeform Rule

When the user signals they want to describe something in their own words ("let me describe it", "something else", any open-ended reply), ask your follow-up as plain text — not via structured options. Wait for them to type naturally. Resume structured options only after processing their freeform response.

## Anti-Patterns

- **Checklist walking** — Going through domains regardless of what they said
- **Canned questions** — "What's your core value?" regardless of context
- **Corporate speak** — "What are your success criteria?" "Who are your stakeholders?"
- **Interrogation** — Firing questions without building on answers
- **Rushing** — Minimizing questions to get to "the work"
- **Shallow acceptance** — Taking vague answers without probing
- **Premature constraints** — Asking about tech stack before understanding the idea

## Gray Area Classification

Before probing implementation details, classify the work domain:

| Domain | Probe These Gray Areas |
|--------|----------------------|
| Visual features | Layout, density, interactions, empty states |
| APIs/CLIs | Response format, flags, error handling, verbosity |
| Content systems | Structure, tone, depth, flow |
| Organization tasks | Grouping criteria, naming, duplicates, exceptions |
| Data pipelines | Input format, error tolerance, idempotency, output schema |
| Infrastructure | Rollback strategy, monitoring, capacity, failure modes |

Probe only relevant categories. Don't ask layout preferences for a CLI tool.
