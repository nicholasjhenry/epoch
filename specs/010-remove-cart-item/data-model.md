# Data Model: Remove Item from Cart

**Feature**: 010-remove-cart-item
**Date**: 2025-11-26

## Entities

### RemoveItem.Command (NEW)

Command struct for removing an item from a cart.

**Location**: `apps/epoch_web/lib/epoch_web/slices/remove_item/command.ex`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| session_id | String.t() | Yes | Cart session identifier |
| item_id | String.t() | Yes | Unique identifier of the item to remove |

**Validation Rules**:
- `session_id` must be a non-empty string
- `item_id` must be a non-empty string
- Item must exist in the current cart state (validated by CommandHandler)

**Typespec**:
```elixir
@type t :: %__MODULE__{
  session_id: String.t(),
  item_id: String.t()
}
```

---

### ItemRemoved Event (EXISTING)

Event emitted when an item is removed from the cart.

**Location**: `apps/epoch/lib/epoch/cart/events/item_removed.ex`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| item_id | String.t() | Yes | Unique identifier of the removed item |
| removed_at | DateTime.t() | Yes | Timestamp when removal occurred |

**Typespec** (existing):
```elixir
@type t :: %__MODULE__{
  item_id: String.t(),
  removed_at: DateTime.t()
}
```

---

### CartItemsView State (EXISTING)

Read model state for displaying cart items.

**Location**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

| Field | Type | Description |
|-------|------|-------------|
| items | [cart_item()] | List of items in cart |
| total | float() | Sum of all item prices |

**cart_item type**:
| Field | Type | Description |
|-------|------|-------------|
| item_id | String.t() | Unique item identifier |
| name | String.t() | Product name |
| price | float() | Item price |

**State Transitions**:
- `ItemRemoved` event: Removes item from `items` list, subtracts price from `total`
- If item_id not found: State unchanged (handled gracefully in view)

---

## Relationships

```
┌─────────────────────┐
│ RemoveItem.Command  │
│ (session_id,        │
│  item_id)           │
└─────────┬───────────┘
          │ validates against
          ▼
┌─────────────────────┐
│ CartItemsView State │◄──────────┐
│ (items, total)      │           │
└─────────┬───────────┘           │
          │ if item exists        │ evolve()
          ▼                       │
┌─────────────────────┐           │
│ ItemRemoved Event   │───────────┘
│ (item_id,           │
│  removed_at)        │
└─────────────────────┘
```

## Event Flow

1. User clicks remove button → `RemoveItem.Component` receives event
2. Component creates `RemoveItem.Command` with session_id and item_id
3. `CommandHandler.handle/1` reconstructs cart state via `Cart.get_cart_items/1`
4. CommandHandler validates item exists in state
   - If not found: return `{:error, :item_not_found}`
   - If found: create `ItemRemoved` event
5. CommandHandler appends event to cart stream via `EventStore.append_to_stream/3`
6. EventStore broadcasts to `stream_type:cart` PubSub topic
7. `CartLive` receives broadcast, reloads cart state, updates UI

## No Database Changes

This feature uses the in-memory EventStore. No Ecto migrations or database schema changes required.
