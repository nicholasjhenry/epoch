# Quickstart Guide: In-Memory Event Store

**Feature**: 001-elixir-event-store  
**Date**: 2025-11-24

## Overview

This quickstart guide demonstrates how to use the Epoch.EventStore module for event sourcing in Elixir. The event store provides in-memory storage of events organized into named streams, with support for optimistic concurrency control, pagination, and subscriptions.

## Prerequisites

- Elixir ~> 1.15 installed
- Epoch umbrella application running
- No external dependencies required

## Basic Usage

### 1. Appending Events

Events are appended to named streams. Events can be any Elixir term (structs, maps, tuples, etc.).

```elixir
# Define some event types
defmodule OrderEvents do
  defmodule OrderPlaced do
    defstruct [:order_id, :customer_id, :items, :total]
  end
  
  defmodule OrderShipped do
    defstruct [:order_id, :tracking_number, :carrier]
  end
  
  defmodule OrderCancelled do
    defstruct [:order_id, :reason]
  end
end

# Append events to a stream
alias Epoch.EventStore

event1 = %OrderEvents.OrderPlaced{
  order_id: "order-123",
  customer_id: "customer-456",
  items: ["item1", "item2"],
  total: 99.99
}

event2 = %OrderEvents.OrderShipped{
  order_id: "order-123",
  tracking_number: "TRACK-789",
  carrier: "FedEx"
}

# Append single event
{:ok, %{next_expected_version: 1}} = 
  EventStore.append_to_stream("order-123", [event1])

# Append multiple events atomically
{:ok, %{next_expected_version: 2}} = 
  EventStore.append_to_stream("order-123", [event2])
```

### 2. Reading Events

```elixir
# Read all events from a stream
{:ok, %{events: events, version: 2}} = 
  EventStore.read_stream("order-123")

# events is a list of the original events you appended
[%OrderEvents.OrderPlaced{}, %OrderEvents.OrderShipped{}] = events
```

### 3. Optimistic Concurrency Control

Prevent lost updates by specifying the expected stream version:

```elixir
# Read current state
{:ok, %{events: events, version: current_version}} = 
  EventStore.read_stream("order-123")

# Do some work...
decision_event = make_decision(events)

# Append with version check
case EventStore.append_to_stream(
  "order-123", 
  [decision_event], 
  expected_version: current_version
) do
  {:ok, %{next_expected_version: new_version}} ->
    # Success - no one else modified the stream
    :ok
    
  {:error, %Epoch.EventStore.VersionMismatchError{} = error} ->
    # Conflict - someone else appended events since we read
    # Retry: re-read events, recalculate decision, try again
    handle_conflict(error)
end
```

### 4. Paginated Reading

For large streams, read events in chunks:

```elixir
# Read events 0-9 (first 10 events)
{:ok, %{events: page1, version: 100}} = 
  EventStore.read_stream("large-stream", from: 0, max_count: 10)

# Read events 10-19 (next 10 events)
{:ok, %{events: page2, version: 100}} = 
  EventStore.read_stream("large-stream", from: 10, max_count: 10)

# Alternative: specify range with from/to
{:ok, %{events: events_20_to_30, version: 100}} = 
  EventStore.read_stream("large-stream", from: 20, to: 30)
```

### 5. Aggregate State Reconstruction

Reconstruct aggregate state by applying an evolve function:

```elixir
# Define initial state
initial_state = %{
  order_id: nil,
  status: :pending,
  items: [],
  total: 0.0,
  tracking_number: nil
}

# Define evolve function
evolve = fn
  state, %OrderEvents.OrderPlaced{} = event ->
    %{state |
      order_id: event.order_id,
      status: :placed,
      items: event.items,
      total: event.total
    }
    
  state, %OrderEvents.OrderShipped{} = event ->
    %{state |
      status: :shipped,
      tracking_number: event.tracking_number
    }
    
  state, %OrderEvents.OrderCancelled{} = _event ->
    %{state | status: :cancelled}
end

# Reconstruct current state
{:ok, %{state: order_state, version: 2}} = 
  EventStore.aggregate_stream("order-123", initial_state, evolve)

# order_state now contains the current state of the order
%{
  order_id: "order-123",
  status: :shipped,
  items: ["item1", "item2"],
  total: 99.99,
  tracking_number: "TRACK-789"
} = order_state
```

### 6. Stream Subscriptions

Subscribe to streams to receive notifications when events are appended:

```elixir
# Define a callback function
callback = fn version, events ->
  IO.puts("Stream updated to version #{version}")
  IO.inspect(events, label: "New events")
  
  # Process events (update read model, trigger side effects, etc.)
  Enum.each(events, &process_event/1)
end

# Subscribe to a stream
{:ok, subscription_ref} = 
  EventStore.subscribe("order-123", callback)

# The callback is immediately invoked with existing events
# (if the stream has any)

# Later: append events to trigger subscription
EventStore.append_to_stream("order-123", [new_event])
# => callback is invoked synchronously with (new_version, [new_event])

# Unsubscribe when done
:ok = EventStore.unsubscribe("order-123", subscription_ref)
```

## Common Patterns

### Pattern 1: Event-Sourced Aggregate

```elixir
defmodule Order do
  alias Epoch.EventStore
  
  defstruct [:order_id, :status, :items, :total, :version]
  
  def place_order(order_id, customer_id, items, total) do
    stream_name = stream_name(order_id)
    
    event = %OrderEvents.OrderPlaced{
      order_id: order_id,
      customer_id: customer_id,
      items: items,
      total: total
    }
    
    # Append to new stream (expect version 0)
    EventStore.append_to_stream(
      stream_name, 
      [event], 
      expected_version: 0
    )
  end
  
  def ship_order(order_id, tracking_number, carrier) do
    stream_name = stream_name(order_id)
    
    # Load current state
    {:ok, order} = load(order_id)
    
    # Validate command
    unless order.status == :placed do
      raise "Cannot ship order in status #{order.status}"
    end
    
    # Generate event
    event = %OrderEvents.OrderShipped{
      order_id: order_id,
      tracking_number: tracking_number,
      carrier: carrier
    }
    
    # Append with optimistic concurrency
    EventStore.append_to_stream(
      stream_name,
      [event],
      expected_version: order.version
    )
  end
  
  def load(order_id) do
    stream_name = stream_name(order_id)
    
    initial_state = %__MODULE__{order_id: order_id}
    evolve = &evolve/2
    
    case EventStore.aggregate_stream(stream_name, initial_state, evolve) do
      {:ok, %{state: state, version: version}} ->
        {:ok, %{state | version: version}}
      
      {:error, :stream_not_found} ->
        {:error, :order_not_found}
    end
  end
  
  defp evolve(state, %OrderEvents.OrderPlaced{} = event) do
    %{state |
      status: :placed,
      items: event.items,
      total: event.total
    }
  end
  
  defp evolve(state, %OrderEvents.OrderShipped{}) do
    %{state | status: :shipped}
  end
  
  defp evolve(state, %OrderEvents.OrderCancelled{}) do
    %{state | status: :cancelled}
  end
  
  defp stream_name(order_id), do: "order-#{order_id}"
end

# Usage
{:ok, _} = Order.place_order("123", "customer-456", ["item1"], 99.99)
{:ok, order} = Order.load("123")
{:ok, _} = Order.ship_order("123", "TRACK-789", "FedEx")
```

### Pattern 2: Read Model Projection

```elixir
defmodule OrderReadModel do
  use GenServer
  alias Epoch.EventStore
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_order_summary(order_id) do
    GenServer.call(__MODULE__, {:get_order, order_id})
  end
  
  # Server Callbacks
  
  def init(_opts) do
    # Subscribe to all order streams
    # (In practice, you'd subscribe to specific streams or a category)
    state = %{orders: %{}}
    {:ok, state}
  end
  
  def handle_call({:get_order, order_id}, _from, state) do
    order = Map.get(state.orders, order_id)
    {:reply, order, state}
  end
  
  def handle_info({:event, stream_name, version, events}, state) do
    # Extract order_id from stream name
    order_id = String.replace_prefix(stream_name, "order-", "")
    
    # Update read model
    order_summary = 
      Enum.reduce(events, state.orders[order_id] || %{}, fn event, summary ->
        apply_event(summary, event)
      end)
    
    new_state = put_in(state, [:orders, order_id], order_summary)
    {:noreply, new_state}
  end
  
  defp apply_event(summary, %OrderEvents.OrderPlaced{} = event) do
    Map.merge(summary, %{
      status: :placed,
      customer_id: event.customer_id,
      total: event.total
    })
  end
  
  defp apply_event(summary, %OrderEvents.OrderShipped{}) do
    %{summary | status: :shipped}
  end
  
  defp apply_event(summary, %OrderEvents.OrderCancelled{}) do
    %{summary | status: :cancelled}
  end
end
```

### Pattern 3: Testing with Event Store

```elixir
defmodule OrderTest do
  use ExUnit.Case
  alias Epoch.EventStore
  
  setup do
    # Event store runs as singleton, so ensure clean state per test
    # Option 1: Use unique stream names per test
    stream_name = "order-test-#{System.unique_integer()}"
    
    # Option 2: Use a test-specific event store instance
    # (would require passing event store pid to functions)
    
    %{stream_name: stream_name}
  end
  
  test "placing an order creates placed event", %{stream_name: stream} do
    event = %OrderEvents.OrderPlaced{
      order_id: "123",
      customer_id: "customer-456",
      items: ["item1"],
      total: 99.99
    }
    
    {:ok, _} = EventStore.append_to_stream(stream, [event])
    
    {:ok, %{events: [stored_event], version: 1}} = 
      EventStore.read_stream(stream)
    
    assert stored_event == event
  end
  
  test "version mismatch prevents concurrent modification", %{stream_name: stream} do
    # Set up initial state
    event1 = %OrderEvents.OrderPlaced{order_id: "123", customer_id: "c1", items: [], total: 0}
    {:ok, %{next_expected_version: 1}} = EventStore.append_to_stream(stream, [event1])
    
    # Simulate concurrent modification
    event2 = %OrderEvents.OrderShipped{order_id: "123", tracking_number: "T1", carrier: "FedEx"}
    {:ok, %{next_expected_version: 2}} = EventStore.append_to_stream(stream, [event2])
    
    # Try to append with stale version
    event3 = %OrderEvents.OrderCancelled{order_id: "123", reason: "customer request"}
    
    assert {:error, %Epoch.EventStore.VersionMismatchError{
      expected_version: 1,
      current_version: 2
    }} = EventStore.append_to_stream(stream, [event3], expected_version: 1)
  end
end
```

## Debugging

### Inspect All Streams

```elixir
# Get a map of all streams and their event counts
EventStore.debug_all_streams()
# => %{
#   "order-123" => 3,
#   "order-456" => 1,
#   "cart-789" => 5
# }
```

### Enable Logging

The event store logs key operations at the debug level:

```elixir
# In config/dev.exs or config/test.exs
config :logger, level: :debug
```

## Performance Considerations

1. **Subscription Callbacks Block Appends**: Keep subscription callbacks fast. Long-running operations should be offloaded to background jobs.

2. **Memory Usage**: The event store holds all events in memory. For 10,000 events, expect ~2MB of memory usage.

3. **Pagination for Large Streams**: Use pagination when reading streams with thousands of events to avoid loading everything into memory at once.

4. **Concurrent Operations**: All operations serialize through the GenServer. High throughput scenarios may experience queuing.

## Common Pitfalls

### Pitfall 1: Forgetting Version Check

```elixir
# BAD: No version check, last write wins
{:ok, order} = Order.load(order_id)
# ... time passes, another process modifies the order ...
EventStore.append_to_stream(stream, [event])  # Silently overwrites!

# GOOD: Always use expected_version
{:ok, order} = Order.load(order_id)
EventStore.append_to_stream(stream, [event], expected_version: order.version)
```

### Pitfall 2: Slow Subscription Callbacks

```elixir
# BAD: Slow operation in callback
EventStore.subscribe("order-123", fn _version, events ->
  Enum.each(events, fn event ->
    # This sends HTTP request and waits for response
    send_notification_to_customer(event)  # BLOCKS!
  end)
end)

# GOOD: Offload to background job
EventStore.subscribe("order-123", fn _version, events ->
  Enum.each(events, fn event ->
    BackgroundJob.enqueue(:send_notification, event)  # Fast, returns immediately
  end)
end)
```

### Pitfall 3: Not Handling Empty Streams

```elixir
# BAD: Assumes stream exists
{:ok, %{events: events}} = EventStore.read_stream("order-999")
List.first(events).order_id  # Crashes if events is []

# GOOD: Handle empty case
case EventStore.read_stream("order-999") do
  {:ok, %{events: [], version: 0}} ->
    :stream_empty
    
  {:ok, %{events: events}} ->
    process_events(events)
    
  {:error, :stream_not_found} ->
    :no_such_stream
end
```

## Next Steps

1. **Run the Tests**: See the comprehensive test suite in `apps/epoch/test/epoch/event_store_test.exs`

2. **Review the Data Model**: See `data-model.md` for detailed entity documentation

3. **Check the API Contract**: See `contracts/event_store_api.exs` for complete API reference

4. **Build Your Aggregate**: Use the Order example as a template for your domain aggregates

5. **Add Read Models**: Create GenServers that subscribe to streams and maintain queryable projections

## Reference

- **Module**: `Epoch.EventStore`
- **Location**: `apps/epoch/lib/epoch/event_store.ex`
- **Tests**: `apps/epoch/test/epoch/event_store_test.exs`
- **TypeScript Reference**: `tmp/course-implementing-eventsourcing/app/infrastructure/inmemoryEventstore.ts`
