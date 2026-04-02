# Cognitive Guardrails

Bias mitigation micro-skills for agentic work.

## Install

This plugin lives at `~/.claude/plugins/cognitive-guardrails/`.

## CLAUDE.md Prompt Block

Add this to your global or project CLAUDE.md to enable self-directed guardrail triggers:

```markdown
## Cognitive Guardrails

At these decision points, pause and invoke the relevant check:

- **Before acting on gathered evidence:** What's missing? What's unverifiable from code alone? → invoke bias:wysiati
- **After producing a substantive analysis or plan:** Did you answer the actual question? → invoke bias:substitution
- **When building on factual claims for downstream decisions:** How do you know each claim? → invoke bias:overconfidence
- **When reaching a conclusion or recommendation:** What's the strongest counter-argument? → invoke bias:reframe
- **When synthesizing from few source types or after 3+ searches:** What haven't you looked at? Are early findings anchoring you? → invoke bias:availability
- **When assessing compound likelihood:** Does the narrative feel more probable than the math allows? → invoke bias:conjunction
- **When deep into execution and the plan feels locked-in:** Would a fresh agent continue this plan? → invoke bias:sunk-cost
```
