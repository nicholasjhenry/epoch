defmodule Epoch.Cart.Events.ItemArchived do
  @moduledoc """
  Event emitted when a line item is archived (soft removal).
  """

  @type t :: %__MODULE__{
          item_id: String.t(),
          archived_at: DateTime.t()
        }

  defstruct [:item_id, :archived_at]
end
