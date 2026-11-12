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
  A -->|a to p| P
  P -->|p to s| S
  S -->|s to x| X
  X -->|done| A
  Y -->|done too| B
  B -->|b to y| Y
```
- Choice: renderer only

## Risk
- none
