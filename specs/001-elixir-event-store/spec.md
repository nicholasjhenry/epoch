# Feature Specification: In-Memory Event Store

**Feature Branch**: `001-elixir-event-store`  
**Created**: 2025-11-24  
**Status**: Draft  
**Input**: User description: "Implement an event store in Elixir based on inmemoryEventstore.ts"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Store and Retrieve Events (Priority: P1)

As a developer building an event-sourced system, I need to append events to named streams and read them back so that I can persist and reconstruct the state of my domain aggregates.

**Why this priority**: This is the foundational capability of any event store - without it, no other features are possible. It represents the core value proposition.

**Independent Test**: Can be fully tested by appending events to a stream and reading them back, verifying the events are returned in order with correct metadata.

**Acceptance Scenarios**:

1. **Given** an empty event store, **When** I append 3 events to a stream named "order-123", **Then** the stream contains exactly 3 events in the order they were appended
2. **Given** a stream "order-123" with 5 events, **When** I read the stream, **Then** I receive all 5 events with their original data intact
3. **Given** multiple streams exist, **When** I read from "order-123", **Then** I only receive events from that specific stream, not from other streams
4. **Given** a stream with no events, **When** I attempt to read it, **Then** the system indicates the stream is empty or does not exist

---

### User Story 2 - Optimistic Concurrency Control (Priority: P1)

As a developer building concurrent systems, I need the event store to verify expected stream versions when appending so that I can prevent lost updates when multiple processes attempt to modify the same stream simultaneously.

**Why this priority**: Concurrent writes are common in distributed systems. Without version checking, the last write wins and earlier changes are silently lost, corrupting the event history.

**Independent Test**: Can be fully tested by attempting to append events with an expected version that doesn't match the current stream version, and verifying the operation is rejected.

**Acceptance Scenarios**:

1. **Given** a stream "order-123" at version 3, **When** I append events expecting version 3, **Then** the append succeeds and the stream advances to version 4
2. **Given** a stream "order-123" at version 5, **When** I append events expecting version 3, **Then** the append is rejected with a version mismatch error
3. **Given** an empty stream, **When** I append events expecting version 0 or no stream exists, **Then** the append succeeds and creates the stream at version 1
4. **Given** a stream at version 2, **When** I append without specifying an expected version, **Then** the append succeeds unconditionally (no version check)

---

### User Story 3 - Paginated Stream Reading (Priority: P2)

As a developer working with large event streams, I need to read events in chunks using pagination so that I can process historical events without loading the entire stream into memory.

**Why this priority**: Essential for production systems where streams can grow to thousands of events. Memory constraints make full stream loading impractical.

**Independent Test**: Can be fully tested by creating a stream with 100 events, reading events 20-40, and verifying only those 20 events are returned.

**Acceptance Scenarios**:

1. **Given** a stream with 100 events, **When** I read events starting from position 20 with a limit of 10, **Then** I receive events 20-29
2. **Given** a stream with 50 events, **When** I read events from position 40 to position 60, **Then** I receive events 40-49 (up to the end of the stream)
3. **Given** a stream with events, **When** I specify a starting position beyond the stream length, **Then** I receive an empty result
4. **Given** a stream with 100 events, **When** I read with no pagination parameters, **Then** I receive all 100 events

---

### User Story 4 - Aggregate State Reconstruction (Priority: P2)

As a developer building event-sourced aggregates, I need to apply an evolve function to all events in a stream so that I can reconstruct the current state of my aggregate without manually reading and reducing events.

**Why this priority**: Common pattern in event sourcing that reduces boilerplate. However, can be implemented by consumers using basic read functionality, making it a convenience feature.

**Independent Test**: Can be fully tested by appending events representing state changes, providing an evolve function that applies those changes, and verifying the final state matches expectations.

**Acceptance Scenarios**:

1. **Given** a stream "counter-1" with events [+5, +3, -2], **When** I aggregate with an evolve function that sums values starting from 0, **Then** the final state is 6
2. **Given** an empty stream, **When** I aggregate with initial state 0, **Then** the final state is 0
3. **Given** a stream with 50 events, **When** I aggregate with pagination (reading only first 20 events), **Then** the state reflects only those 20 events
4. **Given** a stream at version 10, **When** I aggregate, **Then** the result includes both the final state and the current stream version (10)

---

### User Story 5 - Stream Subscriptions (Priority: P3)

As a developer building reactive systems, I need to subscribe to streams and receive notifications when new events are appended so that I can trigger side effects and maintain read models without polling.

**Why this priority**: Enables reactive patterns and read model projections, but the system functions without it. Subscriptions are a performance optimization over polling.

**Independent Test**: Can be fully tested by subscribing to a stream, appending events, and verifying the subscription callback receives those events.

**Acceptance Scenarios**:

1. **Given** I subscribe to stream "order-123", **When** an event is appended to that stream, **Then** my callback receives the new event and the updated stream version
2. **Given** I subscribe to an empty stream "order-456", **When** the subscription is established, **Then** my callback immediately receives the current state (empty stream at version 0)
3. **Given** I subscribe to a stream with existing events, **When** the subscription is established, **Then** my callback receives all existing events as initial state
4. **Given** I have an active subscription, **When** I unsubscribe, **Then** I no longer receive notifications for subsequent events
5. **Given** multiple subscriptions on the same stream, **When** an event is appended, **Then** all active subscriptions receive the event

---

### Edge Cases

- What happens when appending zero events to a stream? (Should be a no-op or return current version)
- What happens when a subscription callback throws an error? (Logged and swallowed - see Failure Modes section)
- How does the system handle concurrent appends to different streams? (Should not block each other)
- What happens when reading a stream with negative offsets or positions? (Should return an error or treat as position 0)
- How are event IDs generated? (Must be unique across all events, not just within a stream)
- What happens when unsubscribing a subscription that doesn't exist or was already unsubscribed? (Should be idempotent)
- What happens if a subscription callback takes a very long time to execute? (The append operation will block until all callbacks complete, since callbacks are synchronous)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST store events in named streams, where each stream maintains its own ordered sequence of events
- **FR-002**: System MUST append one or more events to a stream atomically, ensuring all events are added or none are
- **FR-003**: System MUST assign each event a unique identifier when appended
- **FR-004**: System MUST track three metadata values for each event: event ID, position within stream (starting at 1), and global position across all events
- **FR-005**: System MUST increment stream version by the number of events appended (e.g., appending 3 events to version 5 results in version 8)
- **FR-006**: System MUST support optimistic concurrency control by allowing callers to specify an expected stream version when appending
- **FR-007**: System MUST reject append operations when the expected version does not match the current stream version
- **FR-008**: System MUST allow appending to streams without specifying an expected version (unconditional append)
- **FR-009**: System MUST support reading all events from a stream in the order they were appended
- **FR-010**: System MUST support reading a subset of events using "from position" and "to position" parameters
- **FR-011**: System MUST support reading a limited number of events using "from position" and "max count" parameters
- **FR-012**: System MUST return the current stream version when reading a stream
- **FR-013**: System MUST indicate when a requested stream does not exist or is empty
- **FR-014**: System MUST support aggregating a stream by applying an evolve function to each event, producing a final state
- **FR-015**: System MUST support aggregating a subset of a stream using the same pagination options as reading
- **FR-016**: System MUST allow multiple subscribers to register callbacks for a single stream
- **FR-017**: System MUST invoke all active subscription callbacks synchronously when events are appended to their subscribed stream, completing all callbacks before the append operation returns
- **FR-018**: System MUST provide newly appended events and the new stream version to subscription callbacks
- **FR-019**: System MUST invoke subscription callbacks with existing events when a subscription is first registered
- **FR-020**: System MUST allow unsubscribing active subscriptions
- **FR-021**: System MUST maintain event order within a stream across all operations (append, read, aggregate, subscribe)

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: None - This is an in-memory implementation with no external dependencies
- **Configuration**: None - All behavior is deterministic and requires no configuration

### Key Entities *(include if feature involves data)*

- **Event**: A domain event representing something that happened, containing event-specific data. The structure of event data is determined by the application, not the event store.
- **Event Envelope**: A wrapper around an event that adds metadata: event ID, stream position, and global log position. This is what gets physically stored in the event store.
- **Stream**: A named, ordered collection of event envelopes. Each stream has a name (string) and a current version (integer representing the count of events).
- **Stream Version**: An integer representing the number of events in a stream. Used for optimistic concurrency control. An empty or non-existent stream has no version (or can be considered version 0).
- **Subscription**: A registered callback function that receives notifications when events are appended to a specific stream. A subscription is associated with exactly one stream but a stream can have multiple subscriptions.
- **Aggregate State**: The result of applying an evolve function sequentially to all events in a stream, starting from an initial state. Not stored - computed on demand.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test appending a single event to a new stream creates the stream with version 1
- Test appending multiple events atomically increments version by the count of events
- Test reading from a non-existent stream returns null or appropriate empty indicator
- Test reading from a stream returns events in append order
- Test appending with matching expected version succeeds
- Test appending with mismatched expected version raises an error
- Test appending without expected version always succeeds regardless of current version
- Test event IDs are unique across multiple appends to multiple streams
- Test stream position metadata starts at 1 and increments sequentially
- Test global log position increases monotonically across all streams
- Test paginated reading with "from" and "to" parameters returns correct subset
- Test paginated reading with "from" and "max count" returns correct subset
- Test paginated reading beyond stream length returns empty or partial results
- Test aggregating a stream with an evolve function produces correct final state
- Test aggregating an empty stream returns the initial state
- Test aggregating with pagination applies evolve only to requested events
- Test subscribing to a stream immediately invokes callback with existing events
- Test appending to a stream invokes all active subscription callbacks
- Test subscription callback receives correct events and new version
- Test unsubscribing prevents future callback invocations
- Test multiple subscriptions on the same stream all receive events independently

### Integration Tests *(required for each cross-boundary interaction)*

- Test concurrent appends to different streams do not block each other
- Test concurrent appends to the same stream with version checking (only one should succeed)
- Test subscription callbacks are isolated (one callback error doesn't affect others)
- Test event store behaves correctly when integrated as a GenServer process (if applicable)

## Failure Modes & Observability *(mandatory)*

### Expected Failure Scenarios

- **Version Mismatch**: When expected version doesn't match current version during append
  - **Detection**: Explicitly checked before appending events
  - **Response**: Raise an error indicating the expected version and actual current version
  - **Observable**: Error contains both expected and actual versions for debugging

- **Invalid Pagination Parameters**: When reading with negative positions or "to" less than "from"
  - **Detection**: Validate parameters before executing read
  - **Response**: Raise argument error or return empty results (depending on parameter)
  - **Observable**: Error message indicates which parameter is invalid

- **Subscription Callback Errors**: When a subscription callback raises an error
  - **Detection**: Wrap callback invocations in error handling
  - **Response**: Log the error with full context and continue processing remaining subscriptions. The append operation completes successfully regardless of subscription callback failures.
  - **Observable**: Error log entry includes stream name, subscription identity, callback error details, and the events that triggered the error
  - **Rationale**: Subscription callbacks are side effects - they should not prevent events from being persisted. Failed subscribers can review logs and re-process events if needed.

### Logging & Observability

- Log each append operation with: stream name, number of events appended, previous version, new version
- Log subscription registrations and unsubscriptions with stream name and subscriber identity
- Log version mismatch errors with full context (stream name, expected vs actual version)
- For debugging, provide a function to inspect all streams and their event counts

### Performance Characteristics

- Append operations should complete in O(1) time (just adding to the end of a list/array) plus O(m) time where m is the number of active subscriptions (since callbacks are executed synchronously)
- Read operations should complete in O(n) time where n is the number of events requested
- Subscription notifications are synchronous - append operations block until all subscription callbacks complete
- Memory usage grows linearly with the total number of events across all streams (in-memory storage)
- **Performance consideration**: Slow or blocking subscription callbacks will directly impact append operation latency

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can append events and read them back with 100% accuracy - no events lost or corrupted
- **SC-002**: The event store correctly prevents lost updates in 100% of concurrent write scenarios using version checking
- **SC-003**: Developers can reconstruct aggregate state by reading and reducing events, or using the aggregate function, with identical results
- **SC-004**: Subscriptions deliver all appended events to all active subscribers with zero missed events
- **SC-005**: The event store supports at least 10,000 events across 1,000 streams without performance degradation (as this is an in-memory store)
- **SC-006**: All 21 functional requirements are verified by passing unit tests
- **SC-007**: Documentation and examples enable a developer unfamiliar with the codebase to successfully append and read events within 15 minutes
