# Event Contracts: Price Change Automation

**Feature**: 014-price-change-automation  
**Date**: 2025-12-01

## Overview

This document defines the event contracts for the price change automation feature. Events represent facts that have occurred in the system.

---

## PriceChanged

**Stream**: `price-{product_id}`  
**Producer**: `Epoch.Backoffice.Price.change_price/1`  
**Consumers**: 
- `ProductsWithPriceChanges` (read model)
- `PriceChangeProcessor` (automation)

### Schema

```elixir
%Epoch.Backoffice.Events.PriceChanged{
  product_id: String.t(),        # Product identifier
  old_price: Decimal.t() | nil,  # Previous price (nil if first)
  new_price: Decimal.t(),        # New price
  changed_at: DateTime.t()       # UTC timestamp
}
```

### JSON Representation (for debugging/logs)

```json
{
  "type": "PriceChanged",
  "data": {
    "product_id": "espresso-blend",
    "old_price": "14.99",
    "new_price": "15.99",
    "changed_at": "2025-12-01T10:30:00Z"
  }
}
```

### Invariants

- `product_id` references a valid product in Catalog at time of emission
- `new_price` > 0
- `old_price` may be nil only for first price change
- `changed_at` is always UTC

### PubSub Topic

- `stream_type:price` - All price change events

---

## ItemArchiveRequested

**Stream**: `cart-{cart_id}`  
**Producer**: `Epoch.Cart.request_archive/1`  
**Consumers**:
- `ItemsToArchive` (read model - adds to pending)
- `ArchiveProcessor` (automation - triggers archive)

### Schema

```elixir
%Epoch.Cart.Events.ItemArchiveRequested{
  cart_id: String.t(),      # Cart/session identifier
  product_id: String.t(),   # Product that triggered request
  item_id: String.t(),      # Unique item identifier
  reason: String.t(),       # Why archive requested
  requested_at: DateTime.t() # UTC timestamp
}
```

### JSON Representation

```json
{
  "type": "ItemArchiveRequested",
  "data": {
    "cart_id": "session-123",
    "product_id": "espresso-blend",
    "item_id": "espresso-blend-1701234567",
    "reason": "price_changed",
    "requested_at": "2025-12-01T10:31:00Z"
  }
}
```

### Invariants

- `cart_id` references existing cart stream
- `item_id` was present in cart at request time
- `reason` is non-empty string
- `requested_at` is always UTC
- Only one `ItemArchiveRequested` per `item_id` (idempotent)

### PubSub Topic

- `stream_type:cart` - All cart events

### Reason Values

| Reason | Description |
|--------|-------------|
| `price_changed` | Product price was changed |
| `inventory_low` | Inventory dropped below threshold (future) |
| `product_discontinued` | Product removed from catalog (future) |

---

## ItemArchived

**Stream**: `cart-{cart_id}`  
**Producer**: `Epoch.Cart.archive_item/1`  
**Consumers**:
- `ItemsToArchive` (read model - removes from pending)
- `CartsWithProducts` (read model - removes mapping)
- `CartItemsView` (read model - removes from display)

### Schema

```elixir
%Epoch.Cart.Events.ItemArchived{
  cart_id: String.t(),        # Cart/session identifier
  item_id: String.t(),        # Archived item identifier
  reason: String.t() | nil,   # Why archived (optional)
  archived_at: DateTime.t()   # UTC timestamp
}
```

### JSON Representation

```json
{
  "type": "ItemArchived",
  "data": {
    "cart_id": "session-123",
    "item_id": "espresso-blend-1701234567",
    "reason": "price_changed",
    "archived_at": "2025-12-01T10:32:00Z"
  }
}
```

### Invariants

- `cart_id` references existing cart stream
- `item_id` was present in cart at archive time
- `archived_at` is always UTC
- Only one `ItemArchived` per `item_id` (idempotent)

### PubSub Topic

- `stream_type:cart` - All cart events

---

## Event Ordering

Within a cart stream, events follow this ordering constraint:

```
ItemAdded(item_id: X)
    │
    ├── ItemArchiveRequested(item_id: X)  [optional]
    │       │
    │       └── ItemArchived(item_id: X)  [if requested]
    │
    └── ItemRemoved(item_id: X)  [alternative: user removes]
```

**Rules**:
1. `ItemArchiveRequested` can only occur after `ItemAdded` for same `item_id`
2. `ItemArchived` can only occur after `ItemArchiveRequested` for same `item_id`
3. `ItemRemoved` and `ItemArchived` are mutually exclusive for same `item_id`
4. Once archived or removed, no further events for that `item_id`

---

## Cross-Stream Event Correlation

The price change automation correlates events across streams:

```
price-espresso-blend stream:
├── PriceChanged{product_id: "espresso-blend", ...}

cart-session-123 stream:
├── ItemAdded{item_id: "espresso-blend-123", product_id: "espresso-blend", ...}
├── ItemArchiveRequested{item_id: "espresso-blend-123", product_id: "espresso-blend", reason: "price_changed", ...}
└── ItemArchived{item_id: "espresso-blend-123", reason: "price_changed", ...}

cart-session-456 stream:
├── ItemAdded{item_id: "espresso-blend-456", product_id: "espresso-blend", ...}
├── ItemArchiveRequested{item_id: "espresso-blend-456", product_id: "espresso-blend", reason: "price_changed", ...}
└── ItemArchived{item_id: "espresso-blend-456", reason: "price_changed", ...}
```

**Correlation Key**: `product_id` links `PriceChanged` to affected `ItemAdded` events

---

## Event Metadata

All events are wrapped in `EventEnvelope` with metadata:

```elixir
%Epoch.EventStore.EventEnvelope{
  event: %PriceChanged{...},  # or any domain event
  metadata: %Epoch.EventStore.EventMetadata{
    event_id: "uuid-v4",           # Unique event identifier
    stream_position: 1,            # Position in stream (1-indexed)
    log_position: 42               # Global position (1-indexed)
  }
}
```

This metadata enables:
- Deduplication via `event_id`
- Ordering via `stream_position` and `log_position`
- Debugging and auditing
