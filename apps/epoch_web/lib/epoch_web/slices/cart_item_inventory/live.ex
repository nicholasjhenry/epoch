defmodule Epoch.Slices.CartItemInventory.Live do
  @moduledoc """
  Nested LiveView for displaying inventory quantity for a cart item.

  This LiveView runs as a separate process from the parent CartItems.Live,
  enabling independent PubSub subscription to inventory updates. Each instance
  subscribes to `stream_type:inventory` and filters events by product_id.

  ## Display States

  - Normal (quantity > 5): "{quantity} available" with info styling
  - Low Stock (0 < quantity <= 5): "{quantity} available" with warning styling
  - Out of Stock (quantity == 0): "Out of stock" with danger styling
  - Unknown (fetch failed): "Unknown" with muted styling
  """
  use EpochWeb, :live_view

  alias Epoch.Backoffice.Inventory

  @low_stock_threshold 5

  @impl true
  def mount(_params, %{"product_id" => product_id}, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:inventory")
    end

    socket =
      socket
      |> assign(:product_id, product_id)
      |> load_inventory()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <span id={"inventory-#{@product_id}"} class={["tag", inventory_class(@inventory)]}>
      {inventory_text(@inventory)}
    </span>
    """
  end

  @impl true
  def handle_info({:events_appended, _stream_name, events}, socket) do
    # Filter events by product_id (matching InventoriesStateView.ts pattern)
    quantity =
      events
      |> Enum.filter(fn envelope ->
        envelope.event.product_id == socket.assigns.product_id
      end)
      |> case do
        [] ->
          # No matching events, keep current value
          socket.assigns.inventory

        matching ->
          # Get latest quantity from matching events
          List.last(matching).event.quantity
      end

    {:noreply, assign(socket, :inventory, quantity)}
  end

  defp load_inventory(socket) do
    {:ok, quantity} = Inventory.get_quantity(socket.assigns.product_id)
    assign(socket, :inventory, quantity)
  end

  defp inventory_text(:unknown), do: "Unknown"
  defp inventory_text(0), do: "Out of stock"
  defp inventory_text(quantity), do: "#{quantity} available"

  defp inventory_class(:unknown), do: "is-light"
  defp inventory_class(0), do: "is-danger"
  defp inventory_class(quantity) when quantity <= @low_stock_threshold, do: "is-warning"
  defp inventory_class(_quantity), do: "is-info"
end
