# Read Model Contracts: Price Change Automation

**Feature**: 014-price-change-automation  
**Date**: 2025-12-01

## Overview

This document defines the read model contracts for the price change automation feature. Read models are projections of events optimized for querying.

---

## ProductsWithPriceChanges

**Module**: `Epoch.Backoffice.ProductsWithPriceChanges`  
**Purpose**: Track products that have had price changes  
**Input Events**: `PriceChanged`  
**Source Streams**: `price-*`

### State Schema

```elixir
@type product_price :: %{
  product_id: String.t(),
  old_price: Decimal.t() | nil,
  new_price: Decimal.t(),
  last_changed_at: DateTime.t()
}

@type state :: %{
  products: %{String.t() => product_price()}
}
```

### Query Interface

```elixir
@doc "Get price change info for specific product"
@spec get_product(state(), String.t()) :: product_price() | nil

@doc "List all products with price changes"
@spec all_products(state()) :: [product_price()]

@doc "Get products changed after a specific timestamp"
@spec changed_since(state(), DateTime.t()) :: [product_price()]

@doc "Check if product has had price changes"
@spec has_price_changes?(state(), String.t()) :: boolean()
```

### Example Queries

```elixir
# Get current price info for a product
ProductsWithPriceChanges.get_product(state, "espresso-blend")
# => %{product_id: "espresso-blend", old_price: Decimal.new("14.99"), 
#      new_price: Decimal.new("15.99"), last_changed_at: ~U[2025-12-01 10:30:00Z]}

# Get all products with price changes
ProductsWithPriceChanges.all_products(state)
# => [%{product_id: "espresso-blend", ...}, %{product_id: "french-roast", ...}]
```

### Build Pattern

```elixir
def build do
  {:ok, %{events: events}} = EventStore.read_by_stream_type("price")
  events
  |> Enum.map(& &1.event)
  |> Enum.reduce(initial_state(), &evolve(&2, &1))
end
```

---

## CartsWithProducts

**Module**: `Epoch.Cart.CartsWithProducts`  
**Purpose**: Track which carts contain which products for affected cart lookup  
**Input Events**: `ItemAdded`, `ItemRemoved`, `CartCleared`, `ItemArchived`  
**Source Streams**: `cart-*`

### State Schema

```elixir
@type mapping :: %{
  cart_id: String.t(),
  product_id: String.t(),
  item_id: String.t()
}

@type state :: %{
  mappings: [mapping()],
  by_product: %{String.t() => [mapping()]},
  by_cart: %{String.t() => [mapping()]}
}
```

### Query Interface

```elixir
@doc "Find all carts containing a specific product"
@spec carts_with_product(state(), String.t()) :: [String.t()]

@doc "Get all product mappings for a cart"
@spec products_in_cart(state(), String.t()) :: [mapping()]

@doc "Get all items for a specific product across all carts"
@spec items_for_product(state(), String.t()) :: [mapping()]

@doc "Check if an item exists in any cart"
@spec item_exists?(state(), String.t()) :: boolean()

@doc "Count total items across all carts"
@spec total_items(state()) :: non_neg_integer()
```

### Example Queries

```elixir
# Find all carts with espresso-blend
CartsWithProducts.carts_with_product(state, "espresso-blend")
# => ["session-123", "session-456", "session-789"]

# Get all items for a product (for archive requests)
CartsWithProducts.items_for_product(state, "espresso-blend")
# => [
#   %{cart_id: "session-123", product_id: "espresso-blend", item_id: "espresso-blend-123"},
#   %{cart_id: "session-456", product_id: "espresso-blend", item_id: "espresso-blend-456"}
# ]

# Get products in a specific cart
CartsWithProducts.products_in_cart(state, "session-123")
# => [
#   %{cart_id: "session-123", product_id: "espresso-blend", item_id: "espresso-blend-123"},
#   %{cart_id: "session-123", product_id: "french-roast", item_id: "french-roast-789"}
# ]
```

### Build Pattern

```elixir
def build do
  {:ok, %{events: events}} = EventStore.read_by_stream_type("cart")
  events
  |> Enum.map(& &1.event)
  |> Enum.reduce(initial_state(), &evolve(&2, &1))
end
```

### Event Evolution

| Event | Action |
|-------|--------|
| `ItemAdded` | Add mapping to state |
| `ItemRemoved` | Remove mapping by item_id |
| `ItemArchived` | Remove mapping by item_id |
| `CartCleared` | Remove all mappings for cart_id |

---

## ItemsToArchive (TODO List)

**Module**: `Epoch.Cart.ItemsToArchive`  
**Purpose**: Track items pending archive completion  
**Input Events**: `ItemArchiveRequested`, `ItemArchived`  
**Source Streams**: `cart-*`

### State Schema

```elixir
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
```

### Query Interface

```elixir
@doc "Get all items pending archive"
@spec all_pending(state()) :: [todo_item()]

@doc "Get pending items for a specific cart"
@spec pending_for_cart(state(), String.t()) :: [todo_item()]

@doc "Get pending items for a specific product"
@spec pending_for_product(state(), String.t()) :: [todo_item()]

@doc "Check if a specific item is pending archive"
@spec is_pending?(state(), String.t()) :: boolean()

@doc "Count of pending items"
@spec pending_count(state()) :: non_neg_integer()

@doc "Get oldest pending item (for processing order)"
@spec oldest_pending(state()) :: todo_item() | nil
```

### Example Queries

```elixir
# Get all pending archive requests
ItemsToArchive.all_pending(state)
# => [
#   %{cart_id: "session-123", product_id: "espresso-blend", 
#     item_id: "espresso-blend-123", reason: "price_changed",
#     requested_at: ~U[2025-12-01 10:31:00Z]},
#   %{cart_id: "session-456", product_id: "espresso-blend",
#     item_id: "espresso-blend-456", reason: "price_changed",
#     requested_at: ~U[2025-12-01 10:31:01Z]}
# ]

# Check if specific item is pending
ItemsToArchive.is_pending?(state, "espresso-blend-123")
# => true

# Get count for monitoring
ItemsToArchive.pending_count(state)
# => 2
```

### Build Pattern

```elixir
def build do
  {:ok, %{events: events}} = EventStore.read_by_stream_type("cart")
  events
  |> Enum.map(& &1.event)
  |> Enum.reduce(initial_state(), &evolve(&2, &1))
end
```

### Event Evolution

| Event | Action |
|-------|--------|
| `ItemArchiveRequested` | Add to pending (idempotent - skip if already pending) |
| `ItemArchived` | Remove from pending by item_id |

---

## Read Model Lifecycle

```
System Startup
    │
    ▼
Build read models from event streams
    │
    ├── ProductsWithPriceChanges.build()
    ├── CartsWithProducts.build()
    └── ItemsToArchive.build()
    │
    ▼
Subscribe to PubSub for updates
    │
    ├── stream_type:price → ProductsWithPriceChanges
    └── stream_type:cart → CartsWithProducts, ItemsToArchive
    │
    ▼
Process incoming events
    │
    ├── evolve(state, event)
    └── Update in-memory state
```

---

## Consistency Model

All read models are **eventually consistent**:

1. Events are persisted to EventStore first (source of truth)
2. Read models are updated after successful persistence
3. On restart, read models are rebuilt from event streams
4. No data loss as long as EventStore is available

### Staleness Window

| Scenario | Max Staleness |
|----------|---------------|
| Normal operation | ~10ms (PubSub latency) |
| High load | ~100ms (processing queue) |
| After restart | 0 (rebuilt from events) |

---

## Memory Considerations

Read models are held in memory. Estimated sizes:

| Read Model | Memory per Item | Expected Items | Total Memory |
|------------|-----------------|----------------|--------------|
| ProductsWithPriceChanges | ~200 bytes | 5 products | ~1 KB |
| CartsWithProducts | ~150 bytes | 100 items | ~15 KB |
| ItemsToArchive | ~200 bytes | 10 pending | ~2 KB |

Total expected memory: < 20 KB (negligible for current scale)

---

## Testing Read Models

Each read model should be tested with:

1. **Evolution tests**: Verify each event type is handled correctly
2. **Projection tests**: Build from event sequence, verify final state
3. **Query tests**: Verify each query function returns correct results
4. **Idempotency tests**: Same event applied twice produces same state

### Example Test Structure

```elixir
defmodule Epoch.Cart.ItemsToArchiveTest do
  use ExUnit.Case
  
  alias Epoch.Cart.ItemsToArchive
  alias Epoch.Cart.Events.{ItemArchiveRequested, ItemArchived}
  
  describe "evolve/2 with ItemArchiveRequested" do
    test "adds item to pending list" do
      state = ItemsToArchive.initial_state()
      event = %ItemArchiveRequested{...}
      
      new_state = ItemsToArchive.evolve(state, event)
      
      assert length(new_state.pending) == 1
    end
    
    test "is idempotent for same item_id" do
      state = ItemsToArchive.initial_state()
      event = %ItemArchiveRequested{item_id: "item-1", ...}
      
      state = ItemsToArchive.evolve(state, event)
      state = ItemsToArchive.evolve(state, event)
      
      assert length(state.pending) == 1
    end
  end
  
  describe "evolve/2 with ItemArchived" do
    test "removes item from pending list" do
      state = %{pending: [%{item_id: "item-1", ...}]}
      event = %ItemArchived{item_id: "item-1", ...}
      
      new_state = ItemsToArchive.evolve(state, event)
      
      assert new_state.pending == []
    end
  end
end
```
