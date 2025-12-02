defmodule Epoch.Slices.RequestToArchiveItem.Command do
  @moduledoc """
  Command for requesting that a cart item be archived.

  Typically triggered by automation when external factors (like price changes)
  require cart items to be archived.
  """

  @type t :: %__MODULE__{
          cart_id: String.t(),
          product_id: String.t(),
          item_id: String.t(),
          reason: String.t()
        }

  defstruct [:cart_id, :product_id, :item_id, :reason]
end
