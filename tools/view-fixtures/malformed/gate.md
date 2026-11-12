<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/order-cache/proposal.md

Escalated decisions — pinned FIRST, never buried.
  E1. Add a cache-version column to orders (DEC-2) | basis: invalidation needs it | if wrong: one migration to drop it

Changes — the explanation layer for the decision-maker.

  1. Order reads come from a shared cache
     Problem: when a customer refreshes an order, because every read hits the database,
              the page is slow at peak.
     After:   when the customer refreshes, because a shared cache sits in front,
              the read is served in 2 ms, so peak pages stay fast.
     Cost:    Redis becomes a runtime dependency
  2. Writes invalidate the cached order
     Problem: when a payment lands, because nothing clears the cache, the order shows unpaid.
     After:   when a payment lands, the write clears the key, so the next read is fresh.
     Cost:    one extra call per write
  3. Hit ratio is reported
     Problem: when the cache misbehaves, nobody can see it.
     After:   the dashboard shows the hit ratio.
     Cost:    one metric series

Decided without asking: DEC-3 TTL backstop 5 min (config value)
Unsourced additions: none
Uncovered requirements: R-4 "Admins can flush the cache"
Unresolved critique: none
</HARD-GATE>
