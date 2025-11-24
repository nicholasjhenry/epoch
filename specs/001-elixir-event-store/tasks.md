# Tasks: In-Memory Event Store

**Input**: Design documents from `/specs/001-elixir-event-store/`  
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for every user story. Write failing tests first (TDD approach as specified in plan.md constitution check), then implement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella App**: `apps/epoch/lib/epoch/` for source, `apps/epoch/test/epoch/` for tests
- Based on plan.md project structure

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create directory structure: `apps/epoch/lib/epoch/event_store/` and `apps/epoch/test/epoch/event_store/`
- [ ] T002 [P] Create error type module in `apps/epoch/lib/epoch/event_store/version_mismatch_error.ex`
- [ ] T003 [P] Create EventMetadata struct in `apps/epoch/lib/epoch/event_store/event_metadata.ex`
- [ ] T004 [P] Create EventEnvelope struct in `apps/epoch/lib/epoch/event_store/event_envelope.ex`
- [ ] T005 [P] Create test events module in `apps/epoch/test/epoch/event_store/support/test_events.ex`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core GenServer infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create GenServer skeleton with state structure in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T007 Implement `start_link/1` and `init/1` callbacks in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T008 Implement UUID generation helper function in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T009 Add EventStore to application supervision tree in `apps/epoch/lib/epoch/application.ex`
- [ ] T010 [P] Create basic GenServer startup test in `apps/epoch/test/epoch/event_store_test.exs`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Store and Retrieve Events (Priority: P1) 🎯 MVP

**Goal**: Append events to named streams and read them back with correct ordering and metadata

**Independent Test**: Append events to a stream and read them back, verifying events are returned in order with correct metadata

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T011 [P] [US1] Test appending single event to new stream creates stream with version 1 in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T012 [P] [US1] Test appending multiple events atomically increments version by count in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T013 [P] [US1] Test reading from non-existent stream returns appropriate indicator in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T014 [P] [US1] Test reading from stream returns events in append order in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T015 [P] [US1] Test event IDs are unique across multiple appends and streams in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T016 [P] [US1] Test stream position metadata starts at 1 and increments sequentially in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T017 [P] [US1] Test global log position increases monotonically across all streams in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T018 [P] [US1] Test appending zero events is no-op and returns current version in `apps/epoch/test/epoch/event_store_test.exs`

### Implementation for User Story 1

- [ ] T019 [US1] Implement `handle_call(:append_to_stream, ...)` for basic append without version check in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T020 [US1] Implement EventEnvelope creation with metadata generation in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T021 [US1] Implement `handle_call(:read_stream, ...)` for basic stream reading in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T022 [US1] Implement public API functions `append_to_stream/3` and `read_stream/2` in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T023 [US1] Add logging for append operations in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: User Story 1 should be fully functional and testable independently - can append and read events

---

## Phase 4: User Story 2 - Optimistic Concurrency Control (Priority: P1)

**Goal**: Verify expected stream versions when appending to prevent lost updates

**Independent Test**: Attempt to append events with mismatched expected version and verify operation is rejected with proper error

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [ ] T024 [P] [US2] Test appending with matching expected version succeeds in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T025 [P] [US2] Test appending with mismatched expected version raises VersionMismatchError in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T026 [P] [US2] Test appending without expected version always succeeds regardless of current version in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T027 [P] [US2] Test appending with expected_version: 0 succeeds on new/empty stream in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T028 [P] [US2] Integration test: concurrent appends to same stream with version checking (one succeeds) in `apps/epoch/test/epoch/event_store/concurrency_test.exs`

### Implementation for User Story 2

- [ ] T029 [US2] Add expected_version validation logic to append handler in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T030 [US2] Implement version mismatch error raising with context in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T031 [US2] Add logging for version mismatch errors in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: User Story 2 complete - optimistic concurrency control works independently

---

## Phase 5: User Story 3 - Paginated Stream Reading (Priority: P2)

**Goal**: Read events in chunks using from/to or from/max_count pagination

**Independent Test**: Create stream with 100 events, read events 20-40, verify only those 20 events are returned

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [ ] T032 [P] [US3] Test paginated reading with from/to parameters returns correct subset in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T033 [P] [US3] Test paginated reading with from/max_count returns correct subset in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T034 [P] [US3] Test reading beyond stream length returns empty or partial results in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T035 [P] [US3] Test invalid pagination parameters raise ArgumentError in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T036 [P] [US3] Test reading with no pagination parameters returns all events in `apps/epoch/test/epoch/event_store_test.exs`

### Implementation for User Story 3

- [ ] T037 [US3] Implement pagination parameter parsing (from, to, max_count) in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T038 [US3] Implement pagination validation (negative from, to < from, etc.) in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T039 [US3] Update read_stream handler to apply pagination via Enum.slice in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: User Story 3 complete - paginated reading works independently

---

## Phase 6: User Story 4 - Aggregate State Reconstruction (Priority: P2)

**Goal**: Apply evolve function to stream events to reconstruct aggregate state

**Independent Test**: Append events representing state changes, provide evolve function, verify final state matches expectations

### Tests for User Story 4 (MANDATORY - write these first) ⚠️

- [ ] T040 [P] [US4] Test aggregating stream with evolve function produces correct final state in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T041 [P] [US4] Test aggregating empty stream returns initial state in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T042 [P] [US4] Test aggregating with pagination applies evolve only to requested events in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T043 [P] [US4] Test aggregate result includes both final state and current version in `apps/epoch/test/epoch/event_store_test.exs`

### Implementation for User Story 4

- [ ] T044 [US4] Implement `handle_call(:aggregate_stream, ...)` using read + Enum.reduce in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T045 [US4] Implement public API function `aggregate_stream/4` in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: User Story 4 complete - aggregate reconstruction works independently

---

## Phase 7: User Story 5 - Stream Subscriptions (Priority: P3)

**Goal**: Subscribe to streams and receive notifications when events are appended

**Independent Test**: Subscribe to stream, append events, verify callback receives those events with correct version

### Tests for User Story 5 (MANDATORY - write these first) ⚠️

- [ ] T046 [P] [US5] Test subscribing immediately invokes callback with existing events in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T047 [P] [US5] Test appending invokes all active subscription callbacks in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T048 [P] [US5] Test subscription callback receives correct events and new version in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T049 [P] [US5] Test unsubscribing prevents future callback invocations in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T050 [P] [US5] Test multiple subscriptions on same stream all receive events independently in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T051 [P] [US5] Integration test: subscription callback errors are isolated (one error doesn't affect others) in `apps/epoch/test/epoch/event_store/subscription_test.exs`
- [ ] T052 [P] [US5] Test unsubscribing non-existent subscription is idempotent in `apps/epoch/test/epoch/event_store/subscription_test.exs`

### Implementation for User Story 5

- [ ] T053 [US5] Add subscriptions map to GenServer state in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T054 [US5] Implement `handle_call(:subscribe, ...)` with immediate callback invocation in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T055 [US5] Implement `handle_call(:unsubscribe, ...)` in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T056 [US5] Update append handler to notify subscriptions synchronously with error isolation in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T057 [US5] Implement public API functions `subscribe/2` and `unsubscribe/2` in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T058 [US5] Add logging for subscription registration/unregistration and callback errors in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: User Story 5 complete - subscriptions work independently

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T059 [P] Implement `debug_all_streams/0` for debugging in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T060 [P] Add test for debug_all_streams in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T061 [P] Integration test: concurrent appends to different streams do not block each other in `apps/epoch/test/epoch/event_store/concurrency_test.exs`
- [ ] T062 [P] Integration test: GenServer process lifecycle and state in `apps/epoch/test/epoch/event_store/concurrency_test.exs`
- [ ] T063 Add seed data with sample event streams to `apps/epoch/priv/repo/seeds.exs`
- [ ] T064 Run quickstart.md validation scenarios manually
- [ ] T065 Final code review and cleanup

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User Story 1 (P1): Must complete first - provides basic append/read
  - User Story 2 (P1): Depends on US1 - adds version checking to append
  - User Story 3 (P2): Depends on US1 - adds pagination to read
  - User Story 4 (P2): Depends on US1 and US3 - uses read with pagination
  - User Story 5 (P3): Depends on US1 - adds subscriptions to append
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Core functionality
- **User Story 2 (P1)**: Requires US1 completion - Extends append with version check
- **User Story 3 (P2)**: Requires US1 completion - Extends read with pagination
- **User Story 4 (P2)**: Requires US1 + US3 completion - Uses paginated read
- **User Story 5 (P3)**: Requires US1 completion - Extends append with subscription notification

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Core logic before public API wrappers
- Logging added after core functionality works
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002-T005)
- Foundational task T010 can run in parallel with any non-blocking task
- All tests for a user story marked [P] can run in parallel
- User Stories 2, 3, and 5 have partial parallelism - they each extend US1 but don't depend on each other
- All Polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Test appending single event to new stream..." (T011)
Task: "Test appending multiple events atomically..." (T012)
Task: "Test reading from non-existent stream..." (T013)
Task: "Test reading from stream returns events..." (T014)
Task: "Test event IDs are unique..." (T015)
Task: "Test stream position metadata..." (T016)
Task: "Test global log position..." (T017)
Task: "Test appending zero events..." (T018)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Store and Retrieve Events)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready - basic append/read works!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Append/read works (MVP!)
3. Add User Story 2 → Test independently → Concurrency control works
4. Add User Story 3 → Test independently → Pagination works
5. Add User Story 4 → Test independently → Aggregation works
6. Add User Story 5 → Test independently → Subscriptions work
7. Each story adds value without breaking previous stories

### Priority-Based Delivery

With limited time, deliver in priority order:
- **P1 (Critical)**: US1 + US2 - Core functionality with safety
- **P2 (Important)**: US3 + US4 - Scalability and convenience
- **P3 (Nice to have)**: US5 - Reactive patterns

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Required skills: `elixir-core`, `elixir-otp`, `elixir-testing`
