defmodule Epoch.Backoffice.InventoryState do
  @moduledoc """
  Aggregate state for product inventory.

  State is reconstructed from InventoryUpdated events stored in EventStore.
  Stream name format: "inventory-{product_id}"
  """

  alias Epoch.Backoffice.Events.InventoryUpdated

  @type t :: %__MODULE__{
          product_id: String.t() | nil,
          quantity: non_neg_integer()
        }

  defstruct product_id: nil, quantity: 0

  @doc """
  Returns initial state for inventory aggregation.
  """
  @spec initial_state() :: t()
  def initial_state, do: %__MODULE__{}

  @doc """
  Evolves inventory state by applying an event.
  """
  @spec evolve(t(), InventoryUpdated.t()) :: t()
  def evolve(_state, %InventoryUpdated{} = event) do
    %__MODULE__{
      product_id: event.product_id,
      quantity: event.quantity
    }
  end
end
