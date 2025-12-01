defmodule Epoch.Cart.CartsWithProducts do
  @moduledoc """
  Read model tracking which carts contain which products.

  This read model maintains a mapping of cart-product relationships,
  enabling efficient lookup of all carts containing a specific product.
  Used by the price change automation to find affected carts.
  """

  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemArchived, ItemRemoved}

  @type mapping :: %{
          cart_id: String.t(),
          product_id: String.t(),
          item_id: String.t()
        }

  @type state :: %{
          mappings: [mapping()],
          by_product: %{String.t() => [mapping()]},
          by_cart: %{String.t() => [mapping()]}
        }

  @doc """
  Returns the initial empty state.
  """
  @spec initial_state() :: state()
  def initial_state do
    %{mappings: [], by_product: %{}, by_cart: %{}}
  end

  @doc """
  Applies a single event to the current state, returning updated state.
  """
  @spec evolve(state(), struct()) :: state()
  def evolve(state, %ItemAdded{cart_id: cart_id, product_id: product_id, item_id: item_id})
      when is_binary(cart_id) do
    mapping = %{cart_id: cart_id, product_id: product_id, item_id: item_id}

    %{
      state
      | mappings: [mapping | state.mappings],
        by_product: Map.update(state.by_product, product_id, [mapping], &[mapping | &1]),
        by_cart: Map.update(state.by_cart, cart_id, [mapping], &[mapping | &1])
    }
  end

  def evolve(state, %ItemAdded{}) do
    # Skip events without cart_id (legacy events)
    state
  end

  def evolve(state, %ItemRemoved{item_id: item_id}) do
    remove_item(state, item_id)
  end

  def evolve(state, %ItemArchived{item_id: item_id}) do
    remove_item(state, item_id)
  end

  def evolve(state, %CartCleared{} = event) do
    cart_id = Map.get(event, :cart_id)

    if cart_id do
      items_to_remove = Map.get(state.by_cart, cart_id, [])
      Enum.reduce(items_to_remove, state, fn m, acc -> remove_item(acc, m.item_id) end)
    else
      state
    end
  end

  def evolve(state, _), do: state

  @doc """
  Find all carts containing a specific product.
  """
  @spec carts_with_product(state(), String.t()) :: [String.t()]
  def carts_with_product(state, product_id) do
    state.by_product
    |> Map.get(product_id, [])
    |> Enum.map(& &1.cart_id)
    |> Enum.uniq()
  end

  @doc """
  Get all items for a specific product across all carts.
  """
  @spec items_for_product(state(), String.t()) :: [mapping()]
  def items_for_product(state, product_id) do
    Map.get(state.by_product, product_id, [])
  end

  @doc """
  Get all product mappings for a cart.
  """
  @spec products_in_cart(state(), String.t()) :: [mapping()]
  def products_in_cart(state, cart_id) do
    Map.get(state.by_cart, cart_id, [])
  end

  @doc """
  Check if an item exists in any cart.
  """
  @spec item_exists?(state(), String.t()) :: boolean()
  def item_exists?(state, item_id) do
    Enum.any?(state.mappings, &(&1.item_id == item_id))
  end

  @doc """
  Count total items across all carts.
  """
  @spec total_items(state()) :: non_neg_integer()
  def total_items(state) do
    length(state.mappings)
  end

  @doc """
  Projects a list of events into final state.
  """
  @spec project([struct()]) :: state()
  def project(events) do
    Enum.reduce(events, initial_state(), &evolve(&2, &1))
  end

  defp remove_item(state, item_id) do
    case Enum.find(state.mappings, &(&1.item_id == item_id)) do
      nil ->
        state

      mapping ->
        %{
          state
          | mappings: Enum.reject(state.mappings, &(&1.item_id == item_id)),
            by_product:
              Map.update(state.by_product, mapping.product_id, [], fn items ->
                Enum.reject(items, &(&1.item_id == item_id))
              end),
            by_cart:
              Map.update(state.by_cart, mapping.cart_id, [], fn items ->
                Enum.reject(items, &(&1.item_id == item_id))
              end)
        }
    end
  end
end
