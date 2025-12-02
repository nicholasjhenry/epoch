defmodule Epoch.Backoffice.ProductsWithPriceChanges do
  @moduledoc """
  Read model tracking products that have had price changes.

  This read model maintains a record of all products with price changes,
  storing the latest price information for each product. Used by the
  price change automation to identify products needing cart updates.
  """

  alias Epoch.Backoffice.Events.PriceChanged

  @type product_price :: %{
          product_id: String.t(),
          old_price: Decimal.t() | nil,
          new_price: Decimal.t(),
          last_changed_at: DateTime.t()
        }

  @type state :: %{
          products: %{String.t() => product_price()}
        }

  @doc """
  Returns the initial empty state.
  """
  @spec initial_state() :: state()
  def initial_state, do: %{products: %{}}

  @doc """
  Applies a single event to the current state, returning updated state.
  """
  @spec evolve(state(), struct()) :: state()
  def evolve(state, %PriceChanged{} = event) do
    product = %{
      product_id: event.product_id,
      old_price: event.old_price,
      new_price: event.new_price,
      last_changed_at: event.changed_at
    }

    %{state | products: Map.put(state.products, event.product_id, product)}
  end

  def evolve(state, _), do: state

  @doc """
  Get price change info for specific product.
  """
  @spec get_product(state(), String.t()) :: product_price() | nil
  def get_product(state, product_id) do
    Map.get(state.products, product_id)
  end

  @doc """
  List all products with price changes.
  """
  @spec all_products(state()) :: [product_price()]
  def all_products(state) do
    Map.values(state.products)
  end

  @doc """
  Get products changed after a specific timestamp.
  """
  @spec changed_since(state(), DateTime.t()) :: [product_price()]
  def changed_since(state, datetime) do
    state.products
    |> Map.values()
    |> Enum.filter(&(DateTime.compare(&1.last_changed_at, datetime) == :gt))
  end

  @doc """
  Check if product has had price changes.
  """
  @spec has_price_changes?(state(), String.t()) :: boolean()
  def has_price_changes?(state, product_id) do
    Map.has_key?(state.products, product_id)
  end

  @doc """
  Projects a list of events into final state.
  """
  @spec project([struct()]) :: state()
  def project(events) do
    Enum.reduce(events, initial_state(), &evolve(&2, &1))
  end
end
