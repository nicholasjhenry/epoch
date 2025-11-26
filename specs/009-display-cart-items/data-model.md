# Data Model: Display Cart Items

**Feature**: 009-display-cart-items
**Date**: 2025-11-26

## Overview

This feature introduces a read model (state view) for displaying cart items. The model projects cart events into a displayable structure with item details and totals.

---

## Entities

### CartItem (View Model)

Represents a single displayable item in the shopping cart.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `item_id` | `String.t()` | Unique identifier for this line item | Required, unique per cart |
| `name` | `String.t()` | Product display name | Required, non-empty |
| `price` | `float()` | Item price in dollars | Required, positive |

**Notes**:
- This is a view model, not persisted
- Derived from `ItemAdded` events
- Each `ItemAdded` creates one `CartItem` (no quantity aggregation)

### CartItemsState (Projection State)

The accumulated state from projecting cart events.

| Field | Type | Description |
|-------|------|-------------|
| `items` | `[CartItem.t()]` | List of active cart items |
| `total` | `float()` | Sum of all item prices |

**Computed**:
- `total` = `Enum.sum(Enum.map(items, & &1.price))`
- `empty?` = `items == []`

---

## Events

### ItemAdded

Emitted when a product is added to the cart as a new line item.

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String.t()` | Unique line item identifier |
| `product_id` | `String.t()` | Reference to catalog product |
| `name` | `String.t()` | Product name (denormalized) |
| `price` | `float()` | Price at time of add (denormalized) |
| `added_at` | `DateTime.t()` | Timestamp |

**Stream**: `cart-{session_id}`

**Projection Effect**: Appends new `CartItem` to items list

### ItemRemoved

Emitted when a specific line item is removed from the cart.

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String.t()` | Line item to remove |
| `removed_at` | `DateTime.t()` | Timestamp |

**Stream**: `cart-{session_id}`

**Projection Effect**: Removes `CartItem` with matching `item_id` from items list

### CartCleared

Emitted when all items are removed from the cart.

| Field | Type | Description |
|-------|------|-------------|
| `cleared_at` | `DateTime.t()` | Timestamp |

**Stream**: `cart-{session_id}`

**Projection Effect**: Clears all items, sets items to `[]`

### ItemArchived

Emitted when a line item is archived (soft removal).

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String.t()` | Line item to archive |
| `archived_at` | `DateTime.t()` | Timestamp |

**Stream**: `cart-{session_id}`

**Projection Effect**: Removes `CartItem` with matching `item_id` from items list (same as ItemRemoved)

---

## State Transitions

```
Initial State: {items: [], total: 0.0}

ItemAdded(item_id, name, price) →
  items: items ++ [%{item_id: item_id, name: name, price: price}]
  total: total + price

ItemRemoved(item_id) →
  removed_item = find_by_item_id(items, item_id)
  items: reject_by_item_id(items, item_id)
  total: total - removed_item.price

CartCleared →
  items: []
  total: 0.0

ItemArchived(item_id) →
  (same as ItemRemoved)
```

---

## Validation Rules

### Event Creation
- `ItemAdded.price` must be positive (> 0)
- `ItemAdded.name` must be non-empty string
- `ItemAdded.item_id` must be unique within the cart stream
- `ItemRemoved.item_id` should reference an existing item (idempotent if not found)
- `ItemArchived.item_id` should reference an existing item (idempotent if not found)

### Projection
- Unknown event types are ignored (logged as warning)
- Events with missing required fields are skipped (logged as warning)
- Price calculations use standard floating-point arithmetic (sufficient for display)

---

## Relationships

```
┌─────────────────┐      projects to      ┌─────────────────┐
│   EventStore    │ ────────────────────► │ CartItemsState  │
│   (cart-{id})   │                       │   (view model)  │
└─────────────────┘                       └─────────────────┘
        │                                         │
        │ stores                                  │ renders
        ▼                                         ▼
┌─────────────────┐                       ┌─────────────────┐
│  Cart Events    │                       │    CartLive     │
│  (ItemAdded,    │                       │   (LiveView)    │
│   ItemRemoved,  │                       └─────────────────┘
│   CartCleared,  │
│   ItemArchived) │
└─────────────────┘
```

---

## Integration with Existing Models

### Catalog.Product
- `ItemAdded.product_id` references `Catalog.Product.id`
- `ItemAdded.name` and `ItemAdded.price` are copied from product at add time
- No runtime dependency on Catalog for display

### Cart.CartSession
- `CartSession` tracks `{product_id, quantity}` for command validation
- `CartItemsState` tracks `{item_id, name, price}` for display
- Both project from same event stream but serve different purposes
- May coexist or be unified in future (out of scope for this feature)

### EventStore
- Events read via `EventStore.aggregate_stream/4`
- Stream name: `"cart-{session_id}"`
- Uses existing EventStore infrastructure from Feature 001

---

## Example Event Sequence

```elixir
# Stream: "cart-session-abc123"

[
  %ItemAdded{item_id: "item-1", product_id: "espresso-blend", name: "Espresso Blend", price: 14.99, added_at: ~U[2025-11-26 10:00:00Z]},
  %ItemAdded{item_id: "item-2", product_id: "french-roast", name: "French Roast", price: 13.99, added_at: ~U[2025-11-26 10:01:00Z]},
  %ItemRemoved{item_id: "item-1", removed_at: ~U[2025-11-26 10:02:00Z]},
  %ItemAdded{item_id: "item-3", product_id: "espresso-blend", name: "Espresso Blend", price: 14.99, added_at: ~U[2025-11-26 10:03:00Z]}
]

# Projected State:
%CartItemsState{
  items: [
    %{item_id: "item-2", name: "French Roast", price: 13.99},
    %{item_id: "item-3", name: "Espresso Blend", price: 14.99}
  ],
  total: 28.98
}
```
