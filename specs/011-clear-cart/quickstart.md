# Quickstart: Clear All Items from Cart

**Feature**: 011-clear-cart
**Date**: 2025-11-26

## Prerequisites

- Elixir 1.19.2+ / OTP 28+
- Feature 009 (Cart Display) implemented
- EventStore running

## Implementation Order

### 1. Create Command Struct

**File**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/command.ex`

```elixir
defmodule Epoch.Slices.ClearCart.Command do
  @moduledoc """
  Command for clearing all items from cart.
  """

  @type t :: %__MODULE__{session_id: String.t()}

  defstruct [:session_id]
end
```

### 2. Create CommandHandler

**File**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/command_handler.ex`

Key behaviors:
- Validate cart is non-empty before emitting event
- Append `CartCleared` event to cart stream
- Return updated cart state or error

```elixir
defmodule Epoch.Slices.ClearCart.CommandHandler do
  alias Epoch.Cart
  alias Epoch.Cart.Events.CartCleared
  alias Epoch.EventStore
  alias Epoch.Slices.ClearCart.Command

  @spec handle(Command.t()) :: {:ok, Cart.CartItemsView.state()} | {:error, term()}
  def handle(%Command{} = command) do
    with {:ok, cart_state} <- Cart.get_cart_items(command.session_id),
         :ok <- validate_not_empty(cart_state) do
      event = %CartCleared{cleared_at: DateTime.utc_now()}
      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> Cart.get_cart_items(command.session_id)
        {:error, _} = error -> error
      end
    end
  end

  defp validate_not_empty(%{items: []}), do: {:error, :cart_empty}
  defp validate_not_empty(_state), do: :ok
end
```

### 3. Create LiveComponent

**File**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex`

Key behaviors:
- Render button with `phx-confirm` for confirmation dialog
- Handle click event, delegate to CommandHandler
- Send flash messages on error

```elixir
defmodule Epoch.Slices.ClearCart.Component do
  use EpochWeb, :live_component

  alias Epoch.Slices.ClearCart.Command, as: ClearCart
  alias Epoch.Slices.ClearCart.CommandHandler

  @impl true
  def render(assigns) do
    ~H"""
    <button
      id="clear-cart-button"
      class="button is-danger is-outlined"
      phx-click="clear_cart"
      phx-target={@myself}
      phx-confirm="Are you sure you want to remove all items from your cart?"
    >
      <span class="icon is-small">
        <i class="fas fa-trash-alt"></i>
      </span>
      <span>Clear Cart</span>
    </button>
    """
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    result = CommandHandler.handle(%ClearCart{session_id: socket.assigns.cart_session_id})

    case result do
      {:ok, _state} -> {:noreply, socket}
      {:error, reason} ->
        send(self(), {:flash, :error, error_message(reason)})
        {:noreply, socket}
    end
  end

  defp error_message(:cart_empty), do: "Cart is already empty"
  defp error_message(_reason), do: "Unable to clear cart. Please try again."
end
```

### 4. Integrate into CartItems.Live

**File**: `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex`

Add the ClearCart component conditionally:

```heex
<%= unless @cart_empty? do %>
  <div class="level">
    <div class="level-left"></div>
    <div class="level-right">
      <div class="level-item">
        <.live_component
          module={Epoch.Slices.ClearCart.Component}
          id="clear-cart-component"
          cart_session_id={@cart_session_id}
        />
      </div>
    </div>
  </div>
<% end %>
```

### 5. Write Tests

**File**: `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`

Test categories:
1. CommandHandler unit tests (validate empty, emit event)
2. Component rendering tests (button visibility)
3. Integration tests (click flow, UI updates)

## Verification Steps

```bash
# Run tests
mix test apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs

# Manual verification
# 1. Start server: mix phx.server
# 2. Navigate to /products
# 3. Add multiple items to cart
# 4. Navigate to cart page
# 5. Click "Clear Cart" button
# 6. Confirm in dialog
# 7. Verify empty cart state displayed
```

## Files to Create

| File | Purpose |
|------|---------|
| `apps/epoch_web/lib/epoch_web/slices/clear_cart/command.ex` | Command struct |
| `apps/epoch_web/lib/epoch_web/slices/clear_cart/command_handler.ex` | Business logic |
| `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex` | LiveComponent |
| `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs` | Tests |

## Files to Modify

| File | Change |
|------|--------|
| `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex` | Add ClearCart.Component |

## No Changes Required

- `CartCleared` event already exists
- `CartItemsView` already handles `CartCleared` event
- PubSub integration works automatically
