defmodule Epoch.Slices.AddItem.Command do
  @moduledoc """
  Command for adding an item to cart.

  Each command adds a single item. Multiple items of the same product
  are represented as multiple items in the cart.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          product_id: String.t()
        }

  defstruct [:session_id, :product_id]
end
