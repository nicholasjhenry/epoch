defmodule Epoch.EventStore.SubscriptionTest do
  use ExUnit.Case, async: false

  alias Epoch.EventStore
  alias Epoch.EventStore.TestEvents.{OrderPlaced, OrderShipped}

  defp unique_stream_name(base) do
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

  describe "US5: subscribing immediately invokes callback with existing events" do
    test "callback receives existing events on subscribe" do
      stream = unique_stream_name("subscribe-existing")

      # Add some events first
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_shipped()])

      # Track callback invocations
      test_pid = self()

      callback = fn version, events ->
        send(test_pid, {:callback_invoked, version, events})
      end

      {:ok, _ref} = EventStore.subscribe(stream, callback)

      # Should receive immediate callback with existing events
      assert_receive {:callback_invoked, 2, events}, 1000
      assert length(events) == 2
      assert Enum.at(events, 0) == sample_order_placed()
      assert Enum.at(events, 1) == sample_order_shipped()
    end

    test "callback not invoked if stream is empty" do
      stream = unique_stream_name("subscribe-empty")
      test_pid = self()

      callback = fn version, events ->
        send(test_pid, {:callback_invoked, version, events})
      end

      {:ok, _ref} = EventStore.subscribe(stream, callback)

      # Should not receive callback for empty stream
      refute_receive {:callback_invoked, _, _}, 100
    end
  end

  describe "US5: appending invokes all active subscription callbacks" do
    test "callback invoked on append" do
      stream = unique_stream_name("subscribe-append")
      test_pid = self()

      callback = fn version, events ->
        send(test_pid, {:callback_invoked, version, events})
      end

      {:ok, _ref} = EventStore.subscribe(stream, callback)

      # Append new event
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Should receive callback
      assert_receive {:callback_invoked, 1, [%OrderPlaced{}]}, 1000
    end
  end

  describe "US5: subscription callback receives correct events and new version" do
    test "callback receives only new events and updated version" do
      stream = unique_stream_name("subscribe-new-events")

      # Add initial event
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      test_pid = self()

      callback = fn version, events ->
        send(test_pid, {:callback_invoked, version, events})
      end

      {:ok, _ref} = EventStore.subscribe(stream, callback)

      # Receive initial callback
      assert_receive {:callback_invoked, 1, _}, 1000

      # Append new event
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_shipped()])

      # Should receive callback with only the new event and new version
      assert_receive {:callback_invoked, 2, [%OrderShipped{}]}, 1000
    end
  end

  describe "US5: unsubscribing prevents future callback invocations" do
    test "unsubscribed callback is not invoked" do
      stream = unique_stream_name("unsubscribe")
      test_pid = self()

      callback = fn version, events ->
        send(test_pid, {:callback_invoked, version, events})
      end

      {:ok, ref} = EventStore.subscribe(stream, callback)

      # Unsubscribe
      :ok = EventStore.unsubscribe(stream, ref)

      # Append event
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Should not receive callback
      refute_receive {:callback_invoked, _, _}, 100
    end
  end

  describe "US5: multiple subscriptions on same stream" do
    test "all receive events independently" do
      stream = unique_stream_name("multi-subscribe")
      test_pid = self()

      callback1 = fn version, events ->
        send(test_pid, {:callback1, version, events})
      end

      callback2 = fn version, events ->
        send(test_pid, {:callback2, version, events})
      end

      {:ok, _ref1} = EventStore.subscribe(stream, callback1)
      {:ok, _ref2} = EventStore.subscribe(stream, callback2)

      # Append event
      {:ok, _} = EventStore.append_to_stream(stream, [sample_order_placed()])

      # Both should receive callback
      assert_receive {:callback1, 1, [%OrderPlaced{}]}, 1000
      assert_receive {:callback2, 1, [%OrderPlaced{}]}, 1000
    end
  end

  describe "US5 Integration: subscription callback errors are isolated" do
    test "one error doesn't affect others" do
      stream = unique_stream_name("error-isolation")
      test_pid = self()

      # Callback that raises an error
      error_callback = fn _version, _events ->
        raise "Intentional test error"
      end

      # Callback that works
      good_callback = fn version, events ->
        send(test_pid, {:good_callback, version, events})
      end

      {:ok, _ref1} = EventStore.subscribe(stream, error_callback)
      {:ok, _ref2} = EventStore.subscribe(stream, good_callback)

      # Append should succeed despite error callback
      {:ok, result} = EventStore.append_to_stream(stream, [sample_order_placed()])
      assert result.next_expected_version == 1

      # Good callback should still be invoked
      assert_receive {:good_callback, 1, [%OrderPlaced{}]}, 1000
    end
  end

  describe "US5: unsubscribing non-existent subscription is idempotent" do
    test "unsubscribe with unknown callback returns ok" do
      stream = unique_stream_name("unsubscribe-unknown")

      fake_callback = fn _, _ -> :ok end

      # Should not raise, just return :ok
      assert :ok = EventStore.unsubscribe(stream, fake_callback)
    end

    test "double unsubscribe returns ok" do
      stream = unique_stream_name("double-unsubscribe")

      callback = fn _, _ -> :ok end

      {:ok, ref} = EventStore.subscribe(stream, callback)
      :ok = EventStore.unsubscribe(stream, ref)

      # Second unsubscribe should also succeed
      assert :ok = EventStore.unsubscribe(stream, ref)
    end
  end
end
