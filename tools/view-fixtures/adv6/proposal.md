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
  B -->|parallel b| Y
  P -->|side| Q
  Q -->|side two| R
  A -->|a to p| P
  B -->|b to r| R
```
- Choice: renderer only

## Risk
- none
