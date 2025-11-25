# Implementation Plan: Default Event List

**Branch**: `004-default-event-list` | **Date**: 2025-11-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-default-event-list/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Display all events from the EventStore by default when the event viewer loads, enabling immediate browsing without requiring a filter. This requires:
1. Adding a `read_all_events/2` function to the EventStore with pagination support
2. Adding an `"all_events"` PubSub topic for global event subscriptions
3. Modifying the EventsLive LiveView to load all events on mount and subscribe to global updates
4. Distinguishing empty states: "no events in store" vs "no events match filter"

## Technical Context

**Language/Version**: Elixir ~> 1.15 (using 1.19.2) / OTP 28  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1  
**Storage**: In-memory EventStore (GenServer-based, Feature 001)  
**Testing**: ExUnit with Phoenix.LiveViewTest  
**Target Platform**: Web (Phoenix LiveView)  
**Project Type**: Umbrella web application (apps/epoch, apps/epoch_web)  
**Performance Goals**: Events displayed within 2 seconds of publication (per spec FR-005)  
**Constraints**: Pagination enforced (20 events/page default) to prevent memory issues  
**Scale/Scope**: Development tool - single instance, moderate event volumes (hundreds to low thousands)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
  - **Unit Tests (EventStore)**:
    - `read_all_events/2` returns events from all streams
    - `read_all_events/2` returns events in chronological order by global position
    - `read_all_events/2` pagination works correctly (page 1, page 2, etc.)
    - `read_all_events/2` returns empty result for empty store
    - PubSub broadcasts to `"all_events"` topic on any event append
  - **Integration Tests (LiveView)**:
    - Open viewer with existing events → all events displayed on load
    - Open viewer with empty store → "No events in store" message
    - In default view, publish event → update received in real-time
    - Start in default view, apply filter → filtered results shown
    - Start with filter, clear filter → return to all events view
    - Create 50 events, navigate pages in default view
    - Concurrent viewers receive independent live updates

- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
  - **EventStore → LiveView**: `read_all_events/2` call with pagination
  - **PubSub → LiveView**: `"all_events"` topic subscription for live updates
  - **Test data setup**: Use `EventStore.append_to_stream/3` to seed test events across multiple streams

- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
  - **Dependency**: EventStore (Feature 001) - requires new `read_all_events/2` function
  - **Dependency**: PubSub - requires broadcasting to new `"all_events"` topic
  - **Configuration**: Uses existing page size (20) and live update timeout (2 seconds)
  - **No new dependencies or configuration changes required**

- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
  - EventStore unavailable: Display flash error, same as current filter behavior
  - Large result sets: Pagination enforced (existing pattern)
  - Live update failure: Log error, client reconnect (existing pattern)
  - Subscription leak: Monitor active subscription count (existing pattern)

- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
  - **Not applicable**: EventStore is in-memory; no persistent seed data
  - **Manual verification**: Use existing PubSub mechanism to append test events via IEx

- [x] Skill-driven implementation planned: required skills identified (e.g., phoenix-contexts, ecto, elixir-testing) and conventions documented for code generation compliance.
  - **Required Skills**:
    - `elixir-core`: Pattern matching, function design, data structures
    - `elixir-otp`: GenServer patterns for EventStore modifications
    - `phoenix-liveview`: LiveView streams, subscriptions, assigns, testing
    - `phoenix-html`: HEEx template updates for empty state messages
    - `elixir-testing`: ExUnit patterns, LiveView testing with `Phoenix.LiveViewTest`

## Project Structure

### Documentation (this feature)

```text
specs/004-default-event-list/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Elixir Umbrella Application
apps/
├── epoch/                           # Core business logic
│   ├── lib/epoch/
│   │   ├── event_store.ex          # GenServer - ADD read_all_events/2
│   │   └── event_store/
│   │       ├── event_envelope.ex   # No changes
│   │       └── event_metadata.ex   # No changes
│   └── test/epoch/
│       └── event_store_test.exs    # ADD unit tests for read_all_events/2
│
└── epoch_web/                       # Phoenix web application
    ├── lib/epoch_web/
    │   └── live/dev/
    │       └── events_live.ex      # MODIFY mount, handle_info, template
    └── test/epoch_web/live/dev/
        └── events_live_test.exs    # ADD integration tests
```

**Structure Decision**: Umbrella application with `epoch` (core EventStore) and `epoch_web` (Phoenix LiveView). Changes span both apps: EventStore API extension in `epoch`, LiveView modifications in `epoch_web`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations identified. All Constitution Check gates pass.

## Post-Design Constitution Check (Phase 1 Complete)

*Re-evaluated after Phase 1 design artifacts generated.*

| Gate | Status | Notes |
|------|--------|-------|
| Tests-first plan | ✅ PASS | Unit and integration tests documented in quickstart.md |
| Cross-boundary interactions | ✅ PASS | EventStore→LiveView and PubSub→LiveView flows in data-model.md |
| Dependencies documented | ✅ PASS | No new deps; contracts specify API extensions |
| Failure handling | ✅ PASS | Same patterns as Feature 003; flash errors, pagination |
| Demo data | ✅ N/A | In-memory store; IEx-based verification |
| Skill-driven implementation | ✅ PASS | Required skills listed; contracts follow conventions |

**Gate Result**: All gates PASS. Ready for Phase 2 (task generation via `/speckit.tasks`).
