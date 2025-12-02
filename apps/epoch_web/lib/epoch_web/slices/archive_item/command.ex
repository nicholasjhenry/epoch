defmodule Epoch.Slices.ArchiveItem.Command do
  @moduledoc """
  Command for archiving a cart item.

  Completes a pending archive request by emitting an ItemArchived event.
  """

  @type t :: %__MODULE__{
          cart_id: String.t(),
          item_id: String.t(),
          reason: String.t() | nil
        }

  defstruct [:cart_id, :item_id, :reason]
end
