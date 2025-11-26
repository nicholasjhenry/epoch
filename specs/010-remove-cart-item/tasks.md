# Tasks: Remove Item from Cart

**Input**: Design documents from `/specs/010-remove-cart-item/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Tests are REQUIRED for every user story. List the failing unit tests first and include integration coverage for every cross-boundary change.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` (core domain), `apps/epoch_web/` (web layer)
- **Slices**: `apps/epoch_web/lib/epoch_web/slices/remove_item/`
- **Tests**: `apps/epoch_web/test/epoch_web/slices/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify existing infrastructure and create slice directory structure

- [X] T001 Verify existing EventStore, Cart context, and ItemRemoved event are functional
- [X] T002 Create remove_item slice directory at apps/epoch_web/lib/epoch_web/slices/remove_item/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create core slice modules that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create RemoveItem.Command struct in apps/epoch_web/lib/epoch_web/slices/remove_item/command.ex
- [X] T004 Create RemoveItem.CommandHandler with handle/1 in apps/epoch_web/lib/epoch_web/slices/remove_item/command_handler.ex
- [X] T005 Add PubSub subscription to CartLive mount/3 in apps/epoch_web/lib/epoch_web/live/cart_live.ex
- [X] T006 Add handle_info/2 for {:events_appended, _, _} in apps/epoch_web/lib/epoch_web/live/cart_live.ex

**Checkpoint**: Foundation ready - CommandHandler and real-time updates functional

---

## Phase 3: User Story 1 - Remove Single Item from Cart (Priority: P1) 🎯 MVP

**Goal**: Users can click a remove button on a cart item and have it removed from the cart display

**Independent Test**: Add items to cart, click remove on one, verify it disappears and total updates

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T007 [P] [US1] Unit test "handle/1 returns error when item_id not in cart" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T008 [P] [US1] Unit test "handle/1 appends ItemRemoved event when item exists" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T009 [P] [US1] Unit test "handle/1 returns updated cart session after removal" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T010 [P] [US1] Integration test "clicking remove button removes item from cart display" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T011 [P] [US1] Integration test "cart total updates after item removal" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T012 [P] [US1] Integration test "removing last item shows empty cart state" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T013 [P] [US1] Integration test "removing non-existent item shows error flash" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs

### Implementation for User Story 1

- [X] T014 [US1] Create RemoveItem.Component LiveComponent in apps/epoch_web/lib/epoch_web/slices/remove_item/component.ex
- [X] T015 [US1] Add remove button column to cart item rows in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex
- [X] T016 [US1] Add handle_info/2 for {:flash, :error, message} in apps/epoch_web/lib/epoch_web/live/cart_live.ex
- [X] T017 [US1] Verify all tests pass and cart removal works end-to-end

**Checkpoint**: User Story 1 complete - users can remove items, total updates, empty state displays

---

## Phase 4: User Story 2 - Visual Feedback on Item Removal (Priority: P2)

**Goal**: Users see immediate feedback when removing an item (within 500ms)

**Independent Test**: Remove an item and observe UI updates immediately without page reload

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [X] T018 [US2] Integration test "item disappears immediately after clicking remove" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs

### Implementation for User Story 2

- [X] T019 [US2] Verify PubSub-based real-time update provides sub-500ms feedback (already implemented in Foundational phase)
- [X] T020 [US2] Verify cart total updates reflect immediately in UI

**Checkpoint**: User Story 2 complete - visual feedback is immediate and responsive

---

## Phase 5: User Story 3 - Remove Button Accessibility (Priority: P2)

**Goal**: Each cart item has a clearly visible, accessible remove control

**Independent Test**: View cart and verify each item row has a visible remove button

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [X] T021 [US3] Integration test "each cart item displays a remove button" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs
- [X] T022 [US3] Integration test "remove button has accessible label" in apps/epoch_web/test/epoch_web/slices/remove_item_test.exs

### Implementation for User Story 3

- [X] T023 [US3] Style remove button with Tailwind classes for visual distinction in apps/epoch_web/lib/epoch_web/slices/remove_item/component.ex
- [X] T024 [US3] Add aria-label or title attribute for accessibility in apps/epoch_web/lib/epoch_web/slices/remove_item/component.ex

**Checkpoint**: User Story 3 complete - remove buttons are visible and accessible

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and validation

- [X] T025 Run full test suite to verify no regressions: mix test
- [X] T026 Run quickstart.md manual verification steps
- [X] T027 Verify error logging for remove failures per plan.md failure handling table

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1): Independent, MVP scope
  - User Story 2 (P2): Can run parallel with US3
  - User Story 3 (P2): Can run parallel with US2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Verifies behavior from US1 but independently testable
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Independently testable (visual/accessibility)

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Component before template integration
- Core implementation before error handling
- Story complete before moving to next priority

### Parallel Opportunities

- T007-T013: All US1 tests can be written in parallel
- T021-T022: US3 tests can be written in parallel
- US2 and US3 can be worked on in parallel (different concerns)

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test 'handle/1 returns error when item_id not in cart'"
Task: "Unit test 'handle/1 appends ItemRemoved event when item exists'"
Task: "Unit test 'handle/1 returns updated cart session after removal'"
Task: "Integration test 'clicking remove button removes item from cart display'"
Task: "Integration test 'cart total updates after item removal'"
Task: "Integration test 'removing last item shows empty cart state'"
Task: "Integration test 'removing non-existent item shows error flash'"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify existing infrastructure)
2. Complete Phase 2: Foundational (Command, CommandHandler, PubSub subscription)
3. Complete Phase 3: User Story 1 (tests → component → template)
4. **STOP and VALIDATE**: Test User Story 1 independently using quickstart.md
5. Deploy/demo if ready - users can now remove items from cart

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 + User Story 3 → Test independently → Deploy/Demo
4. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Follow existing add_item slice pattern for consistency
- ItemRemoved event and CartItemsView.evolve/2 already exist - no changes needed
