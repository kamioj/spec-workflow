# Proposal: adv2

## Why
Readers cannot tell which branch a label belongs to.

## What
- Draw the routing fixture | refs: R-1 | verify: page renders without fallback

**Not in this change**: nothing else.

## How
```mermaid
flowchart TD
  subgraph Top
    A["Source A"]
    B["Source B"]
  end
  subgraph Mid one
    P["Parser"]
    Q["Queue"]
    R["Router"]
  end
  subgraph Mid two
    S["Store"]
    T["Tracer"]
  end
  subgraph Bottom
    X["Target X"]
    Y["Target Y"]
  end
  A -->|long one| Y
  B -->|long two| X
  A -->|parallel a| X
  B -->|parallel b| Y
  P -->|side| Q
  Q -->|side two| R
  S -->|hop| T
  A -->|a to p| P
  B -->|b to r| R
  P -->|p to s| S
  R -->|r to t| T
  X -->|done| A
  Y -->|done too| B
```
- Choice: renderer only

## Risk
- none
