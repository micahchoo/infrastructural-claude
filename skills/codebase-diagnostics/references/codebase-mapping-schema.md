# Codebase Mapping Schema

Reference document defining the structure, formats, and conventions for
architecture documentation produced by codebase-diagnostics.

## Doc Tree Structure

```
docs/architecture/
├── _meta.json
├── overview.md
├── domain.md
├── ecosystem.md
├── infrastructure.md
├── subsystems.md
├── subsystems/<name>/
│   ├── components.md
│   ├── contracts.md
│   ├── modules.md
│   └── behavior.md
├── cross-cutting/
│   ├── patterns.md
│   ├── data-flow.md
│   ├── security.md
│   ├── conventions.md
│   └── quality.md
├── risk-map.md
└── evolution.md
```

## Required vs Optional by Project Shape

| Doc | Monolith | Microservices | Monorepo | Library | Scripts |
|-----|----------|---------------|----------|---------|---------|
| overview.md | Required | Required | Required | Required | Required |
| domain.md | Required | Required | Required | Required | Optional |
| ecosystem.md | Required | Required | Required | Required | Optional |
| infrastructure.md | Required | Required | Required | Optional | Optional |
| subsystems.md | Required | Required | Required | Skip | Skip |
| subsystems/\<name\>/ | Required | Per-service | Per-package | Skip | Skip |
| cross-cutting/ | Required | Required | Required | Optional | Skip |
| risk-map.md | Required | Required | Required | Required | Optional |
| evolution.md | Optional | Optional | Optional | Optional | Skip |

## _meta.json Format

```json
{
  "schema_version": 1,
  "last_full_run": "ISO-8601",
  "project_shape": "monolith|microservices|monorepo|library|scripts",
  "docs": {
    "<relative-path>": {
      "git_hash": "output of: git log -1 --format=%H -- <source_glob>",
      "source_glob": ["glob patterns for files this doc describes"],
      "zoom_level": "domain|ecosystem|infrastructure|subsystem|component|contract|module|behavior",
      "subsystem": "name or null",
      "last_updated": "ISO-8601"
    }
  }
}
```

Hashing: `git log -1 --format=%H -- <expanded globs>`. Tracks committed
changes only. Uncommitted work does not trigger staleness.

## Cross-Reference Format

Each doc links to related docs at adjacent zoom levels:

```markdown
**See also:** [infrastructure](../infrastructure.md) | [components](components.md)
```

## Mulch Tag Schema

All mulch records from codebase-diagnostics use these tags:
- `source:codebase-diagnostics` (always)
- `scope:<subsystem-name>` (when scoped to a subsystem)
- `zoom:<level>` (one of the 8 zoom levels)
- `lens:<name>` (one of the 6 cross-cutting lenses, when applicable)

## Seeds Tag Schema

All seeds from codebase-diagnostics use:
- `source:codebase-diagnostics` (always)
- `zoom:<level>` (where the finding originated)
- `subsystem:<name>` (when scoped)

## Seed Proposal Format (Agent Output)

Dispatched agents propose seeds as structured JSON, one per line:
```json
{"finding": "<what>", "file": "<path>", "line": null, "severity": "high|medium|low", "seed_type": "task|question|feature", "reason": "<why actionable>"}
```

## Inter-Wave Context Format

Structured summary passed between dispatch waves. Built incrementally — each
wave adds its frame data for downstream waves to use.

```json
{
  "project_shape": "<shape>",
  "subsystems": [
    {
      "name": "",
      "root_path": "",
      "risk_signals": [],
      "key_dependencies": [],
      "boundary_type": "",
      "drainage_density": "high|low|mixed",
      "flow_basin_aligned": true
    }
  ],
  "infrastructure": {"databases": [], "queues": [], "ci": "", "deployment": ""},
  "domain_summary": "",
  "era_markers": [
    {
      "pattern": "var|require|class_component|jquery_ajax|callback_nesting",
      "era": "pre-2016|2016-2019|2020+",
      "locations": ["src/legacy/", "lib/old-utils.js"],
      "confidence": "high|medium|low"
    }
  ],
  "flow_basins": [
    {
      "entry": "src/api/routes.ts",
      "terminal": "src/db/queries.ts",
      "subsystems_touched": ["api", "db"],
      "validated": false
    }
  ],
  "faults": [
    {
      "location": "src/api/legacy-adapter.ts",
      "era_a": "callbacks",
      "era_b": "async-await",
      "type": "partial_migration|inverted_strata|metamorphism"
    }
  ],
  "crossings": [
    {
      "boundary": "api↔db",
      "count": 12,
      "era_weighted_count": 18,
      "classification": "prime|composite",
      "security_pins": []
    }
  ]
}
```

**When each field is populated:**
- `era_markers`: Wave 1 (Infrastructure agent collects index fossils)
- `flow_basins`, `drainage_density`, `flow_basin_aligned`: Wave 2 (Subsystem agent maps flow)
- `faults`: Wave 2 (initial from era marker + boundary cross-ref) → Wave 3 (enriched by Component agent stratigraphy)
- `crossings`: Wave 3 (Contract agent knot analysis)
