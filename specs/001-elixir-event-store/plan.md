# Implementation Plan: In-Memory Event Store

**Branch**: `001-elixir-event-store` | **Date**: 2025-11-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-elixir-event-store/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement an in-memory event store in Elixir that provides event sourcing capabilities: appending events to named streams, reading events with pagination, optimistic concurrency control via stream versions, aggregate state reconstruction, and stream subscriptions. The implementation is based on the TypeScript reference implementation at `tmp/course-implementing-eventsourcing/app/infrastructure/inmemoryEventstore.ts`.

## Technical Context

**Language/Version**: Elixir ~> 1.15  
**Primary Dependencies**: None (pure Elixir/OTP implementation)  
**Storage**: In-memory (GenServer state with Map-based storage)  
**Testing**: ExUnit with unit and integration tests  
**Target Platform**: Elixir/BEAM umbrella application (apps/epoch)  
**Project Type**: Library module within existing Phoenix umbrella app  
**Performance Goals**: 10,000+ events across 1,000 streams without degradation; O(1) append operations (excluding subscription callbacks)  
**Constraints**: Synchronous subscription callbacks block append operations; memory linear with total event count  
**Scale/Scope**: Development/testing event store; not intended for production persistence (in-memory only)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Tests-first plan documented**: Spec contains comprehensive test plan with 21 unit tests and 4 integration tests covering all functional requirements. Tests will be written before implementation following TDD.
- [x] **Cross-boundary interactions enumerated**: No external boundaries - pure in-memory implementation. Integration tests cover GenServer process interaction and concurrent access patterns.
- [x] **Dependencies, configuration changes, and feature contracts documented**: Zero external dependencies. No configuration required. Public API contracts will be documented in contracts/ (Phase 1).
- [x] **Failure handling strategy captured**: Spec defines three failure modes: version mismatch (raise error with context), invalid pagination (raise ArgumentError), subscription callback errors (log and continue). No external dependencies to handle.
- [x] **Demo data additions planned**: Will add seed data with sample event streams demonstrating typical usage patterns (orders, counters, user activity).
- [x] **Skill-driven implementation planned**: Required skills: `elixir-core` (pattern matching, data structures), `elixir-otp` (GenServer design), `elixir-testing` (ExUnit patterns). No Phoenix/Ecto involvement - pure library code.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
apps/epoch/
├── lib/
│   └── epoch/
│       ├── event_store.ex          # Main GenServer and public API
│       ├── event_store/
│       │   ├── event_envelope.ex   # Event metadata wrapper struct
│       │   ├── stream.ex           # Stream state and operations
│       │   └── subscription.ex     # Subscription management
│       └── application.ex          # (existing - add EventStore to supervision tree)
└── test/
    └── epoch/
        ├── event_store_test.exs    # Main API tests (append, read, aggregate)
        └── event_store/
            ├── concurrency_test.exs     # Integration: concurrent operations
            ├── subscription_test.exs    # Subscription behavior tests
            └── support/
                └── test_events.ex       # Sample event types for testing

apps/epoch/priv/repo/
└── seeds.exs                        # (existing - add event store demo data)
```

**Structure Decision**: Elixir umbrella application structure. The event store will be implemented as a GenServer module within the existing `apps/epoch` application. All code lives under `lib/epoch/event_store` with the main API surface in `epoch/event_store.ex`. Tests follow the same structure under `test/epoch/`. This is a library component with no web/UI layer, so no Phoenix involvement is needed.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. All constitution checks pass.
