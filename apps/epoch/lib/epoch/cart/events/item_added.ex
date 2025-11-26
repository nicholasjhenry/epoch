defmodule Epoch.Cart.Events.ItemAdded do
  @moduledoc """
  Event emitted when an item is added to the cart for display purposes.

  This event contains denormalized product information (name, price)
  captured at the time of add for the cart items view.
  """

  @type t :: %__MODULE__{
          item_id: String.t(),
          product_id: String.t(),
          name: String.t(),
          price: float(),
          added_at: DateTime.t()
        }

  defstruct [:item_id, :product_id, :name, :price, :added_at]
end
