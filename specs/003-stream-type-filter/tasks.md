# Tasks: Stream Type Filter

**Input**: Design documents from `/specs/003-stream-type-filter/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Tests are REQUIRED per the Constitution Check in plan.md. Unit tests must be written first (TDD approach).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Core app**: `apps/epoch/lib/epoch/`, `apps/epoch/test/epoch/`
- **Web app**: `apps/epoch_web/lib/epoch_web/`, `apps/epoch_web/test/epoch_web/`

---

## Phase 1: Setup

**Purpose**: Project initialization and test infrastructure

- [X] T001 Create test file structure for unit tests in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
- [X] T002 [P] Create test file structure for integration tests in apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs
- [X] T003 [P] Create LiveView directory structure at apps/epoch_web/lib/epoch_web/live/dev/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational (write first)

- [X] T004 [P] Write unit tests for extract_stream_type/1 helper in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test extracting "order" from "order-123"
  - Test extracting "order" from "order-456-item" (first hyphen only)
  - Test edge case: stream with no hyphen returns full name
  - Test edge case: empty string returns empty string

### Implementation for Foundational

- [X] T005 Implement extract_stream_type/1 helper function in apps/epoch/lib/epoch/event_store.ex
- [X] T006 Add route `/dev/events` to dev-only scope in apps/epoch_web/lib/epoch_web/router.ex

**Checkpoint**: Foundation ready - `extract_stream_type/1` passes all tests, route configured

---

## Phase 3: User Story 1 - Filter Events by Stream Type (Priority: P1) 🎯 MVP

**Goal**: Allow filtering events by stream type prefix (e.g., "order" matches "order-123", "order-456")

**Independent Test**: Create events across multiple streams with different type prefixes, filter by "order", verify only order-related events are returned in chronological order.

### Tests for User Story 1 (write first)

- [X] T007 [P] [US1] Write unit tests for read_by_stream_type/3 filtering logic in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test filtering returns events from all matching streams
  - Test filtering excludes events from non-matching streams
  - Test results are ordered by global position (chronological)
  - Test empty filter input is rejected with error
  - Test non-existent type returns empty list (not error)

- [X] T008 [P] [US1] Write unit tests for read_by_stream_type/3 validation in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test whitespace-only stream_type rejected
  - Test page < 1 rejected
  - Test page_size < 1 rejected
  - Test page_size > 100 rejected

- [X] T009 [P] [US1] Write integration test for LiveView filter workflow in apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs
  - Test mounting at /dev/events
  - Test entering filter text and submitting
  - Test filter results update display
  - Test clearing filter

### Implementation for User Story 1

- [X] T010 [US1] Implement read_by_stream_type/3 function in apps/epoch/lib/epoch/event_store.ex
  - Add validation for stream_type, page, page_size
  - Add GenServer.call handler for {:read_by_stream_type, ...}
  - Filter streams by type, collect events, sort by log_position
  - Apply pagination and return filtered_events_result

- [X] T011 [US1] Create basic EventsLive module skeleton in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Implement mount/3 with initial assigns (stream_type, page, page_size, has_more, total, events_empty?)
  - Initialize :events stream

- [X] T012 [US1] Implement filter event handler in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Handle "filter" event with stream_type param
  - Validate input, call EventStore.read_by_stream_type/2
  - Update assigns and reset events stream with results

- [X] T013 [US1] Implement clear_filter event handler in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Clear stream_type assign
  - Reset events stream to empty

- [X] T014 [US1] Implement LiveView template in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Filter form with stream_type input (#filter-form)
  - Results summary showing type and total count
  - Events list with phx-update="stream" (#events)
  - Each event shows stream_name, event type, event data, log_position

**Checkpoint**: User Story 1 complete - can filter events by type and see results

---

## Phase 4: User Story 2 - Live Updates for New Events (Priority: P1)

**Goal**: Newly published events automatically appear in filtered view via PubSub

**Independent Test**: Open filtered view for type "order", publish new event to "order-789", verify event appears without user action.

### Tests for User Story 2 (write first)

- [ ] T015 [P] [US2] Write unit tests for PubSub broadcast on append in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test new events trigger broadcast for matching type
  - Test broadcast message format {:events_appended, stream_name, events}

- [ ] T016 [P] [US2] Write integration test for live updates in apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs
  - Test subscribing to filtered type on filter
  - Test receiving new events via PubSub and display update
  - Test non-matching events do not appear
  - Test unsubscribing when filter cleared

### Implementation for User Story 2

- [ ] T017 [US2] Add PubSub broadcast to append_to_stream/4 in apps/epoch/lib/epoch/event_store.ex
  - After successful append in do_append/4
  - Broadcast to topic "stream_type:#{extract_stream_type(stream_name)}"
  - Message format: {:events_appended, stream_name, events}

- [ ] T018 [US2] Add PubSub subscription management in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Subscribe to "stream_type:#{type}" in filter handler (when connected)
  - Unsubscribe from old topic when changing filter
  - Unsubscribe when clearing filter

- [ ] T019 [US2] Implement handle_info for {:events_appended, ...} in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Transform events to event_with_stream format
  - Append to events stream
  - Update total count

**Checkpoint**: User Stories 1 AND 2 complete - filter works with live updates

---

## Phase 5: User Story 3 - View Stream Type Results with Pagination (Priority: P2)

**Goal**: View filtered results in manageable pages with navigation

**Independent Test**: Create 100 events, request page 2 with 20 items per page, verify events 21-40 are returned.

### Tests for User Story 3 (write first)

- [ ] T020 [P] [US3] Write unit tests for pagination in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test default page size (20)
  - Test custom page size
  - Test page boundaries (correct slice returned)
  - Test has_more flag accuracy
  - Test requesting page beyond results returns empty

- [ ] T021 [P] [US3] Write integration test for pagination UI in apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs
  - Test pagination controls display
  - Test navigating to next page
  - Test navigating to previous page
  - Test disabled states (prev on page 1, next when no more)

### Implementation for User Story 3

- [ ] T022 [US3] Add pagination to filtered results in apps/epoch/lib/epoch/event_store.ex (if not already complete from T010)
  - Verify pagination logic in read_by_stream_type handler
  - Ensure offset calculation: (page - 1) * page_size
  - Ensure has_more calculation: offset + page_size < total

- [ ] T023 [US3] Implement next_page/prev_page event handlers in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Increment/decrement page
  - Fetch events for new page
  - Reset events stream with results

- [ ] T024 [US3] Add pagination controls to template in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Previous button (disabled when page == 1)
  - Current page display
  - Next button (disabled when !has_more)

**Checkpoint**: User Stories 1, 2, AND 3 complete - full filtering with pagination and live updates

---

## Phase 6: User Story 4 - Identify Source Stream for Each Event (Priority: P2)

**Goal**: Each event clearly shows its source stream name

**Independent Test**: Filter events and verify each returned event includes its source stream identifier displayed alongside event data.

### Tests for User Story 4 (write first)

- [ ] T025 [P] [US4] Write unit test verifying event_with_stream includes stream_name in apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - Test each event in result has stream_name field
  - Test stream_name matches source stream

- [ ] T026 [P] [US4] Write integration test for stream name display in apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs
  - Test stream name visible for each event in list
  - Test correct stream name displayed per event

### Implementation for User Story 4

- [ ] T027 [US4] Verify event_with_stream structure in read_by_stream_type/3 in apps/epoch/lib/epoch/event_store.ex
  - Ensure each event includes :stream_name, :event, :metadata keys
  - (May already be complete from T010)

- [ ] T028 [US4] Ensure template displays stream_name prominently in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Stream name displayed in each event row (may already be complete from T014)
  - Verify styling makes stream name clearly visible

**Checkpoint**: All user stories complete - full feature functional

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T029 [P] Add demo seed data to priv/repo/seeds.exs (per Constitution Check)
  - 5 order streams with 3-5 events each
  - 3 cart streams with 2-3 events each
  - 2 user streams with 1-2 events each

- [ ] T030 [P] Add helper function event_type_name/1 in apps/epoch_web/lib/epoch_web/live/dev/events_live.ex
  - Extract readable event type name from struct

- [ ] T031 Run full test suite and fix any failures
  - mix test apps/epoch/test/epoch/event_store/stream_type_filter_test.exs
  - mix test apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs

- [ ] T032 Run quickstart.md validation to verify feature works end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational
- **User Story 2 (Phase 4)**: Depends on User Story 1 (needs filter to exist for live updates)
- **User Story 3 (Phase 5)**: Can start after Foundational (pagination is independent)
- **User Story 4 (Phase 6)**: Can start after User Story 1 (needs events display)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Foundational (T004-T006)
    │
    ├──► US1: Filter (T007-T014) ──► US2: Live Updates (T015-T019)
    │         │
    │         └──► US4: Stream Names (T025-T028)
    │
    └──► US3: Pagination (T020-T024)
```

### Within Each User Story

- Tests MUST be written first and fail before implementation
- EventStore changes before LiveView changes
- Core implementation before UI polish

### Parallel Opportunities

**Phase 1 (all parallel):**
- T001, T002, T003 can all run in parallel

**Phase 2:**
- T004 (tests) runs first, then T005, T006 can run in parallel

**Phase 3 (US1):**
- T007, T008, T009 (tests) can all run in parallel
- T010 must complete before T011-T014
- T011-T014 are sequential (building LiveView incrementally)

**Phase 4 (US2):**
- T015, T016 (tests) can run in parallel
- T017 must complete before T018, T019 (need broadcast for subscription)
- T018, T019 are sequential

**Phase 5 (US3):**
- T020, T021 (tests) can run in parallel
- T022-T024 are sequential

**Phase 6 (US4):**
- T025, T026 (tests) can run in parallel
- T027, T028 mostly verification (may be no-ops if already done)

**Phase 7:**
- T029, T030 can run in parallel
- T031, T032 are sequential (run after all implementation)

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Write unit tests for read_by_stream_type/3 filtering logic" (T007)
Task: "Write unit tests for read_by_stream_type/3 validation" (T008)
Task: "Write integration test for LiveView filter workflow" (T009)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test filtering works independently
5. Deploy/demo if ready - users can filter events by type

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → **MVP: Basic filtering works**
3. Add User Story 2 → Test → **Live updates work**
4. Add User Story 3 → Test → **Pagination works**
5. Add User Story 4 → Test → **Stream names clear** (likely already done)
6. Polish → **Production ready**

### Recommended Order (Single Developer)

1. T001-T003 (Setup)
2. T004-T006 (Foundational)
3. T007-T014 (US1 - MVP)
4. T015-T019 (US2 - Live Updates)
5. T020-T024 (US3 - Pagination)
6. T025-T028 (US4 - Stream Names)
7. T029-T032 (Polish)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 are both P1 priority but US2 depends on US1
- US3 and US4 are P2 but largely independent of each other
- US4 may require minimal work if stream_name display is done in US1
- Tests are MANDATORY per Constitution Check - write and fail before implementation
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
