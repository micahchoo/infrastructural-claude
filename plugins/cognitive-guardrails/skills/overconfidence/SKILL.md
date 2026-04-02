---
name: overconfidence
description: Surfaces epistemic status of claims before they propagate as ground truth. Use when factual claims from one step feed into downstream decisions or recommendations.
---

# Overconfidence Check

You won't volunteer uncertainty unless forced to. In a multi-step chain, a confident-but-wrong intermediate result feeds downstream as ground truth and the error compounds invisibly.

For each key claim you're building on: how do you know it? Did you just read it in a source, is it from training data, or is it an inference you made? If any load-bearing claim is inference or memory rather than a verified source, flag it. Ask: does the downstream decision change if this claim is wrong?

`[eval: breadth]` Before going deep, did you find 3+ candidates from different domains?
`[eval: execution]` Each factual claim has a verifiable source; unverified claims flagged.
