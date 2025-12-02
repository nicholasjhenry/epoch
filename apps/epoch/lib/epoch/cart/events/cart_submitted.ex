defmodule Epoch.Cart.Events.CartSubmitted do
  @moduledoc """
  Event emitted when a cart is successfully submitted.

  This event marks the cart as submitted after inventory validation passes.
  """

  @type t :: %__MODULE__{
          cart_id: String.t(),
          submitted_at: DateTime.t()
        }

  defstruct [:cart_id, :submitted_at]
end
