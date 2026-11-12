---
change: order-cache
round: 1
stage: verify
date: 2026-11-05
conclusion: fail
issues: { critical: 1, major: 1, minor: 1, open: 2 }
---

# Verify: order-cache

## Findings
| ID | Severity | Location | Finding | Status | Rounds |
|----|----------|----------|---------|--------|--------|
| V-1 | critical | src/cache/orderCache.ts:40 | invalidate is not awaited | open | r1 |
| V-2 | major | src/cache/orderCache.ts:12 | tenant missing from the key | fixed(r1) | r0→r1 |
| V-3 | minor | README.md:3 | metric name differs from the dashboard | wontfix: dashboard renames it | r1 |
| V-4 | major | src/orders/pay.ts:88 | payment path skips invalidate | open | r1 |

## Evidence (round 1)
npm test → exit 1 (1 failing: invalidate ordering)
