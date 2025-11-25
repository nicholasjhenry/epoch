# Data Model: Stream Type Filter

**Feature**: 003-stream-type-filter  
**Date**: 2025-11-25

## Overview

This feature extends the existing EventStore with stream type filtering capabilities. No new persistent entities are introduced; the feature operates on the existing in-memory event data structures.

## Existing Entities (Reference)

### EventEnvelope

Wraps an event with metadata. Already exists in `Epoch.EventStore.EventEnvelope`.

```elixir
defmodule Epoch.EventStore.EventEnvelope do
  @type t :: %__MODULE__{
    event: term(),
    metadata: EventMetadata.t()
  }
  
  defstruct [:event, :metadata]
end
```

### EventMetadata

Contains positioning information for each event. Already exists in `Epoch.EventStore.EventMetadata`.

```elixir
defmodule Epoch.EventStore.EventMetadata do
  @type t :: %__MODULE__{
    event_id: String.t(),
    stream_position: non_neg_integer(),
    log_position: non_neg_integer()
  }
  
  defstruct [:event_id, :stream_position, :log_position]
end
```

## New Data Structures

### EventWithStream

A view model combining an event with its source stream name for display purposes.

```elixir
@type event_with_stream :: %{
  event: term(),
  stream_name: String.t(),
  metadata: EventMetadata.t()
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| event | term() | The domain event (e.g., OrderPlaced, CartCreated) |
| stream_name | String.t() | Source stream identifier (e.g., "order-123") |
| metadata | EventMetadata.t() | Event positioning metadata |

### FilteredEventsResult

Result structure returned from stream type queries.

```elixir
@type filtered_events_result :: %{
  events: [event_with_stream()],
  has_more: boolean(),
  total: non_neg_integer()
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| events | [event_with_stream()] | Paginated list of events matching filter |
| has_more | boolean() | True if more pages available |
| total | non_neg_integer() | Total count of matching events |

### FilterState

LiveView state for the events filter view.

```elixir
@type filter_state :: %{
  stream_type: String.t() | nil,
  page: pos_integer(),
  page_size: pos_integer(),
  has_more: boolean(),
  total: non_neg_integer(),
  events_empty?: boolean()
}
```

**Fields:**
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| stream_type | String.t() \| nil | nil | Current filter value |
| page | pos_integer() | 1 | Current page number |
| page_size | pos_integer() | 20 | Events per page |
| has_more | boolean() | false | More pages available |
| total | non_neg_integer() | 0 | Total matching events |
| events_empty? | boolean() | true | No events match filter |

## Stream Naming Convention

### Format
```
{type}-{identifier}
```

### Examples
| Stream Name | Type | Identifier |
|-------------|------|------------|
| order-123 | order | 123 |
| order-456 | order | 456 |
| cart-abc | cart | abc |
| user-u001 | user | u001 |

### Type Extraction Rules

1. Split stream name on first hyphen
2. First segment is the type
3. If no hyphen, full name is the type

```elixir
# Examples
"order-123"     → type: "order"
"order-456-v2"  → type: "order"  (split on FIRST hyphen only)
"payment"       → type: "payment" (no hyphen)
""              → error (invalid)
```

## PubSub Topics

### Topic Format
```
stream_type:{type}
```

### Examples
| Topic | Events |
|-------|--------|
| stream_type:order | All events from order-* streams |
| stream_type:cart | All events from cart-* streams |
| stream_type:user | All events from user-* streams |

### Message Format
```elixir
{:events_appended, stream_name, events}
```

Where:
- `stream_name` - The specific stream that received events (e.g., "order-123")
- `events` - List of raw domain events (not envelopes)

## Validation Rules

### Stream Type Filter

| Validation | Rule | Error |
|------------|------|-------|
| Required | Cannot be empty or whitespace | "Stream type is required" |
| Format | String only | "Stream type must be a string" |

### Pagination

| Validation | Rule | Error |
|------------|------|-------|
| Page | >= 1 | "Page must be at least 1" |
| Page Size | 1-100 | "Page size must be between 1 and 100" |

## State Transitions

### Filter State Machine

```
[Initial]
    │
    ▼
[No Filter] ──filter({type})──→ [Filtered]
    │                               │
    │                               ├──filter({new_type})──→ [Filtered]
    │                               │
    │                               ├──clear()──→ [No Filter]
    │                               │
    │                               └──page({n})──→ [Filtered]
    │
    └──(mount)
```

### Event Flow

```
[EventStore] ──append──→ [broadcast to stream_type:{type}]
                               │
                               ▼
[LiveView subscribed to stream_type:{type}] ──handle_info──→ [stream update]
                                                                   │
                                                                   ▼
                                                            [UI updates]
```

## Relationships

```
┌──────────────────────────────────────────────────────────────┐
│                        EventStore                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ streams: %{                                              │ │
│  │   "order-123" => %{events: [...], version: 5},          │ │
│  │   "order-456" => %{events: [...], version: 3},          │ │
│  │   "cart-789"  => %{events: [...], version: 2}           │ │
│  │ }                                                        │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                              │ read_by_stream_type("order")
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    FilteredEventsResult                       │
│  events: [                                                    │
│    %{event: %OrderPlaced{}, stream_name: "order-123", ...}, │
│    %{event: %OrderShipped{}, stream_name: "order-456", ...} │
│  ],                                                           │
│  has_more: false,                                             │
│  total: 8                                                     │
└──────────────────────────────────────────────────────────────┘
```
