# Command Contracts: Price Change Automation

**Feature**: 014-price-change-automation  
**Date**: 2025-12-01

## Overview

This document defines the command contracts for the price change automation feature. Commands represent user intentions and system actions that mutate state via event emission.

---

## ChangePrice Command

**Module**: `Epoch.Backoffice.Price`  
**Function**: `change_price/1`  
**Purpose**: Change the price of a product in the catalog

### Request

```elixir
%{
  product_id: String.t(),   # Required: Product identifier
  new_price: Decimal.t()    # Required: New price (must be > 0)
}
```

### Response

**Success**:
```elixir
{:ok, %PriceChanged{
  product_id: String.t(),
  old_price: Decimal.t() | nil,
  new_price: Decimal.t(),
  changed_at: DateTime.t()
}}
```

**Errors**:
```elixir
{:error, :product_not_found}  # Product ID doesn't exist in Catalog
{:error, :invalid_price}      # New price <= 0
```

### Side Effects

1. Appends `PriceChanged` event to `price-{product_id}` stream
2. Broadcasts event via PubSub to `stream_type:price` topic
3. Triggers `ProductsWithPriceChanges` read model update
4. Triggers `PriceChangeProcessor` automation

### Idempotency

Not idempotent - each call emits a new `PriceChanged` event. Multiple price changes for same product are valid (tracks price history).

### Example

```elixir
# Change price of espresso-blend to $15.99
iex> Epoch.Backoffice.Price.change_price(%{
...>   product_id: "espresso-blend",
...>   new_price: Decimal.new("15.99")
...> })
{:ok, %PriceChanged{
  product_id: "espresso-blend",
  old_price: Decimal.new("14.99"),
  new_price: Decimal.new("15.99"),
  changed_at: ~U[2025-12-01 10:30:00Z]
}}
```

---

## RequestToArchiveItem Command

**Module**: `Epoch.Cart`  
**Function**: `request_archive/1`  
**Purpose**: Request that a cart item be archived (triggered by automation)

### Request

```elixir
%{
  cart_id: String.t(),      # Required: Cart/session identifier
  product_id: String.t(),   # Required: Product triggering archive
  item_id: String.t(),      # Required: Item to archive
  reason: String.t()        # Required: Why archiving (e.g., "price_changed")
}
```

### Response

**Success**:
```elixir
{:ok, %ItemArchiveRequested{
  cart_id: String.t(),
  product_id: String.t(),
  item_id: String.t(),
  reason: String.t(),
  requested_at: DateTime.t()
}}
```

**Errors**:
```elixir
{:error, :already_requested}  # Archive request already exists for item
{:error, :item_not_found}     # Item doesn't exist in cart
{:error, :already_archived}   # Item was already archived
```

### Side Effects

1. Appends `ItemArchiveRequested` event to `cart-{cart_id}` stream
2. Broadcasts event via PubSub to `stream_type:cart` topic
3. Updates `ItemsToArchive` read model (adds to pending)

### Idempotency

Idempotent - returns `{:error, :already_requested}` if called twice for same item. Safe to retry.

### Example

```elixir
# Request archive for item due to price change
iex> Epoch.Cart.request_archive(%{
...>   cart_id: "session-123",
...>   product_id: "espresso-blend",
...>   item_id: "espresso-blend-1701234567",
...>   reason: "price_changed"
...> })
{:ok, %ItemArchiveRequested{
  cart_id: "session-123",
  product_id: "espresso-blend",
  item_id: "espresso-blend-1701234567",
  reason: "price_changed",
  requested_at: ~U[2025-12-01 10:31:00Z]
}}
```

---

## ArchiveItem Command

**Module**: `Epoch.Cart`  
**Function**: `archive_item/1`  
**Purpose**: Archive a cart item (complete the pending archive request)

### Request

```elixir
%{
  cart_id: String.t(),        # Required: Cart/session identifier
  item_id: String.t(),        # Required: Item to archive
  reason: String.t() | nil    # Optional: Why archived
}
```

### Response

**Success**:
```elixir
{:ok, %ItemArchived{
  cart_id: String.t(),
  item_id: String.t(),
  reason: String.t() | nil,
  archived_at: DateTime.t()
}}
```

**Errors**:
```elixir
{:error, :item_not_found}     # Item doesn't exist in cart
{:error, :already_archived}   # Item was already archived
```

### Side Effects

1. Appends `ItemArchived` event to `cart-{cart_id}` stream
2. Broadcasts event via PubSub to `stream_type:cart` topic
3. Updates `ItemsToArchive` read model (removes from pending)
4. Updates `CartsWithProducts` read model (removes mapping)
5. Updates `CartItemsView` read model (removes from cart display)

### Idempotency

Idempotent - returns `{:error, :already_archived}` if called twice for same item. Safe to retry.

### Example

```elixir
# Archive a cart item
iex> Epoch.Cart.archive_item(%{
...>   cart_id: "session-123",
...>   item_id: "espresso-blend-1701234567",
...>   reason: "price_changed"
...> })
{:ok, %ItemArchived{
  cart_id: "session-123",
  item_id: "espresso-blend-1701234567",
  reason: "price_changed",
  archived_at: ~U[2025-12-01 10:32:00Z]
}}
```

---

## Command Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Backoffice UI                              │
│                                                                 │
│  [Change Price Form]                                            │
│       │                                                         │
│       ▼                                                         │
│  ChangePrice Command ──────────────────────────────────────┐    │
│       │                                                    │    │
│       ▼                                                    │    │
│  PriceChanged Event ◄──────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┬─┘
                                                                │
                                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  PriceChangeProcessor                           │
│                                                                 │
│  (Subscribes to stream_type:price)                              │
│       │                                                         │
│       ▼                                                         │
│  Query CartsWithProducts ───► Find affected carts               │
│       │                                                         │
│       ▼ (for each affected item)                                │
│  RequestToArchiveItem Command ─────────────────────────────┐    │
│       │                                                    │    │
│       ▼                                                    │    │
│  ItemArchiveRequested Event ◄──────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┬─┘
                                                                │
                                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   ArchiveProcessor                              │
│                                                                 │
│  (Reads ItemsToArchive TODO list)                               │
│       │                                                         │
│       ▼ (for each pending item)                                 │
│  ArchiveItem Command ──────────────────────────────────────┐    │
│       │                                                    │    │
│       ▼                                                    │    │
│  ItemArchived Event ◄──────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Error Handling Summary

| Command | Error | HTTP Status (if exposed) | Recovery |
|---------|-------|--------------------------|----------|
| ChangePrice | :product_not_found | 404 | Use valid product_id |
| ChangePrice | :invalid_price | 422 | Price must be > 0 |
| RequestToArchiveItem | :already_requested | 409 | Safe to ignore (idempotent) |
| RequestToArchiveItem | :item_not_found | 404 | Item was already removed |
| RequestToArchiveItem | :already_archived | 409 | Safe to ignore (idempotent) |
| ArchiveItem | :item_not_found | 404 | Item was already removed |
| ArchiveItem | :already_archived | 409 | Safe to ignore (idempotent) |
