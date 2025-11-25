# Data Model: Default Event List

**Feature Branch**: `004-default-event-list`  
**Date**: 2025-11-25

## Overview

This feature extends existing data structures rather than introducing new entities. The primary additions are:
1. New EventStore API function with consistent return type
2. New LiveView assign for view mode tracking
3. New PubSub topic for global event notifications

## Entities

### EventStore State (Existing - No Changes)

```elixir
%{
  streams: %{stream_name() => stream_data()},
  subscriptions: %{stream_name() => [callback()]},
  global_position: non_neg_integer()
}
```

### Event With Stream (Existing - Reused)

Used by both `read_by_stream_type/3` and the new `read_all_events/2`:

```elixir
@type event_with_stream :: %{
  event: term(),
  stream_name: String.t(),
  metadata: EventMetadata.t()
}
```

### EventMetadata (Existing - No Changes)

```elixir
@type t :: %EventMetadata{
  event_id: String.t(),
  stream_position: pos_integer(),
  log_position: pos_integer()
}
```

### Pagination Result (Existing Pattern - Reused)

```elixir
@type pagination_result :: %{
  events: [event_with_stream()],
  has_more: boolean(),
  total: non_neg_integer()
}
```

## New API Functions

### read_all_events/2

```elixir
@spec read_all_events(server(), keyword()) :: {:ok, pagination_result()}

@doc """
Reads all events from all streams, paginated.

## Options
  * `:page` - Page number (1-indexed, default: 1)
  * `:page_size` - Events per page (default: 20, max: 100)

## Returns
  * `{:ok, %{events: [...], has_more: boolean(), total: integer()}}`

## Examples

    iex> EventStore.read_all_events(page: 1, page_size: 20)
    {:ok, %{
      events: [
        %{event: %OrderPlaced{...}, stream_name: "order-123", metadata: %{...}},
        %{event: %CartUpdated{...}, stream_name: "cart-456", metadata: %{...}}
      ],
      has_more: true,
      total: 45
    }}

    iex> EventStore.read_all_events()  # Empty store
    {:ok, %{events: [], has_more: false, total: 0}}
"""
def read_all_events(server \\ __MODULE__, opts \\ [])
```

## LiveView Assigns

### New Assigns

| Assign | Type | Default | Purpose |
|--------|------|---------|---------|
| `:view_mode` | `:all \| :filtered` | `:all` | Tracks current view state for empty message differentiation |

### Modified Assigns

| Assign | Previous Default | New Default | Reason |
|--------|------------------|-------------|--------|
| `:events_empty?` | `true` | Computed from `read_all_events/2` result | Now loads data on mount |
| `:total` | `0` | Computed from `read_all_events/2` result | Now loads data on mount |
| `:has_more` | `false` | Computed from `read_all_events/2` result | Now loads data on mount |

### Assign State Machine

```
                  ┌─────────────────────────────────────────┐
                  │                                         │
    mount()       │         apply filter                    │
        │         │              │                          │
        ▼         │              ▼                          │
   ┌────────┐     │         ┌──────────┐                    │
   │  :all  │─────┼────────▶│ :filtered│────────────────────┘
   └────────┘     │         └──────────┘      clear filter
        │         │              │
        │         │              │
        ▼         │              ▼
   subscribes to  │       subscribes to
   "all_events"   │    "stream_type:{type}"
```

## PubSub Topics

### New Topic

| Topic | Message Format | Sender | Subscribers |
|-------|----------------|--------|-------------|
| `"all_events"` | `{:events_appended, stream_name, [EventEnvelope.t()]}` | EventStore on append | LiveView when `view_mode == :all` |

### Existing Topics (Unchanged)

| Topic | Message Format | Sender | Subscribers |
|-------|----------------|--------|-------------|
| `"stream_type:{type}"` | `{:events_appended, stream_name, [EventEnvelope.t()]}` | EventStore on append | LiveView when `view_mode == :filtered` |

## Validation Rules

### Pagination Options

| Option | Type | Default | Validation |
|--------|------|---------|------------|
| `page` | `pos_integer()` | `1` | Must be >= 1 |
| `page_size` | `pos_integer()` | `20` | Must be 1..100 |

### View Mode Transitions

| Current Mode | Event | New Mode | Side Effects |
|--------------|-------|----------|--------------|
| `:all` | `"filter"` with non-empty type | `:filtered` | Unsubscribe `"all_events"`, subscribe `"stream_type:{type}"` |
| `:filtered` | `"clear_filter"` | `:all` | Unsubscribe `"stream_type:{type}"`, subscribe `"all_events"` |
| `:filtered` | `"filter"` with different type | `:filtered` | Unsubscribe old type, subscribe new type |

## State Transitions

### EventStore Append Flow

```
append_to_stream(stream_name, events)
    │
    ├── Store events in stream
    ├── Increment global_position
    ├── Broadcast to "stream_type:{type}"  (existing)
    └── Broadcast to "all_events"          (NEW)
```

### LiveView Mount Flow (NEW)

```
mount(_params, _session, socket)
    │
    ├── if connected?(socket):
    │   └── subscribe to "all_events"
    │
    ├── call read_all_events(page: 1)
    │
    ├── assign :view_mode = :all
    ├── assign :stream_type = nil
    ├── assign :events from result
    ├── assign :has_more from result
    ├── assign :total from result
    └── assign :events_empty? from result
```

## Empty State Messages

| Condition | Message |
|-----------|---------|
| `view_mode == :all` and `events == []` | "No events in store" |
| `view_mode == :filtered` and `events == []` | "No events match filter '[stream_type]'" |
