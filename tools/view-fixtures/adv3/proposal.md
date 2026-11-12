# Proposal: adv3

## Why
Readers cannot tell which branch a label belongs to.

## What
- Draw the routing fixture | refs: R-1 | verify: page renders without fallback

**Not in this change**: nothing else.

## How
```mermaid
flowchart LR
  A["Client"] -->|request| B["Gateway"]
  A -->|bypass call| D["Service"]
  B -->|forward| C["Auth"]
  C -->|token| D
  B -->|direct| D
  D -->|reply| E["Logger"]
  A -->|audit| E
```
- Choice: renderer only

## Risk
- none
