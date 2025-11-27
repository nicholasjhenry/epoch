# Quickstart: Update Product Inventory

**Feature**: 012-update-inventory  
**Date**: 2025-11-27

## Prerequisites

- Elixir 1.15+ installed
- Project dependencies fetched (`mix deps.get`)
- Phoenix server running (`mix phx.server`)

## Implementation Files

### New Files to Create

1. **Event**: `apps/epoch/lib/epoch/backoffice/events/inventory_updated.ex`
2. **State**: `apps/epoch/lib/epoch/backoffice/inventory_state.ex`
3. **Context**: `apps/epoch/lib/epoch/backoffice/inventory.ex`
4. **LiveView**: `apps/epoch_web/lib/epoch_web/live/backoffice/inventory_live.ex`
5. **Tests**: `apps/epoch/test/epoch/backoffice/inventory_test.exs`
6. **LiveView Tests**: `apps/epoch_web/test/epoch_web/live/backoffice/inventory_live_test.exs`

### Files to Modify

1. **Router**: `apps/epoch_web/lib/epoch_web/router.ex` - add backoffice inventory route

## Quick Verification

### 1. Run Tests

```bash
# Run all inventory tests
mix test apps/epoch/test/epoch/backoffice/inventory_test.exs

# Run LiveView tests
mix test apps/epoch_web/test/epoch_web/live/backoffice/inventory_live_test.exs
```

### 2. Manual Testing via IEx

```elixir
# Start IEx with project
iex -S mix

# Update inventory for a product
Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 100)
# => {:ok, %Epoch.Backoffice.InventoryState{product_id: "espresso-blend", quantity: 100}}

# Get current quantity
Epoch.Backoffice.Inventory.get_quantity("espresso-blend")
# => {:ok, 100}

# Try invalid product
Epoch.Backoffice.Inventory.update_quantity("nonexistent", 50)
# => {:error, :not_found}

# Try negative quantity
Epoch.Backoffice.Inventory.update_quantity("espresso-blend", -10)
# => {:error, :invalid_quantity}
```

### 3. Manual Testing via Browser

1. Start the Phoenix server: `mix phx.server`
2. Navigate to `http://localhost:4000/backoffice/inventory`
3. Enter a product ID (e.g., "espresso-blend")
4. Enter a quantity (e.g., 50)
5. Click "Update Inventory"
6. Verify success message appears

## Key Patterns to Follow

### Event Structure

```elixir
# apps/epoch/lib/epoch/backoffice/events/inventory_updated.ex
defmodule Epoch.Backoffice.Events.InventoryUpdated do
  @type t :: %__MODULE__{
          product_id: String.t(),
          quantity: non_neg_integer(),
          updated_at: DateTime.t()
        }

  defstruct [:product_id, :quantity, :updated_at]
end
```

### Context Function

```elixir
# apps/epoch/lib/epoch/backoffice/inventory.ex
def update_quantity(product_id, quantity) when is_integer(quantity) and quantity >= 0 do
  with {:ok, _product} <- Catalog.get_product(product_id) do
    event = %Events.InventoryUpdated{
      product_id: product_id,
      quantity: quantity,
      updated_at: DateTime.utc_now()
    }

    stream = EventStore.stream_name("inventory", product_id)

    case EventStore.append_to_stream(stream, [event]) do
      {:ok, _} -> get_state(product_id)
      {:error, _} -> {:error, :persistence_failed}
    end
  end
end

def update_quantity(_product_id, _quantity), do: {:error, :invalid_quantity}
```

### LiveView Form

```elixir
# apps/epoch_web/lib/epoch_web/live/backoffice/inventory_live.ex
defmodule EpochWeb.Backoffice.InventoryLive do
  use EpochWeb, :live_view

  alias Epoch.Backoffice.Inventory

  def mount(_params, _session, socket) do
    form = to_form(%{"product_id" => "", "quantity" => ""})
    {:ok, assign(socket, form: form, result: nil)}
  end

  def handle_event("save", %{"product_id" => product_id, "quantity" => qty_str}, socket) do
    case Integer.parse(qty_str) do
      {quantity, ""} ->
        result = Inventory.update_quantity(product_id, quantity)
        {:noreply, assign(socket, result: result)}

      _ ->
        {:noreply, assign(socket, result: {:error, :invalid_quantity})}
    end
  end
end
```

## Test Pattern

```elixir
# apps/epoch/test/epoch/backoffice/inventory_test.exs
defmodule Epoch.Backoffice.InventoryTest do
  use ExUnit.Case, async: true

  alias Epoch.Backoffice.Inventory

  setup do
    start_supervised!({Epoch.EventStore, name: :"test_es_#{System.unique_integer()}"})
    :ok
  end

  describe "update_quantity/2" do
    test "updates quantity for valid product" do
      assert {:ok, state} = Inventory.update_quantity("espresso-blend", 50)
      assert state.product_id == "espresso-blend"
      assert state.quantity == 50
    end

    test "returns error for invalid product" do
      assert {:error, :not_found} = Inventory.update_quantity("nonexistent", 10)
    end

    test "returns error for negative quantity" do
      assert {:error, :invalid_quantity} = Inventory.update_quantity("espresso-blend", -5)
    end
  end
end
```

## Checklist

- [ ] Event struct created with typespec
- [ ] InventoryState with evolve/2 function
- [ ] Context module with update_quantity/2 and get_quantity/1
- [ ] LiveView with form for updating inventory
- [ ] Route added to router at `/backoffice/inventory`
- [ ] Unit tests pass
- [ ] LiveView tests pass
- [ ] Manual verification in browser works
