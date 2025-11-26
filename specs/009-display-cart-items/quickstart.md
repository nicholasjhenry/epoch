# Quickstart: Display Cart Items

**Feature**: 009-display-cart-items
**Date**: 2025-11-26

## Overview

This guide provides a quick reference for implementing the cart items display feature.

---

## Prerequisites

- Elixir 1.15+ installed
- Epoch application running (`mix phx.server`)
- Feature 001 (EventStore) and Feature 008 (Add Item to Cart) completed

## Quick Test

```bash
# Run existing tests to verify baseline
cd /Users/nicholas/Workspaces/professional/projects/epoch
mix test

# Start the application
mix phx.server

# Visit products page and add items
open http://localhost:4000/products

# Cart page (after implementation)
open http://localhost:4000/cart/{session_id}
```

---

## Implementation Steps

### Step 1: Define New Events

Create event structs in `apps/epoch/lib/epoch/cart/events/`:

```elixir
# item_added.ex
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

# item_removed.ex
defmodule Epoch.Cart.Events.ItemRemoved do
  @type t :: %__MODULE__{item_id: String.t(), removed_at: DateTime.t()}
  defstruct [:item_id, :removed_at]
end

# cart_cleared.ex
defmodule Epoch.Cart.Events.CartCleared do
  @type t :: %__MODULE__{cleared_at: DateTime.t()}
  defstruct [:cleared_at]
end

# item_archived.ex
defmodule Epoch.Cart.Events.ItemArchived do
  @type t :: %__MODULE__{item_id: String.t(), archived_at: DateTime.t()}
  defstruct [:item_id, :archived_at]
end
```

### Step 2: Create Cart Items View

Create `apps/epoch/lib/epoch/cart/cart_items_view.ex`:

```elixir
defmodule Epoch.Cart.CartItemsView do
  alias Epoch.Cart.Events.{ItemAdded, ItemRemoved, CartCleared, ItemArchived}

  @type cart_item :: %{item_id: String.t(), name: String.t(), price: float()}
  @type state :: %{items: [cart_item()], total: float()}

  @spec initial_state() :: state()
  def initial_state, do: %{items: [], total: 0.0}

  @spec evolve(state(), struct()) :: state()
  def evolve(state, %ItemAdded{item_id: id, name: name, price: price}) do
    item = %{item_id: id, name: name, price: price}
    %{state | items: state.items ++ [item], total: state.total + price}
  end

  def evolve(state, %ItemRemoved{item_id: id}) do
    remove_item(state, id)
  end

  def evolve(_state, %CartCleared{}) do
    initial_state()
  end

  def evolve(state, %ItemArchived{item_id: id}) do
    remove_item(state, id)
  end

  def evolve(state, _unknown_event), do: state

  defp remove_item(state, item_id) do
    case Enum.find(state.items, &(&1.item_id == item_id)) do
      nil -> state
      item ->
        items = Enum.reject(state.items, &(&1.item_id == item_id))
        %{state | items: items, total: state.total - item.price}
    end
  end

  @spec empty?(state()) :: boolean()
  def empty?(%{items: []}), do: true
  def empty?(_), do: false
end
```

### Step 3: Extend Cart Context

Add to `apps/epoch/lib/epoch/cart/cart.ex`:

```elixir
def get_cart_items(session_id) do
  stream_name = "cart-#{session_id}"
  
  case EventStore.aggregate_stream(
    stream_name,
    CartItemsView.initial_state(),
    &CartItemsView.evolve/2
  ) do
    {:ok, state, _version} -> {:ok, state}
    {:error, reason} -> {:error, reason}
  end
end
```

### Step 4: Create Cart LiveView

Create `apps/epoch_web/lib/epoch_web/live/cart_live.ex`:

```elixir
defmodule EpochWeb.CartLive do
  use EpochWeb, :live_view
  alias Epoch.Cart

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    socket =
      socket
      |> assign(:session_id, session_id)
      |> load_cart_items()

    {:ok, socket}
  end

  defp load_cart_items(socket) do
    case Cart.get_cart_items(socket.assigns.session_id) do
      {:ok, state} ->
        socket
        |> assign(:cart_items, state.items)
        |> assign(:cart_total, state.total)
        |> assign(:cart_empty?, state.items == [])

      {:error, _} ->
        socket
        |> assign(:cart_items, [])
        |> assign(:cart_total, 0.0)
        |> assign(:cart_empty?, true)
    end
  end

  defp format_price(price) do
    "$#{:erlang.float_to_binary(price * 1.0, decimals: 2)}"
  end
end
```

### Step 5: Create Cart Template

Create `apps/epoch_web/lib/epoch_web/live/cart_live.html.heex`:

```heex
<div id="cart" class="box">
  <h3 class="title is-4">Shopping Cart</h3>

  <%= if @cart_empty? do %>
    <div id="cart-empty" class="notification is-light">
      Your cart is empty
    </div>
  <% else %>
    <div class="table-container">
      <table id="cart-items" class="table is-fullwidth is-striped">
        <thead>
          <tr>
            <th>Product</th>
            <th>Price</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @cart_items} id={"cart-item-#{item.item_id}"}>
            <td id={"cart-item-name-#{item.item_id}"}>{item.name}</td>
            <td id={"cart-item-price-#{item.item_id}"}>{format_price(item.price)}</td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th class="has-text-right">Total:</th>
            <th id="cart-total">{format_price(@cart_total)}</th>
          </tr>
        </tfoot>
      </table>
    </div>
  <% end %>
</div>
```

### Step 6: Add Route

In `apps/epoch_web/lib/epoch_web/router.ex`:

```elixir
scope "/", EpochWeb do
  pipe_through :browser

  # ... existing routes ...
  live "/cart/:session_id", CartLive
end
```

---

## Testing Quick Reference

### Unit Tests (CartItemsView)

```elixir
# apps/epoch/test/epoch/cart/cart_items_view_test.exs

describe "evolve/2" do
  test "adds item on ItemAdded event"
  test "removes item on ItemRemoved event"
  test "clears all items on CartCleared event"
  test "removes item on ItemArchived event"
  test "ignores unknown events"
end

describe "total calculation" do
  test "sums all item prices"
  test "returns 0.0 for empty cart"
end
```

### Integration Tests (CartLive)

```elixir
# apps/epoch_web/test/epoch_web/live/cart_live_test.exs

describe "mount" do
  test "displays empty cart message when no items"
  test "displays items when cart has items"
  test "displays correct total"
end

describe "item display" do
  test "shows item name"
  test "shows formatted price"
end
```

---

## Common Patterns

### Currency Formatting

```elixir
defp format_price(price) when is_number(price) do
  "$#{:erlang.float_to_binary(price * 1.0, decimals: 2)}"
end
```

### Stream Name Construction

```elixir
def stream_name(session_id), do: "cart-#{session_id}"
```

### Empty State Check

```elixir
<%= if @cart_empty? do %>
  <!-- empty state -->
<% else %>
  <!-- items table -->
<% end %>
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cart shows empty despite adding items | Check session_id matches between ProductsLive and CartLive |
| Prices show as integers | Ensure `price * 1.0` in format_price for float conversion |
| Events not projecting | Verify event struct names match in evolve pattern matches |
| Route not found | Run `mix phx.routes` to verify route registration |

---

## Files Changed Summary

| File | Change |
|------|--------|
| `apps/epoch/lib/epoch/cart/events/item_added.ex` | New |
| `apps/epoch/lib/epoch/cart/events/item_removed.ex` | New |
| `apps/epoch/lib/epoch/cart/events/cart_cleared.ex` | New |
| `apps/epoch/lib/epoch/cart/events/item_archived.ex` | New |
| `apps/epoch/lib/epoch/cart/cart_items_view.ex` | New |
| `apps/epoch/lib/epoch/cart/cart.ex` | Extended |
| `apps/epoch_web/lib/epoch_web/live/cart_live.ex` | New |
| `apps/epoch_web/lib/epoch_web/live/cart_live.html.heex` | New |
| `apps/epoch_web/lib/epoch_web/router.ex` | Modified |
| `apps/epoch/test/epoch/cart/cart_items_view_test.exs` | New |
| `apps/epoch_web/test/epoch_web/live/cart_live_test.exs` | New |
