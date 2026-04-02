# Signal Collection Plan — Onboarding Flow Redesign

## Overview

Four signal types required for robust measurement. Each signal type addresses different
blind spots. Quantitative alone lies; qualitative alone doesn't scale.

---

## Signal 1: Quantitative (Analytics Dashboard)

**Source**: Product analytics dashboard (available now)
**Owner**: You (data already accessible)

### Data Points to Extract

#### Primary KPIs
- [ ] **Trial-to-paid conversion rate** (last 14 days) — compare against 12% baseline
  - Segment by: signup source, user role/company size (if available), device type
  - Cohort view: compare users who saw old flow vs. new flow (if any overlap exists)
  - **Caveat**: Many trial users from the last 2 weeks may not have reached conversion decision yet. Typical SaaS trial is 14-30 days. The current conversion number is likely understated.

- [ ] **Time-to-first-value** (last 14 days) — compare against 45-minute baseline
  - Define "first value" precisely: what event in analytics constitutes value delivery?
  - Distribution view: median, P25, P75, P95 (averages hide bimodal distributions)
  - Segment by: same dimensions as above

#### Funnel Metrics (Leading Indicators)
- [ ] **Onboarding completion rate** — what % of new signups complete the full flow?
- [ ] **Step-by-step drop-off** — where in the new flow do users abandon?
- [ ] **Time per onboarding step** — which steps take disproportionately long?
- [ ] **Activation rate** — what % of users who complete onboarding perform a core action within 24 hours?

#### Comparison Metrics
- [ ] **Old vs. new flow completion rates** (if A/B or sequential cohort comparison is possible)
- [ ] **Retention at Day 7 and Day 14** — are users who went through new onboarding retaining better?

### Interpretation Guidance

| Metric | Green (on track) | Yellow (watch) | Red (intervene) |
|--------|-------------------|----------------|-----------------|
| Conversion (2-week read) | > 10% (understated due to immature cohort) | 7-10% | < 7% |
| TTFV median | < 15 min | 15-25 min | > 25 min |
| Onboarding completion | > 80% | 60-80% | < 60% |
| Step drop-off (any step) | < 10% | 10-20% | > 20% |

**Why conversion threshold is lower at 2 weeks**: Trial cohorts haven't matured. A 2-week
conversion read of 10% may resolve to 16-18% once all trialists in the window reach their
conversion decision point. The key question is trajectory vs. the same-period read from
the old flow.

---

## Signal 2: Qualitative (Support Tickets)

**Source**: 30 support tickets since launch
**Owner**: You (tickets accessible)

### Analysis Framework

Categorize each of the 30 tickets along three dimensions:

#### Dimension 1: Onboarding Stage
- [ ] **Pre-onboarding** — account creation, email verification, login issues
- [ ] **During onboarding** — confusion about steps, errors in the flow, missing guidance
- [ ] **Post-onboarding** — "what do I do next?", feature discovery, advanced setup
- [ ] **Unrelated** — billing, existing feature bugs, etc.

#### Dimension 2: Issue Type
- [ ] **Confusion** — user didn't understand what to do (UX/copy problem)
- [ ] **Error/Bug** — something broke (technical problem)
- [ ] **Missing capability** — user expected something the flow doesn't provide (scope gap)
- [ ] **Performance** — slow loading, timeouts (technical problem)

#### Dimension 3: Sentiment
- [ ] **Frustrated** — user is stuck, possibly at risk of churning
- [ ] **Curious** — user is engaged but needs help
- [ ] **Positive** — user is providing feedback or praise

### Key Questions to Answer
1. What % of tickets are directly related to the new onboarding flow?
2. Is there a cluster of tickets about a specific step or screen?
3. Are there tickets from users who started onboarding but didn't finish (drop-off signal)?
4. How does the ticket volume compare to the same 2-week period before the redesign?
5. Are any tickets from users who would have converted but didn't because of onboarding friction?

### Expected Output
A ticket analysis table with columns: `Ticket ID | Stage | Type | Sentiment | Onboarding Step (if applicable) | Key Quote | Actionable?`

---

## Signal 3: UX Audit (Shadow-Walk)

**Source**: Walk the implemented onboarding flow
**Owner**: Dispatch to shadow-walk skill (or manual walkthrough)

### Audit Brief

> Walk the new onboarding flow from the perspective of a first-time user who signed up
> for a free trial. Focus on: time-to-first-value — what in the flow supports or
> undermines the user reaching their first "aha moment" quickly?

### Specific Checkpoints
- [ ] How many steps/screens before the user sees value?
- [ ] Is there a clear "aha moment" or does value emerge gradually?
- [ ] Are there any mandatory steps that don't contribute to first-value?
- [ ] Does the flow adapt to user role/use case, or is it one-size-fits-all?
- [ ] Are there escape hatches for users who want to skip ahead?
- [ ] How does the flow handle errors or unexpected user behavior?
- [ ] Is progress visible (progress bar, step count)?
- [ ] What happens after onboarding completes? Is there a clear next action?

### Persona Lens
If personas exist, evaluate from each persona's perspective. If not, use:
- **Evaluator**: just signed up to see if this tool solves their problem (time-pressured, skeptical)
- **Committed adopter**: decided to use the tool, wants to set up properly (patient, thorough)

---

## Signal 4: Technical Health

**Source**: Application monitoring, error logs, performance dashboards
**Owner**: Engineering team (may need to request)

### Metrics to Gather
- [ ] **Error rate** in onboarding flow endpoints (last 14 days vs. prior 14 days)
- [ ] **Page load time** for each onboarding screen (P50, P95)
- [ ] **API latency** for onboarding-related calls
- [ ] **Client-side errors** (JavaScript errors on onboarding pages)
- [ ] **Mobile vs. desktop** performance comparison
- [ ] **Browser/device breakdowns** for any error spikes

### Threshold Assessment
- Error rate > 1% on any onboarding endpoint = red flag
- P95 load time > 3 seconds on any screen = UX friction contributor
- Any 5xx errors in the flow = urgent fix needed

---

## Collection Timeline

| Signal | Data Available | Analysis Effort | Priority |
|--------|---------------|-----------------|----------|
| Quantitative (analytics) | Now | 2-3 hours | **P0** — do first |
| Qualitative (30 tickets) | Now | 3-4 hours | **P0** — do in parallel |
| UX Audit (shadow-walk) | Anytime | 1-2 hours | **P1** — after initial data review |
| Technical health | Request needed | 1 hour | **P1** — request now, analyze when available |

**Recommended sequence**: Pull analytics and categorize tickets simultaneously. Use
initial findings to focus the shadow-walk on problem areas. Technical health confirms
or rules out infrastructure as a factor.

---

## What We're NOT Measuring (Explicit Gaps)

Per `bias:wysiati` — name what's missing:

1. **Users who never started onboarding** — bounce rate from signup page to first onboarding screen
2. **Long-term retention** — too early; need 30-60 days minimum
3. **Revenue impact** — conversion rate alone doesn't capture plan tier or expansion revenue
4. **Competitor comparison** — are competitors also improving their onboarding?
5. **Internal user segments** — if different user types have wildly different TTFV, the aggregate metric hides the story
6. **Referral/word-of-mouth effects** — improved onboarding may drive organic growth, invisible for months
