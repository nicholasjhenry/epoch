defmodule Epoch.Cart.Events.CartCreated do
  @moduledoc """
  Event emitted when a cart session is created.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          created_at: DateTime.t()
        }

  defstruct [:session_id, :created_at]
end
