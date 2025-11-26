defmodule Epoch.Slices.AddItem.Component do
  @moduledoc """
  LiveComponent for the "Add Item" button that adds a product to the cart
  and navigates to the cart page.
  """
  use EpochWeb, :live_component

  alias Epoch.Slices.AddItem.Command, as: AddItem
  alias Epoch.Slices.AddItem.CommandHandler

  @impl true
  def render(assigns) do
    ~H"""
    <button
      id={"add-item-#{@product_id}"}
      class="card-footer-item button is-primary"
      phx-click="add_to_cart"
      phx-target={@myself}
    >
      Add Item
    </button>
    """
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    result =
      CommandHandler.handle(%AddItem{
        session_id: socket.assigns.cart_session_id,
        product_id: socket.assigns.product_id
      })

    case result do
      {:ok, _session} ->
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:flash, :error, error_message(reason)})
        {:noreply, socket}
    end
  end

  defp error_message(:quantity_exceed), do: "Maximum quantity of 3 items per product reached"
  defp error_message(:product_not_found), do: "Product not found"
  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(_reason), do: "Unable to add item to cart"
end
