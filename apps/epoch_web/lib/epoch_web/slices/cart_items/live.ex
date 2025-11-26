defmodule Epoch.Slices.CartItems.Live do
  @moduledoc """
  Nested LiveView for displaying cart items.

  This LiveView manages its own PubSub subscription to receive real-time
  updates when items are added or removed from the cart. It runs as a
  separate process from the parent CartLive, enabling independent state
  management following vertical-slice architecture.
  """
  use EpochWeb, :live_view

  alias Epoch.Cart

  @impl true
  def mount(_params, %{"session_id" => session_id}, socket) do
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
  def render(assigns) do
    ~H"""
    <div id="cart-items-container">
      <.flash id="flash-error-cart-items" kind={:error} flash={@flash} />
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
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @cart_items} id={"cart-item-#{item.item_id}"}>
                <td id={"cart-item-name-#{item.item_id}"}>{item.name}</td>
                <td id={"cart-item-price-#{item.item_id}"}>{format_price(item.price)}</td>
                <td>
                  <.live_component
                    module={Epoch.Slices.RemoveItem.Component}
                    id={"remove-component-#{item.item_id}"}
                    item_id={item.item_id}
                    item_name={item.name}
                    cart_session_id={@cart_session_id}
                  />
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th class="has-text-right">Total:</th>
                <th id="cart-total">{format_price(@cart_total)}</th>
                <th></th>
              </tr>
            </tfoot>
          </table>
        </div>
        <div class="level mt-4">
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
    </div>
    """
  end

  @impl true
  def handle_info({:events_appended, stream_name, _events}, socket) do
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
