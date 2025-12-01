defmodule Epoch.Cart.CartItemsView do
  @moduledoc """
  State view module for projecting cart events into displayable cart state.

  This read model projects cart events (ItemAdded, ItemRemoved, CartCleared,
  ItemArchived) into a structure suitable for displaying cart items with
  names, prices, and totals.
  """

  require Logger

  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemArchived, ItemRemoved}

  @type cart_item :: %{
          item_id: String.t(),
          product_id: String.t(),
          name: String.t(),
          price: float()
        }

  @type state :: %{
          items: [cart_item()],
          total: float()
        }

  @doc """
  Returns the initial empty cart state.
  """
  @spec initial_state() :: state()
  def initial_state, do: %{items: [], total: 0.0}

  @doc """
  Checks if cart state has no items.
  """
  @spec empty?(state()) :: boolean()
  def empty?(%{items: []}), do: true
  def empty?(_state), do: false

  @doc """
  Applies a single event to the current state, returning updated state.
  """
  @spec evolve(state(), struct()) :: state()
  def evolve(state, %ItemAdded{item_id: id, product_id: product_id, name: name, price: price}) do
    item = %{item_id: id, product_id: product_id, name: name, price: price}
    %{state | items: state.items ++ [item], total: state.total + price}
  end

  def evolve(state, %ItemRemoved{item_id: id}) do
    remove_item(state, id)
  end

  def evolve(_state, %CartCleared{}) do
    initial_state()
  end

  def evolve(state, %ItemArchived{item_id: id}) do
    remove_item(state, id)
  end

  def evolve(state, unknown_event) do
    Logger.warning(
      "CartItemsView: Ignoring unknown event type: #{inspect(unknown_event.__struct__)}"
    )

    state
  end

  @doc """
  Projects a list of events into final cart state.
  """
  @spec project([struct()]) :: state()
  def project(events) do
    Enum.reduce(events, initial_state(), &evolve(&2, &1))
  end

  defp remove_item(state, item_id) do
    case Enum.find(state.items, &(&1.item_id == item_id)) do
      nil ->
        state

      item ->
        items = Enum.reject(state.items, &(&1.item_id == item_id))
        %{state | items: items, total: state.total - item.price}
    end
  end
end
