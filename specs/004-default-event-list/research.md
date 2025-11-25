# Research: Default Event List

**Feature Branch**: `004-default-event-list`  
**Date**: 2025-11-25

## Research Questions

### 1. How should `read_all_events/2` be implemented in the EventStore?

**Decision**: Follow the existing `read_by_stream_type/3` pattern with pagination support.

**Rationale**:
- `read_by_stream_type/3` already collects events across multiple streams and sorts by `log_position`
- The new function is simpler: no type filtering, just collect all events from all streams
- Same pagination interface ensures consistency: `page`, `page_size`, `has_more`, `total`
- Same return structure: `{:ok, %{events: [...], has_more: boolean(), total: integer()}}`

**Alternatives Considered**:
- **Stream-based approach (rejected)**: Could return a lazy stream, but pagination is simpler and matches existing patterns
- **Cursor-based pagination (rejected)**: More complex; page-based pagination already works well for the viewer

**Implementation Approach**:
```elixir
@spec read_all_events(server(), opts()) :: 
  {:ok, %{events: [event_with_stream()], has_more: boolean(), total: non_neg_integer()}}
  
def read_all_events(server \\ __MODULE__, opts \\ []) do
  GenServer.call(server, {:read_all_events, opts})
end
```

### 2. What PubSub topic should be used for global event notifications?

**Decision**: Use topic `"all_events"` with the same message format as stream-type topics.

**Rationale**:
- Consistent message format: `{:events_appended, stream_name, events}`
- Simple topic name that clearly indicates its purpose
- Broadcast to `"all_events"` happens in addition to `"stream_type:{type}"` (not instead of)
- LiveView can subscribe to `"all_events"` when no filter is applied

**Alternatives Considered**:
- **Wildcard subscription (rejected)**: PubSub doesn't support wildcards; would require tracking all type topics
- **Single global topic for all events (rejected)**: Current approach broadcasts to both, preserving filter functionality

**Implementation Approach**:
```elixir
# In EventStore.do_append/4, add broadcast to all_events topic:
defp broadcast_to_all_events(stream_name, events) do
  Phoenix.PubSub.broadcast(
    Epoch.PubSub,
    "all_events",
    {:events_appended, stream_name, events}
  )
end
```

### 3. How should the LiveView distinguish between empty store vs empty filter results?

**Decision**: Use a new assign `:view_mode` to track current state: `:all`, `:filtered`, or `:initial`.

**Rationale**:
- Clear semantic distinction between viewing all events vs filtered events
- Template can render different empty state messages based on mode
- `:initial` mode removed - viewer now loads with `:all` mode by default (per spec)

**Alternatives Considered**:
- **Boolean `:has_filter` assign (rejected)**: Less expressive, doesn't capture initial state
- **Derive from `:stream_type` presence (rejected)**: `nil` is ambiguous between "no filter" and "initial load"

**Implementation Approach**:
```elixir
# Mount with :all mode and load events immediately
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")
  end
  
  socket = 
    socket
    |> assign(:view_mode, :all)  # or :filtered when filter applied
    |> assign(:stream_type, nil)
    |> load_all_events()
  
  {:ok, socket}
end

# Template empty state:
# :all mode + empty → "No events in store"
# :filtered mode + empty → "No events match filter '[type]'"
```

### 4. How should the LiveView handle the transition between default and filtered views?

**Decision**: Unsubscribe from current topic, subscribe to new topic, refresh events.

**Rationale**:
- Same pattern as existing filter transitions
- When applying filter: unsubscribe `"all_events"`, subscribe `"stream_type:{type}"`
- When clearing filter: unsubscribe `"stream_type:{type}"`, subscribe `"all_events"`
- Maintains single subscription at a time (prevents duplicate updates)

**Implementation Approach**:
```elixir
def handle_event("filter", %{"stream_type" => type}, socket) do
  if connected?(socket) do
    # Unsubscribe from current topic
    if socket.assigns.view_mode == :all do
      Phoenix.PubSub.unsubscribe(Epoch.PubSub, "all_events")
    else
      Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
    end
    
    # Subscribe to new type topic
    Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:#{type}")
  end
  
  socket =
    socket
    |> assign(:view_mode, :filtered)
    |> assign(:stream_type, type)
    |> load_filtered_events(type)
  
  {:noreply, socket}
end

def handle_event("clear_filter", _params, socket) do
  if connected?(socket) do
    Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
    Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")
  end
  
  socket =
    socket
    |> assign(:view_mode, :all)
    |> assign(:stream_type, nil)
    |> load_all_events()
  
  {:noreply, socket}
end
```

### 5. Should events include stream name in the default view?

**Decision**: Yes, same as `read_by_stream_type/3` - return events with `stream_name` included.

**Rationale**:
- FR-008 requires displaying source stream name for each event in default view
- Already implemented in `read_by_stream_type/3` return structure
- Template already handles this format

**Implementation**: Return structure matches existing:
```elixir
%{
  event: <domain_event>,
  stream_name: "order-123",
  metadata: %EventMetadata{...}
}
```

## Best Practices Consulted

### Phoenix LiveView Patterns
- Use `connected?(socket)` guard for PubSub subscriptions (already implemented)
- Stream-based updates for event lists (already implemented)
- Page-1-only live updates to avoid confusion (already implemented)

### GenServer Patterns  
- Pagination via `handle_call` with option keyword list (already implemented)
- Consistent return types across similar functions

### PubSub Patterns
- Topic naming: noun-based (`"all_events"`) consistent with existing (`"stream_type:{type}"`)
- Same message format across topics for handler reuse

## Dependencies Verified

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| Phoenix.PubSub | 2.1 | Event broadcasting | Already in use |
| Phoenix.LiveView | 1.1.17 | Real-time UI | Already in use |
| EventStore | Feature 001 | Event storage | Requires extension |

## Conclusion

All research questions resolved. The implementation follows established patterns in the codebase with minimal new concepts:

1. **EventStore**: Add `read_all_events/2` following `read_by_stream_type/3` pattern
2. **PubSub**: Broadcast to `"all_events"` topic in addition to type-specific topics
3. **LiveView**: Add `:view_mode` assign, load events on mount, manage subscriptions
4. **Template**: Conditional empty state messages based on view mode
