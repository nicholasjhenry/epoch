defmodule Epoch.Cart.Events.CartCleared do
  @moduledoc """
  Event emitted when all items are removed from the cart.
  """

  @type t :: %__MODULE__{
          cleared_at: DateTime.t()
        }

  defstruct [:cleared_at]
end
