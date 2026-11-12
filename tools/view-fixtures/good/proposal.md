# Proposal: order-cache

## Why

Order reads dominate load (R-1); paid orders must never show as unpaid (R-2).

## What

1. **Order read cache** | refs: R-1, R-2 | verify: a second read of the same order within the TTL hits the cache
2. **Invalidate on write** | refs: R-2 | verify: after a payment event the next read shows the new status
3. **Cache metrics** | refs: R-3 | verify: hit ratio appears on the dashboard

**Not in this change**: cache warm-up.

## How

- Redis via the existing client (DEC-2 adds the version column).

## Risk

- Redis outage → reads fall through to the database; rollback = disable the cache flag.
