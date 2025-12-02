defmodule Epoch.Cart do
  @moduledoc """
  The Cart context for managing shopping cart sessions.

  Cart state is event-sourced using Epoch.EventStore.
  """

  alias Epoch.Cart.CartItemsView
  alias Epoch.Cart.CartSession
  alias Epoch.Cart.Events.{CartCreated, ItemAdded, ItemArchived, ItemArchiveRequested}
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
  Each call adds a single item to the cart.
  """
  @spec add_item(String.t(), String.t()) :: {:ok, CartSession.t()} | {:error, term()}
  def add_item(session_id, product_id) do
    with {:ok, product} <- Catalog.get_product(product_id) do
      now = DateTime.utc_now()

      event = %ItemAdded{
        cart_id: session_id,
        item_id: "#{product_id}-#{DateTime.to_unix(now, :microsecond)}",
        product_id: product_id,
        name: product.name,
        price: Decimal.to_float(product.price),
        added_at: now
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

  @doc """
  Retrieves displayable cart items for a session.

  Returns the cart items state including items list and total.
  """
  @spec get_cart_items(String.t()) :: {:ok, CartItemsView.state()}
  def get_cart_items(session_id) do
    stream_name = stream_name(session_id)

    {:ok, %{state: state}} =
      EventStore.aggregate_stream(
        stream_name,
        CartItemsView.initial_state(),
        &CartItemsView.evolve/2
      )

    {:ok, state}
  end

  @doc """
  Requests that a cart item be archived.

  Emits an ItemArchiveRequested event to the cart stream.
  Checks for idempotency - returns error if archive already requested.
  """
  @spec request_item_archive(map()) :: {:ok, ItemArchiveRequested.t()} | {:error, atom()}
  def request_item_archive(%{
        cart_id: cart_id,
        product_id: product_id,
        item_id: item_id,
        reason: reason
      }) do
    stream_name = stream_name(cart_id)

    # Check if archive already requested for this item
    {:ok, %{events: events}} = EventStore.read_stream(stream_name)

    already_requested =
      Enum.any?(events, fn e ->
        e.__struct__ == ItemArchiveRequested and e.item_id == item_id
      end)

    if already_requested do
      {:error, :already_requested}
    else
      event = %ItemArchiveRequested{
        cart_id: cart_id,
        product_id: product_id,
        item_id: item_id,
        reason: reason || "price_changed",
        requested_at: DateTime.utc_now()
      }

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> {:ok, event}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Archives a cart item.

  Emits an ItemArchived event to the cart stream.
  Checks for idempotency - returns error if item already archived.
  """
  @spec archive_item(map()) :: {:ok, ItemArchived.t()} | {:error, atom()}
  def archive_item(%{cart_id: cart_id, item_id: item_id, reason: reason}) do
    stream_name = stream_name(cart_id)

    # Check if item already archived
    {:ok, %{events: events}} = EventStore.read_stream(stream_name)

    already_archived =
      Enum.any?(events, fn e ->
        e.__struct__ == ItemArchived and e.item_id == item_id
      end)

    if already_archived do
      {:error, :already_archived}
    else
      event = %ItemArchived{
        cart_id: cart_id,
        item_id: item_id,
        reason: reason || "price_changed",
        archived_at: DateTime.utc_now()
      }

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> {:ok, event}
        {:error, _} = error -> error
      end
    end
  end

  defp stream_name(session_id), do: "cart-#{session_id}"
end
