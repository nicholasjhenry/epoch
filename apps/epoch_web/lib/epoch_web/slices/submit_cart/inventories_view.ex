defmodule Epoch.Slices.SubmitCart.InventoriesView do
  @moduledoc """
  Slice-local read model for inventory validation during cart submission.

  Projects InventoryUpdated events into a map of product quantities.
  This view is dedicated to the SubmitCart slice and avoids coupling
  to the Epoch.Backoffice.Inventory context.
  """

  alias Epoch.Backoffice.Events.InventoryUpdated

  @type state :: %{String.t() => non_neg_integer()}

  @doc """
  Returns initial empty state.
  """
  @spec initial_state() :: state()
  def initial_state, do: %{}

  @doc """
  Evolves state by applying an InventoryUpdated event.
  Updates the quantity for the given product_id.
  """
  @spec evolve(state(), InventoryUpdated.t()) :: state()
  def evolve(state, %InventoryUpdated{product_id: product_id, quantity: quantity}) do
    Map.put(state, product_id, quantity)
  end

  @doc """
  Gets the quantity for a product_id. Returns 0 if no inventory record exists.
  """
  @spec get_quantity(state(), String.t()) :: non_neg_integer()
  def get_quantity(state, product_id) do
    Map.get(state, product_id, 0)
  end

  @doc """
  Projects a list of events into final inventory state.
  """
  @spec project([InventoryUpdated.t()]) :: state()
  def project(events) do
    Enum.reduce(events, initial_state(), &evolve(&2, &1))
  end
end
