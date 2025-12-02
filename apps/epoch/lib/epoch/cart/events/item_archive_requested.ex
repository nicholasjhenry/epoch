defmodule Epoch.Cart.Events.ItemArchiveRequested do
  @moduledoc """
  Event emitted when an item archive is requested due to external factors.

  This event signals that a cart item should be archived, typically
  triggered by automation (e.g., price change). The reason field
  indicates why the archive was requested.
  """

  @type t :: %__MODULE__{
          cart_id: String.t(),
          product_id: String.t(),
          item_id: String.t(),
          reason: String.t(),
          requested_at: DateTime.t()
        }

  defstruct [:cart_id, :product_id, :item_id, :reason, :requested_at]
end
