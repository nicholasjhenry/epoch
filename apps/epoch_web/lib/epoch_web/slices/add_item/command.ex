defmodule Epoch.Slices.AddItem.Command do
  @moduledoc """
  Command for adding an item to cart.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          product_id: String.t(),
          quantity: pos_integer()
        }

  defstruct [:session_id, :product_id, quantity: 1]
end
