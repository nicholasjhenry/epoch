# Cart Items API Contract

**Feature**: 009-display-cart-items
**Date**: 2025-11-26

## Overview

This document defines the internal API contracts for the cart items display feature. Since this is a Phoenix LiveView application without external REST/GraphQL APIs, the contracts define module interfaces and data structures.

---

## Module Contracts

### Epoch.Cart.CartItemsView

State view module for projecting cart events into displayable cart state.

#### Types

```elixir
@type cart_item :: %{
  item_id: String.t(),
  name: String.t(),
  price: float()
}

@type state :: %{
  items: [cart_item()],
  total: float()
}
```

#### Functions

##### `initial_state/0`

Returns the initial empty cart state.

```elixir
@spec initial_state() :: state()

# Returns
%{items: [], total: 0.0}
```

##### `evolve/2`

Applies a single event to the current state, returning updated state.

```elixir
@spec evolve(state(), event()) :: state()
  when event: ItemAdded.t() | ItemRemoved.t() | CartCleared.t() | ItemArchived.t()
```

**Behavior by Event Type**:

| Event | Effect |
|-------|--------|
| `ItemAdded` | Append item to list, add price to total |
| `ItemRemoved` | Remove item by `item_id`, subtract price from total |
| `CartCleared` | Reset to initial state |
| `ItemArchived` | Remove item by `item_id`, subtract price from total |

##### `project/1`

Projects a list of events into final cart state (convenience function).

```elixir
@spec project([event()]) :: state()

# Implementation
def project(events) do
  Enum.reduce(events, initial_state(), &evolve(&2, &1))
end
```

##### `empty?/1`

Checks if cart state has no items.

```elixir
@spec empty?(state()) :: boolean()

# Returns true when items list is empty
```

---

### Epoch.Cart (Extended)

Extensions to existing Cart context module.

#### New Functions

##### `get_cart_items/1`

Retrieves displayable cart items for a session.

```elixir
@spec get_cart_items(session_id :: String.t()) :: {:ok, CartItemsView.state()} | {:error, term()}
```

**Implementation**:
1. Build stream name: `"cart-#{session_id}"`
2. Call `EventStore.aggregate_stream/4` with `CartItemsView.evolve/2`
3. Return projected state

**Errors**:
- `{:error, :stream_not_found}` - No cart stream exists for session

---

### EpochWeb.CartLive

LiveView module for displaying cart items.

#### Socket Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `@session_id` | `String.t()` | Cart session identifier |
| `@cart_items` | `[cart_item()]` | List of items to display |
| `@cart_total` | `float()` | Sum of item prices |
| `@cart_empty?` | `boolean()` | Whether cart has items |

#### Mount

```elixir
@spec mount(params, session, socket) :: {:ok, socket}
  when params: %{optional(String.t()) => String.t()},
       session: map(),
       socket: Phoenix.LiveView.Socket.t()
```

**Params**:
- `"session_id"` (required) - The cart session to display

**Behavior**:
1. Extract `session_id` from params
2. Load cart state via `Cart.get_cart_items/1`
3. Assign cart_items, cart_total, cart_empty? to socket

#### Events (Future)

For real-time updates (not in initial scope):

```elixir
@spec handle_info({:events_appended, stream_name, events}, socket) :: {:noreply, socket}
```

---

## Event Contracts

### ItemAdded

```elixir
defmodule Epoch.Cart.Events.ItemAdded do
  @type t :: %__MODULE__{
    item_id: String.t(),
    product_id: String.t(),
    name: String.t(),
    price: float(),
    added_at: DateTime.t()
  }

  defstruct [:item_id, :product_id, :name, :price, :added_at]
end
```

### ItemRemoved

```elixir
defmodule Epoch.Cart.Events.ItemRemoved do
  @type t :: %__MODULE__{
    item_id: String.t(),
    removed_at: DateTime.t()
  }

  defstruct [:item_id, :removed_at]
end
```

### CartCleared

```elixir
defmodule Epoch.Cart.Events.CartCleared do
  @type t :: %__MODULE__{
    cleared_at: DateTime.t()
  }

  defstruct [:cleared_at]
end
```

### ItemArchived

```elixir
defmodule Epoch.Cart.Events.ItemArchived do
  @type t :: %__MODULE__{
    item_id: String.t(),
    archived_at: DateTime.t()
  }

  defstruct [:item_id, :archived_at]
end
```

---

## Route Contract

### GET /cart/:session_id

Displays the cart for a given session.

**Path Parameters**:
- `session_id` (string, required) - Cart session identifier

**Response**: HTML page rendered by CartLive

**Behavior**:
- If session exists: Display cart items, total, or empty state
- If session not found: Display empty cart state (graceful degradation)

---

## Template Contract

### cart_live.html.heex

Required elements with DOM IDs for testing:

| Element | ID Pattern | Purpose |
|---------|------------|---------|
| Container | `#cart` | Main cart container |
| Empty message | `#cart-empty` | "Your cart is empty" notification |
| Items table | `#cart-items` | Table of cart items |
| Item row | `#cart-item-{item_id}` | Individual item row |
| Item name | `#cart-item-name-{item_id}` | Item name cell |
| Item price | `#cart-item-price-{item_id}` | Item price cell |
| Total | `#cart-total` | Cart total display |

**Conditional Rendering**:
- Show `#cart-empty` when `@cart_empty?` is true
- Show `#cart-items` and `#cart-total` when `@cart_empty?` is false
