defmodule Epoch.Cart.Events.ItemAddedToCart do
  @moduledoc """
  Event emitted when an item is added to cart.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          quantity: pos_integer(),
          added_at: DateTime.t()
        }

  defstruct [:product_id, :quantity, :added_at]
end
