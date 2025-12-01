# Data Model: Price Change TODO List & Automation

**Feature**: 014-price-change-automation  
**Date**: 2025-12-01  
**Status**: Complete

## Overview

This feature introduces price change tracking and automated cart item archival. The data model consists of:
- 3 new events (`PriceChanged`, `ItemArchiveRequested`, `ItemArchived` - extends existing)
- 2 new read models (`ProductsWithPriceChanges`, `CartsWithProducts`)
- 1 extended read model (`ItemsToArchive` - TODO list)
- 2 commands (`ChangePrice`, `RequestToArchiveItem`, plus existing `ArchiveItem`)

## Events

### PriceChanged

**Stream**: `price-{product_id}`  
**Purpose**: Records that a product's price has been changed in the backoffice

```elixir
defmodule Epoch.Backoffice.Events.PriceChanged do
  @type t :: %__MODULE__{
    product_id: String.t(),
    old_price: Decimal.t(),
    new_price: Decimal.t(),
    changed_at: DateTime.t()
  }
  
  @enforce_keys [:product_id, :new_price, :changed_at]
  defstruct [:product_id, :old_price, :new_price, :changed_at]
end
```

**Field Details**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| product_id | String.t() | Yes | Product identifier (e.g., "espresso-blend") |
| old_price | Decimal.t() | No | Previous price (nil if first price set) |
| new_price | Decimal.t() | Yes | New price for the product |
| changed_at | DateTime.t() | Yes | UTC timestamp of price change |

**Validation Rules**:
- `product_id` must exist in Catalog
- `new_price` must be > 0
- `old_price` may be nil (for initial price)

---

### ItemArchiveRequested

**Stream**: `cart-{cart_id}`  
**Purpose**: Signals that a cart item should be archived due to price change

```elixir
defmodule Epoch.Cart.Events.ItemArchiveRequested do
  @type t :: %__MODULE__{
    cart_id: String.t(),
    product_id: String.t(),
    item_id: String.t(),
    reason: String.t(),
    requested_at: DateTime.t()
  }
  
  @enforce_keys [:cart_id, :product_id, :item_id, :reason, :requested_at]
  defstruct [:cart_id, :product_id, :item_id, :reason, :requested_at]
end
```

**Field Details**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| cart_id | String.t() | Yes | Cart/session identifier |
| product_id | String.t() | Yes | Product that triggered the archive request |
| item_id | String.t() | Yes | Unique item identifier in cart |
| reason | String.t() | Yes | Why archival requested (e.g., "price_changed") |
| requested_at | DateTime.t() | Yes | UTC timestamp of request |

**Validation Rules**:
- `cart_id` must reference existing cart stream
- `item_id` must exist in cart (not already archived/removed)
- `reason` must be non-empty string

---

### ItemArchived (Extended)

**Stream**: `cart-{cart_id}`  
**Purpose**: Records that a cart item has been archived  
**Note**: This event already exists from feature 013; extending with additional fields

```elixir
defmodule Epoch.Cart.Events.ItemArchived do
  @type t :: %__MODULE__{
    cart_id: String.t(),
    item_id: String.t(),
    reason: String.t() | nil,
    archived_at: DateTime.t()
  }
  
  @enforce_keys [:cart_id, :item_id, :archived_at]
  defstruct [:cart_id, :item_id, :reason, :archived_at]
end
```

**Field Changes from Feature 013**:
| Field | Change | Description |
|-------|--------|-------------|
| cart_id | Added | Explicit cart identifier for read model processing |
| reason | Added | Why item was archived (optional, for tracking) |

---

## Read Models

### ProductsWithPriceChanges

**Purpose**: Tracks products that have had price changes for automation triggering

```elixir
defmodule Epoch.Backoffice.ProductsWithPriceChanges do
  @type product_price :: %{
    product_id: String.t(),
    old_price: Decimal.t() | nil,
    new_price: Decimal.t(),
    last_changed_at: DateTime.t()
  }
  
  @type state :: %{
    products: %{String.t() => product_price()}
  }
  
  def initial_state, do: %{products: %{}}
  
  def evolve(state, %PriceChanged{} = event) do
    product = %{
      product_id: event.product_id,
      old_price: event.old_price,
      new_price: event.new_price,
      last_changed_at: event.changed_at
    }
    %{state | products: Map.put(state.products, event.product_id, product)}
  end
  
  def evolve(state, _), do: state
end
```

**Query Operations**:
| Operation | Signature | Description |
|-----------|-----------|-------------|
| get_product | `get_product(state, product_id) :: product_price \| nil` | Get price change for specific product |
| all_products | `all_products(state) :: [product_price]` | List all products with price changes |
| changed_since | `changed_since(state, datetime) :: [product_price]` | Products changed after timestamp |

**Build Pattern**:
```elixir
# Build from all price streams
{:ok, %{events: events}} = EventStore.read_by_stream_type("price")
state = events |> Enum.map(& &1.event) |> Enum.reduce(initial_state(), &evolve(&2, &1))
```

---

### CartsWithProducts

**Purpose**: Tracks which carts contain which products for affected cart identification

```elixir
defmodule Epoch.Cart.CartsWithProducts do
  @type mapping :: %{
    cart_id: String.t(),
    product_id: String.t(),
    item_id: String.t()
  }
  
  @type state :: %{
    mappings: [mapping()],
    by_product: %{String.t() => [mapping()]},  # Index for efficient lookup
    by_cart: %{String.t() => [mapping()]}      # Index for efficient lookup
  }
  
  def initial_state do
    %{mappings: [], by_product: %{}, by_cart: %{}}
  end
  
  def evolve(state, %ItemAdded{cart_id: cart_id, product_id: product_id, item_id: item_id}) do
    mapping = %{cart_id: cart_id, product_id: product_id, item_id: item_id}
    
    %{state |
      mappings: [mapping | state.mappings],
      by_product: Map.update(state.by_product, product_id, [mapping], &[mapping | &1]),
      by_cart: Map.update(state.by_cart, cart_id, [mapping], &[mapping | &1])
    }
  end
  
  def evolve(state, %ItemRemoved{item_id: item_id}) do
    remove_item(state, item_id)
  end
  
  def evolve(state, %ItemArchived{item_id: item_id}) do
    remove_item(state, item_id)
  end
  
  def evolve(state, %CartCleared{cart_id: cart_id}) do
    items_to_remove = Map.get(state.by_cart, cart_id, [])
    Enum.reduce(items_to_remove, state, fn m, acc -> remove_item(acc, m.item_id) end)
  end
  
  def evolve(state, _), do: state
  
  defp remove_item(state, item_id) do
    mapping = Enum.find(state.mappings, &(&1.item_id == item_id))
    case mapping do
      nil -> state
      m ->
        %{state |
          mappings: Enum.reject(state.mappings, &(&1.item_id == item_id)),
          by_product: Map.update(state.by_product, m.product_id, [], &Enum.reject(&1, fn x -> x.item_id == item_id end)),
          by_cart: Map.update(state.by_cart, m.cart_id, [], &Enum.reject(&1, fn x -> x.item_id == item_id end))
        }
    end
  end
end
```

**Query Operations**:
| Operation | Signature | Description |
|-----------|-----------|-------------|
| carts_with_product | `carts_with_product(state, product_id) :: [cart_id]` | All carts containing product |
| products_in_cart | `products_in_cart(state, cart_id) :: [mapping]` | All products in a cart |
| item_exists? | `item_exists?(state, item_id) :: boolean` | Check if item still in any cart |

**Build Pattern**:
```elixir
# Build from all cart streams
{:ok, %{events: events}} = EventStore.read_by_stream_type("cart")
state = events |> Enum.map(& &1.event) |> Enum.reduce(initial_state(), &evolve(&2, &1))
```

**Note on ItemAdded**: The `ItemAdded` event needs `cart_id` field added for this read model to work correctly.

---

### ItemsToArchive (TODO List)

**Purpose**: Tracks items pending archive completion

```elixir
defmodule Epoch.Cart.ItemsToArchive do
  @type todo_item :: %{
    cart_id: String.t(),
    product_id: String.t(),
    item_id: String.t(),
    reason: String.t(),
    requested_at: DateTime.t()
  }
  
  @type state :: %{
    pending: [todo_item()]
  }
  
  def initial_state, do: %{pending: []}
  
  def evolve(state, %ItemArchiveRequested{} = event) do
    # Idempotency: only add if not already pending
    case Enum.find(state.pending, &(&1.item_id == event.item_id)) do
      nil ->
        item = %{
          cart_id: event.cart_id,
          product_id: event.product_id,
          item_id: event.item_id,
          reason: event.reason,
          requested_at: event.requested_at
        }
        %{state | pending: [item | state.pending]}
      _ -> state
    end
  end
  
  def evolve(state, %ItemArchived{item_id: item_id}) do
    %{state | pending: Enum.reject(state.pending, &(&1.item_id == item_id))}
  end
  
  def evolve(state, _), do: state
end
```

**Query Operations**:
| Operation | Signature | Description |
|-----------|-----------|-------------|
| all_pending | `all_pending(state) :: [todo_item]` | All items awaiting archive |
| pending_for_cart | `pending_for_cart(state, cart_id) :: [todo_item]` | Pending items in specific cart |
| pending_count | `pending_count(state) :: non_neg_integer` | Count of pending items |
| is_pending? | `is_pending?(state, item_id) :: boolean` | Check if item is pending |

**Build Pattern**:
```elixir
# Build from all cart streams
{:ok, %{events: events}} = EventStore.read_by_stream_type("cart")
state = events |> Enum.map(& &1.event) |> Enum.reduce(initial_state(), &evolve(&2, &1))
```

---

## Commands

### ChangePrice

**Purpose**: Change the price of a product

```elixir
defmodule Epoch.Backoffice.Commands.ChangePrice do
  @type t :: %__MODULE__{
    product_id: String.t(),
    new_price: Decimal.t()
  }
  
  @enforce_keys [:product_id, :new_price]
  defstruct [:product_id, :new_price]
end
```

**Handler Behavior**:
1. Validate product exists in Catalog
2. Validate new_price > 0
3. Get current price (if any) for old_price field
4. Emit PriceChanged event to `price-{product_id}` stream
5. Return `{:ok, event}` or `{:error, reason}`

**Possible Errors**:
| Error | Condition |
|-------|-----------|
| `:product_not_found` | Product ID doesn't exist in Catalog |
| `:invalid_price` | New price <= 0 |

---

### RequestToArchiveItem

**Purpose**: Request that a cart item be archived (triggered by automation)

```elixir
defmodule Epoch.Cart.Commands.RequestToArchiveItem do
  @type t :: %__MODULE__{
    cart_id: String.t(),
    product_id: String.t(),
    item_id: String.t(),
    reason: String.t()
  }
  
  @enforce_keys [:cart_id, :product_id, :item_id, :reason]
  defstruct [:cart_id, :product_id, :item_id, :reason]
end
```

**Handler Behavior**:
1. Check if item already has pending archive request (idempotency)
2. Check if item exists and not already archived
3. Emit ItemArchiveRequested event to `cart-{cart_id}` stream
4. Return `{:ok, event}` or `{:error, reason}`

**Possible Errors**:
| Error | Condition |
|-------|-----------|
| `:already_requested` | ItemArchiveRequested already exists for item_id |
| `:item_not_found` | Item doesn't exist in cart |
| `:already_archived` | Item was already archived |

---

### ArchiveItem (Existing from Feature 013)

**Purpose**: Actually archive a cart item (complete the TODO)

```elixir
defmodule Epoch.Cart.Commands.ArchiveItem do
  @type t :: %__MODULE__{
    cart_id: String.t(),
    item_id: String.t(),
    reason: String.t() | nil
  }
  
  @enforce_keys [:cart_id, :item_id]
  defstruct [:cart_id, :item_id, :reason]
end
```

**Handler Behavior**:
1. Validate item exists in cart
2. Emit ItemArchived event to `cart-{cart_id}` stream
3. Return `{:ok, event}` or `{:error, reason}`

**Note**: May already exist from feature 013; extend as needed.

---

## State Transitions

### Cart Item Lifecycle (with Price Change)

```
[ItemAdded]
    │
    ▼
  Active ────────────────────────┐
    │                            │
    │ (price changes)            │ (user removes)
    ▼                            ▼
[ItemArchiveRequested]      [ItemRemoved]
    │                            │
    ▼                            ▼
  Pending Archive            Removed
    │
    │ (automation processes)
    ▼
[ItemArchived]
    │
    ▼
  Archived
```

### Price Change Processing Flow

```
[PriceChanged]
    │
    ▼
PriceChangeProcessor
    │
    ├─────────────────────────────────┐
    │ (for each affected cart item)   │
    ▼                                 │
[ItemArchiveRequested]                │
    │                                 │
    ▼                                 │
ItemsToArchive (TODO added)           │
    │                                 │
    ▼                                 │
ArchiveProcessor                      │
    │                                 │
    ▼                                 │
[ItemArchived]                        │
    │                                 │
    ├─► ItemsToArchive (TODO removed) │
    │                                 │
    └─► CartsWithProducts (mapping removed)
    │
    └─► CartItemsView (item removed from display)
```

---

## Stream Naming

| Entity | Stream Pattern | Example |
|--------|----------------|---------|
| Price changes | `price-{product_id}` | `price-espresso-blend` |
| Cart events | `cart-{cart_id}` | `cart-abc123` |

---

## Event Field Requirements Summary

### New/Modified Events

| Event | Field | Status | Notes |
|-------|-------|--------|-------|
| PriceChanged | product_id | New | Required |
| PriceChanged | old_price | New | Optional (nil for first price) |
| PriceChanged | new_price | New | Required, > 0 |
| PriceChanged | changed_at | New | Required, UTC timestamp |
| ItemArchiveRequested | cart_id | New | Required |
| ItemArchiveRequested | product_id | New | Required |
| ItemArchiveRequested | item_id | New | Required |
| ItemArchiveRequested | reason | New | Required |
| ItemArchiveRequested | requested_at | New | Required |
| ItemArchived | cart_id | Added | Required (was implicit) |
| ItemArchived | reason | Added | Optional |
| ItemAdded | cart_id | Added | Required (was implicit) |
| ItemRemoved | cart_id | Added | Required (was implicit) |
| CartCleared | cart_id | Added | Required (was implicit) |

---

## Index Requirements (Future Optimization)

For efficient querying at scale, the following indexes would be beneficial:

| Read Model | Index | Purpose |
|------------|-------|---------|
| CartsWithProducts | `by_product[product_id] -> [cart_id]` | Find affected carts |
| CartsWithProducts | `by_cart[cart_id] -> [item_id]` | Clear cart operations |
| ItemsToArchive | `by_item[item_id] -> todo_item` | Idempotency checks |

Currently implemented as in-memory maps; no database indexes needed.
