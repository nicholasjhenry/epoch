# Data Model: In-Memory Event Store

**Feature**: 001-elixir-event-store  
**Date**: 2025-11-24

## Overview

This document defines the data structures and their relationships for the in-memory event store implementation. All structures are held in GenServer state with no persistence.

## Core Entities

### 1. EventEnvelope

**Description**: A wrapper around a domain event that adds system metadata. This is what gets stored in the event store.

**Module**: `Epoch.EventStore.EventEnvelope`

**Fields**:
- `event` (term) - The actual domain event data (application-defined structure)
- `metadata` (EventMetadata.t()) - System-generated metadata

**Struct Definition**:
```elixir
defmodule Epoch.EventStore.EventEnvelope do
  @type t :: %__MODULE__{
    event: term(),
    metadata: Epoch.EventStore.EventMetadata.t()
  }
  
  defstruct [:event, :metadata]
end
```

**Invariants**:
- `event` can be any Elixir term (no validation enforced)
- `metadata` must be present and valid EventMetadata struct

**Creation**: Created internally during append operations, never directly by clients

---

### 2. EventMetadata

**Description**: System metadata attached to every event envelope.

**Module**: `Epoch.EventStore.EventMetadata`

**Fields**:
- `event_id` (String.t()) - UUID v4 uniquely identifying this event
- `stream_position` (pos_integer) - Position within the stream (starts at 1)
- `log_position` (pos_integer) - Global position across all streams (starts at 1)

**Struct Definition**:
```elixir
defmodule Epoch.EventStore.EventMetadata do
  @type t :: %__MODULE__{
    event_id: String.t(),
    stream_position: pos_integer(),
    log_position: pos_integer()
  }
  
  defstruct [:event_id, :stream_position, :log_position]
end
```

**Invariants**:
- `event_id` must be unique across all events (enforced by UUID generation)
- `stream_position` starts at 1 and increments sequentially within a stream
- `log_position` starts at 1 and increments monotonically across all streams
- Both positions are never reused or decremented

---

### 3. Stream

**Description**: An ordered collection of event envelopes with a unique name and version.

**Module**: `Epoch.EventStore.Stream` (internal structure in GenServer state)

**Fields**:
- `name` (String.t()) - Unique identifier for the stream
- `events` (list(EventEnvelope.t())) - Ordered list of event envelopes
- `version` (non_neg_integer) - Count of events in the stream

**State Representation**:
```elixir
# In GenServer state, streams stored as:
%{
  "stream-name" => %{
    events: [%EventEnvelope{}, ...],
    version: 5
  }
}
```

**Invariants**:
- Stream name must be a non-empty string
- Events list is append-only (no deletions or modifications)
- Version always equals `length(events)`
- Empty stream has `version: 0, events: []`
- Events maintain insertion order

**State Transitions**:
```
Empty (version: 0) 
  -> append(1 event) 
  -> version: 1
  
version: N 
  -> append(M events) 
  -> version: N + M
```

---

### 4. Subscription

**Description**: A registered callback function that receives notifications when events are appended to a specific stream.

**Module**: Managed internally by GenServer state

**Fields**:
- `stream_name` (String.t()) - The stream being watched
- `callback` (function) - Function invoked when events are appended

**State Representation**:
```elixir
# In GenServer state, subscriptions stored as:
%{
  "stream-name" => [
    callback_fun,  # (version, events) -> :ok
    callback_fun2,
    ...
  ]
}
```

**Callback Signature**:
```elixir
@type subscription_callback :: (
  version :: non_neg_integer(),
  events :: [term()]
) -> any()
```

**Invariants**:
- Each stream can have zero or more subscriptions
- Subscriptions are identified by their function reference
- Callbacks receive unwrapped events (not EventEnvelopes)
- Callbacks execute synchronously during append operations
- Callback return values are ignored
- Callback errors are logged but don't prevent append success

**Lifecycle**:
1. **Register**: Add callback to stream's subscription list
2. **Initialize**: Immediately invoke with current stream state
3. **Notify**: Invoke on each append to the subscribed stream
4. **Unregister**: Remove callback from subscription list

---

### 5. GenServer State

**Description**: The complete in-memory state of the event store.

**Module**: `Epoch.EventStore` (internal state)

**Fields**:
- `streams` (map) - Stream name to stream data mapping
- `subscriptions` (map) - Stream name to callback list mapping
- `global_position` (non_neg_integer) - Next global log position to assign

**State Structure**:
```elixir
%{
  streams: %{
    "order-123" => %{
      events: [%EventEnvelope{...}, ...],
      version: 5
    },
    "order-456" => %{
      events: [...],
      version: 3
    }
  },
  subscriptions: %{
    "order-123" => [callback_fun],
    "order-456" => [callback_fun1, callback_fun2]
  },
  global_position: 8  # Total events across all streams
}
```

**Invariants**:
- `global_position` always equals sum of all stream versions
- Subscription keys are a subset of stream keys (can subscribe to non-existent streams)
- All operations serialize through GenServer (no concurrent state mutations)

---

## Relationships

### EventEnvelope → EventMetadata
- **Type**: Composition (1:1)
- **Direction**: EventEnvelope contains EventMetadata
- **Lifecycle**: Created together during append, never separated

### Stream → EventEnvelope
- **Type**: Aggregation (1:many)
- **Direction**: Stream contains ordered list of EventEnvelopes
- **Lifecycle**: EventEnvelopes created when appended to stream
- **Order**: Insertion order maintained

### Stream → Subscription
- **Type**: Association (1:many)
- **Direction**: Stream has multiple subscriptions watching it
- **Lifecycle**: Independent - subscriptions can outlive stream recreation

### GenServer State → Stream
- **Type**: Composition (1:many)
- **Direction**: State owns all streams
- **Lifecycle**: Streams exist only within GenServer state

### GenServer State → Subscription
- **Type**: Composition (1:many)
- **Direction**: State owns all subscriptions
- **Lifecycle**: Subscriptions exist only within GenServer state

---

## Data Flow Diagrams

### Append Operation Flow

```
Client
  |
  | 1. GenServer.call(:append_to_stream, events, opts)
  v
EventStore GenServer
  |
  | 2. Validate expected_version
  |
  | 3. Generate EventEnvelopes (with metadata)
  |    - Generate UUIDs
  |    - Assign stream positions
  |    - Assign global log positions
  |
  | 4. Update stream state
  |    - Append envelopes to events list
  |    - Increment version
  |
  | 5. Notify subscriptions (synchronous)
  |    - For each callback: callback.(new_version, new_events)
  |
  | 6. Return result
  v
Client receives {:ok, %{next_expected_version: N}}
```

### Read Operation Flow

```
Client
  |
  | 1. GenServer.call(:read_stream, stream_name, opts)
  v
EventStore GenServer
  |
  | 2. Lookup stream by name
  |
  | 3. Apply pagination (from/to or from/max_count)
  |    - Calculate slice range
  |    - Extract events
  |
  | 4. Unwrap EventEnvelopes to get raw events
  |
  | 5. Return result
  v
Client receives {:ok, %{events: [...], version: N}}
           or {:error, :stream_not_found}
```

### Subscription Flow

```
Client
  |
  | 1. GenServer.call(:subscribe, stream_name, callback)
  v
EventStore GenServer
  |
  | 2. Add callback to subscriptions map
  |
  | 3. Immediately invoke callback with current state
  |    callback.(current_version, current_events)
  |
  | 4. Return subscription reference
  v
Client receives callback_fun

... later, when events appended ...

EventStore GenServer (during append)
  |
  | For each subscription on stream:
  |   - callback.(new_version, new_events)
  |   - Log any errors but continue
  v
All subscriptions notified
```

---

## Validation Rules

### Stream Name
- Must be non-empty string
- No length limit enforced
- Recommended: Use descriptive names like "order-{id}", "cart-{id}"

### Expected Version (for optimistic concurrency)
- `nil` - No version check (unconditional append)
- `0` - Expect stream to be empty or non-existent
- `N > 0` - Expect stream to have exactly N events

**Validation Logic**:
```elixir
case {current_version, expected_version} do
  {current, nil} -> 
    # No check, always proceed
    :ok
  {current, expected} when current == expected -> 
    # Versions match, proceed
    :ok
  {current, expected} -> 
    # Mismatch, raise error
    raise VersionMismatchError
end
```

### Pagination Parameters
- `from` - Must be non-negative integer (default: 0)
- `to` - Must be >= from (default: end of stream)
- `max_count` - Must be positive integer (default: none)
- Invalid combinations raise ArgumentError

### Event Data
- No validation enforced
- Can be any Elixir term: struct, map, tuple, atom, etc.
- Recommendation: Use structs for type safety

---

## Error Cases

### VersionMismatchError
**When**: Expected version doesn't match current version during append

**Data**:
```elixir
%Epoch.EventStore.VersionMismatchError{
  stream_name: "order-123",
  expected_version: 3,
  current_version: 5,
  message: "Expected stream 'order-123' to be at version 3 but found version 5"
}
```

### ArgumentError
**When**: Invalid pagination parameters or malformed input

**Examples**:
- `from` is negative
- `to < from`
- `max_count` is zero or negative
- Stream name is empty string

---

## Memory Considerations

### Event Envelope Size
Approximate memory per event:

```
EventEnvelope: 100-500 bytes
  - event: 50-400 bytes (depends on event data)
  - metadata: ~50 bytes
    - event_id: 36 bytes (UUID string)
    - stream_position: 8 bytes
    - log_position: 8 bytes
```

### Scale Estimates

| Events | Streams | Memory (approx) |
|--------|---------|-----------------|
| 1,000 | 10 | ~200 KB |
| 10,000 | 100 | ~2 MB |
| 100,000 | 1,000 | ~20 MB |
| 1,000,000 | 10,000 | ~200 MB |

**Note**: These are rough estimates. Actual memory usage depends on event data size and BEAM overhead.

---

## Future Extensions (Not in Scope)

### Possible Enhancements
1. **Stream snapshots** - Cache aggregate state at intervals
2. **Event deletion/truncation** - Remove old events
3. **Stream metadata** - Store additional stream-level data
4. **Event type filtering** - Read only specific event types
5. **Global event stream** - Read all events across all streams
6. **Persistent storage** - Snapshot to disk/database
7. **Async subscriptions** - Non-blocking callback execution

These are explicitly out of scope for this implementation but documented for future consideration.
