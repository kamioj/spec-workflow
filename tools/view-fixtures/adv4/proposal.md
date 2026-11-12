# Proposal: adv4

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
  end
  subgraph Stores
    X["Orders DB"]
    Y["Search index"]
  end
  A -->|writes orders| Y
  B -->|reads stock| X
  P -->|enqueue| Q
```
- Choice: renderer only

## Risk
- none
