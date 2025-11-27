defmodule EpochWeb.Backoffice.InventoryLive do
  use EpochWeb, :live_view

  alias Epoch.Backoffice.Inventory

  def mount(_params, _session, socket) do
    form = to_form(%{"product_id" => "", "quantity" => ""})
    {:ok, assign(socket, form: form, result: nil)}
  end

  def handle_event("save", %{"product_id" => product_id, "quantity" => qty_str}, socket) do
    result =
      case Integer.parse(qty_str) do
        {quantity, ""} ->
          Inventory.update_quantity(product_id, quantity)

        _ ->
          {:error, :invalid_quantity}
      end

    {:noreply, assign(socket, result: result)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-8 p-6">
      <h1 class="text-2xl font-bold mb-6">Update Inventory</h1>

      <.form for={@form} phx-submit="save" id="inventory-form" class="space-y-4">
        <div>
          <label for="product_id" class="block text-sm font-medium mb-1">Product ID</label>
          <input
            type="text"
            name="product_id"
            id="product_id"
            value={@form[:product_id].value}
            class="w-full px-3 py-2 border rounded-md"
            placeholder="e.g., espresso-blend"
            required
          />
        </div>

        <div>
          <label for="quantity" class="block text-sm font-medium mb-1">Quantity</label>
          <input
            type="number"
            name="quantity"
            id="quantity"
            value={@form[:quantity].value}
            class="w-full px-3 py-2 border rounded-md"
            min="0"
            placeholder="e.g., 50"
            required
          />
        </div>

        <button
          type="submit"
          class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700"
        >
          Update Inventory
        </button>
      </.form>

      <%= if @result do %>
        <div class="mt-6" id="result-message">
          <%= case @result do %>
            <% {:ok, state} -> %>
              <div class="p-4 bg-green-100 text-green-800 rounded-md">
                <p class="font-medium">Inventory updated successfully!</p>
                <p>Product: {state.product_id}</p>
                <p>Quantity: {state.quantity}</p>
              </div>
            <% {:error, :not_found} -> %>
              <div class="p-4 bg-red-100 text-red-800 rounded-md">
                <p class="font-medium">Error: Product not found</p>
              </div>
            <% {:error, :invalid_quantity} -> %>
              <div class="p-4 bg-red-100 text-red-800 rounded-md">
                <p class="font-medium">Error: Invalid quantity (must be a non-negative integer)</p>
              </div>
            <% {:error, _reason} -> %>
              <div class="p-4 bg-red-100 text-red-800 rounded-md">
                <p class="font-medium">Error: An unexpected error occurred</p>
              </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
