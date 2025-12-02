defmodule Epoch.Automation.ArchiveProcessor do
  @moduledoc """
  GenServer that automatically processes pending archive requests.

  Subscribes to the stream_type:cart PubSub topic to receive
  ItemArchiveRequested events. For each request, it archives the item
  by emitting an ItemArchived event.

  This processor can also be triggered to process all pending items
  from the ItemsToArchive read model on startup or on demand.
  """

  use GenServer
  require Logger

  alias Epoch.Cart
  alias Epoch.Cart.Events.{ItemArchived, ItemArchiveRequested}
  alias Epoch.Cart.ItemsToArchive
  alias Epoch.EventStore

  @pubsub Epoch.PubSub
  @topic "stream_type:cart"

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Triggers processing of all pending archive requests.
  """
  def process_pending(server \\ __MODULE__) do
    GenServer.cast(server, :process_pending)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to cart stream events
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    Logger.info("ArchiveProcessor started and subscribed to #{@topic}")

    # Process any pending items on startup
    send(self(), :process_pending_on_startup)

    {:ok, %{}}
  end

  @impl true
  def handle_cast(:process_pending, state) do
    process_all_pending()
    {:noreply, state}
  end

  @impl true
  def handle_info(:process_pending_on_startup, state) do
    process_all_pending()
    {:noreply, state}
  end

  def handle_info({:events_appended, stream_name, envelopes}, state) do
    Logger.debug("ArchiveProcessor received events from #{stream_name}")

    # Process each ItemArchiveRequested event immediately
    Enum.each(envelopes, fn envelope ->
      case envelope.event do
        %ItemArchiveRequested{} = event ->
          archive_item(event)

        _ ->
          :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warning("ArchiveProcessor received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  # Private Functions

  defp process_all_pending do
    Logger.debug("Processing all pending archive requests")

    # Build the ItemsToArchive read model from all cart streams
    items_state = build_items_to_archive_state()

    # Get all pending items
    pending = ItemsToArchive.all_pending(items_state)

    Logger.info("Found #{length(pending)} pending archive requests to process")

    # Archive each pending item
    Enum.each(pending, fn item ->
      archive_item_from_pending(item)
    end)
  end

  defp build_items_to_archive_state do
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
          e.__struct__ in [ItemArchiveRequested, ItemArchived]
        end)
      end)

    # Project events into ItemsToArchive state
    ItemsToArchive.project(events)
  end

  defp archive_item(%ItemArchiveRequested{} = event) do
    result =
      Cart.archive_item(%{
        cart_id: event.cart_id,
        item_id: event.item_id,
        reason: event.reason
      })

    case result do
      {:ok, _archived_event} ->
        Logger.info("Archived item #{event.item_id} in cart #{event.cart_id}")

      {:error, :already_archived} ->
        Logger.debug("Item #{event.item_id} already archived")

      {:error, reason} ->
        Logger.error("Failed to archive item #{event.item_id}: #{inspect(reason)}")
    end
  end

  defp archive_item_from_pending(item) do
    result =
      Cart.archive_item(%{
        cart_id: item.cart_id,
        item_id: item.item_id,
        reason: item.reason
      })

    case result do
      {:ok, _archived_event} ->
        Logger.info("Archived pending item #{item.item_id} in cart #{item.cart_id}")

      {:error, :already_archived} ->
        Logger.debug("Pending item #{item.item_id} already archived")

      {:error, reason} ->
        Logger.error("Failed to archive pending item #{item.item_id}: #{inspect(reason)}")
    end
  end
end
