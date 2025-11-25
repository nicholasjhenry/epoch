defmodule EpochWeb.ProductsLive do
  @moduledoc """
  LiveView for displaying the product catalog with navigation
  and "Add Item" cart functionality.
  """
  use EpochWeb, :live_view

  alias Epoch.Catalog
  alias Epoch.Slices.AddItem

  @impl true
  def mount(_params, _session, socket) do
    session_id = Ecto.UUID.generate()
    Epoch.Cart.create_session(session_id)
    products = Catalog.list_products()

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:cart_session_id, session_id)}
  end

  @doc """
  Formats a Decimal price with dollar sign and 2 decimal places.
  """
  def format_price(%Decimal{} = price) do
    "$#{Decimal.round(price, 2)}"
  end
end
