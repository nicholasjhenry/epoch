defmodule Epoch.Slices.ClearCart.Command do
  @moduledoc """
  Command for clearing all items from cart.

  The session_id identifies the cart session to be cleared.
  """

  @type t :: %__MODULE__{
          session_id: String.t()
        }

  defstruct [:session_id]
end
