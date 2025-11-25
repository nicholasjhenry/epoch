# Research: Stream Type Filter

**Feature**: 003-stream-type-filter  
**Date**: 2025-11-25  
**Status**: Complete

## Research Questions

1. How to extract stream type from stream name?
2. How to extend EventStore to filter by stream type?
3. How to broadcast events via PubSub when events are appended?
4. How to subscribe to stream type events in LiveView?
5. How to use LiveView streams for displaying events?
6. How to implement pagination for filtered results?

---

## 1. Stream Type Extraction

### Decision
Use string splitting on hyphen delimiter to extract stream type prefix.

### Rationale
- Stream naming convention follows `{type}-{id}` pattern (e.g., "order-123", "cart-456")
- Simple and deterministic extraction
- Handles edge cases (no hyphen returns full name as type)

### Implementation
```elixir
defp extract_stream_type(stream_name) do
  case String.split(stream_name, "-", parts: 2) do
    [type, _id] -> type
    [full_name] -> full_name
  end
end
```

### Alternatives Considered
1. **Regex matching** - More flexible but overkill for simple prefix extraction
2. **Configurable delimiter** - Adds complexity without clear benefit
3. **Type registry** - Would require additional state management

---

## 2. EventStore Extension for Stream Type Filtering

### Decision
Add `read_by_stream_type/3` function to EventStore that:
1. Iterates all streams in memory
2. Filters by type prefix match
3. Collects and sorts events by global position
4. Applies pagination

### Rationale
- Keeps filtering logic in EventStore where event data lives
- Global position ordering ensures chronological correctness across streams
- Pagination at source prevents memory issues

### Implementation
```elixir
@spec read_by_stream_type(GenServer.server(), String.t(), keyword()) ::
        {:ok, %{events: [event_with_stream()], has_more: boolean(), total: non_neg_integer()}}
def read_by_stream_type(server \\ __MODULE__, stream_type, opts \\ []) do
  validate_stream_type!(stream_type)
  page = Keyword.get(opts, :page, 1)
  page_size = Keyword.get(opts, :page_size, 20)
  
  GenServer.call(server, {:read_by_stream_type, stream_type, page, page_size})
end
```

### Alternatives Considered
1. **Client-side filtering** - Would require loading all events into LiveView memory
2. **Separate index** - Adds complexity for in-memory store; better for persistent store

---

## 3. PubSub Broadcasting

### Decision
Broadcast to topic `"stream_type:{type}"` when events are appended, using existing `Epoch.PubSub`.

### Rationale
- Phoenix.PubSub already configured in application
- Topic per stream type allows targeted subscriptions
- Minimal change to existing EventStore append logic

### Implementation
```elixir
# In EventStore.do_append/4 after successful append:
defp broadcast_events(stream_name, events) do
  stream_type = extract_stream_type(stream_name)
  
  Phoenix.PubSub.broadcast(
    Epoch.PubSub,
    "stream_type:#{stream_type}",
    {:events_appended, stream_name, events}
  )
end
```

### Topic Convention
- `"stream_type:order"` - all events for streams with type "order"
- `"stream_type:cart"` - all events for streams with type "cart"

### Alternatives Considered
1. **Single global topic** - Would require client-side filtering, inefficient
2. **Per-stream topic** - Too granular, LiveView would need many subscriptions

---

## 4. LiveView Subscription

### Decision
Subscribe in `mount/3` when connected, unsubscribe handled automatically by LiveView.

### Rationale
- Only subscribe when WebSocket connected (not during static render)
- LiveView automatically cleans up subscriptions when process terminates
- Simple pattern matching in `handle_info/2` for updates

### Implementation
```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, :stream_type, nil)}
end

def handle_event("filter", %{"stream_type" => type}, socket) do
  # Unsubscribe from old topic if any
  if socket.assigns.stream_type do
    Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
  end
  
  # Subscribe to new topic
  if connected?(socket) and type != "" do
    Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:#{type}")
  end
  
  # Fetch and display events
  {:ok, result} = Epoch.EventStore.read_by_stream_type(type)
  
  {:noreply,
   socket
   |> assign(:stream_type, type)
   |> stream(:events, result.events, reset: true)}
end

def handle_info({:events_appended, stream_name, events}, socket) do
  events_with_stream = Enum.map(events, &%{event: &1, stream_name: stream_name})
  {:noreply, stream(socket, :events, events_with_stream)}
end
```

### Alternatives Considered
1. **Phoenix.Presence** - Overkill for this use case (no user presence needed)
2. **Channels** - LiveView PubSub integration is simpler and sufficient

---

## 5. LiveView Streams for Event Display

### Decision
Use LiveView streams (`stream/3`) for the event list with DOM IDs based on event metadata.

### Rationale
- Streams efficiently handle large collections without memory bloat
- Supports live updates (append) without full re-render
- Required per phoenix-liveview skill for collections

### Implementation
```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:stream_type, nil)
   |> assign(:page, 1)
   |> assign(:events_empty?, true)
   |> stream(:events, [])}
end

# Template
~H"""
<div id="events" phx-update="stream">
  <div class="hidden only:block">No events found</div>
  <div :for={{id, event} <- @streams.events} id={id} class="event-row">
    <span class="stream-name">{event.stream_name}</span>
    <span class="event-type">{event.event.__struct__ |> Module.split() |> List.last()}</span>
    <span class="event-data">{inspect(event.event)}</span>
  </div>
</div>
"""
```

### Stream DOM ID
```elixir
# Events need unique IDs for streams
defp event_dom_id(%{metadata: %{event_id: id}}), do: "event-#{id}"
defp event_dom_id(%{event: event, stream_name: name}) do
  hash = :erlang.phash2({name, event})
  "event-#{hash}"
end
```

### Alternatives Considered
1. **Regular assigns** - Would cause memory issues with large event lists
2. **Virtual scroll** - More complex, not needed for initial implementation

---

## 6. Pagination

### Decision
Server-side pagination with page number and page size parameters.

### Rationale
- Keeps memory bounded
- Simple UI (prev/next or page numbers)
- Consistent with existing patterns

### Implementation
```elixir
# In EventStore
def handle_call({:read_by_stream_type, stream_type, page, page_size}, _from, state) do
  matching_events =
    state.streams
    |> Enum.filter(fn {name, _} -> extract_stream_type(name) == stream_type end)
    |> Enum.flat_map(fn {name, stream} ->
      Enum.map(stream.events, &%{event: &1.event, stream_name: name, metadata: &1.metadata})
    end)
    |> Enum.sort_by(& &1.metadata.log_position)
  
  total = length(matching_events)
  offset = (page - 1) * page_size
  
  events =
    matching_events
    |> Enum.drop(offset)
    |> Enum.take(page_size)
  
  has_more = offset + page_size < total
  
  {:reply, {:ok, %{events: events, has_more: has_more, total: total}}, state}
end
```

### Configuration
- Default page size: 20
- Maximum page size: 100
- Invalid page sizes (< 1 or > 100) rejected with error

### Alternatives Considered
1. **Cursor-based pagination** - More complex, better for real-time but overkill here
2. **Infinite scroll** - Requires more frontend complexity

---

## Existing Codebase Analysis

### EventStore (apps/epoch/lib/epoch/event_store.ex)

**Current capabilities:**
- `append_to_stream/4` - Appends events with optimistic concurrency
- `read_stream/3` - Reads from single stream with pagination
- `subscribe/3` - Per-stream subscription callbacks
- `debug_all_streams/1` - Lists all streams (useful for filtering)

**Key data structures:**
- State: `%{streams: %{}, subscriptions: %{}, global_position: 0}`
- Stream: `%{events: [EventEnvelope.t()], version: non_neg_integer()}`
- EventEnvelope: `%{event: term(), metadata: EventMetadata.t()}`
- EventMetadata: `%{event_id: String.t(), stream_position: non_neg_integer(), log_position: non_neg_integer()}`

**Extension points:**
- Add `read_by_stream_type/3` function
- Add PubSub broadcast in `do_append/4`
- Add helper `extract_stream_type/1`

### Router (apps/epoch_web/lib/epoch_web/router.ex)

**Current dev routes:**
```elixir
if Application.compile_env(:epoch_web, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: EpochWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
```

**Extension:**
Add `live "/events", EpochWeb.Dev.EventsLive` inside the `/dev` scope.

### PubSub Configuration

**Found in:** `apps/epoch_web/lib/epoch_web/application.ex`
```elixir
children = [
  {Phoenix.PubSub, name: Epoch.PubSub},
  # ...
]
```

**PubSub name:** `Epoch.PubSub` (already available)

---

## Summary

All research questions resolved. Implementation will:

1. Add `extract_stream_type/1` helper to EventStore
2. Add `read_by_stream_type/3` function to EventStore
3. Add PubSub broadcast in `do_append/4`
4. Create `EpochWeb.Dev.EventsLive` with streams-based display
5. Add route `/dev/events` in dev-only scope
6. Implement server-side pagination with configurable page size
