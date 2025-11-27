# Data Model: Update Product Inventory

**Feature**: 012-update-inventory  
**Date**: 2025-11-27

## Overview

Data structures for inventory management using event sourcing. Events are persisted to the in-memory EventStore and state is reconstructed by folding events. All inventory management is namespaced under `Backoffice`.

## Events

### InventoryUpdated

Represents a change to a product's inventory quantity.

```elixir
defmodule Epoch.Backoffice.Events.InventoryUpdated do
  @moduledoc """
  Event emitted when a product's inventory quantity is updated.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          quantity: non_neg_integer(),
          updated_at: DateTime.t()
        }

  defstruct [:product_id, :quantity, :updated_at]
end
```

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `product_id` | `String.t()` | Product identifier (e.g., "espresso-blend") |
| `quantity` | `non_neg_integer()` | New inventory quantity (0 or greater) |
| `updated_at` | `DateTime.t()` | Timestamp when update occurred |

**Stream**: `"inventory-{product_id}"` (one stream per product)

## Aggregate State

### InventoryState

Represents the current inventory state for a single product, reconstructed from events.

```elixir
defmodule Epoch.Backoffice.InventoryState do
  @moduledoc """
  Aggregate state for product inventory.
  """

  @type t :: %__MODULE__{
          product_id: String.t() | nil,
          quantity: non_neg_integer()
        }

  defstruct product_id: nil, quantity: 0

  @doc """
  Returns initial state for inventory aggregation.
  """
  @spec initial_state() :: t()
  def initial_state, do: %__MODULE__{}

  @doc """
  Evolves inventory state by applying an event.
  """
  @spec evolve(t(), Epoch.Backoffice.Events.InventoryUpdated.t()) :: t()
  def evolve(_state, %Epoch.Backoffice.Events.InventoryUpdated{} = event) do
    %__MODULE__{
      product_id: event.product_id,
      quantity: event.quantity
    }
  end
end
```

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `product_id` | `String.t() \| nil` | Product identifier (nil for initial state) |
| `quantity` | `non_neg_integer()` | Current inventory quantity (defaults to 0) |

## Entity Relationships

```text
┌─────────────────┐         ┌─────────────────────┐
│     Product     │◄────────│   InventoryState    │
│  (Catalog ctx)  │         │  (Backoffice ctx)   │
├─────────────────┤         ├─────────────────────┤
│ product_id (PK) │         │ product_id (FK)     │
│ name            │         │ quantity            │
│ description     │         └─────────────────────┘
│ price           │                   ▲
└─────────────────┘                   │ reconstructed from
                                      │
                           ┌─────────────────────┐
                           │  InventoryUpdated   │
                           │      (Event)        │
                           ├─────────────────────┤
                           │ product_id          │
                           │ quantity            │
                           │ updated_at          │
                           └─────────────────────┘
```

## Validation Rules

1. **product_id**: Must reference an existing product in Catalog
   - Validated via `Catalog.get_product/1` before event creation
   - Error: `{:error, :not_found}`

2. **quantity**: Must be a non-negative integer
   - Validated in context before event creation
   - Accepts: 0, 1, 2, ... (any non-negative integer)
   - Rejects: -1, 1.5, "ten", nil
   - Error: `{:error, :invalid_quantity}`

## State Transitions

```text
┌─────────────────┐    InventoryUpdated     ┌─────────────────┐
│  No inventory   │ ────────────────────────► │  Has inventory  │
│  (quantity: 0)  │    {product_id, qty}     │  (quantity: N)  │
└─────────────────┘                          └─────────────────┘
        ▲                                            │
        │                                            │
        │         InventoryUpdated                   │
        │         {product_id, 0}                    │
        └────────────────────────────────────────────┘
                  InventoryUpdated
                  {product_id, M}
```

Note: Each `InventoryUpdated` event sets the absolute quantity, not a delta. This simplifies state reconstruction - the latest event's quantity is the current quantity.

## Read Model Integration

For displaying inventory alongside products (FR-007), the Backoffice.Inventory context provides:

```elixir
@spec get_quantity(String.t()) :: {:ok, non_neg_integer()}
def get_quantity(product_id)
```

Products without inventory events return `{:ok, 0}` per FR-006.

For bulk retrieval (product listing with inventory), consider:

```elixir
@spec get_quantities([String.t()]) :: {:ok, %{String.t() => non_neg_integer()}}
def get_quantities(product_ids)
```

This allows efficient batch loading to avoid N+1 queries when displaying product listings.
