# Quickstart: Stream Type Filter

**Feature**: 003-stream-type-filter  
**Date**: 2025-11-25

## Prerequisites

- Epoch umbrella application running
- EventStore started (automatic via Application supervision tree)
- Dev routes enabled (default in dev environment)

## Quick Verification

### 1. Start the application

```bash
cd /Users/nicholas/Workspaces/professional/projects/epoch
iex -S mix phx.server
```

### 2. Seed test data (in IEx)

```elixir
# Create some order events
Epoch.EventStore.append_to_stream("order-123", [
  %{type: :order_placed, product: "Widget", quantity: 2},
  %{type: :order_confirmed, confirmed_at: DateTime.utc_now()}
])

Epoch.EventStore.append_to_stream("order-456", [
  %{type: :order_placed, product: "Gadget", quantity: 1}
])

# Create some cart events
Epoch.EventStore.append_to_stream("cart-abc", [
  %{type: :item_added, product: "Widget"},
  %{type: :item_added, product: "Gadget"}
])

# Verify streams exist
Epoch.EventStore.debug_all_streams()
# => %{"order-123" => 2, "order-456" => 1, "cart-abc" => 2}
```

### 3. Access the Events Viewer

Open in browser: http://localhost:4000/dev/events

### 4. Test filtering

1. Enter "order" in the filter input
2. Click "Filter"
3. Verify: Shows 3 events from order-123 and order-456
4. Clear filter and enter "cart"
5. Verify: Shows 2 events from cart-abc

### 5. Test live updates

1. Filter by "order" in the browser
2. In IEx, append a new event:
   ```elixir
   Epoch.EventStore.append_to_stream("order-789", [
     %{type: :order_placed, product: "Thingamajig", quantity: 5}
   ])
   ```
3. Verify: New event appears in browser without refresh

## API Quick Reference

### Filter events by type

```elixir
{:ok, result} = Epoch.EventStore.read_by_stream_type("order")

# result = %{
#   events: [%{event: ..., stream_name: "order-123", metadata: ...}, ...],
#   has_more: false,
#   total: 3
# }
```

### Filter with pagination

```elixir
{:ok, page1} = Epoch.EventStore.read_by_stream_type("order", page: 1, page_size: 10)
{:ok, page2} = Epoch.EventStore.read_by_stream_type("order", page: 2, page_size: 10)
```

### Subscribe to stream type events

```elixir
Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:order")

# Receive messages:
# {:events_appended, "order-123", [%{type: :order_shipped}]}
```

## Running Tests

```bash
# Run all tests for this feature
mix test test/epoch/event_store/stream_type_filter_test.exs
mix test test/epoch_web/live/dev/events_live_test.exs

# Run with verbose output
mix test test/epoch/event_store/stream_type_filter_test.exs --trace
```

## Troubleshooting

### Route not found (404)

Ensure dev routes are enabled:
```elixir
# config/dev.exs
config :epoch_web, :dev_routes, true
```

### Events not appearing in live updates

1. Check PubSub is running:
   ```elixir
   Process.whereis(Epoch.PubSub)
   # Should return a PID
   ```

2. Check subscription:
   ```elixir
   # In LiveView, ensure connected?(socket) is true before subscribing
   ```

### Empty results when events exist

1. Verify stream names follow convention:
   ```elixir
   Epoch.EventStore.debug_all_streams()
   ```

2. Check stream type extraction:
   ```elixir
   # "order-123" -> type "order"
   # "order" (no hyphen) -> type "order"
   ```

## File Locations

| File | Purpose |
|------|---------|
| apps/epoch/lib/epoch/event_store.ex | EventStore with read_by_stream_type/3 |
| apps/epoch_web/lib/epoch_web/live/dev/events_live.ex | LiveView for /dev/events |
| apps/epoch_web/lib/epoch_web/router.ex | Route definition |
| test/epoch/event_store/stream_type_filter_test.exs | Unit tests |
| test/epoch_web/live/dev/events_live_test.exs | Integration tests |
