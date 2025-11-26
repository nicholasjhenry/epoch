defmodule Epoch.Cart.Events.ItemRemoved do
  @moduledoc """
  Event emitted when a specific line item is removed from the cart.
  """

  @type t :: %__MODULE__{
          item_id: String.t(),
          removed_at: DateTime.t()
        }

  defstruct [:item_id, :removed_at]
end
