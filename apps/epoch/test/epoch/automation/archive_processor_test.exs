defmodule Epoch.Automation.ArchiveProcessorTest do
  use ExUnit.Case, async: false

  alias Epoch.Automation.ArchiveProcessor
  alias Epoch.Cart.Events.{ItemArchived, ItemArchiveRequested}
  alias Epoch.EventStore

  setup do
    # Use existing application-started EventStore
    :ok
  end

  describe "when processing archive requests" do
    test "given ItemArchiveRequested event then archives the item" do
      cart_id = "cart-archive-test-#{System.unique_integer([:positive])}"
      item_id = "item-#{System.unique_integer([:positive])}"

      # Create an archive request
      request_event = %ItemArchiveRequested{
        cart_id: cart_id,
        product_id: "espresso-blend",
        item_id: item_id,
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      stream_name = "cart-#{cart_id}"
      {:ok, _} = EventStore.append_to_stream(stream_name, [request_event])

      # Start the processor with unique id for proper cleanup
      processor_id = :"ArchiveProcessor_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {ArchiveProcessor, name: processor_id},
          id: processor_id
        )

      # Wait for processor to handle the pending item on startup
      Process.sleep(100)

      # Verify ItemArchived was emitted
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)

      archived_events =
        Enum.filter(events, fn e -> e.__struct__ == ItemArchived end)

      assert length(archived_events) >= 1

      archived = hd(archived_events)
      assert archived.cart_id == cart_id
      assert archived.item_id == item_id

      stop_supervised(processor_id)
    end

    test "given multiple pending items then processes all" do
      cart1_id = "cart-multi-archive-1-#{System.unique_integer([:positive])}"
      cart2_id = "cart-multi-archive-2-#{System.unique_integer([:positive])}"
      item1_id = "item-multi-1-#{System.unique_integer([:positive])}"
      item2_id = "item-multi-2-#{System.unique_integer([:positive])}"

      # Create archive requests in two carts
      request1 = %ItemArchiveRequested{
        cart_id: cart1_id,
        product_id: "espresso-blend",
        item_id: item1_id,
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      request2 = %ItemArchiveRequested{
        cart_id: cart2_id,
        product_id: "french-roast",
        item_id: item2_id,
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("cart-#{cart1_id}", [request1])
      {:ok, _} = EventStore.append_to_stream("cart-#{cart2_id}", [request2])

      # Start the processor with unique id for proper cleanup
      processor_id = :"ArchiveProcessor_multi_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {ArchiveProcessor, name: processor_id},
          id: processor_id
        )

      # Wait for processing
      Process.sleep(100)

      # Verify both items were archived
      {:ok, %{events: cart1_events}} = EventStore.read_stream("cart-#{cart1_id}")
      {:ok, %{events: cart2_events}} = EventStore.read_stream("cart-#{cart2_id}")

      cart1_archived = Enum.filter(cart1_events, fn e -> e.__struct__ == ItemArchived end)
      cart2_archived = Enum.filter(cart2_events, fn e -> e.__struct__ == ItemArchived end)

      assert length(cart1_archived) >= 1
      assert length(cart2_archived) >= 1

      stop_supervised(processor_id)
    end
  end

  describe "when receiving live events" do
    test "given new ItemArchiveRequested then archives immediately" do
      # Start the processor first with unique id for proper cleanup
      processor_id = :"ArchiveProcessor_live_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {ArchiveProcessor, name: processor_id},
          id: processor_id
        )

      Process.sleep(50)

      # Now create a new archive request (processor should receive via PubSub)
      cart_id = "cart-live-#{System.unique_integer([:positive])}"
      item_id = "item-live-#{System.unique_integer([:positive])}"

      request_event = %ItemArchiveRequested{
        cart_id: cart_id,
        product_id: "espresso-blend",
        item_id: item_id,
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      stream_name = "cart-#{cart_id}"
      {:ok, _} = EventStore.append_to_stream(stream_name, [request_event])

      # Wait for processor to handle via PubSub
      Process.sleep(100)

      # Verify ItemArchived was emitted
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)

      archived_events =
        Enum.filter(events, fn e -> e.__struct__ == ItemArchived end)

      assert length(archived_events) >= 1

      stop_supervised(processor_id)
    end
  end
end
