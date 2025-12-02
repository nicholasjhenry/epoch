defmodule Epoch.Slices.SubmitCart.Component do
  @moduledoc """
  LiveComponent for the "Submit Cart" button that submits the cart for checkout.

  Validates inventory availability before submission and displays appropriate
  error messages if any products are out of stock.
  """
  use EpochWeb, :live_component

  alias Epoch.Slices.SubmitCart.Command, as: SubmitCart
  alias Epoch.Slices.SubmitCart.CommandHandler

  @impl true
  def render(assigns) do
    ~H"""
    <button
      id="submit-cart-button"
      class="button is-success"
      phx-click="submit_cart"
      phx-target={@myself}
    >
      <span class="icon is-small">
        <i class="fas fa-check"></i>
      </span>
      <span>Submit Cart</span>
    </button>
    """
  end

  @impl true
  def handle_event("submit_cart", _params, socket) do
    result = CommandHandler.handle(%SubmitCart{session_id: socket.assigns.cart_session_id})

    case result do
      {:ok, _event} ->
        send(self(), {:flash, :info, "Cart submitted successfully!"})
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:flash, :error, error_message(reason)})
        {:noreply, socket}
    end
  end

  defp error_message(:cart_empty), do: "Your cart is empty"

  defp error_message({:insufficient_inventory, _product_ids}),
    do: "Cannot order products without quantity"

  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(_reason), do: "Unable to submit cart. Please try again."
end
