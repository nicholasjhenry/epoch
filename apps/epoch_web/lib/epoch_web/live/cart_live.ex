defmodule EpochWeb.CartLive do
  @moduledoc """
  LiveView for displaying shopping cart items.

  Projects cart events into a displayable state showing item names,
  prices, and cart total. Subscribes to PubSub for real-time updates
  when items are added or removed.
  """
  use EpochWeb, :live_view

  alias Epoch.Cart

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:cart")
    end

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:cart_session_id, session_id)
      |> load_cart_items()

    {:ok, socket}
  end

  @impl true
  def handle_info({:events_appended, stream_name, _events}, socket) do
    # Only reload if the event is for this cart session
    if stream_name == "cart-#{socket.assigns.session_id}" do
      {:noreply, load_cart_items(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:flash, level, message}, socket) do
    {:noreply, put_flash(socket, level, message)}
  end

  defp load_cart_items(socket) do
    {:ok, state} = Cart.get_cart_items(socket.assigns.session_id)

    socket
    |> assign(:cart_items, state.items)
    |> assign(:cart_total, state.total)
    |> assign(:cart_empty?, state.items == [])
  end

  @doc """
  Formats a price value as USD currency with 2 decimal places.
  """
  def format_price(price) when is_number(price) do
    "$#{:erlang.float_to_binary(price * 1.0, decimals: 2)}"
  end
end
