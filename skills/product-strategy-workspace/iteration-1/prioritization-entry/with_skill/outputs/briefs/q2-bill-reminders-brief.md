# Strategic Brief — Bill Reminders (Q2 2026)

*From product-strategy, for downstream build pipeline (brainstorming → writing-plans)*

## Target Persona
**Budget-Conscious Maya** — Millennial who maintains financial awareness through weekly manual reconciliation and calendar reminders for bills. Falls behind on categorization when life gets busy, losing visibility into her spending.

## Success Metric
**Monthly Active Retention (MAR)** — baseline to be established in weeks 1-3 via analytics instrumentation. Target: 5+ percentage point improvement in week-1 retention within 60 days of bill reminders launch. Secondary: 40%+ of users with connected bank accounts enable at least one bill reminder.

## Priority Rationale
RICE score of 0.945 (second only to analytics instrumentation, which ships concurrently). High reach (70% of users), high confidence (90% — direct feature requests + observable workaround behavior), low effort (1 person-month). Bill reminders are table-stakes that competitors already offer — this is a churn-prevention move, not a differentiator. But it's the fastest path to measurably improving retention while the higher-effort household feature is designed.

## Constraints (Explicitly Out of Scope)
- **No bill pay or automatic payments** — liability and regulatory complexity far exceeds value for a solo dev
- **No subscription management** — adjacent feature that dilutes focus; revisit post-Q3
- **No bill negotiation** — tempting but entirely different product surface
- **Must ship AFTER analytics instrumentation** (or at minimum, concurrently) so retention impact is measurable
- **Notification frequency must be user-controlled** — aggressive defaults will damage the indie trust brand

## Competitive Context
YNAB has basic bill tracking (age-of-money approach). Monarch has bill detection and reminders. Copilot has subscription tracking. Pocketwise's bill reminders don't need to be best-in-class — they need to be present and reliable. The absence of this feature is more damaging than any competitor's superior version. Parity is the goal; differentiation comes from household budgets in Q3.

## Technical Context
- Plaid's Transactions API includes recurring transaction detection — leverage this rather than building custom detection
- Push notifications require platform-specific implementation (FCM for Android, APNs for iOS) or a cross-platform service (OneSignal, Firebase)
- Email reminders as fallback for users who disable push notifications
- Consider: should reminders show in-app as a dashboard widget? (Likely yes — gives Maya her "am I on track?" glance)
