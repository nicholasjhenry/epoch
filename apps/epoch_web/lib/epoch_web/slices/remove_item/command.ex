defmodule Epoch.Slices.RemoveItem.Command do
  @moduledoc """
  Command for removing an item from cart.

  The item_id identifies a specific line item in the cart to be removed.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          item_id: String.t()
        }

  defstruct [:session_id, :item_id]
end
