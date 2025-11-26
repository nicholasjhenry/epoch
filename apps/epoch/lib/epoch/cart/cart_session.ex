defmodule Epoch.Cart.CartSession do
  @moduledoc """
  Represents the current state of a shopping cart session.

  State is reconstructed from events stored in EventStore.
  Stream name format: "cart-{session_id}"
  """

  alias Epoch.Cart.Events.{CartCreated, ItemAdded}

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
  @spec evolve(t(), CartCreated.t() | ItemAdded.t()) :: t()
  def evolve(state, %CartCreated{session_id: id, created_at: at}) do
    %{state | session_id: id, created_at: at}
  end

  def evolve(state, %ItemAdded{product_id: pid}) do
    # Each ItemAdded event represents a single item (quantity=1)
    updated_items = add_or_update_item(state.items, pid, 1)
    %{state | items: updated_items}
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
end
