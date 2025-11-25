defmodule Epoch.Slices.AddItem.Component do
  @moduledoc """
  LiveComponent for the "Add Item" button that adds a product to the cart
  and navigates to the cart page.
  """
  use EpochWeb, :live_component

  alias Epoch.Cart

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
    Cart.add_item(socket.assigns.cart_session_id, socket.assigns.product_id)
    {:noreply, push_navigate(socket, to: "/cart")}
  end
end
