defmodule EpochWeb.ProductsLive do
  @moduledoc """
  LiveView for displaying the product catalog with navigation
  and "Add Item" cart functionality.
  """
  use EpochWeb, :live_view

  alias Epoch.Catalog
  alias Epoch.Slices.AddItem

  @impl true
  def mount(_params, session, socket) do
    products = Catalog.list_products()
    # Cart session is initialized by EpochWeb.Plugs.CartSession
    cart_session_id = session["cart_session_id"]

    socket =
      socket
      |> assign(:cart_session_id, cart_session_id)
      |> assign(:products, products)

    {:ok, socket}
  end

  @impl true
  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  @doc """
  Formats a Decimal price with dollar sign and 2 decimal places.
  """
  def format_price(%Decimal{} = price) do
    "$#{Decimal.round(price, 2)}"
  end
end
