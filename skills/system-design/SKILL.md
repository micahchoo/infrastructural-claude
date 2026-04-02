---
name: system-design
description: >-
  System design reference library covering networking, databases, distributed systems,
  architectural patterns, and real-world system design case studies. 5 chapters across
  14 reference files. Use when discussing system architecture, infrastructure decisions,
  database selection, scaling strategies, or preparing for system design interviews.
  TRIGGERS: "system design", "how would you design", "design a system", "architecture for",
  "scaling strategy", "database choice", "CAP theorem", "load balancing", "caching strategy",
  "microservices vs monolith", "message queue", "sharding", "replication", "rate limiting",
  "API gateway", "circuit breaker", "URL shortener design", "design WhatsApp", "design Twitter",
  "design Netflix", "design Uber", "distributed transactions", "consistent hashing",
  "event sourcing", "CQRS", "pub/sub", "WebSockets vs SSE", "OAuth", "SSO", "DNS",
  "CDN", "proxy vs load balancer", "availability nines", "horizontal vs vertical scaling".
  Do NOT trigger for: implementation-level code questions, CSS/styling, debugging specific
  errors, or framework-specific API usage (use domain-codebooks or library docs instead).
---

# System Design Reference Library

Pattern and concept reference for distributed systems architecture, organized by topic domain.

**Source**: [karanpratapsingh/system-design](https://github.com/karanpratapsingh/system-design) (adapted)

## Reference Index

| Keywords | Reference | Path |
|----------|-----------|------|
| IP, IPv4, IPv6, OSI, TCP, UDP, DNS, network | networking-fundamentals | `references/networking-fundamentals.md` |
| load balancer, round robin, L4, L7, sticky session | load-balancing | `references/load-balancing.md` |
| cluster, active-active, active-passive, failover | clustering-and-availability | `references/clustering-and-availability.md` |
| cache, LRU, write-through, write-back, eviction, Redis | caching | `references/caching.md` |
| CDN, push CDN, pull CDN, edge, proxy, forward, reverse | cdn-and-proxies | `references/cdn-and-proxies.md` |
| SQL, NoSQL, relational, document, key-value, graph, wide column | databases | `references/databases.md` |
| replication, master-slave, master-master, index, normalization | replication-and-indexing | `references/replication-and-indexing.md` |
| ACID, BASE, CAP, PACELC, transaction, consistency | consistency-models | `references/consistency-models.md` |
| shard, partition, consistent hashing, federation, virtual node | sharding-and-partitioning | `references/sharding-and-partitioning.md` |
| microservice, monolith, ESB, N-tier, message broker, event driven | architectural-patterns | `references/architectural-patterns.md` |
| message queue, pub/sub, event sourcing, CQRS, saga | messaging-and-events | `references/messaging-and-events.md` |
| REST, GraphQL, gRPC, API gateway, WebSocket, SSE, long polling | apis-and-communication | `references/apis-and-communication.md` |
| geohash, quadtree, circuit breaker, rate limit, service discovery, OAuth, SSO, TLS | infrastructure-patterns | `references/infrastructure-patterns.md` |
| URL shortener, WhatsApp, Twitter, Netflix, Uber, interview | case-studies | `references/case-studies.md` |

## Discovery

Before loading references, search for prior decisions and real-world implementations:
- `search("<architecture topic>", project_root=root)` — find prior decisions, reference designs, and mulch expertise (includes mulch automatically)
- `search_references("<architecture topic>")` — find how reference projects implement these patterns (load balancing strategies, caching layers, sharding schemes in real code)

`[eval: prior-art-searched]` Both foxhound search and search_references called for the design topic; results reviewed before proceeding to reference lookup.

`bias:overconfidence` — After trade-off analysis, ask: how do you know each claim? Training data may be outdated; verify against indexed docs and reference implementations before asserting trade-offs.

`[eval: references-loaded]` At least one reference file read or indexed lookup returned substantive content for each matched keyword domain; no design advice given from training data alone.

**Codebook gap**: If foxhound/reference lookup returns empty for a design domain with competing trade-offs, record it: `~/.claude/scripts/codebook-gap.sh record "Force: X vs Y vs Z" "Leads: [repos/files seen]. Context: [what you were doing]"`

**Produce**: After design discussion concludes, if architectural decisions were made: `ml record --type decision --title "<the decision>" --rationale "<why>" --tags "architecture,<topic>" --classification foundational --evidence-file <context>`.

`[eval: decision-recorded]` If an architectural decision was reached, `ml record` called with type=decision, architecture tag, and evidence-file pointing to the source context.

## Routing

1. **Match keywords** from the user's question to the index above
2. **Indexed lookup first**: `get_docs("claude-skill-tree", "<matched keywords>")` — returns relevant sections without loading full reference files. Use 2-4 keywords from the matched row. Sufficient for focused questions and comparisons.
3. **Foxhound**: `search_references("<architecture topic>")` to find how reference projects implement these patterns — grounds conceptual advice in real implementations.
4. **Full reference Read (fallback)**: Only when indexed lookup returns thin results or you need comprehensive coverage (interview prep, multi-topic design). Read the matched file(s).
5. **Multiple matches?** Query indexed content for each. Only Read full files when depth requires it. System design questions often span multiple topics (e.g., "design a chat app" touches messaging, databases, caching, and APIs).
6. **Interview prep?** Load `case-studies` plus whichever foundational references apply — this is a legitimate full-Read case.
7. **Comparison questions** ("SQL vs NoSQL", "REST vs gRPC"): `get_docs("claude-skill-tree", "<both sides>")` first; Read the reference only if indexed content doesn't cover both sides.
8. **No match?** Check domain-codebooks for architectural pattern questions, or library docs for implementation specifics.

## Usage Notes

- These references are conceptual/architectural — pair with `domain-codebooks` for implementation-level force analysis
- For library-specific APIs, verify via `get_docs("<lib>", "<keyword>")` before recommending
- Case studies follow a standard structure: Requirements → Estimation → Data Model → API → High-level → Detailed → Bottlenecks

`[eval: tradeoffs-grounded]` Each stated trade-off cites a specific source (reference file, foxhound result, or indexed doc); no trade-off asserted purely from training data.

`bias:reframe` — When reaching a design conclusion, ask: what's the strongest counter-argument? If you'd struggle to defend this design to a skeptical staff engineer, the alternatives haven't been weighed enough.

`[eval: counter-argument-stated]` At least one explicit counter-argument or rejected alternative documented with rationale before finalizing the design recommendation.
