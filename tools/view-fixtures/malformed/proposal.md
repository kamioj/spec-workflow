# Proposal: order-cache

## Why

Order reads dominate load (R-1); paid orders must never show as unpaid (R-2).

## What

We add a read cache for orders (R-1), invalidate it on every write (R-2) and report the hit ratio (R-3).

**Not in this change**: cache warm-up.

## How

- Redis via the existing client (DEC-2 adds the version column).

## Risk

- Redis outage → reads fall through to the database; rollback = disable the cache flag.
