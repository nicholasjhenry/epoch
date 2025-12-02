defmodule Epoch.Backoffice.Events.PriceChanged do
  @moduledoc """
  Event emitted when a product's price is changed.

  This event records the price change for a product, including both
  the old and new prices. The old_price may be nil for the first
  price change of a product.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          old_price: Decimal.t() | nil,
          new_price: Decimal.t(),
          changed_at: DateTime.t()
        }

  defstruct [:product_id, :old_price, :new_price, :changed_at]
end
