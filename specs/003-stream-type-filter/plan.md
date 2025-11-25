# Implementation Plan: Stream Type Filter

**Branch**: `003-stream-type-filter` | **Date**: 2025-11-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-stream-type-filter/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a LiveView-based event store viewer accessible at `/dev/events` that allows filtering events by stream type prefix (e.g., "order" matches "order-123", "order-456"). The view will display events from all matching streams in chronological order with pagination, live updates via PubSub when new events are published, and clear identification of source streams for each event.

## Technical Context

**Language/Version**: Elixir ~> 1.15 / OTP 28  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1  
**Storage**: In-memory EventStore (GenServer-based, Feature 001)  
**Testing**: ExUnit with Phoenix.LiveViewTest, LazyHTML  
**Target Platform**: Phoenix web application (dev-only route)
**Project Type**: Umbrella application (apps/epoch, apps/epoch_web)  
**Performance Goals**: Filter results within 2 seconds for up to 10,000 matching events; live updates within 2 seconds of publication  
**Constraints**: Maximum page size 100 events; default page size 20 events  
**Scale/Scope**: Support 100 concurrent users viewing filtered events with live updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
- [x] Skill-driven implementation planned: required skills identified (e.g., phoenix-contexts, ecto, elixir-testing) and conventions documented for code generation compliance.

### Tests-First Plan

#### Unit Tests (write first)

1. **Stream type extraction**
   - Test extracting "order" from "order-123"
   - Test extracting "order" from "order-456-item"
   - Test edge case: stream with no hyphen returns full name
   - Test edge case: empty string returns empty string

2. **Stream filtering by type**
   - Test filtering returns events from all matching streams
   - Test filtering excludes events from non-matching streams
   - Test results are ordered by global position (chronological)
   - Test empty filter input is rejected with error
   - Test non-existent type returns empty list (not error)

3. **Pagination**
   - Test default page size (20)
   - Test custom page size
   - Test page boundaries
   - Test invalid page size rejection (< 1 or > 100)

4. **PubSub notifications**
   - Test new events trigger broadcast for matching type
   - Test new events do not broadcast for non-matching type

#### Integration Tests

1. **LiveView mount and display**
   - Test mounting at `/dev/events`
   - Test displaying events with stream names
   - Test pagination controls

2. **Filtering workflow**
   - Test entering filter text and submitting
   - Test filter results update display
   - Test clearing filter

3. **Live updates**
   - Test subscribing to filtered type
   - Test receiving new events via PubSub
   - Test unsubscribing on navigate away

### Cross-Boundary Interactions

| Boundary | Interaction | Integration Test |
|----------|-------------|------------------|
| EventStore → LiveView | Query events by type | Test filtering returns correct events |
| EventStore → PubSub | Broadcast on append | Test new events trigger broadcast |
| PubSub → LiveView | Receive live updates | Test LiveView receives and displays new events |
| LiveView → Router | Dev-only route | Test route only available in dev |

### Dependencies

- **Epoch.EventStore**: Existing in-memory event store (Feature 001) - must be extended with stream type filtering
- **Phoenix.PubSub**: Already configured in application - used for live updates broadcast
- **No new dependencies required**

### Configuration

- Route `/dev/events` added inside existing `if dev_routes` block in router
- No new configuration keys needed

### Failure Handling

| Failure Mode | Strategy |
|--------------|----------|
| EventStore unavailable | Return error tuple, display error message in LiveView |
| Invalid filter input | Return validation error, show inline error |
| Large result sets | Enforce max page size (100), paginate |
| PubSub delivery failure | Log warning, client can reconnect |
| Subscription leak | Clean up in `terminate/2` callback |

### Demo Data

Seeds file will be updated to include:
- 5 order streams with 3-5 events each
- 3 cart streams with 2-3 events each
- 2 user streams with 1-2 events each

### Required Skills

| Skill | Usage |
|-------|-------|
| phoenix-liveview | LiveView implementation, streams for event list, live updates |
| elixir-testing | ExUnit test structure, describe blocks, fixtures |
| elixir-core | Pattern matching, function design |
| elixir-otp | GenServer patterns for EventStore extension |

## Project Structure

### Documentation (this feature)

```text
specs/003-stream-type-filter/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Umbrella application structure
apps/
├── epoch/                           # Core business logic
│   ├── lib/
│   │   └── epoch/
│   │       └── event_store.ex       # Extend with read_by_stream_type/2
│   └── test/
│       └── epoch/
│           └── event_store/
│               └── stream_type_filter_test.exs  # Unit tests
│
└── epoch_web/                       # Web interface
    ├── lib/
    │   └── epoch_web/
    │       ├── live/
    │       │   └── dev/
    │       │       └── events_live.ex           # LiveView for /dev/events
    │       └── router.ex                        # Add /dev/events route
    └── test/
        └── epoch_web/
            └── live/
                └── dev/
                    └── events_live_test.exs     # Integration tests
```

**Structure Decision**: Umbrella application - core EventStore extension in `epoch` app, LiveView in `epoch_web` app. This maintains the existing separation of concerns.

## Complexity Tracking

> No violations requiring justification.
