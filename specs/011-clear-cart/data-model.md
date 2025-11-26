# Data Model: Clear All Items from Cart

**Feature**: 011-clear-cart
**Date**: 2025-11-26

## Entities

### 1. ClearCart Command

**Location**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/command.ex`

**Purpose**: Represents the intent to clear all items from a cart session.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `session_id` | `String.t()` | Cart session identifier | Required, non-empty |

**Structure**:
```elixir
defmodule Epoch.Slices.ClearCart.Command do
  @type t :: %__MODULE__{
          session_id: String.t()
        }

  defstruct [:session_id]
end
```

### 2. CartCleared Event (Existing)

**Location**: `apps/epoch/lib/epoch/cart/events/cart_cleared.ex`

**Purpose**: Domain event emitted when all items are removed from a cart.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `cleared_at` | `DateTime.t()` | Timestamp of clear action | Set by handler |

**Structure** (already exists):
```elixir
defmodule Epoch.Cart.Events.CartCleared do
  @type t :: %__MODULE__{
          cleared_at: DateTime.t()
        }

  defstruct [:cleared_at]
end
```

### 3. CartItemsView State (Existing)

**Location**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

**Purpose**: Read model for cart display state.

| Field | Type | Description |
|-------|------|-------------|
| `items` | `[cart_item()]` | List of cart items |
| `total` | `float()` | Sum of item prices |

**CartCleared Handling** (already exists):
```elixir
def evolve(_state, %CartCleared{}) do
  initial_state()  # Returns %{items: [], total: 0.0}
end
```

## State Transitions

### Cart State Machine

```
┌─────────────────┐
│   Has Items     │
│  (items > 0)    │
└────────┬────────┘
         │
         │ ClearCart Command
         │ (with confirmation)
         ▼
┌─────────────────┐
│  CartCleared    │
│    Event        │
└────────┬────────┘
         │
         │ Project via CartItemsView
         ▼
┌─────────────────┐
│     Empty       │
│  (items == 0)   │
└─────────────────┘
```

### Event Flow

1. User clicks "Clear Cart" button
2. Browser displays `confirm()` dialog
3. User confirms → LiveComponent receives `"clear_cart"` event
4. CommandHandler validates cart is non-empty
5. CommandHandler appends `CartCleared` event to stream
6. EventStore broadcasts to PubSub
7. CartItems.Live receives broadcast, reloads state
8. CartItemsView projects events → empty state
9. UI re-renders with empty cart message

## Relationships

```
┌──────────────────────┐
│  ClearCart.Component │
│    (LiveComponent)   │
└──────────┬───────────┘
           │ handle_event("clear_cart")
           ▼
┌──────────────────────┐
│ ClearCart.Command    │
│   {session_id}       │
└──────────┬───────────┘
           │ CommandHandler.handle/1
           ▼
┌──────────────────────┐
│ Cart.get_cart_items  │
│  (validate non-empty)│
└──────────┬───────────┘
           │ :ok
           ▼
┌──────────────────────┐
│ CartCleared Event    │
│   {cleared_at}       │
└──────────┬───────────┘
           │ EventStore.append_to_stream
           ▼
┌──────────────────────┐
│    Event Stream      │
│  "cart-{session_id}" │
└──────────┬───────────┘
           │ PubSub broadcast
           ▼
┌──────────────────────┐
│  CartItems.Live      │
│  (subscribed)        │
└──────────────────────┘
```

## Validation Rules

| Rule | Location | Behavior |
|------|----------|----------|
| Cart must have items | CommandHandler | Return `{:error, :cart_empty}` if no items |
| Session must exist | Implicit via get_cart_items | Returns empty state for non-existent sessions |

## No Database Changes

This feature uses the in-memory EventStore. No Ecto migrations or database schema changes are required.
