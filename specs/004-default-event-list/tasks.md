# Tasks: Default Event List

**Input**: Design documents from `/specs/004-default-event-list/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Tests are REQUIRED for every user story. Unit tests first, then integration tests for cross-boundary changes.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` (core), `apps/epoch_web/` (web)
- **Core**: `apps/epoch/lib/epoch/`, tests in `apps/epoch/test/epoch/`
- **Web**: `apps/epoch_web/lib/epoch_web/`, tests in `apps/epoch_web/test/epoch_web/`

---

## Phase 1: Setup

**Purpose**: No new setup required - this feature extends existing infrastructure

- [ ] T001 Verify Feature 001 (EventStore) and Feature 003 (Stream Type Filter) are complete by running `mix test`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: EventStore API extension required before any LiveView changes

**⚠️ CRITICAL**: User story work cannot begin until EventStore supports `read_all_events/2` and broadcasts to `"all_events"` topic

### Unit Tests (write first, must fail)

- [ ] T002 [P] Add unit test: `read_all_events/2` returns events from all streams in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T003 [P] Add unit test: `read_all_events/2` returns events in chronological order by log_position in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T004 [P] Add unit test: `read_all_events/2` pagination works correctly (page 1, page 2, etc.) in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T005 [P] Add unit test: `read_all_events/2` returns empty result for empty store in `apps/epoch/test/epoch/event_store_test.exs`
- [ ] T006 [P] Add unit test: PubSub broadcasts to `"all_events"` topic on any append in `apps/epoch/test/epoch/event_store_test.exs`

### Implementation

- [ ] T007 Implement `read_all_events/2` function in `apps/epoch/lib/epoch/event_store.ex` with pagination support
- [ ] T008 Add `handle_call({:read_all_events, opts}, ...)` clause in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T009 Add `broadcast_to_all_events/2` helper function in `apps/epoch/lib/epoch/event_store.ex`
- [ ] T010 Call `broadcast_to_all_events/2` in existing `do_append/4` function in `apps/epoch/lib/epoch/event_store.ex`

**Checkpoint**: Run `mix test apps/epoch/test/epoch/event_store_test.exs` - all new tests should pass

---

## Phase 3: User Story 1 - View All Events on Initial Load (Priority: P1) 🎯 MVP

**Goal**: Display all events from the store immediately when the event viewer loads, without requiring a filter

**Independent Test**: Open event viewer with events in store → all events displayed without any user action

### Tests for User Story 1 (write first, must fail) ⚠️

- [ ] T011 [P] [US1] Add integration test: displays all events on initial load in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`
- [ ] T012 [P] [US1] Add integration test: shows "No events in store" message when empty in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`
- [ ] T013 [P] [US1] Add integration test: pagination works in default view (50 events, navigate pages) in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`

### Implementation for User Story 1

- [ ] T014 [US1] Add `:view_mode` assign (`:all` | `:filtered`) to mount in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T015 [US1] Subscribe to `"all_events"` topic on mount (when connected) in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T016 [US1] Add `load_all_events/1` helper function that calls `EventStore.read_all_events/2` in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T017 [US1] Call `load_all_events/1` on mount to populate events stream in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T018 [US1] Update template empty state: show "No events in store" when `view_mode == :all` and empty in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T019 [US1] Update template empty state: show "No events match filter '[type]'" when `view_mode == :filtered` and empty in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`

**Checkpoint**: User Story 1 complete - opening viewer shows all events immediately

---

## Phase 4: User Story 2 - Live Updates for All Events (Priority: P1)

**Goal**: Newly published events automatically appear in the default view within 2 seconds

**Independent Test**: Open viewer in default mode → publish event to any stream → event appears automatically

### Tests for User Story 2 (write first, must fail) ⚠️

- [ ] T020 [P] [US2] Add integration test: receives live updates for any stream in default view in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`
- [ ] T021 [P] [US2] Add integration test: multiple concurrent viewers receive independent updates in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`

### Implementation for User Story 2

- [ ] T022 [US2] Verify existing `handle_info({:events_appended, ...}, socket)` handles messages from `"all_events"` topic in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`

**Checkpoint**: User Story 2 complete - new events appear in real-time without refresh

---

## Phase 5: User Story 3 - Transition Between Default and Filtered Views (Priority: P2)

**Goal**: Seamlessly switch between viewing all events and filtered views

**Independent Test**: Start in default view → apply filter → see filtered results → clear filter → return to all events

### Tests for User Story 3 (write first, must fail) ⚠️

- [ ] T023 [P] [US3] Add integration test: transitions from default to filtered view in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`
- [ ] T024 [P] [US3] Add integration test: transitions from filtered to default view (clear filter) in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`
- [ ] T025 [P] [US3] Add integration test: live updates work correctly after clearing filter in `apps/epoch_web/test/epoch_web/live/dev/events_live_test.exs`

### Implementation for User Story 3

- [ ] T026 [US3] Update `handle_event("filter", ...)` to unsubscribe from `"all_events"` when `view_mode == :all` in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T027 [US3] Update `handle_event("filter", ...)` to set `view_mode: :filtered` in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T028 [US3] Implement `handle_event("clear_filter", ...)` to unsubscribe from stream type topic in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T029 [US3] Implement `handle_event("clear_filter", ...)` to subscribe to `"all_events"` topic in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T030 [US3] Implement `handle_event("clear_filter", ...)` to call `load_all_events/1` and set `view_mode: :all` in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`
- [ ] T031 [US3] Add "Clear" button to template that triggers `"clear_filter"` event (visible when `view_mode == :filtered`) in `apps/epoch_web/lib/epoch_web/live/dev/events_live.ex`

**Checkpoint**: User Story 3 complete - seamless transitions between default and filtered views

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T032 Run `mix test` to verify all tests pass
- [ ] T033 Run `mix precommit` to verify code quality
- [ ] T034 Manual verification per quickstart.md: open viewer, verify events load, test live updates, test filter transitions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Verify existing features work
- **Foundational (Phase 2)**: BLOCKS all user stories - EventStore must support `read_all_events/2`
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion
- **User Story 2 (Phase 4)**: Depends on Phase 3 (uses same subscription)
- **User Story 3 (Phase 5)**: Depends on Phase 3 (extends filter handlers)
- **Polish (Phase 6)**: Depends on all stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Core default view
- **User Story 2 (P1)**: Depends on US1 mount subscription - Live updates
- **User Story 3 (P2)**: Depends on US1 view_mode assign - Filter transitions

### Within Each Phase

- Tests MUST be written first and fail before implementation
- All tests marked [P] can run in parallel
- Implementation tasks are sequential within each story

### Parallel Opportunities

Within Phase 2 (Foundational):
- T002, T003, T004, T005, T006 can all run in parallel (separate test cases)

Within Phase 3 (User Story 1):
- T011, T012, T013 can all run in parallel (separate test cases)

Within Phase 4 (User Story 2):
- T020, T021 can all run in parallel (separate test cases)

Within Phase 5 (User Story 3):
- T023, T024, T025 can all run in parallel (separate test cases)

---

## Parallel Example: Foundational Tests

```bash
# Launch all foundational unit tests together:
Task: "Add unit test: read_all_events/2 returns events from all streams"
Task: "Add unit test: read_all_events/2 returns events in chronological order"
Task: "Add unit test: read_all_events/2 pagination works correctly"
Task: "Add unit test: read_all_events/2 returns empty result for empty store"
Task: "Add unit test: PubSub broadcasts to all_events topic on any append"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup verification
2. Complete Phase 2: Foundational (EventStore extension)
3. Complete Phase 3: User Story 1 (default view)
4. **STOP and VALIDATE**: Viewer loads with all events displayed
5. Continue with US2 and US3

### Incremental Delivery

1. Setup + Foundational → EventStore ready
2. User Story 1 → Default view works (MVP!)
3. User Story 2 → Live updates work
4. User Story 3 → Filter transitions work
5. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different test cases or files, no dependencies
- [Story] label maps task to specific user story for traceability
- Existing `handle_info({:events_appended, ...})` should work unchanged since message format is identical
- Same pagination pattern as existing `read_by_stream_type/3`
- Test file location: existing test files extended, not new files created
