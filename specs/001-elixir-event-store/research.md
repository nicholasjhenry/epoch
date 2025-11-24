# Research: In-Memory Event Store

**Feature**: 001-elixir-event-store  
**Date**: 2025-11-24

## Overview

This document consolidates research findings for implementing an in-memory event store in Elixir. The implementation will be based on the TypeScript reference at `tmp/course-implementing-eventsourcing/app/infrastructure/inmemoryEventstore.ts`.

## Key Technical Decisions

### 1. GenServer vs Agent for State Management

**Decision**: Use GenServer for event store implementation

**Rationale**:
- GenServer provides explicit process lifecycle control (init, terminate)
- Supports both synchronous (call) and asynchronous (cast) operations
- Better suited for complex state management with side effects (subscriptions)
- Allows for structured error handling and supervision
- GenServer call/cast provides clear backpressure semantics
- Reference: Elixir OTP documentation on GenServer patterns

**Alternatives Considered**:
- **Agent**: Simpler API but less control over execution model. Not suitable for managing subscriptions where we need to execute callbacks synchronously during append operations.
- **Pure module with ETS**: Would require manual process management and supervision. GenServer provides these patterns out-of-the-box.

### 2. Stream Version Representation

**Decision**: Use non-negative integers starting from 0 for empty streams

**Rationale**:
- Elixir integers are arbitrary precision (no overflow concerns like JavaScript BigInt)
- Version 0 represents empty/non-existent stream (matches TypeScript `undefined` case)
- Version N means stream has N events (1-indexed positions)
- Simpler than `:undefined` | `pos_integer()` union type
- Reference: TypeScript implementation uses BigInt, but Elixir integers are already arbitrary precision

**Implementation Pattern**:
```elixir
# Empty stream
%{version: 0, events: []}

# Stream with 5 events
%{version: 5, events: [...]}
```

### 3. Event ID Generation

**Decision**: Use Elixir's built-in UUID generation via `:crypto.strong_rand_bytes/1` and formatting

**Rationale**:
- No external dependencies (stdlib only)
- Cryptographically secure random generation
- Reference TypeScript uses `uuid` package's v4 implementation
- Elixir pattern: Generate 16 random bytes, format as UUID v4

**Implementation Pattern**:
```elixir
defp generate_event_id do
  <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
  
  <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  |> Base.encode16(case: :lower)
  |> format_uuid()
end
```

**Alternative**: Could use `Ecto.UUID.generate()` but adds Ecto dependency unnecessarily for a pure library component.

### 4. Subscription Callback Execution Model

**Decision**: Execute subscription callbacks synchronously during append operation

**Rationale**:
- Matches TypeScript reference implementation behavior
- Provides immediate consistency - subscribers see events before append returns
- Simpler error handling - callback errors are immediately visible
- Caller is aware of subscription processing time
- Trade-off: Slow callbacks block append operations (documented constraint)

**Alternatives Considered**:
- **Async with Task.async_stream**: Would provide non-blocking appends but introduces race conditions and makes delivery guarantees complex
- **GenStage/Broadway**: Over-engineered for in-memory dev tool. Adds significant complexity and external dependencies

### 5. Optimistic Concurrency Control Strategy

**Decision**: Validate expected version matches current version before appending

**Rationale**:
- Prevents lost updates in concurrent scenarios
- Matches TypeScript reference: `assertExpectedVersionMatchesCurrent`
- Raise `Epoch.EventStore.VersionMismatchError` with current and expected versions
- `nil` expected version means "append unconditionally"

**Error Structure**:
```elixir
defmodule Epoch.EventStore.VersionMismatchError do
  defexception [:stream_name, :expected_version, :current_version, :message]
end
```

### 6. Pagination Implementation

**Decision**: Support both `from/to` and `from/max_count` read patterns

**Rationale**:
- TypeScript reference supports both patterns
- `from/to`: Read events from position X to position Y (inclusive range)
- `from/max_count`: Read up to N events starting from position X
- Use Enum.slice/2 with calculated range
- Invalid parameters (from > to, negative positions) raise ArgumentError

**Implementation Pattern**:
```elixir
def read_stream(stream_name, opts \\ []) do
  from = Keyword.get(opts, :from, 0)
  to = calculate_to(opts, from)
  
  # Enum.slice handles out-of-bounds gracefully
  events = Enum.slice(all_events, from, to - from)
end
```

### 7. Aggregate State Reconstruction

**Decision**: Provide `aggregate_stream/3` that applies evolve function with Enum.reduce

**Rationale**:
- Common pattern in event sourcing - worth providing as convenience
- TypeScript reference provides this as first-class operation
- Simple delegation to read_stream + Enum.reduce
- Supports same pagination options as read_stream

**Implementation Pattern**:
```elixir
def aggregate_stream(stream_name, initial_state, evolve_fun, opts \\ []) do
  case read_stream(stream_name, opts) do
    {:ok, %{events: events, version: version}} ->
      state = Enum.reduce(events, initial_state, evolve_fun)
      {:ok, %{state: state, version: version}}
    
    {:error, _} = error -> error
  end
end
```

### 8. Subscription Management

**Decision**: Store subscriptions in GenServer state as `%{stream_name => [callback_functions]}`

**Rationale**:
- Simple map structure for O(1) lookup by stream name
- List of callback functions allows multiple subscribers per stream
- Subscribers identified by function reference for unsubscribe
- TypeScript reference uses same pattern with Map and array

**Subscription State Structure**:
```elixir
%{
  streams: %{stream_name => stream_state},
  subscriptions: %{stream_name => [callback_fun, ...]}
}
```

**Callback Signature**:
```elixir
callback_fun :: (version :: non_neg_integer(), events :: [term()]) -> any()
```

## Testing Strategy

### Unit Tests (21 tests based on spec)

**Append Operations** (8 tests):
1. Appending single event to new stream creates stream with version 1
2. Appending multiple events atomically increments version by count
3. Appending with matching expected version succeeds
4. Appending with mismatched expected version raises VersionMismatchError
5. Appending without expected version always succeeds
6. Appending zero events is no-op (returns current version)
7. Event IDs are unique across multiple appends and streams
8. Positions and global log positions increment correctly

**Read Operations** (5 tests):
1. Reading from non-existent stream returns appropriate indicator
2. Reading from stream returns events in append order
3. Paginated reading with from/to returns correct subset
4. Paginated reading with from/max_count returns correct subset
5. Reading beyond stream length returns empty/partial results

**Aggregate Operations** (4 tests):
1. Aggregating stream with evolve function produces correct state
2. Aggregating empty stream returns initial state
3. Aggregating with pagination applies evolve to subset
4. Result includes both final state and current version

**Subscription Operations** (4 tests):
1. Subscribing immediately invokes callback with existing events
2. Appending invokes all active subscription callbacks
3. Callbacks receive correct events and new version
4. Unsubscribing prevents future callback invocations

### Integration Tests (4 tests)

1. Concurrent appends to different streams do not block each other
2. Concurrent appends to same stream with version checking (one succeeds)
3. Subscription callbacks are isolated (one error doesn't affect others)
4. GenServer process lifecycle (restart, state preservation considerations)

### Test Event Types

```elixir
# apps/epoch/test/epoch/event_store/support/test_events.ex

defmodule Epoch.EventStore.TestEvents do
  defmodule OrderPlaced do
    defstruct [:order_id, :customer_id, :items, :total]
  end
  
  defmodule OrderShipped do
    defstruct [:order_id, :tracking_number, :carrier]
  end
  
  defmodule CounterIncremented do
    defstruct [:amount]
  end
  
  defmodule CounterDecremented do
    defstruct [:amount]
  end
end
```

## Performance Characteristics

**Time Complexity**:
- Append: O(1) base + O(m) where m = number of subscriptions
- Read: O(n) where n = number of events requested
- Aggregate: O(n) where n = number of events to process

**Space Complexity**:
- Memory: O(E) where E = total events across all streams
- Each event envelope: ~100-500 bytes depending on event data

**Concurrency**:
- All operations serialize through GenServer (FIFO queue)
- No lock contention - single process model
- Concurrent reads/appends to different streams still serialize
- Trade-off: Simplicity and correctness over throughput

## Logging & Observability

**Key Log Points**:
1. Stream append: stream name, event count, version transition
2. Version mismatch: stream name, expected vs actual version
3. Subscription registered/unregistered: stream name, subscriber count
4. Subscription callback error: stream name, error details, event context

**Debug Interface**:
```elixir
def debug_all_streams() do
  # Returns map of all streams and their event counts
  GenServer.call(__MODULE__, :debug_all_streams)
end
```

## Open Questions & Decisions Deferred to Implementation

1. **Supervision strategy**: Should EventStore be part of application supervision tree or started on-demand? Decision: Add to supervision tree for always-available semantics.

2. **Named vs anonymous GenServer**: Use named GenServer (`name: Epoch.EventStore`) for singleton semantics? Decision: Yes, matches reference implementation's global store pattern.

3. **Event data structure validation**: Should we enforce any structure on event data or accept any term? Decision: Accept any term - let application define event schemas.

4. **Stream deletion/truncation**: Not in spec but might be useful for testing. Decision: Defer to future enhancement if needed.

5. **Callback timeout**: Should subscription callbacks have execution time limits? Decision: No timeout initially - document as constraint. Can add later if needed.

## References

- TypeScript Reference: `tmp/course-implementing-eventsourcing/app/infrastructure/inmemoryEventstore.ts`
- Elixir GenServer: https://hexdocs.pm/elixir/GenServer.html
- Elixir Enum: https://hexdocs.pm/elixir/Enum.html
- UUID Generation: https://hexdocs.pm/elixir/UUID.html concepts
- Event Sourcing Patterns: Martin Fowler's Event Sourcing article (general concepts)
