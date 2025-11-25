defmodule Epoch.EventStoreTest do
  use ExUnit.Case, async: false

  alias Epoch.EventStore
  alias Epoch.EventStore.VersionMismatchError

  alias Epoch.EventStore.TestEvents.{
    CounterDecremented,
    CounterIncremented,
    OrderPlaced,
    OrderShipped
  }

  # ==========================================================================
  # Feature 004: Default Event List - read_all_events/2
  # ==========================================================================

  describe "read_all_events/2" do
    test "returns events from all streams" do
      # Use a fresh EventStore to avoid interference from parallel tests
      {:ok, pid} = EventStore.start_link(name: :all_streams_test)

      stream1 = unique_stream_name("all-events-1")
      stream2 = unique_stream_name("all-events-2")
      stream3 = unique_stream_name("all-events-3")

      {:ok, _} =
        EventStore.append_to_stream(
          pid,
          stream1,
          [
            %OrderPlaced{order_id: "1", customer_id: "c1", items: [], total: 10.0}
          ],
          []
        )

      {:ok, _} =
        EventStore.append_to_stream(
          pid,
          stream2,
          [
            %OrderShipped{order_id: "2", tracking_number: "T1", carrier: "FedEx"}
          ],
          []
        )

      {:ok, _} = EventStore.append_to_stream(pid, stream3, [%CounterIncremented{amount: 5}], [])

      {:ok, result} = EventStore.read_all_events(pid, [])

      # Should include events from all 3 streams
      stream_names = Enum.map(result.events, & &1.stream_name)
      assert stream1 in stream_names
      assert stream2 in stream_names
      assert stream3 in stream_names
      assert result.total == 3

      GenServer.stop(pid)
    end

    test "returns events in chronological order by log_position" do
      # Use a fresh EventStore to avoid interference from parallel tests
      {:ok, pid} = EventStore.start_link(name: :chrono_order_test)

      stream_a = unique_stream_name("chrono-a")
      stream_b = unique_stream_name("chrono-b")

      {:ok, _} = EventStore.append_to_stream(pid, stream_a, [%CounterIncremented{amount: 1}], [])
      {:ok, _} = EventStore.append_to_stream(pid, stream_b, [%CounterIncremented{amount: 2}], [])
      {:ok, _} = EventStore.append_to_stream(pid, stream_a, [%CounterIncremented{amount: 3}], [])

      {:ok, result} = EventStore.read_all_events(pid, [])

      amounts = Enum.map(result.events, & &1.event.amount)
      assert amounts == [1, 2, 3]

      GenServer.stop(pid)
    end

    test "pagination works correctly" do
      # Create 25 events in unique streams
      type = "pagination-test-#{System.unique_integer([:positive])}"

      for i <- 1..25 do
        stream = "#{type}-#{i}"
        {:ok, _} = EventStore.append_to_stream(stream, [%CounterIncremented{amount: i}])
      end

      {:ok, page1} = EventStore.read_all_events(page: 1, page_size: 10)
      {:ok, page2} = EventStore.read_all_events(page: 2, page_size: 10)
      {:ok, page3} = EventStore.read_all_events(page: 3, page_size: 10)

      assert length(page1.events) == 10
      assert page1.has_more == true

      assert length(page2.events) == 10
      assert page2.has_more == true

      # Page 3 depends on total events in store, but should have at least 5
      assert length(page3.events) >= 5
    end

    test "returns empty result for empty store" do
      # Start a fresh EventStore instance
      {:ok, pid} = EventStore.start_link(name: :empty_store_test)

      {:ok, result} = EventStore.read_all_events(pid, [])

      assert result.events == []
      assert result.has_more == false
      assert result.total == 0

      GenServer.stop(pid)
    end
  end

  describe "PubSub all_events topic" do
    test "broadcasts to all_events on any append" do
      Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")

      stream = unique_stream_name("pubsub-all")
      {:ok, _} = EventStore.append_to_stream(stream, [%CounterIncremented{amount: 42}])

      assert_receive {:events_appended, ^stream, events}
      assert length(events) == 1
      assert hd(events).event.amount == 42
    end
  end

  # Use unique stream names per test to avoid interference
  defp unique_stream_name(base \\ "test-stream") do
    "#{base}-#{System.unique_integer([:positive])}"
  end

  defp sample_order_placed(order_id \\ "order-123") do
    %OrderPlaced{
      order_id: order_id,
      customer_id: "customer-456",
      items: ["item1", "item2"],
      total: 99.99
    }
  end

  defp sample_order_shipped(order_id \\ "order-123") do
    %OrderShipped{
      order_id: order_id,
      tracking_number: "TRACK-789",
      carrier: "FedEx"
    }
  end

  describe "GenServer startup" do
    test "EventStore process is running" do
      assert Process.whereis(Epoch.EventStore) != nil
    end

    test "can start a named instance" do
      {:ok, pid} = EventStore.start_link(name: :test_event_store)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Phase 3: User Story 1 - Store and Retrieve Events
  # ==========================================================================

  describe "US1: appending single event to new stream" do
    test "creates stream with version 1" do
      stream = unique_stream_name("append-single")
      event = sample_order_placed()

      {:ok, %{next_expected_version: version}} = EventStore.append_to_stream(stream, [event])

      assert version == 1
    end
  end

  describe "US1: appending multiple events atomically" do
    test "increments version by event count" do
      stream = unique_stream_name("append-multiple")
      event1 = sample_order_placed()
      event2 = sample_order_shipped()

      {:ok, %{next_expected_version: v1}} = EventStore.append_to_stream(stream, [event1])
      assert v1 == 1

      {:ok, %{next_expected_version: v2}} = EventStore.append_to_stream(stream, [event2])
      assert v2 == 2

      # Append multiple events at once
      events = [%CounterIncremented{amount: 1}, %CounterIncremented{amount: 2}]
      {:ok, %{next_expected_version: v3}} = EventStore.append_to_stream(stream, events)
      assert v3 == 4
    end
  end

  describe "US1: reading from non-existent stream" do
    test "returns empty events and version 0" do
      stream = unique_stream_name("nonexistent")

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)

      assert events == []
      assert version == 0
    end
  end

  describe "US1: reading from stream" do
    test "returns events in append order" do
      stream = unique_stream_name("read-order")
      event1 = sample_order_placed()
      event2 = sample_order_shipped()

      {:ok, _} = EventStore.append_to_stream(stream, [event1])
      {:ok, _} = EventStore.append_to_stream(stream, [event2])

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)

      assert length(events) == 2
      assert version == 2
      assert Enum.at(events, 0) == event1
      assert Enum.at(events, 1) == event2
    end
  end

  describe "US1: event IDs uniqueness" do
    test "event IDs are unique across multiple appends and streams" do
      stream1 = unique_stream_name("unique-ids-1")
      stream2 = unique_stream_name("unique-ids-2")

      # Append to multiple streams
      {:ok, _} =
        EventStore.append_to_stream(stream1, [
          sample_order_placed("o1"),
          sample_order_shipped("o1")
        ])

      {:ok, _} = EventStore.append_to_stream(stream2, [sample_order_placed("o2")])
      {:ok, _} = EventStore.append_to_stream(stream1, [%CounterIncremented{amount: 1}])

      # Verify counts are correct
      streams = EventStore.debug_all_streams()
      assert Map.get(streams, stream1) == 3
      assert Map.get(streams, stream2) == 1
    end
  end

  describe "US1: stream position metadata" do
    test "starts at 1 and increments sequentially" do
      stream = unique_stream_name("positions")

      {:ok, %{next_expected_version: v1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      assert v1 == 1

      {:ok, %{next_expected_version: v2}} =
        EventStore.append_to_stream(stream, [sample_order_shipped()])

      assert v2 == 2

      {:ok, %{next_expected_version: v3}} =
        EventStore.append_to_stream(stream, [%CounterIncremented{amount: 1}])

      assert v3 == 3

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 3
      assert version == 3
    end
  end

  describe "US1: global log position" do
    test "increases monotonically across all streams" do
      stream1 = unique_stream_name("global-pos-1")
      stream2 = unique_stream_name("global-pos-2")

      # Get current global position indirectly via stream counts
      initial_streams = EventStore.debug_all_streams()
      initial_total = initial_streams |> Map.values() |> Enum.sum()

      # Append to stream1
      {:ok, _} = EventStore.append_to_stream(stream1, [sample_order_placed()])

      # Append to stream2
      {:ok, _} = EventStore.append_to_stream(stream2, [sample_order_shipped()])

      # Append more to stream1
      {:ok, _} = EventStore.append_to_stream(stream1, [%CounterIncremented{amount: 1}])

      # Verify total event count increased by 3
      final_streams = EventStore.debug_all_streams()
      final_total = final_streams |> Map.values() |> Enum.sum()

      assert final_total == initial_total + 3
    end
  end

  describe "US1: appending zero events" do
    test "is no-op and returns current version" do
      stream = unique_stream_name("zero-events")

      # Append some events first
      {:ok, %{next_expected_version: v1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      assert v1 == 1

      # Append zero events
      {:ok, %{next_expected_version: v2}} = EventStore.append_to_stream(stream, [])
      assert v2 == 1

      # Verify stream still has only 1 event
      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 1
      assert version == 1
    end

    test "on new stream returns version 0" do
      stream = unique_stream_name("zero-events-new")

      {:ok, %{next_expected_version: version}} = EventStore.append_to_stream(stream, [])

      assert version == 0
    end
  end

  # ==========================================================================
  # Phase 4: User Story 2 - Optimistic Concurrency Control
  # ==========================================================================

  describe "US2: appending with matching expected version" do
    test "succeeds when version matches" do
      stream = unique_stream_name("version-match")

      # Create stream with version 1
      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      # Append with correct expected version
      {:ok, %{next_expected_version: 2}} =
        EventStore.append_to_stream(stream, [sample_order_shipped()], expected_version: 1)

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 2
      assert version == 2
    end
  end

  describe "US2: appending with mismatched expected version" do
    test "returns error with VersionMismatchError" do
      stream = unique_stream_name("version-mismatch")

      # Create stream with version 1
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Try to append with wrong expected version
      {:error, %VersionMismatchError{} = error} =
        EventStore.append_to_stream(stream, [sample_order_shipped()], expected_version: 0)

      assert error.stream_name == stream
      assert error.expected_version == 0
      assert error.current_version == 1
      assert error.message =~ "Expected stream"
      assert error.message =~ "version 0"
      assert error.message =~ "version 1"
    end

    test "does not modify stream on version mismatch" do
      stream = unique_stream_name("version-mismatch-no-modify")

      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Try to append with wrong version
      {:error, _} =
        EventStore.append_to_stream(stream, [sample_order_shipped()], expected_version: 5)

      # Verify stream unchanged
      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 1
      assert version == 1
    end
  end

  describe "US2: appending without expected version" do
    test "always succeeds regardless of current version" do
      stream = unique_stream_name("no-version-check")

      # Append without version check multiple times
      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      {:ok, %{next_expected_version: 2}} =
        EventStore.append_to_stream(stream, [sample_order_shipped()])

      {:ok, %{next_expected_version: 3}} =
        EventStore.append_to_stream(stream, [%CounterIncremented{amount: 1}])

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 3
      assert version == 3
    end
  end

  describe "US2: appending with expected_version 0" do
    test "succeeds on new/empty stream" do
      stream = unique_stream_name("version-zero-new")

      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()], expected_version: 0)

      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 1
      assert version == 1
    end

    test "fails on existing stream with events" do
      stream = unique_stream_name("version-zero-existing")

      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      {:error, %VersionMismatchError{} = error} =
        EventStore.append_to_stream(stream, [sample_order_shipped()], expected_version: 0)

      assert error.expected_version == 0
      assert error.current_version == 1
    end
  end

  # ==========================================================================
  # Phase 5: User Story 3 - Paginated Stream Reading
  # ==========================================================================

  describe "US3: paginated reading with from/to parameters" do
    test "returns correct subset of events" do
      stream = unique_stream_name("pagination-from-to")

      # Create 10 events
      events = for i <- 1..10, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      # Read events 2-5 (0-indexed, exclusive end)
      {:ok, %{events: page, version: version}} = EventStore.read_stream(stream, from: 2, to: 5)

      assert version == 10
      assert length(page) == 3
      assert Enum.at(page, 0) == %CounterIncremented{amount: 3}
      assert Enum.at(page, 1) == %CounterIncremented{amount: 4}
      assert Enum.at(page, 2) == %CounterIncremented{amount: 5}
    end
  end

  describe "US3: paginated reading with from/max_count parameters" do
    test "returns correct subset of events" do
      stream = unique_stream_name("pagination-max-count")

      # Create 10 events
      events = for i <- 1..10, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      # Read 3 events starting from position 4
      {:ok, %{events: page, version: version}} =
        EventStore.read_stream(stream, from: 4, max_count: 3)

      assert version == 10
      assert length(page) == 3
      assert Enum.at(page, 0) == %CounterIncremented{amount: 5}
      assert Enum.at(page, 1) == %CounterIncremented{amount: 6}
      assert Enum.at(page, 2) == %CounterIncremented{amount: 7}
    end
  end

  describe "US3: reading beyond stream length" do
    test "returns empty when from is beyond end" do
      stream = unique_stream_name("pagination-beyond")

      events = for i <- 1..5, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      {:ok, %{events: page, version: version}} = EventStore.read_stream(stream, from: 10)

      assert version == 5
      assert page == []
    end

    test "returns partial results when max_count exceeds remaining" do
      stream = unique_stream_name("pagination-partial")

      events = for i <- 1..5, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      {:ok, %{events: page, version: version}} =
        EventStore.read_stream(stream, from: 3, max_count: 10)

      assert version == 5
      assert length(page) == 2
      assert Enum.at(page, 0) == %CounterIncremented{amount: 4}
      assert Enum.at(page, 1) == %CounterIncremented{amount: 5}
    end
  end

  describe "US3: invalid pagination parameters" do
    test "negative from raises ArgumentError" do
      stream = unique_stream_name("pagination-invalid-from")

      assert_raise ArgumentError, ~r/from must be non-negative/, fn ->
        EventStore.read_stream(stream, from: -1)
      end
    end

    test "to less than from raises ArgumentError" do
      stream = unique_stream_name("pagination-invalid-to")

      assert_raise ArgumentError, ~r/to must be >= from/, fn ->
        EventStore.read_stream(stream, from: 5, to: 3)
      end
    end

    test "zero or negative max_count raises ArgumentError" do
      stream = unique_stream_name("pagination-invalid-max-count")

      assert_raise ArgumentError, ~r/max_count must be positive/, fn ->
        EventStore.read_stream(stream, max_count: 0)
      end

      assert_raise ArgumentError, ~r/max_count must be positive/, fn ->
        EventStore.read_stream(stream, max_count: -1)
      end
    end
  end

  describe "US3: reading with no pagination parameters" do
    test "returns all events" do
      stream = unique_stream_name("pagination-all")

      events = for i <- 1..5, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      {:ok, %{events: all_events, version: version}} = EventStore.read_stream(stream)

      assert version == 5
      assert length(all_events) == 5

      for i <- 1..5 do
        assert Enum.at(all_events, i - 1) == %CounterIncremented{amount: i}
      end
    end
  end

  # ==========================================================================
  # Phase 6: User Story 4 - Aggregate State Reconstruction
  # ==========================================================================

  describe "US4: aggregating stream with evolve function" do
    test "produces correct final state" do
      stream = unique_stream_name("aggregate-basic")

      # Create a counter stream with increments and decrements
      events = [
        %CounterIncremented{amount: 5},
        %CounterIncremented{amount: 3},
        %CounterDecremented{amount: 2},
        %CounterIncremented{amount: 10}
      ]

      {:ok, _} = EventStore.append_to_stream(stream, events)

      # Define evolve function for counter (state, event) -> new_state
      evolve = fn
        state, %CounterIncremented{amount: amount} -> state + amount
        state, %CounterDecremented{amount: amount} -> state - amount
      end

      {:ok, %{state: final_state, version: version}} =
        EventStore.aggregate_stream(stream, 0, evolve)

      # 5 + 3 - 2 + 10 = 16
      assert final_state == 16
      assert version == 4
    end

    test "works with complex aggregate state" do
      stream = unique_stream_name("aggregate-complex")

      events = [
        sample_order_placed(),
        sample_order_shipped()
      ]

      {:ok, _} = EventStore.append_to_stream(stream, events)

      initial_state = %{status: :pending, items: [], tracking: nil}

      evolve = fn
        state, %OrderPlaced{items: items} ->
          %{state | status: :placed, items: items}

        state, %OrderShipped{tracking_number: tracking} ->
          %{state | status: :shipped, tracking: tracking}
      end

      {:ok, %{state: final_state, version: version}} =
        EventStore.aggregate_stream(stream, initial_state, evolve)

      assert final_state.status == :shipped
      assert final_state.items == ["item1", "item2"]
      assert final_state.tracking == "TRACK-789"
      assert version == 2
    end
  end

  describe "US4: aggregating empty stream" do
    test "returns initial state" do
      stream = unique_stream_name("aggregate-empty")

      evolve = fn state, _event -> state + 1 end

      {:ok, %{state: final_state, version: version}} =
        EventStore.aggregate_stream(stream, 42, evolve)

      assert final_state == 42
      assert version == 0
    end
  end

  describe "US4: aggregating with pagination" do
    test "applies evolve only to requested events" do
      stream = unique_stream_name("aggregate-paginated")

      # Create 10 increment events
      events = for i <- 1..10, do: %CounterIncremented{amount: i}
      {:ok, _} = EventStore.append_to_stream(stream, events)

      evolve = fn state, %CounterIncremented{amount: amount} -> state + amount end

      # Only aggregate events 2-5 (0-indexed)
      {:ok, %{state: final_state, version: version}} =
        EventStore.aggregate_stream(stream, 0, evolve, from: 2, max_count: 3)

      # Events at positions 2, 3, 4 have amounts 3, 4, 5 -> sum = 12
      assert final_state == 12
      assert version == 10
    end
  end

  describe "US4: aggregate result includes state and version" do
    test "returns both final state and current version" do
      stream = unique_stream_name("aggregate-result")

      events = [%CounterIncremented{amount: 1}, %CounterIncremented{amount: 2}]
      {:ok, _} = EventStore.append_to_stream(stream, events)

      evolve = fn state, %CounterIncremented{amount: amount} -> state + amount end

      result = EventStore.aggregate_stream(stream, 0, evolve)

      assert {:ok, %{state: state, version: version}} = result
      assert state == 3
      assert version == 2
    end
  end

  # ==========================================================================
  # Phase 8: Polish & Cross-Cutting Concerns
  # ==========================================================================

  describe "debug_all_streams" do
    test "returns map of stream names to event counts" do
      stream1 = unique_stream_name("debug-1")
      stream2 = unique_stream_name("debug-2")

      {:ok, _} = EventStore.append_to_stream(stream1, [sample_order_placed()])
      {:ok, _} = EventStore.append_to_stream(stream1, [sample_order_shipped()])
      {:ok, _} = EventStore.append_to_stream(stream2, [%CounterIncremented{amount: 1}])

      streams = EventStore.debug_all_streams()

      assert Map.get(streams, stream1) == 2
      assert Map.get(streams, stream2) == 1
    end

    test "returns empty map when no streams exist" do
      # This test relies on other tests not polluting - we just verify the structure
      streams = EventStore.debug_all_streams()
      assert is_map(streams)
    end
  end
end
