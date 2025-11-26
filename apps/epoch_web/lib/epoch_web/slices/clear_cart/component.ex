defmodule Epoch.Slices.ClearCart.Component do
  @moduledoc """
  LiveComponent for the "Clear Cart" button that removes all items from the cart.

  Displays a button with a confirmation dialog to prevent accidental clearing.
  """
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
      {:ok, _state} ->
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:flash, :error, error_message(reason)})
        {:noreply, socket}
    end
  end

  defp error_message(:cart_empty), do: "Cart is already empty"
  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(_reason), do: "Unable to clear cart. Please try again."
end
