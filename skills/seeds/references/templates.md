# Templates

## Table of Contents
- [Overview](#overview)
- [Creating Templates](#creating-templates)
- [Adding Steps](#adding-steps)
- [Pouring — Instantiating Issues](#pouring--instantiating-issues)
- [Tracking Convoy Status](#tracking-convoy-status)

---

## Overview

Templates let you define recurring multi-step workflows as reusable blueprints. When "poured", a template creates a set of issues (a "convoy") with dependencies pre-wired — each step becomes an issue, and steps are chained in order.

Use cases:
- Release checklists
- Service onboarding procedures
- Incident response playbooks
- Feature development workflows

---

## Creating Templates

```bash
sd tpl create --name "Release Checklist"
```

### List Templates

```bash
sd tpl list
```

### Show Template Details

```bash
sd tpl show tpl-a1b2
```

---

## Adding Steps

Steps are added sequentially — each step becomes an issue when the template is poured.

```bash
sd tpl step add tpl-a1b2 --title "Run full test suite"
sd tpl step add tpl-a1b2 --title "Update changelog"
sd tpl step add tpl-a1b2 --title "Bump version number"
sd tpl step add tpl-a1b2 --title "Create release tag"
sd tpl step add tpl-a1b2 --title "Deploy to production"
```

### Prefix Interpolation

Steps support `{prefix}` placeholders that get replaced when the template is poured:

```bash
sd tpl step add tpl-a1b2 --title "{prefix}: Run integration tests"
sd tpl step add tpl-a1b2 --title "{prefix}: Deploy to staging"
sd tpl step add tpl-a1b2 --title "{prefix}: Verify in production"
```

When poured with `--prefix "v2.1"`, these become:
- "v2.1: Run integration tests"
- "v2.1: Deploy to staging"
- "v2.1: Verify in production"

---

## Pouring — Instantiating Issues

```bash
sd tpl pour tpl-a1b2 --prefix "v2.1"
```

This creates one issue per step, with each step depending on the previous one. The result is a linear chain of issues that `sd ready` will surface one at a time as each is completed.

### Example

```bash
sd tpl pour tpl-x1y2 --prefix "auth-service"
```

Result: One issue per step, chained by dependencies. `sd ready` shows only the first step until it's closed, then surfaces the next.

---

## Tracking Convoy Status

After pouring, track completion progress:

```bash
sd tpl status tpl-a1b2
```

Shows which steps are complete, in progress, or still pending — giving a bird's-eye view of the convoy's progress.
