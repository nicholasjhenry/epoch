# LiveView Contract: Events Live

**Feature**: 003-stream-type-filter  
**Date**: 2025-11-25

## Route

| Method | Path | LiveView Module |
|--------|------|-----------------|
| GET | /dev/events | EpochWeb.Dev.EventsLive |

**Note**: Route only available when `Application.compile_env(:epoch_web, :dev_routes)` is true.

---

## LiveView: EpochWeb.Dev.EventsLive

### Mount

```elixir
@impl true
def mount(_params, _session, socket)
```

**Initial State:**
| Assign | Type | Initial Value |
|--------|------|---------------|
| stream_type | String.t() \| nil | nil |
| page | pos_integer() | 1 |
| page_size | pos_integer() | 20 |
| has_more | boolean() | false |
| total | non_neg_integer() | 0 |
| events_empty? | boolean() | true |

**Streams:**
| Stream | Initial |
|--------|---------|
| :events | [] |

---

## Events

### filter

Filters events by stream type.

**Trigger**: Form submission
**Params**:
```elixir
%{"stream_type" => String.t()}
```

**Behavior**:
1. Validate stream_type (non-empty)
2. Unsubscribe from previous topic (if any)
3. Subscribe to new topic `"stream_type:#{type}"`
4. Fetch events via `EventStore.read_by_stream_type/2`
5. Reset stream with results

**Success Response**: Update UI with filtered events
**Error Response**: Display validation error

### clear_filter

Clears the current filter.

**Trigger**: Button click
**Params**: None

**Behavior**:
1. Unsubscribe from current topic
2. Clear stream_type assign
3. Reset events stream to empty

### next_page / prev_page

Navigate between pages.

**Trigger**: Button click
**Params**: None

**Behavior**:
1. Increment/decrement page
2. Fetch events for new page
3. Reset stream with results

---

## PubSub Messages

### {:events_appended, stream_name, events}

Received when new events match the current filter.

**Params**:
| Field | Type | Description |
|-------|------|-------------|
| stream_name | String.t() | Source stream |
| events | [term()] | New domain events |

**Behavior**:
1. Transform events to `event_with_stream` format
2. Append to events stream
3. Increment total count

---

## Template Structure

```heex
<div class="p-6">
  <h1 class="text-2xl font-bold mb-4">Event Store Viewer</h1>
  
  <%!-- Filter Form --%>
  <.form for={%{}} id="filter-form" phx-submit="filter" class="mb-6">
    <div class="flex gap-4">
      <input 
        type="text" 
        name="stream_type" 
        value={@stream_type}
        placeholder="Enter stream type (e.g., order)"
        class="..."
      />
      <button type="submit">Filter</button>
      <button type="button" phx-click="clear_filter" :if={@stream_type}>Clear</button>
    </div>
  </.form>
  
  <%!-- Results Summary --%>
  <div :if={@stream_type} class="mb-4">
    <p>Showing events for type "<strong>{@stream_type}</strong>" ({@total} total)</p>
  </div>
  
  <%!-- Events List --%>
  <div id="events" phx-update="stream">
    <div class="hidden only:block text-gray-500">
      <%= if @stream_type do %>
        No events found for type "{@stream_type}"
      <% else %>
        Enter a stream type to view events
      <% end %>
    </div>
    
    <div :for={{id, event} <- @streams.events} id={id} class="event-row border-b py-2">
      <div class="flex justify-between">
        <span class="font-mono text-sm">{event.stream_name}</span>
        <span class="text-gray-500 text-xs">#{event.metadata.log_position}</span>
      </div>
      <div class="text-sm">
        <span class="font-semibold">{event_type_name(event.event)}</span>
        <code class="ml-2 text-xs">{inspect(event.event, pretty: true)}</code>
      </div>
    </div>
  </div>
  
  <%!-- Pagination --%>
  <div :if={@stream_type && @total > 0} class="mt-4 flex gap-4">
    <button phx-click="prev_page" disabled={@page == 1}>Previous</button>
    <span>Page {@page}</span>
    <button phx-click="next_page" disabled={!@has_more}>Next</button>
  </div>
</div>
```

---

## DOM IDs (for testing)

| Element | ID/Selector |
|---------|-------------|
| Filter form | #filter-form |
| Stream type input | input[name="stream_type"] |
| Filter button | button[type="submit"] |
| Clear button | button[phx-click="clear_filter"] |
| Events container | #events |
| Event row | #event-{event_id} |
| Previous page | button[phx-click="prev_page"] |
| Next page | button[phx-click="next_page"] |

---

## Test Scenarios

### Mount
- Mounts successfully at /dev/events
- Shows empty state message
- Does not subscribe to any PubSub topic

### Filter
- Filters events by type and displays results
- Shows "no events" message when no matches
- Subscribes to PubSub topic for live updates
- Shows validation error for empty input

### Pagination
- Displays first page by default
- Navigates to next page
- Navigates to previous page
- Disables previous on page 1
- Disables next when no more pages

### Live Updates
- Receives new events via PubSub
- Appends new events to stream
- Updates total count
- Ignores events for non-matching streams

### Clear Filter
- Clears filter and events
- Unsubscribes from PubSub topic
- Shows initial empty state
