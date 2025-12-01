defmodule EpochWeb.Backoffice.InventoryLive do
  use EpochWeb, :live_view

  alias Epoch.Backoffice.Inventory
  alias Epoch.Backoffice.Price
  alias Epoch.Catalog

  def mount(_params, _session, socket) do
    products = Catalog.list_products()
    inventory_form = to_form(%{"product_id" => "", "quantity" => ""})
    price_form = to_form(%{"product_id" => "", "new_price" => ""})

    {:ok,
     socket
     |> assign(:form, inventory_form)
     |> assign(:price_form, price_form)
     |> assign(:products, products)
     |> assign(:result, nil)
     |> assign(:price_result, nil)}
  end

  def handle_event("save", %{"product_id" => product_id, "quantity" => qty_str} = params, socket) do
    result =
      case Integer.parse(qty_str) do
        {quantity, ""} ->
          Inventory.update_quantity(product_id, quantity)

        _ ->
          {:error, :invalid_quantity}
      end

    # Preserve form state on error
    form = to_form(params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:result, result)}
  end

  def handle_event(
        "change_price",
        %{"product_id" => product_id, "new_price" => price_str} = params,
        socket
      ) do
    result =
      case Decimal.parse(price_str) do
        {price, ""} ->
          Price.change_price(%{product_id: product_id, new_price: price})

        _ ->
          {:error, :invalid_price}
      end

    # Preserve form state on error
    price_form = to_form(params)

    {:noreply,
     socket
     |> assign(:price_form, price_form)
     |> assign(:price_result, result)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-8 p-6">
      <h1 class="text-2xl font-bold mb-6">Update Inventory</h1>

      <.form for={@form} phx-submit="save" id="inventory-form" class="space-y-4">
        <div>
          <label for="product_id" class="block text-sm font-medium mb-1">Product</label>
          <select
            name="product_id"
            id="product_id"
            class="w-full px-3 py-2 border rounded-md"
            required
          >
            <option value="">Select a product...</option>
            <option
              :for={product <- @products}
              value={product.product_id}
              selected={@form[:product_id].value == product.product_id}
            >
              {product.name} ({product.product_id})
            </option>
          </select>
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

      <hr class="my-8 border-gray-300" />

      <h2 class="text-xl font-bold mb-6">Change Price</h2>

      <.form for={@price_form} phx-submit="change_price" id="price-form" class="space-y-4">
        <div>
          <label for="price_product_id" class="block text-sm font-medium mb-1">Product</label>
          <select
            name="product_id"
            id="price_product_id"
            class="w-full px-3 py-2 border rounded-md"
            required
          >
            <option value="">Select a product...</option>
            <option
              :for={product <- @products}
              value={product.product_id}
              selected={@price_form[:product_id].value == product.product_id}
            >
              {product.name} ({product.product_id})
            </option>
          </select>
        </div>

        <div>
          <label for="new_price" class="block text-sm font-medium mb-1">New Price</label>
          <input
            type="number"
            name="new_price"
            id="new_price"
            value={@price_form[:new_price].value}
            class="w-full px-3 py-2 border rounded-md"
            min="0.01"
            step="0.01"
            placeholder="e.g., 15.99"
            required
          />
        </div>

        <button
          type="submit"
          class="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700"
        >
          Update Price
        </button>
      </.form>

      <%= if @price_result do %>
        <div class="mt-6" id="price-result-message">
          <%= case @price_result do %>
            <% {:ok, event} -> %>
              <div class="p-4 bg-green-100 text-green-800 rounded-md">
                <p class="font-medium">Price updated successfully!</p>
                <p>Product: {event.product_id}</p>
                <p>New Price: ${Decimal.to_string(event.new_price)}</p>
                <%= if event.old_price do %>
                  <p>Previous Price: ${Decimal.to_string(event.old_price)}</p>
                <% end %>
              </div>
            <% {:error, :product_not_found} -> %>
              <div class="p-4 bg-red-100 text-red-800 rounded-md">
                <p class="font-medium">Error: Product not found</p>
              </div>
            <% {:error, :invalid_price} -> %>
              <div class="p-4 bg-red-100 text-red-800 rounded-md">
                <p class="font-medium">Error: Invalid price (must be greater than 0)</p>
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
