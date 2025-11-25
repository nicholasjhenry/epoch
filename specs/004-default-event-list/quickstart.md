# Quickstart: Default Event List

**Feature Branch**: `004-default-event-list`  
**Estimated Changes**: ~150 lines across 4 files

## Prerequisites

- Elixir 1.15+ installed
- Feature 001 (EventStore) and Feature 003 (Stream Type Filter) complete
- Running on branch `004-default-event-list`

## Implementation Order

### 1. EventStore: Add read_all_events/2 (Unit Tests First)

**File**: `apps/epoch/test/epoch/event_store_test.exs`

Add tests in `describe "read_all_events/2"`:

```elixir
describe "read_all_events/2" do
  test "returns events from all streams" do
    # Append to multiple streams
    EventStore.append_to_stream("order-1", [%{type: "order"}])
    EventStore.append_to_stream("cart-1", [%{type: "cart"}])
    EventStore.append_to_stream("user-1", [%{type: "user"}])
    
    {:ok, result} = EventStore.read_all_events()
    
    assert length(result.events) == 3
    assert result.total == 3
  end

  test "returns events in chronological order by log_position" do
    EventStore.append_to_stream("stream-a", [%{order: 1}])
    EventStore.append_to_stream("stream-b", [%{order: 2}])
    EventStore.append_to_stream("stream-a", [%{order: 3}])
    
    {:ok, result} = EventStore.read_all_events()
    
    orders = Enum.map(result.events, & &1.event.order)
    assert orders == [1, 2, 3]
  end

  test "pagination works correctly" do
    for i <- 1..25 do
      EventStore.append_to_stream("stream-#{i}", [%{i: i}])
    end
    
    {:ok, page1} = EventStore.read_all_events(page: 1, page_size: 10)
    {:ok, page2} = EventStore.read_all_events(page: 2, page_size: 10)
    {:ok, page3} = EventStore.read_all_events(page: 3, page_size: 10)
    
    assert length(page1.events) == 10
    assert page1.has_more == true
    assert length(page2.events) == 10
    assert page2.has_more == true
    assert length(page3.events) == 5
    assert page3.has_more == false
  end

  test "returns empty result for empty store" do
    {:ok, result} = EventStore.read_all_events()
    
    assert result.events == []
    assert result.has_more == false
    assert result.total == 0
  end
end
```

**File**: `apps/epoch/lib/epoch/event_store.ex`

Add function:

```elixir
@doc """
Reads all events from all streams, paginated.
"""
@spec read_all_events(server(), keyword()) :: {:ok, map()}
def read_all_events(server \\ __MODULE__, opts \\ []) do
  GenServer.call(server, {:read_all_events, opts})
end

# In handle_call:
def handle_call({:read_all_events, opts}, _from, state) do
  page = Keyword.get(opts, :page, 1)
  page_size = opts |> Keyword.get(:page_size, 20) |> min(100) |> max(1)
  
  # Collect all events from all streams
  all_events =
    state.streams
    |> Enum.flat_map(fn {stream_name, stream_data} ->
      Enum.map(stream_data.events, fn envelope ->
        %{
          event: envelope.event,
          stream_name: stream_name,
          metadata: envelope.metadata
        }
      end)
    end)
    |> Enum.sort_by(& &1.metadata.log_position)
  
  total = length(all_events)
  offset = (page - 1) * page_size
  events = all_events |> Enum.drop(offset) |> Enum.take(page_size)
  has_more = offset + page_size < total
  
  {:reply, {:ok, %{events: events, has_more: has_more, total: total}}, state}
end
```

### 2. EventStore: Broadcast to all_events Topic

**File**: `apps/epoch/test/epoch/event_store_test.exs`

Add test:

```elixir
describe "PubSub all_events topic" do
  test "broadcasts to all_events on any append" do
    Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")
    
    EventStore.append_to_stream("any-stream", [%{data: "test"}])
    
    assert_receive {:events_appended, "any-stream", events}
    assert length(events) == 1
  end
end
```

**File**: `apps/epoch/lib/epoch/event_store.ex`

In `do_append/4`, add after existing broadcast:

```elixir
# Existing:
broadcast_to_stream_type(stream_name, envelopes)

# Add:
broadcast_to_all_events(stream_name, envelopes)

defp broadcast_to_all_events(stream_name, events) do
  Phoenix.PubSub.broadcast(
    Epoch.PubSub,
    "all_events",
    {:events_appended, stream_name, events}
  )
end
```

### 3. LiveView: Load Events on Mount (Integration Tests First)

**File**: `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`

Add tests:

```elixir
describe "default view on mount" do
  test "displays all events on initial load", %{conn: conn} do
    EventStore.append_to_stream("order-1", [%{type: "order"}])
    EventStore.append_to_stream("cart-1", [%{type: "cart"}])
    
    {:ok, view, html} = live(conn, ~p"/dev/events")
    
    assert html =~ "order-1"
    assert html =~ "cart-1"
  end

  test "shows empty store message when no events", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dev/events")
    
    assert html =~ "No events in store"
  end

  test "receives live updates for any stream", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/events")
    
    EventStore.append_to_stream("new-stream", [%{type: "new"}])
    
    assert render(view) =~ "new-stream"
  end
end

describe "filter transitions" do
  test "transitions from default to filtered view", %{conn: conn} do
    EventStore.append_to_stream("order-1", [%{type: "order"}])
    EventStore.append_to_stream("cart-1", [%{type: "cart"}])
    
    {:ok, view, _html} = live(conn, ~p"/dev/events")
    
    view |> element("form") |> render_submit(%{stream_type: "order"})
    html = render(view)
    
    assert html =~ "order-1"
    refute html =~ "cart-1"
  end

  test "transitions from filtered to default view", %{conn: conn} do
    EventStore.append_to_stream("order-1", [%{type: "order"}])
    EventStore.append_to_stream("cart-1", [%{type: "cart"}])
    
    {:ok, view, _html} = live(conn, ~p"/dev/events")
    view |> element("form") |> render_submit(%{stream_type: "order"})
    view |> element("button", "Clear") |> render_click()
    
    html = render(view)
    assert html =~ "order-1"
    assert html =~ "cart-1"
  end
end
```

**File**: `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`

Modify mount:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")
  end

  socket =
    socket
    |> assign(:view_mode, :all)
    |> assign(:stream_type, nil)
    |> assign(:page, 1)
    |> assign(:page_size, 20)
    |> stream_configure(:events, dom_id: &event_dom_id/1)
    |> load_all_events()

  {:ok, socket}
end

defp load_all_events(socket) do
  case EventStore.read_all_events(page: socket.assigns.page, page_size: socket.assigns.page_size) do
    {:ok, result} ->
      socket
      |> assign(:has_more, result.has_more)
      |> assign(:total, result.total)
      |> assign(:events_empty?, result.events == [])
      |> stream(:events, result.events, reset: true)

    {:error, _reason} ->
      socket
      |> put_flash(:error, "Failed to load events")
      |> assign(:events_empty?, true)
      |> stream(:events, [], reset: true)
  end
end
```

### 4. LiveView: Update Event Handlers

Modify filter handler:

```elixir
def handle_event("filter", %{"stream_type" => stream_type}, socket) do
  stream_type = String.trim(stream_type)
  
  if stream_type == "" do
    {:noreply, put_flash(socket, :error, "Stream type cannot be empty")}
  else
    if connected?(socket) do
      # Unsubscribe from current topic
      if socket.assigns.view_mode == :all do
        Phoenix.PubSub.unsubscribe(Epoch.PubSub, "all_events")
      else
        Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
      end
      
      Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:#{stream_type}")
    end
    
    socket =
      socket
      |> assign(:view_mode, :filtered)
      |> assign(:stream_type, stream_type)
      |> assign(:page, 1)
      |> load_filtered_events()
    
    {:noreply, socket}
  end
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
    |> assign(:page, 1)
    |> load_all_events()
  
  {:noreply, socket}
end
```

### 5. Template: Update Empty State Messages

**File**: `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex` (in render/1)

Update empty state section:

```heex
<%= cond do %>
  <% @view_mode == :all and @events_empty? -> %>
    <p class="text-gray-500">No events in store</p>
  <% @view_mode == :filtered and @events_empty? -> %>
    <p class="text-gray-500">No events match filter '<%= @stream_type %>'</p>
  <% true -> %>
    <%!-- Events list --%>
<% end %>
```

## Verification

```bash
# Run unit tests
mix test apps/epoch/test/epoch/event_store_test.exs

# Run integration tests
mix test apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs

# Run all tests
mix test

# Run precommit
mix precommit

# Manual verification
iex -S mix phx.server
# Navigate to http://localhost:4000/dev/events
# Should see events immediately (or empty state message)
```

## Files Changed

| File | Lines Added | Lines Modified |
|------|-------------|----------------|
| `apps/epoch/lib/epoch/event_store.ex` | ~40 | ~5 |
| `apps/epoch/test/epoch/event_store_test.exs` | ~50 | 0 |
| `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex` | ~30 | ~40 |
| `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs` | ~60 | 0 |

**Total**: ~180 lines added, ~45 lines modified
