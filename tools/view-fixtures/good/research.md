# Research: order-cache

## Practices
- Cache A — Redis shared cache (one network hop per read, strongly consistent across instances) | candidate: multi-instance deployments
- Cache B — Caffeine in-process cache (fastest reads, zero dependencies; per-instance copies) | candidate: single-instance services
- Cache C — no cache, tune the SQL index instead | candidate: when read load stays under 200 qps
- Invalidation: write-through on order update, TTL 5 min as a backstop | candidate: any cache option above
Key references: https://redis.io/docs/ · https://github.com/ben-manes/caffeine

## Constraints
- Orders are read 40x more than written (status-quo metrics) | a cache that serves stale status shows a paid order as unpaid
- Two app instances behind the load balancer | an in-process cache diverges between instances

## Open [TBD]
- [TBD-1] Which cache backs order reads | candidates: Redis (evidence: Practices Cache A) / Caffeine (evidence: Practices Cache B) / skip-or-minimal: SQL index only | select: one
  - Q: When a customer pays and refreshes the order page on another instance, which read path serves the status?
  - 1: consistent across instances / one extra dependency and a network hop
  - 2: fastest, nothing new to run / instances can disagree for up to the TTL
  - 3: nothing new / reads stay on the database
- [TBD-2] Which order fields are cached | candidates: status / totals / line items | select: several
  - Q: The order page shows status, totals and line items — which of them may be served from cache?
  - 1: the hottest field / must be invalidated on every payment event
  - 2: rarely change / small win
  - 3: largest payload / invalidation on every edit

## Decided
- [DEC-1] Cache keys are namespaced per tenant | source: Constraints line 2 | rationale: tenants never share order ids
- [DEC-2] Add a cache-version column to orders | source [TBD-0] | escalated | schema change needed for invalidation | if wrong: one migration to drop the column
- [DEC-3] TTL backstop of 5 minutes | source [TBD-0] | auto | standard backstop | reversibility: config value
