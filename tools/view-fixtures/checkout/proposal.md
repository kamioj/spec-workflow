# Proposal: checkout

## Why
Paid orders stay pending until someone refreshes; receipts go out late.

## What
- Mark orders paid from the payment webhook and send the receipt | refs: R-1 | verify: page renders without fallback

**Not in this change**: nothing else.

## How
```mermaid
flowchart TD
  subgraph Shopper
    S["Shopper<br/>clicks pay"]
    N["Shopper<br/>gets receipt"]
  end
  subgraph Web
    C["Checkout page"]
  end
  subgraph Order service
    O["Order API<br/>creates order"]
    H["Webhook handler<br/>marks paid"]:::new
    M["Mailer"]
  end
  subgraph Payment
    P["Provider<br/>charges card"]
  end
  subgraph Data
    DB["orders DB"]
  end
  S -->|pay| C
  C -->|POST /orders| O
  O -->|insert pending| DB
  O -->|create charge| P
  P -->|redirect URL| C
  P -->|payment webhook| H
  H -->|update paid| DB
  H -->|send receipt| M
  M -->|receipt email| N
```

- Choice: renderer only

## Risk
- none
