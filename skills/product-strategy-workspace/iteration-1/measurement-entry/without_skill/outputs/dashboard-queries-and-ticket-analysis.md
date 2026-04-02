# Dashboard Queries & Ticket Analysis Template

## Analytics Dashboard: Exact Queries to Run

### Query 1: TTFV Distribution (Primary Signal)

Pull the following for users who signed up after the launch date:

```
Segment: signup_date >= [launch_date]
Metric: time from first_login to first_value_event
Group by: nothing (full distribution)
Visualization: histogram with 5-min buckets
```

**What to look for:**
- Median value (not mean -- means are distorted by outliers)
- What percentage of users achieve value in < 15 min (the target)
- Whether the distribution is unimodal or bimodal
- Size of the long tail (users taking > 30 min)

**Interpretation guide:**
| Median TTFV | % under 15 min | Read |
|-------------|----------------|------|
| < 15 min | > 50% | Target hit for this metric. Monitor for stability. |
| 15-25 min | 30-50% | Meaningful improvement from 45 min. Identify the step causing the remaining delay. |
| 25-35 min | < 30% | Modest improvement. The redesign helped but didn't transform the experience. |
| > 35 min | < 15% | Minimal impact. The bottleneck wasn't in the onboarding UX. |

### Query 2: Onboarding Funnel Completion

```
Segment: signup_date >= [launch_date]
Funnel steps: [list each step in your new onboarding flow]
Metric: completion rate at each step, time spent at each step
Visualization: funnel chart + time-per-step bar chart
```

**What to look for:**
- The step with the largest single drop-off (your #1 optimization target)
- Steps where median time > 5 min (friction indicators)
- Whether users who drop off at step N ever return

### Query 3: Activation Rate (Conversion Leading Indicator)

```
Segment: signup_date >= [launch_date]
Metric: % of users who completed [your activation milestone] within first 7 days
Compare to: same metric for users who signed up in the 30 days before launch
```

**What to look for:**
- Absolute activation rate for new cohort
- Delta vs. pre-launch cohort
- If activation improved by 2x+, conversion improvement is highly likely

### Query 4: Early Conversion Signal (if trial period allows)

```
Segment: signup_date >= [launch_date] AND trial_expired = true
Metric: trial_to_paid conversion rate
Compare to: 12% baseline
Note: ONLY valid if enough users have reached trial expiration
```

**Minimum sample size guidance:**
- < 50 expired trials: Do not draw conclusions. Report the number but flag it as directional only.
- 50-200 expired trials: Directional signal. Report with confidence interval.
- 200+ expired trials: Usable for decision-making.

### Query 5: Retention Comparison

```
Segment A: signup_date >= [launch_date] (new onboarding)
Segment B: signup_date in [30 days before launch] (old onboarding)
Metric: Day-1 return rate, Day-7 return rate
```

**Why this matters:** TTFV improvement only helps conversion if users come back. If Day-7 retention is flat, faster TTFV isn't translating to stickiness.

---

## Support Ticket Analysis Template

### Step 1: Categorize Each Ticket

For each of the 30 tickets, assign ONE primary category:

| # | Date | User ID | Category | Onboarding Step | Severity | Summary |
|---|------|---------|----------|-----------------|----------|---------|
| 1 | | | | | | |
| 2 | | | | | | |
| ... | | | | | | |

**Category options:**
- `confusion` -- User didn't understand what to do
- `how-to` -- User asking how to accomplish something
- `bug` -- Something is broken/erroring
- `missing-feature` -- User expected capability that doesn't exist
- `billing` -- Payment/account/pricing question
- `performance` -- Slow, timeout, or loading issue
- `other` -- Doesn't fit above categories

**Severity options:**
- `blocker` -- User cannot proceed at all
- `friction` -- User can proceed but with difficulty
- `cosmetic` -- Minor annoyance, doesn't block progress

### Step 2: Aggregate and Interpret

Fill in after categorization:

| Category | Count | % of Total | Top Onboarding Step | Action |
|----------|-------|------------|---------------------|--------|
| confusion | | | | |
| how-to | | | | |
| bug | | | | |
| missing-feature | | | | |
| billing | | | | |
| performance | | | | |
| other | | | | |

### Step 3: Compare to Pre-Launch Baseline

| Period | Tickets/week | Top category | Top step |
|--------|-------------|--------------|----------|
| 4 weeks pre-launch | ? | ? | ? |
| Week 1 post-launch | ? | ? | ? |
| Week 2 post-launch | ? | ? | ? |

**Interpretation:**
- Tickets up + concentrated in new onboarding steps = expected launch friction, fixable
- Tickets up + scattered across categories = broader quality issue
- Tickets down + remaining ones are how-to = users engaging more deeply
- Tickets flat = onboarding change had no effect on support load

### Step 4: Verbatim Quote Extraction

Pull the 3-5 most representative quotes from tickets. These are more persuasive than numbers for stakeholder communication:

1. Best quote showing the redesign working: _______
2. Best quote showing where it's failing: _______
3. Most surprising/unexpected ticket: _______

---

## Decision Framework at Each Checkpoint

### Week 2 (NOW): Trajectory Check
- **Data available:** TTFV, funnel completion, ticket themes
- **Data NOT available:** Reliable conversion data
- **Decision scope:** Identify quick fixes, do NOT make go/no-go calls

### Week 4: Directional Read
- **Data available:** TTFV (stable), activation rate, early conversion signal
- **Decision scope:** Continue, iterate, or escalate concerns

### Week 6: Firm Signal
- **Data available:** Meaningful conversion data (if volume sufficient)
- **Decision scope:** On track / needs major intervention / consider rollback

### Week 8 (Day 60): Final Verdict
- **Data available:** Full conversion data for 60-day window
- **Decision scope:** Success / partial success / failure, next steps
