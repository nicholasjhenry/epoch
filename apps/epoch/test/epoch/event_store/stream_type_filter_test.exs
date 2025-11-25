defmodule Epoch.EventStore.StreamTypeFilterTest do
  use ExUnit.Case, async: false

  alias Epoch.EventStore

  # Test event structs
  defmodule OrderPlaced do
    defstruct [:order_id, :product, :quantity]
  end

  defmodule CartCreated do
    defstruct [:cart_id, :user_id]
  end

  defmodule UserRegistered do
    defstruct [:user_id, :email]
  end

  # Helper to create unique stream names
  defp unique_stream_name(type, id \\ nil) do
    id = id || System.unique_integer([:positive])
    "#{type}-#{id}"
  end

  # ==========================================================================
  # Phase 2: Foundational - extract_stream_type/1 tests
  # ==========================================================================

  describe "extract_stream_type/1" do
    test "extracts type from standard stream name (order-123)" do
      assert EventStore.extract_stream_type("order-123") == "order"
    end

    test "extracts type from stream name with multiple hyphens (order-456-item)" do
      # Should split on FIRST hyphen only
      assert EventStore.extract_stream_type("order-456-item") == "order"
    end

    test "returns full name when no hyphen present" do
      assert EventStore.extract_stream_type("payment") == "payment"
    end

    test "returns empty string for empty input" do
      assert EventStore.extract_stream_type("") == ""
    end

    test "extracts different stream types correctly" do
      assert EventStore.extract_stream_type("cart-abc") == "cart"
      assert EventStore.extract_stream_type("user-u001") == "user"
      assert EventStore.extract_stream_type("inventory-warehouse-1") == "inventory"
    end
  end

  # ==========================================================================
  # Phase 3: User Story 1 - read_by_stream_type/3 filtering tests
  # ==========================================================================

  describe "read_by_stream_type/3 filtering" do
    test "returns events from all matching streams" do
      # Create order streams
      order_stream1 = unique_stream_name("order")
      order_stream2 = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(order_stream1, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(order_stream2, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      {:ok, result} = EventStore.read_by_stream_type("order")

      # Should have events from both order streams
      assert result.total >= 2

      order_events =
        Enum.filter(result.events, fn e ->
          e.stream_name == order_stream1 or e.stream_name == order_stream2
        end)

      assert length(order_events) == 2
    end

    test "excludes events from non-matching streams" do
      order_stream = unique_stream_name("order")
      cart_stream = unique_stream_name("cart")

      {:ok, _} =
        EventStore.append_to_stream(order_stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(cart_stream, [%CartCreated{cart_id: "c1", user_id: "u1"}])

      {:ok, result} = EventStore.read_by_stream_type("order")

      # Should only have order events, not cart events
      stream_names = Enum.map(result.events, & &1.stream_name)
      refute Enum.any?(stream_names, &String.starts_with?(&1, "cart-"))
    end

    test "results are ordered by global position (chronological)" do
      order_stream1 = unique_stream_name("order")
      order_stream2 = unique_stream_name("order")

      # Append in specific order
      {:ok, _} =
        EventStore.append_to_stream(order_stream1, [
          %OrderPlaced{order_id: "first", product: "A", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(order_stream2, [
          %OrderPlaced{order_id: "second", product: "B", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(order_stream1, [
          %OrderPlaced{order_id: "third", product: "C", quantity: 1}
        ])

      {:ok, result} = EventStore.read_by_stream_type("order")

      # Filter to just our test streams and verify order
      our_events =
        Enum.filter(result.events, fn e ->
          e.stream_name == order_stream1 or e.stream_name == order_stream2
        end)

      positions = Enum.map(our_events, & &1.metadata.log_position)
      assert positions == Enum.sort(positions), "Events should be in chronological order"
    end

    test "non-existent type returns empty list (not error)" do
      {:ok, result} =
        EventStore.read_by_stream_type("nonexistent_type_#{System.unique_integer([:positive])}")

      assert result.events == []
      assert result.total == 0
      assert result.has_more == false
    end
  end

  describe "read_by_stream_type/3 validation" do
    test "empty stream_type is rejected with error" do
      {:error, message} = EventStore.read_by_stream_type("")
      assert message == "Stream type is required"
    end

    test "whitespace-only stream_type is rejected" do
      {:error, message} = EventStore.read_by_stream_type("   ")
      assert message == "Stream type is required"
    end

    test "page < 1 is rejected" do
      {:error, message} = EventStore.read_by_stream_type("order", page: 0)
      assert message == "Page must be at least 1"
    end

    test "page_size < 1 is rejected" do
      {:error, message} = EventStore.read_by_stream_type("order", page_size: 0)
      assert message == "Page size must be between 1 and 100"
    end

    test "page_size > 100 is rejected" do
      {:error, message} = EventStore.read_by_stream_type("order", page_size: 101)
      assert message == "Page size must be between 1 and 100"
    end
  end

  # ==========================================================================
  # Phase 4: User Story 2 - PubSub broadcast tests
  # ==========================================================================

  describe "PubSub broadcast on append" do
    test "new events trigger broadcast for matching type topic" do
      stream_name = unique_stream_name("order")
      topic = "stream_type:order"

      # Subscribe to the topic
      Phoenix.PubSub.subscribe(Epoch.PubSub, topic)

      # Append event
      event = %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
      {:ok, _} = EventStore.append_to_stream(stream_name, [event])

      # Should receive broadcast with EventEnvelope structs
      assert_receive {:events_appended, ^stream_name, [envelope]}, 1000
      assert %Epoch.EventStore.EventEnvelope{event: ^event} = envelope
    end

    test "broadcast message format is {:events_appended, stream_name, envelopes}" do
      stream_name = unique_stream_name("cart")
      topic = "stream_type:cart"

      Phoenix.PubSub.subscribe(Epoch.PubSub, topic)

      event1 = %CartCreated{cart_id: "c1", user_id: "u1"}
      event2 = %CartCreated{cart_id: "c2", user_id: "u2"}
      {:ok, _} = EventStore.append_to_stream(stream_name, [event1, event2])

      assert_receive {:events_appended, received_stream, received_envelopes}, 1000
      assert received_stream == stream_name
      # Envelopes contain the original events wrapped with metadata
      assert [env1, env2] = received_envelopes
      assert %Epoch.EventStore.EventEnvelope{event: ^event1, metadata: %{log_position: _}} = env1
      assert %Epoch.EventStore.EventEnvelope{event: ^event2, metadata: %{log_position: _}} = env2
    end

    test "does not broadcast to non-matching type topics" do
      order_stream = unique_stream_name("order")
      cart_topic = "stream_type:cart"

      Phoenix.PubSub.subscribe(Epoch.PubSub, cart_topic)

      # Append to order stream
      event = %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
      {:ok, _} = EventStore.append_to_stream(order_stream, [event])

      # Should NOT receive broadcast on cart topic
      refute_receive {:events_appended, _, _}, 100
    end
  end

  # ==========================================================================
  # Phase 5: User Story 3 - Pagination tests
  # ==========================================================================

  describe "read_by_stream_type/3 pagination" do
    # Use unique type prefixes to avoid cross-test pollution
    defp unique_type, do: "pagetype#{System.unique_integer([:positive])}"

    test "default page size is 20" do
      type = unique_type()

      # Create 25 events across multiple streams of this type
      for i <- 1..25 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1)

      # Default page_size is 20
      assert length(result.events) == 20
      assert result.has_more == true
      assert result.total == 25
    end

    test "custom page size returns correct number of events" do
      type = unique_type()

      # Create 15 events
      for i <- 1..15 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1, page_size: 5)

      assert length(result.events) == 5
      assert result.has_more == true
      assert result.total == 15
    end

    test "page boundaries return correct slice of events" do
      type = unique_type()

      # Create 10 events - store order_ids to verify slice
      for i <- 1..10 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      # Page 1: events 1-3
      {:ok, page1} = EventStore.read_by_stream_type(type, page: 1, page_size: 3)
      assert length(page1.events) == 3
      # Events are sorted by log_position, so first 3
      order_ids_page1 = Enum.map(page1.events, fn e -> e.event.order_id end)
      assert order_ids_page1 == ["1", "2", "3"]

      # Page 2: events 4-6
      {:ok, page2} = EventStore.read_by_stream_type(type, page: 2, page_size: 3)
      assert length(page2.events) == 3
      order_ids_page2 = Enum.map(page2.events, fn e -> e.event.order_id end)
      assert order_ids_page2 == ["4", "5", "6"]

      # Page 3: events 7-9
      {:ok, page3} = EventStore.read_by_stream_type(type, page: 3, page_size: 3)
      assert length(page3.events) == 3
      order_ids_page3 = Enum.map(page3.events, fn e -> e.event.order_id end)
      assert order_ids_page3 == ["7", "8", "9"]

      # Page 4: event 10 only
      {:ok, page4} = EventStore.read_by_stream_type(type, page: 4, page_size: 3)
      assert length(page4.events) == 1
      order_ids_page4 = Enum.map(page4.events, fn e -> e.event.order_id end)
      assert order_ids_page4 == ["10"]
    end

    test "has_more flag is true when more events exist beyond current page" do
      type = unique_type()

      # Create 5 events
      for i <- 1..5 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      # Page 1 with 3 per page: has_more should be true (2 more events)
      {:ok, result1} = EventStore.read_by_stream_type(type, page: 1, page_size: 3)
      assert result1.has_more == true

      # Page 2 with 3 per page: has_more should be false (no more events)
      {:ok, result2} = EventStore.read_by_stream_type(type, page: 2, page_size: 3)
      assert result2.has_more == false
    end

    test "has_more is false when exactly filling last page" do
      type = unique_type()

      # Create exactly 6 events
      for i <- 1..6 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      # Page 2 with 3 per page: exactly 6 events, so page 2 is the last page
      {:ok, result} = EventStore.read_by_stream_type(type, page: 2, page_size: 3)
      assert length(result.events) == 3
      assert result.has_more == false
    end

    test "requesting page beyond results returns empty list" do
      type = unique_type()

      # Create 3 events
      for i <- 1..3 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      # Page 5 with default page_size of 20: way beyond available events
      {:ok, result} = EventStore.read_by_stream_type(type, page: 5, page_size: 20)
      assert result.events == []
      assert result.has_more == false
      assert result.total == 3
    end
  end

  # ==========================================================================
  # Phase 6: User Story 4 - event_with_stream structure tests
  # ==========================================================================

  describe "event_with_stream structure" do
    # Use unique type prefixes to avoid cross-test pollution
    defp unique_structtype, do: "structtype#{System.unique_integer([:positive])}"

    test "each event in result includes stream_name field" do
      type = unique_structtype()
      stream1 = unique_stream_name(type)
      stream2 = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream1, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(stream2, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1)

      # Each event should have stream_name, event, and metadata
      for event <- result.events do
        assert Map.has_key?(event, :stream_name)
        assert Map.has_key?(event, :event)
        assert Map.has_key?(event, :metadata)
      end
    end

    test "stream_name matches source stream for each event" do
      type = unique_structtype()
      stream1 = unique_stream_name(type)
      stream2 = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream1, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(stream2, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1)

      # Find events by order_id and verify stream_name
      event1 = Enum.find(result.events, fn e -> e.event.order_id == "1" end)
      event2 = Enum.find(result.events, fn e -> e.event.order_id == "2" end)

      assert event1.stream_name == stream1
      assert event2.stream_name == stream2
    end

    test "event contains original domain event data" do
      type = unique_structtype()
      stream = unique_stream_name(type)
      original_event = %OrderPlaced{order_id: "test-123", product: "TestProduct", quantity: 5}

      {:ok, _} = EventStore.append_to_stream(stream, [original_event])

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1)

      # Find our event
      found = Enum.find(result.events, fn e -> e.event.order_id == "test-123" end)

      assert found.event == original_event
    end

    test "metadata includes log_position for ordering" do
      type = unique_structtype()
      stream = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, result} = EventStore.read_by_stream_type(type, page: 1)

      event = hd(result.events)
      assert is_integer(event.metadata.log_position)
      assert event.metadata.log_position > 0
    end
  end
end
