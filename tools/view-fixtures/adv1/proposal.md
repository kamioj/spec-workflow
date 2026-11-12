# Proposal: adv1

## Why
Readers cannot tell which branch a label belongs to.

## What
- Draw the routing fixture | refs: R-1 | verify: page renders without fallback

**Not in this change**: nothing else.

## How
```mermaid
flowchart TD
  subgraph You
    U["Author<br/>runs verify"]
    Z["Author<br/>reads result"]
  end
  subgraph Check
    Q{"active change?"}
    K["Gate check"]
  end
  subgraph Modes
    M1["Change mode"]
    M2["Diff mode"]
    M3["Ship mode"]
  end
  subgraph Out
    L["Ledger"]
    R["Record"]
  end
  U -->|run verify| Q
  Q -->|yes| M1
  Q -->|yes| M3
  Q -->|no| M2
  Q -->|no| R
  K -->|blocks| Z
  M1 -->|writes| L
  M2 -->|writes| R
  M3 -->|writes| L
  L -->|report| Z
  R -->|report| Z
```
- Choice: renderer only

## Risk
- none
