defmodule Epoch.Cart.ItemsToArchive do
  @moduledoc """
  Read model tracking items pending archive completion (TODO list).

  This read model maintains a list of items that have been requested
  for archival but not yet archived. Used by the archive processor
  to process pending archive requests.
  """

  alias Epoch.Cart.Events.{ItemArchived, ItemArchiveRequested}

  @type todo_item :: %{
          cart_id: String.t(),
          product_id: String.t(),
          item_id: String.t(),
          reason: String.t(),
          requested_at: DateTime.t()
        }

  @type state :: %{
          pending: [todo_item()]
        }

  @doc """
  Returns the initial empty state.
  """
  @spec initial_state() :: state()
  def initial_state, do: %{pending: []}

  @doc """
  Applies a single event to the current state, returning updated state.
  """
  @spec evolve(state(), struct()) :: state()
  def evolve(state, %ItemArchiveRequested{} = event) do
    # Idempotency: only add if not already pending
    case Enum.find(state.pending, &(&1.item_id == event.item_id)) do
      nil ->
        item = %{
          cart_id: event.cart_id,
          product_id: event.product_id,
          item_id: event.item_id,
          reason: event.reason,
          requested_at: event.requested_at
        }

        %{state | pending: [item | state.pending]}

      _ ->
        state
    end
  end

  def evolve(state, %ItemArchived{item_id: item_id}) do
    %{state | pending: Enum.reject(state.pending, &(&1.item_id == item_id))}
  end

  def evolve(state, _), do: state

  @doc """
  Get all items pending archive.
  """
  @spec all_pending(state()) :: [todo_item()]
  def all_pending(state), do: state.pending

  @doc """
  Get pending items for a specific cart.
  """
  @spec pending_for_cart(state(), String.t()) :: [todo_item()]
  def pending_for_cart(state, cart_id) do
    Enum.filter(state.pending, &(&1.cart_id == cart_id))
  end

  @doc """
  Get pending items for a specific product.
  """
  @spec pending_for_product(state(), String.t()) :: [todo_item()]
  def pending_for_product(state, product_id) do
    Enum.filter(state.pending, &(&1.product_id == product_id))
  end

  @doc """
  Check if a specific item is pending archive.
  """
  @spec pending?(state(), String.t()) :: boolean()
  def pending?(state, item_id) do
    Enum.any?(state.pending, &(&1.item_id == item_id))
  end

  @doc """
  Count of pending items.
  """
  @spec pending_count(state()) :: non_neg_integer()
  def pending_count(state), do: length(state.pending)

  @doc """
  Get oldest pending item (for processing order).
  """
  @spec oldest_pending(state()) :: todo_item() | nil
  def oldest_pending(state) do
    state.pending
    |> Enum.sort_by(& &1.requested_at, DateTime)
    |> List.first()
  end

  @doc """
  Projects a list of events into final state.
  """
  @spec project([struct()]) :: state()
  def project(events) do
    Enum.reduce(events, initial_state(), &evolve(&2, &1))
  end
end
