defmodule Epoch.Backoffice.Price do
  @moduledoc """
  Context for managing product price changes.

  This module provides the public API for changing product prices.
  """

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Catalog
  alias Epoch.EventStore

  @doc """
  Changes the price of a product.

  Validates the product exists and the price is valid, then emits
  a PriceChanged event to the price stream.

  ## Parameters

    * `attrs` - Map with `:product_id` and `:new_price` keys

  ## Returns

    * `{:ok, event}` - The PriceChanged event on success
    * `{:error, :product_not_found}` - Product doesn't exist
    * `{:error, :invalid_price}` - Price is <= 0

  ## Examples

      iex> Price.change_price(%{product_id: "espresso-blend", new_price: Decimal.new("15.99")})
      {:ok, %PriceChanged{...}}

  """
  @spec change_price(map()) :: {:ok, PriceChanged.t()} | {:error, atom()}
  def change_price(%{product_id: product_id, new_price: new_price}) do
    with :ok <- validate_price(new_price),
         {:ok, _product} <- Catalog.get_product(product_id) do
      old_price = get_current_price(product_id)

      event = %PriceChanged{
        product_id: product_id,
        old_price: old_price,
        new_price: new_price,
        changed_at: DateTime.utc_now()
      }

      stream_name = EventStore.stream_name("price", product_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> {:ok, event}
        {:error, _} = error -> error
      end
    else
      {:error, :not_found} -> {:error, :product_not_found}
      {:error, _} = error -> error
    end
  end

  defp validate_price(price) do
    if Decimal.gt?(price, Decimal.new("0")) do
      :ok
    else
      {:error, :invalid_price}
    end
  end

  defp get_current_price(product_id) do
    stream_name = EventStore.stream_name("price", product_id)

    {:ok, %{events: events}} = EventStore.read_stream(stream_name)

    case events do
      [] ->
        nil

      _ ->
        events
        |> List.last()
        |> Map.get(:new_price)
    end
  end
end
