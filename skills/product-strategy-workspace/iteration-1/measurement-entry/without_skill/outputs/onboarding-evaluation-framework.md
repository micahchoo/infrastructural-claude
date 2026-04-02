# Onboarding Redesign Evaluation Framework

## Context

- **Launch date:** ~2 weeks ago
- **Baseline:** 12% trial-to-paid conversion, ~45 min time-to-first-value (TTFV)
- **Success criteria (PM-defined, 60-day window):** 18% conversion, TTFV < 15 min
- **Available data:** Analytics dashboard, ~30 support tickets

---

## 1. Where You Are vs. Where You Need to Be

| Metric | Baseline | Target | Required Lift | Timeline |
|--------|----------|--------|---------------|----------|
| Trial-to-paid conversion | 12% | 18% | +50% relative | 60 days |
| Time-to-first-value | 45 min | < 15 min | -67% relative | 60 days |

**Week 2 checkpoint reality:** You are 33% through the evaluation window. At this stage, you should be looking for **leading indicators and trajectory**, not final verdicts.

---

## 2. What to Pull from Your Analytics Dashboard Right Now

### Priority 1: TTFV (fastest signal)
- **Median TTFV for post-launch cohort** vs. the 45-min baseline. This metric settles quickly since it measures a single session behavior. If it's already at or near 15 min, the UX redesign is mechanically working.
- **TTFV distribution** (not just average): Look for bimodal patterns. A long tail of users stuck at 40+ min alongside users hitting value in 10 min tells a different story than a uniform 20-min median.
- **Drop-off by onboarding step:** Which step has the highest exit rate? This is your highest-leverage fix.

### Priority 2: Conversion (lagging signal)
- **Raw conversion rate** for the post-launch cohort. BUT: trial-to-paid conversion requires users to reach the end of their trial period. If trials are 14 days, you are only now seeing the first cohort complete. If trials are 30 days, you have zero conversion data yet.
- **Trial age distribution:** How many post-launch signups have actually reached conversion-decision age? If the answer is < 100, the conversion number is noise.
- **Activation rate** as a proxy: What percentage of new trials complete the core onboarding actions? This is the leading indicator for conversion. Industry benchmarks: a 2-3x improvement in activation typically yields 1.3-1.5x improvement in conversion.

### Priority 3: Engagement quality
- **Day-1 and Day-7 retention** for post-launch cohort vs. baseline
- **Feature adoption breadth:** Are users reaching more features, or just hitting first-value faster and then stalling?

---

## 3. Support Ticket Analysis (30 tickets)

30 tickets in 2 weeks is a data point, not a dataset. Here's how to extract maximum signal:

### Categorization framework

| Category | What it tells you | Action threshold |
|----------|-------------------|------------------|
| **Confusion/UX friction** | Onboarding flow has usability gaps | > 10 tickets in same step = urgent fix |
| **"How do I do X?"** | Flow doesn't surface capability X | Check if X is in the onboarding; if yes, it's failing; if no, consider adding |
| **Bugs/errors** | Technical issues in new flow | Any blocking bug = immediate fix |
| **Feature requests** | Users engaged enough to want more | Positive signal, low urgency |
| **Billing/account** | Unrelated to onboarding | Exclude from evaluation |

### Key questions for ticket analysis
1. **Are tickets concentrated in a specific onboarding step?** Clustering = fixable UX problem.
2. **What's the ticket rate vs. pre-launch?** If you were getting 20 tickets/2 weeks before, 30 is a 50% increase worth investigating. If you were getting 28, it's noise.
3. **Are any tickets from users who completed onboarding vs. those who abandoned?** Post-completion tickets suggest the flow works but has rough edges. Abandonment tickets suggest the flow is broken.

---

## 4. Two-Week Verdict Framework

### Scenario A: TTFV is at or below 15 min, activation rate is up
**Assessment:** The mechanical redesign is working. Conversion will likely follow but you don't have enough data to confirm yet. Stay the course.
**Action:** Monitor weekly. Set a Week 4 checkpoint for a firmer conversion read.

### Scenario B: TTFV improved but is still 20-30 min, activation flat
**Assessment:** Partial success. The flow is better but hasn't hit the target. You have time to iterate.
**Action:** Deep-dive into the step-by-step drop-off funnel. Identify the 1-2 steps where users stall and redesign those specifically. The 80/20 is almost always in one bottleneck step.

### Scenario C: TTFV hasn't meaningfully changed, tickets show confusion
**Assessment:** The redesign may have changed the surface without changing the experience. This is a design problem, not a data problem.
**Action:** Run 5 user interviews this week. Watch people go through the flow. The tickets tell you *where* it breaks; interviews tell you *why*.

### Scenario D: Metrics look worse than baseline
**Assessment:** Regression. But at 2 weeks, confirm the data is clean first (tracking instrumentation, correct cohort filtering, no bot traffic inflation in baseline).
**Action:** If confirmed, consider a rollback or rapid A/B test of old vs. new flow.

---

## 5. Statistical Confidence Reality Check

With 2 weeks of data, be honest about sample sizes:

| Metric | Minimum sample for directional confidence | Minimum for statistical significance (p<0.05) |
|--------|------------------------------------------|-----------------------------------------------|
| TTFV (continuous) | ~50 completed onboardings | ~200 per variant |
| Conversion (binary) | Not meaningful until trial periods expire | ~1,000 per variant (12% to 18% is a small absolute change) |
| Support ticket themes | 30 is enough for theme identification | Not a statistical question -- qualitative signal |

**The honest answer at Week 2:** You can evaluate TTFV with reasonable confidence if you have 50+ completed onboardings. You cannot evaluate conversion yet unless you have very short trial periods AND high volume. The support tickets are a qualitative signal that should inform iteration, not judgment.

---

## 6. Recommended Week-2 Actions

1. **Pull TTFV median and distribution** -- this is your primary signal right now
2. **Categorize all 30 support tickets** using the framework above
3. **Check your activation funnel** step by step for the post-launch cohort
4. **Set calendar reminders** for Week 4 (conversion directional read) and Week 8 (final verdict)
5. **Do not make a go/no-go decision yet** -- you are evaluating trajectory, not outcome
