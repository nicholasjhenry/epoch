defmodule Epoch.Backoffice.Events.InventoryUpdated do
  @moduledoc """
  Event emitted when a product's inventory quantity is updated.

  This event sets the absolute quantity for a product, not a delta.
  The latest event in the stream represents the current quantity.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          quantity: non_neg_integer(),
          updated_at: DateTime.t()
        }

  defstruct [:product_id, :quantity, :updated_at]
end
