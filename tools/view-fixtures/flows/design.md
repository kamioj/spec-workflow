# Design: order-pipeline

## Architecture

```mermaid
flowchart TD
  %% layered bands, new nodes, a loop back to the first band
  subgraph Client
    U["Shopper<br/>web or app"]
    N["Notification<br/>email / push"]:::new
  end
  subgraph Edge
    GW["API gateway<br/>auth + rate limit"]
  end
  subgraph Services
    O["Order service<br/>validates cart"]
    P["Payment service"]
    S["Stock reservation<br/>holds items 15 min"]:::new
  end
  subgraph Storage
    DB[("orders DB")]
    Q[["event queue"]]:::new
  end
  U -->|places order| GW
  GW --> O
  O -->|charge| P
  O -->|reserve| S
  P --> DB
  S ==> Q
  Q -->|order.paid| N
  N -->|receipt| U
```

Reads go through the gateway; every write lands in the orders database.

```mermaid
flowchart LR
  A[Checkout] --> B{Cart valid?}
  B -->|no| C[Show errors]
  B -->|yes| D[Price cart]
  D --> E[Apply coupons]
  E --> F[Compute tax]
  F --> G[Reserve stock]
  G -->|fails| H[Back-order prompt]
  G --> I[Create payment intent]
  I --> J{3-D Secure?}
  J -->|yes| K[Challenge]
  J -->|no| L[Capture]
  K --> L
  L --> M[(Write order)]
  M --> N[Emit order.paid]
  N -.-> O[Analytics]
  N --> P([Confirmation page])
  H -.-> A
  C -.-> A
```

```mermaid
sequenceDiagram
  Shopper->>Gateway: POST /orders
  Gateway->>Orders: create
```

## Interfaces

### HTTP
- **Create order**: `POST /api/orders` with the cart id; returns `201` and the order id
- **Get order**: `GET /api/orders/{id}` returns status, totals and lines
- Webhook: `POST /hooks/payment` from the payment provider, signed
  - retries with exponential backoff

### Events
- `order.paid` → stock reservation becomes a sale; notification sent

## Key Decisions

**Reserve stock before payment**
- Problem: two shoppers can pay for the last item at the same time.
- Solution: hold the item for 15 minutes when checkout starts.
- Cost: abandoned checkouts lock stock until the hold expires.
- Why not the alternatives: reserving after payment needs refunds for oversold items.

**Queue between services**
- Problem: a slow notification provider blocks order confirmation.
- Solution: publish `order.paid` to a queue and notify asynchronously.
- Cost: one more piece of infrastructure to operate.

## Migration / Compatibility
- **Database**: add `reserved_until` to `stock_items`; backfill null
- **API**: `GET /api/orders/{id}` gains a `reservation` field; old clients ignore it
- Feature flag `reserve-before-pay` defaults off for one release
