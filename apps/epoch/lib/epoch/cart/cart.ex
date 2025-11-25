defmodule Epoch.Cart do
  @moduledoc """
  The Cart context for managing shopping cart sessions.

  Cart state is event-sourced using Epoch.EventStore.
  """

  alias Epoch.Cart.CartSession
  alias Epoch.Cart.Events.{CartCreated, ItemAddedToCart}
  alias Epoch.Catalog
  alias Epoch.EventStore

  @doc """
  Creates a new cart session in the EventStore.

  Returns `{:ok, cart_session}` on success.
  """
  @spec create_session(String.t()) :: {:ok, CartSession.t()} | {:error, term()}
  def create_session(session_id) do
    event = %CartCreated{
      session_id: session_id,
      created_at: DateTime.utc_now()
    }

    stream_name = stream_name(session_id)

    case EventStore.append_to_stream(stream_name, [event], expected_version: 0) do
      {:ok, _} -> get_session(session_id)
      {:error, _} = error -> error
    end
  end

  @doc """
  Adds a product to the cart.

  Validates the product exists in the catalog before adding.
  Defaults to quantity of 1 if not specified.
  """
  @spec add_item(String.t(), String.t(), pos_integer()) ::
          {:ok, CartSession.t()} | {:error, term()}
  def add_item(session_id, product_id, quantity \\ 1) do
    with {:ok, _product} <- Catalog.get_product(product_id) do
      event = %ItemAddedToCart{
        product_id: product_id,
        quantity: quantity,
        added_at: DateTime.utc_now()
      }

      stream_name = stream_name(session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> get_session(session_id)
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Retrieves the current state of a cart session.

  Returns `{:ok, cart_session}` if exists, `{:error, :not_found}` otherwise.
  """
  @spec get_session(String.t()) :: {:ok, CartSession.t()} | {:error, :not_found}
  def get_session(session_id) do
    stream_name = stream_name(session_id)

    case EventStore.aggregate_stream(
           stream_name,
           %CartSession{},
           &CartSession.evolve/2
         ) do
      {:ok, %{state: %CartSession{session_id: nil}, version: 0}} ->
        {:error, :not_found}

      {:ok, %{state: session}} ->
        {:ok, session}
    end
  end

  defp stream_name(session_id), do: "cart-#{session_id}"
end
