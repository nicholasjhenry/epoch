defmodule Epoch.Automation.PriceChangeProcessor do
  @moduledoc """
  GenServer that automatically processes price changes and requests
  archiving of affected cart items.

  Subscribes to the stream_type:price PubSub topic to receive
  PriceChanged events. For each price change, it:
  1. Builds the CartsWithProducts read model
  2. Finds all cart items containing the changed product
  3. Emits ItemArchiveRequested events for each affected item
  """

  use GenServer
  require Logger

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Cart
  alias Epoch.Cart.CartsWithProducts
  alias Epoch.Cart.Events.ItemAdded
  alias Epoch.EventStore

  @pubsub Epoch.PubSub
  @topic "stream_type:price"

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to price stream events
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    Logger.info("PriceChangeProcessor started and subscribed to #{@topic}")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:events_appended, stream_name, envelopes}, state) do
    Logger.debug("PriceChangeProcessor received events from #{stream_name}")

    # Process each PriceChanged event
    Enum.each(envelopes, fn envelope ->
      case envelope.event do
        %PriceChanged{} = event ->
          process_price_change(event)

        _ ->
          :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warning("PriceChangeProcessor received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  # Private Functions

  defp process_price_change(%PriceChanged{product_id: product_id} = event) do
    Logger.info("Processing price change for product #{product_id}")

    # Build the CartsWithProducts read model from all cart streams
    carts_state = build_carts_with_products_state()

    # Find all items for this product across all carts
    affected_items = CartsWithProducts.items_for_product(carts_state, product_id)

    Logger.debug("Found #{length(affected_items)} cart items affected by price change")

    # Request archive for each affected item
    Enum.each(affected_items, fn item ->
      request_item_archive(item, event)
    end)
  end

  defp build_carts_with_products_state do
    # Get all cart streams and build the read model
    all_streams = EventStore.debug_all_streams()

    cart_streams =
      all_streams
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "cart-"))

    # Collect all relevant events from cart streams
    events =
      cart_streams
      |> Enum.flat_map(fn stream_name ->
        {:ok, %{events: stream_events}} = EventStore.read_stream(stream_name)

        Enum.filter(stream_events, fn e ->
          e.__struct__ in [
            ItemAdded,
            Epoch.Cart.Events.ItemRemoved,
            Epoch.Cart.Events.ItemArchived,
            Epoch.Cart.Events.CartCleared
          ]
        end)
      end)

    # Project events into CartsWithProducts state
    CartsWithProducts.project(events)
  end

  defp request_item_archive(item, _price_changed_event) do
    result =
      Cart.request_item_archive(%{
        cart_id: item.cart_id,
        product_id: item.product_id,
        item_id: item.item_id,
        reason: "price_changed"
      })

    case result do
      {:ok, _event} ->
        Logger.info(
          "Requested archive for item #{item.item_id} in cart #{item.cart_id} due to price change"
        )

      {:error, :already_requested} ->
        Logger.debug("Archive already requested for item #{item.item_id}")

      {:error, reason} ->
        Logger.error("Failed to request archive for item #{item.item_id}: #{inspect(reason)}")
    end
  end
end
