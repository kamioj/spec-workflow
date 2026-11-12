# Proposal: adv5

## Why
Readers cannot tell which branch a label belongs to.

## What
- Draw the routing fixture | refs: R-1 | verify: page renders without fallback

**Not in this change**: nothing else.

## How
```mermaid
flowchart TD
  subgraph Clients
    A["Web app"]
    B["Mobile app"]
  end
  subgraph Services
    P["Parser"]
    Q["Queue"]
    R["Router"]
  end
  subgraph Stores
    X["Orders DB"]
    Y["Search index"]
  end
  B -->|sync| Y
  P -->|parse| Q
  Q -->|route jobs| R
  A -->|submit| P
  R -->|store| X
```
- Choice: renderer only

## Risk
- none
