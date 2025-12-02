defmodule Epoch.Cart.Events.ItemArchived do
  @moduledoc """
  Event emitted when a line item is archived (soft removal).

  The cart_id field explicitly identifies the cart for read model processing.
  The reason field indicates why the item was archived (e.g., "price_changed").
  """

  @type t :: %__MODULE__{
          cart_id: String.t(),
          item_id: String.t(),
          reason: String.t() | nil,
          archived_at: DateTime.t()
        }

  defstruct [:cart_id, :item_id, :reason, :archived_at]
end
