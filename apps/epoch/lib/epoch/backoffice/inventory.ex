defmodule Epoch.Backoffice.Inventory do
  @moduledoc """
  The Inventory context for managing product inventory quantities.

  Inventory state is event-sourced using Epoch.EventStore.
  Stream name format: "inventory-{product_id}"
  """

  require Logger

  alias Epoch.Backoffice.Events.InventoryUpdated
  alias Epoch.Backoffice.InventoryState
  alias Epoch.Catalog
  alias Epoch.EventStore

  @spec update_quantity(String.t(), integer()) ::
          {:ok, InventoryState.t()}
          | {:error, :not_found | :invalid_quantity | :persistence_failed}
  def update_quantity(product_id, quantity) when is_integer(quantity) and quantity >= 0 do
    {:ok, old_state} = get_state(product_id)
    old_quantity = old_state.quantity

    case Catalog.get_product(product_id) do
      {:ok, _product} ->
        event = %InventoryUpdated{
          product_id: product_id,
          quantity: quantity,
          updated_at: DateTime.utc_now()
        }

        stream = EventStore.stream_name("inventory", product_id)

        case EventStore.append_to_stream(stream, [event]) do
          {:ok, _} ->
            Logger.info(
              "Inventory updated: product_id=#{product_id} old_quantity=#{old_quantity} new_quantity=#{quantity}"
            )

            get_state(product_id)

          {:error, reason} ->
            Logger.error(
              "Inventory update failed: product_id=#{product_id} reason=#{inspect(reason)}"
            )

            {:error, :persistence_failed}
        end

      {:error, :not_found} ->
        Logger.warning("Inventory update failed: product_id=#{product_id} reason=not_found")
        {:error, :not_found}
    end
  end

  def update_quantity(product_id, quantity) do
    Logger.warning(
      "Inventory update failed: product_id=#{product_id} quantity=#{inspect(quantity)} reason=invalid_quantity"
    )

    {:error, :invalid_quantity}
  end

  @spec get_quantity(String.t()) :: {:ok, non_neg_integer()}
  def get_quantity(product_id) do
    {:ok, state} = get_state(product_id)
    {:ok, state.quantity}
  end

  @spec get_state(String.t()) :: {:ok, InventoryState.t()}
  def get_state(product_id) do
    stream = EventStore.stream_name("inventory", product_id)

    {:ok, %{state: state}} =
      EventStore.aggregate_stream(
        stream,
        InventoryState.initial_state(),
        &InventoryState.evolve/2
      )

    {:ok, state}
  end
end
