defmodule Epoch.EventStore.ConcurrencyTest do
  use ExUnit.Case, async: false

  alias Epoch.EventStore
  alias Epoch.EventStore.TestEvents.{OrderPlaced, OrderShipped}
  alias Epoch.EventStore.VersionMismatchError

  defp unique_stream_name(base \\ "concurrency") do
    "#{base}-#{System.unique_integer([:positive])}"
  end

  defp sample_order_placed(order_id \\ "order-123") do
    %OrderPlaced{
      order_id: order_id,
      customer_id: "customer-456",
      items: ["item1"],
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

  describe "US2 Integration: concurrent appends to same stream with version checking" do
    test "one succeeds, one fails with version mismatch" do
      stream = unique_stream_name("concurrent-same-stream")

      # Set up stream with initial event
      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      # Simulate two concurrent processes trying to append with same expected version
      # In practice, they would race, but we can test the behavior sequentially

      # First append succeeds
      {:ok, %{next_expected_version: 2}} =
        EventStore.append_to_stream(stream, [sample_order_shipped()], expected_version: 1)

      # Second append with same expected version (1) should fail
      {:error, %VersionMismatchError{} = error} =
        EventStore.append_to_stream(stream, [sample_order_shipped("retry")], expected_version: 1)

      assert error.expected_version == 1
      assert error.current_version == 2

      # Verify only 2 events exist
      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 2
      assert version == 2
    end

    test "concurrent tasks - one wins version race" do
      stream = unique_stream_name("concurrent-tasks")

      # Set up stream
      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream(stream, [sample_order_placed()])

      # Spawn multiple tasks that all try to append with expected_version: 1
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            EventStore.append_to_stream(
              stream,
              [sample_order_shipped("order-#{i}")],
              expected_version: 1
            )
          end)
        end

      results = Task.await_many(tasks, 5000)

      # Exactly one should succeed
      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, %VersionMismatchError{}}, &1))

      assert successes == 1
      assert failures == 4

      # Verify stream has exactly 2 events
      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 2
      assert version == 2
    end
  end

  describe "Integration: concurrent appends to different streams" do
    test "do not block each other" do
      streams = for i <- 1..5, do: unique_stream_name("parallel-stream-#{i}")

      # Spawn tasks that append to different streams concurrently
      tasks =
        for {stream, i} <- Enum.with_index(streams, 1) do
          Task.async(fn ->
            # Each task appends multiple events to its own stream
            for j <- 1..10 do
              EventStore.append_to_stream(stream, [sample_order_placed("order-#{i}-#{j}")])
            end

            stream
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All tasks should complete
      assert length(results) == 5

      # Each stream should have 10 events
      for stream <- streams do
        {:ok, %{version: version}} = EventStore.read_stream(stream)
        assert version == 10
      end
    end
  end

  describe "Integration: GenServer process lifecycle" do
    test "EventStore survives and processes requests" do
      stream = unique_stream_name("lifecycle")

      # Perform several operations
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])
      {:ok, %{events: events1}} = EventStore.read_stream(stream)
      assert length(events1) == 1

      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_shipped()])
      {:ok, %{events: events2}} = EventStore.read_stream(stream)
      assert length(events2) == 2

      # Verify process is still alive
      assert Process.whereis(Epoch.EventStore) != nil
    end

    test "state is maintained across operations" do
      stream = unique_stream_name("state-maintained")

      # Create events
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Read back
      {:ok, %{events: events, version: version}} = EventStore.read_stream(stream)
      assert length(events) == 1
      assert version == 1

      # Add more
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_shipped()])

      # Read again - should see both
      {:ok, %{events: events2, version: version2}} = EventStore.read_stream(stream)
      assert length(events2) == 2
      assert version2 == 2
    end
  end
end
