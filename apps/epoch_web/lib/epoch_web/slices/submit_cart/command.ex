defmodule Epoch.Slices.SubmitCart.Command do
  @moduledoc """
  Command for submitting a cart.

  The session_id identifies the cart session to be submitted.
  """

  @type t :: %__MODULE__{
          session_id: String.t()
        }

  defstruct [:session_id]
end
