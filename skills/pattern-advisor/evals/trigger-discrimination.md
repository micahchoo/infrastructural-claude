# Pattern-Advisor Trigger Discrimination Eval Set

20 queries: 10 should-trigger pattern-advisor, 10 should NOT.

## Should Trigger (→ pattern-advisor)

| # | Query | Expected codebooks | Why pattern-advisor |
|---|-------|-------------------|---------------------|
| 1 | "Which sync pattern should I use for my offline-first React app with IndexedDB?" | distributed-state-sync, optimistic-ui-vs-data-consistency | Specific project, specific architectural decision |
| 2 | "We're building a whiteboard with Yjs and Canvas 2D — advise on the undo architecture" | undo-under-distributed-state, distributed-state-sync | Specific project constraints, needs pattern selection |
| 3 | "Help me choose between Canvas 2D and WebGL for our diagram tool with 10K shapes" | rendering-backend-heterogeneity, interactive-spatial-editing | Specific decision point with project constraints |
| 4 | "We picked event-sourcing for undo but it's causing problems with our CRDT sync" | undo-under-distributed-state, distributed-state-sync | Brownfield: existing choice not working |
| 5 | "Given our constraints (P2P, offline, 50K shapes), what's the right sync+render architecture?" | distributed-state-sync, rendering-backend-heterogeneity, interactive-spatial-editing | Multi-cluster decision for specific project |
| 6 | "Is our architecture right? We're using LWW for a collaborative text editor" | distributed-state-sync | Brownfield: evaluating existing architecture |
| 7 | "We're about to choose between fractional indexing and integer ordering for our layer panel — guidance?" | hierarchical-resource-composition | Specific decision between competing patterns |
| 8 | "Recommend a gesture handling approach for our map editor with draw/select/pan tools" | gesture-disambiguation, interactive-spatial-editing | Specific project, specific tool set |
| 9 | "Our optimistic updates keep flickering — should we switch to a different pattern?" | optimistic-ui-vs-data-consistency | Brownfield: symptom leading to architectural decision |
| 10 | "We need to embed our editor as an npm package — advise on API surface strategy" | embeddability-and-api-surface | Specific project with specific embedding context |

## Should NOT Trigger

| # | Query | Correct skill | Why NOT pattern-advisor |
|---|-------|---------------|------------------------|
| 1 | "What is the command pattern for undo/redo?" | domain-codebooks | Learning/browsing, not deciding for a project |
| 2 | "How does tldraw handle arrow bindings?" | domain-codebooks or hybrid-research | Learning about a specific codebase, not deciding |
| 3 | "Extract patterns from this Excalidraw clone I'm studying" | pattern-extraction-pipeline | Creating a codebook, not using one |
| 4 | "My React component re-renders too often" | systematic-debugging | Debugging, not architectural decision |
| 5 | "Let's brainstorm ideas for a collaborative whiteboard app" | brainstorming | Open-ended brainstorming, not specific decision |
| 6 | "What are the different approaches to CRDT garbage collection?" | domain-codebooks | General pattern learning |
| 7 | "Fix this TypeScript error in my sync handler" | systematic-debugging | Debugging a specific error |
| 8 | "Show me examples of gesture state machines" | domain-codebooks | Browsing reference material |
| 9 | "Plan the implementation of our new drawing tool" | writing-plans (+ domain-codebooks diffused) | Planning, not architectural decision — though codebooks should diffuse |
| 10 | "What patterns exist for schema migration in distributed systems?" | domain-codebooks | "What patterns exist" = browsing, not "which should I use" |

## Discrimination Criteria

The key discriminator: **Is the user making a SPECIFIC architectural decision for THEIR project?**

- "Which pattern for MY app" → pattern-advisor
- "What patterns exist" → domain-codebooks
- "How does X work in Y codebase" → domain-codebooks or hybrid-research
- "Create patterns from this code" → pattern-extraction-pipeline
- "Fix this bug" → systematic-debugging
- "Let's brainstorm" → brainstorming

Edge cases:
- "Plan my collaborative editor" → writing-plans with domain-codebooks diffused (NOT pattern-advisor, because planning is broader than pattern selection)
- "Our sync is broken" → systematic-debugging first (NOT pattern-advisor, because the immediate need is fixing, not choosing). But if debugging reveals an architectural mismatch, pattern-advisor may be routed to secondarily.
- "What pattern should I use for X" where X is generic (no project context) → domain-codebooks (need to ask clarifying questions first, which is the router's job, not the advisor's)

---

## Hard Cases (Added 2026-03-21)

10 queries targeting specific gaps identified in the eval results: (a) FP risk from trigger vocabulary without project context, (b) "my" in learning queries, (c) architectural-sounding planning queries, (d) debug+architecture hybrids, (e) indirect brownfield without trigger words, (f) force-cluster symptom without pattern naming, (g) multi-part questions, (h) retrospective evaluation.

### FP-Probing (should NOT trigger — but might)

| # | Query | Expected | Correct skill | Why hard | Disambiguating signal |
|---|-------|----------|---------------|----------|-----------------------|
| H1 | "Which pattern should I use for gesture handling in canvas apps?" | not-trigger | domain-codebooks | Has "which pattern should I use" — exact trigger phrase fragment — but no project ownership signal ("my app", "our editor"). Generic "canvas apps" is a domain category, not a named project. | Description requires BOTH a decision verb AND ownership signal ("my X", "our X"). No possessive = no trigger. |
| H2 | "I'm learning about sync architectures — which approach would you recommend for a real-time collaborative tool?" | not-trigger | domain-codebooks | "recommend" + "which approach" are trigger-adjacent, and "I'm" is first-person. But "I'm learning" frames the question as educational browsing, and "a real-time collaborative tool" is a hypothetical, not a named project. | The learning frame ("I'm learning") inverts the ownership signal. Distinguishing test: is the user deciding for THEIR project? No — they're surveying the space. |
| H3 | "What pattern would you advise for state management in my new side project?" | not-trigger | domain-codebooks | "advise" is a verbatim trigger word, and "my" signals ownership. But "new side project" with no stack, constraints, or domain is too underspecified for intake — no force clusters can be identified. | Advisor requires specific project constraints to run diagnostic intake. Underspecified ownership ("my side project") without any tech context is still a learning/survey question. |
| H4 | "My sync layer keeps dropping edits — I want to understand what patterns address this class of problem" | not-trigger | domain-codebooks | "My sync layer" is a project ownership signal and the symptom ("dropping edits") maps to a real force cluster. But "understand what patterns address this class of problem" explicitly frames the goal as learning, not deciding. | The framing verb matters: "I want to understand what patterns" = browsing. Contrast with "should I switch patterns" (T9) which is a decision ask. |
| H5 | "We're planning to add collaborative features to our app — what patterns should we be aware of?" | not-trigger | domain-codebooks (or writing-plans) | "our app" is strong project ownership, and "what patterns" sounds like decision prep. But "be aware of" frames the request as a survey/education step, not a specific architectural decision. | "Be aware of" signals orientation, not selection. No force-cluster framing, no competing approaches, no active decision point. Pattern-advisor needs a specific decision to run intake against. |

### FN-Probing (should trigger — but might not)

| # | Query | Expected | Expected codebooks | Why hard | Disambiguating signal |
|---|-------|----------|--------------------|----------|-----------------------|
| H6 | "Our sync layer keeps dropping edits whenever two users edit the same object simultaneously" | trigger | distributed-state-sync, optimistic-ui-vs-data-consistency | No trigger vocabulary at all — no "advise", "recommend", "which pattern", "evaluate". But this is a brownfield force-cluster symptom: a specific named project ("our sync layer"), a concrete failure mode (concurrent edits dropped), which directly maps to conflict resolution pattern selection. | Description's brownfield arm: "pattern X isn't working" covers this even without the phrase — the symptom *is* the pattern-not-working signal. Project ownership ("our") + architectural symptom = trigger. |
| H7 | "We shipped cursor presence six months ago and it's been a mess — latency spikes, ghost cursors, users rage-quitting" | trigger | distributed-state-sync, optimistic-ui-vs-data-consistency | No pattern names, no decision verbs, reads like venting or a bug report. But the force cluster is fully described: a shipped architectural choice (cursor presence) with compounding symptoms pointing to a pattern mismatch. | This is brownfield evaluation: "pattern X isn't working" expressed as a symptom cluster, not a labeled pattern. "We shipped X" + symptoms + implicit "what went wrong?" = architectural decision trigger. |
| H8 | "We need to support offline mode and also keep a server-side audit log — these two requirements seem to pull in opposite directions" | trigger | distributed-state-sync, optimistic-ui-vs-data-consistency | Describes a force tension without naming any pattern or using trigger vocabulary. Could be read as a requirements-clarification or planning question. But the framing — two requirements pulling in opposite directions — is the canonical description of a force cluster conflict requiring pattern selection. | "Stuck between two approaches" (in description) generalizes to "stuck between two requirements". The opposition framing ("pull in opposite directions") is the signal, even without naming patterns. |
| H9 | "We just finished migrating our undo stack to event-sourcing. Now that we're done, I'm wondering if we actually made the right call — our collaborators are seeing conflicts we didn't have before" | trigger | undo-under-distributed-state, distributed-state-sync | Retrospective evaluation after the fact. No explicit "evaluate my architecture" phrase. Could seem like post-hoc reflection or a debugging question about the new conflicts. | "Was that right?" class of retrospective is covered by brownfield evaluation ("evaluate my architecture"). The new symptoms ("conflicts we didn't have before") confirm a live architectural mismatch, not just curiosity. Trigger on both the evaluation ask and the active symptom. |
| H10 | "I'm trying to decide how to structure our canvas rendering — part of me wants to go WebGL for performance, but I'm worried about accessibility and our current team's familiarity with the API" | trigger | rendering-backend-heterogeneity, interactive-spatial-editing | Genuine decision framing ("trying to decide") with project ownership ("our canvas") and named forces (performance, accessibility, team familiarity). But the first-person hedging ("part of me wants", "I'm worried") and lack of explicit trigger vocabulary might make it look like thinking-out-loud. | The force cluster is fully articulated: a specific project, two competing approaches (Canvas 2D vs WebGL implied), three named forces (performance, accessibility, API familiarity). "Trying to decide" is a decision verb even without "advise/recommend". Trigger. |
