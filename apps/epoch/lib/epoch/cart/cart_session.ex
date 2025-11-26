defmodule Epoch.Cart.CartSession do
  @moduledoc """
  Represents the current state of a shopping cart session.

  State is reconstructed from events stored in EventStore.
  Stream name format: "cart-{session_id}"
  """

  alias Epoch.Cart.Events.{CartCleared, CartCreated, ItemAdded, ItemArchived, ItemRemoved}

  @type cart_item :: %{
          product_id: String.t(),
          quantity: pos_integer()
        }

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          items: [cart_item()],
          created_at: DateTime.t() | nil
        }

  defstruct session_id: nil, items: [], created_at: nil

  @doc """
  Evolves cart state by applying an event.
  """
  @spec evolve(
          t(),
          CartCreated.t() | ItemAdded.t() | ItemRemoved.t() | ItemArchived.t() | CartCleared.t()
        ) :: t()
  def evolve(state, %CartCreated{session_id: id, created_at: at}) do
    %{state | session_id: id, created_at: at}
  end

  def evolve(state, %ItemAdded{product_id: pid}) do
    # Each ItemAdded event represents a single item (quantity=1)
    updated_items = add_or_update_item(state.items, pid, 1)
    %{state | items: updated_items}
  end

  def evolve(state, %ItemRemoved{item_id: item_id}) do
    remove_item(state, item_id)
  end

  def evolve(state, %ItemArchived{item_id: item_id}) do
    remove_item(state, item_id)
  end

  def evolve(_state, %CartCleared{}) do
    %__MODULE__{}
  end

  defp add_or_update_item(items, product_id, quantity) do
    case Enum.find_index(items, &(&1.product_id == product_id)) do
      nil ->
        items ++ [%{product_id: product_id, quantity: quantity}]

      index ->
        List.update_at(items, index, fn item ->
          %{item | quantity: item.quantity + quantity}
        end)
    end
  end

  defp remove_item(state, item_id) do
    # item_id format: "{product_id}-{timestamp}"
    # Extract product_id by removing the timestamp suffix
    product_id = extract_product_id(item_id)

    case Enum.find_index(state.items, &(&1.product_id == product_id)) do
      nil -> state
      index -> %{state | items: decrement_or_remove_item(state.items, index)}
    end
  end

  defp decrement_or_remove_item(items, index) do
    item = Enum.at(items, index)

    if item.quantity > 1 do
      List.update_at(items, index, fn i -> %{i | quantity: i.quantity - 1} end)
    else
      List.delete_at(items, index)
    end
  end

  defp extract_product_id(item_id) do
    # item_id format: "{product_id}-{unix_timestamp_microseconds}"
    # Split by "-" and rejoin all but the last part (the timestamp)
    parts = String.split(item_id, "-")

    parts
    |> Enum.take(length(parts) - 1)
    |> Enum.join("-")
  end
end
