# Proposal: export-csv

## Why
Managers need full-year exports (R-1).

## What
1. **Streaming export** | refs: R-1 | verify: a 2-million-row export completes

## How
- Stream rows from the cursor.

## Risk
- Slow clients hold a connection open.
