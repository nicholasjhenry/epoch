defmodule Epoch.Slices.ChangePrice.Command do
  @moduledoc """
  Command for changing the price of a product.

  Triggers price change automation that archives affected cart items.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          new_price: Decimal.t()
        }

  defstruct [:product_id, :new_price]
end
