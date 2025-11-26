# Tasks: Clear All Items from Cart

**Input**: Design documents from `/specs/011-clear-cart/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for every user story. List the failing unit tests first and include integration coverage for every cross-boundary change.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` (domain layer), `apps/epoch_web/` (web layer)
- **Slices**: `apps/epoch_web/lib/epoch_web/slices/`
- **Tests**: `apps/epoch_web/test/epoch_web/slices/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create vertical slice directory structure

- [X] T001 Create clear_cart slice directory at `apps/epoch_web/lib/epoch_web/slices/clear_cart/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core components that MUST be complete before user story integration

**Note**: CartCleared event already exists at `apps/epoch/lib/epoch/cart/events/cart_cleared.ex` - no foundational work needed.

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - Clear All Cart Items (Priority: P1) 🎯 MVP

**Goal**: Enable users to clear all items from cart with a single action

**Independent Test**: Add multiple items to cart, click clear button, confirm, verify all items removed and empty cart state displays

### Tests for User Story 1 (MANDATORY - write these first)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T002 [P] [US1] Unit test CommandHandler validates non-empty cart in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T003 [P] [US1] Unit test CommandHandler emits CartCleared event in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T004 [P] [US1] Unit test CommandHandler returns error for empty cart in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T005 [P] [US1] Integration test cart display shows empty state after clear in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`

### Implementation for User Story 1

- [X] T006 [P] [US1] Create ClearCart.Command struct in `apps/epoch_web/lib/epoch_web/slices/clear_cart/command.ex`
- [X] T007 [US1] Implement ClearCart.CommandHandler with empty cart validation in `apps/epoch_web/lib/epoch_web/slices/clear_cart/command_handler.ex`

**Checkpoint**: User Story 1 core logic complete - clearing cart emits event

---

## Phase 4: User Story 2 - Clear Cart Confirmation (Priority: P1)

**Goal**: Require confirmation before destructive clear action

**Independent Test**: Click clear cart, verify confirmation dialog appears, cancel confirms cart unchanged, confirm proceeds with clear

### Tests for User Story 2 (MANDATORY - write these first)

- [X] T008 [P] [US2] Unit test Component renders with phx-confirm attribute in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T009 [P] [US2] Integration test confirming dialog clears cart in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`

### Implementation for User Story 2

- [X] T010 [US2] Create ClearCart.Component LiveComponent with phx-confirm in `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex`
- [X] T011 [US2] Implement handle_event("clear_cart") delegating to CommandHandler in `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex`
- [X] T012 [US2] Add error handling with flash messages for failures in `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex`

**Checkpoint**: User Story 2 complete - confirmation required before clearing

---

## Phase 5: User Story 3 - Clear Cart Button Visibility (Priority: P2)

**Goal**: Show clear button only when cart has items

**Independent Test**: View empty cart (no clear button), add items (button appears), clear cart (button disappears)

### Tests for User Story 3 (MANDATORY - write these first)

- [X] T013 [P] [US3] Unit test Clear Cart button visible when cart has items in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T014 [P] [US3] Unit test Clear Cart button NOT visible when cart is empty in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`
- [X] T015 [P] [US3] Integration test button disappears after clearing cart in `apps/epoch_web/test/epoch_web/slices/clear_cart_test.exs`

### Implementation for User Story 3

- [X] T016 [US3] Integrate ClearCart.Component into CartItems.Live with conditional rendering in `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex`

**Checkpoint**: All user stories complete - feature fully functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T017 Run full test suite to verify no regressions via `mix test`
- [ ] T018 Run quickstart.md manual verification steps
- [ ] T019 Verify PubSub updates work across browser tabs (edge case)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - create directory structure
- **Foundational (Phase 2)**: N/A - CartCleared event already exists
- **User Story 1 (Phase 3)**: Depends on Setup - core clear logic
- **User Story 2 (Phase 4)**: Depends on US1 - adds confirmation UI
- **User Story 3 (Phase 5)**: Depends on US2 - adds conditional visibility
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent - implements core clear logic
- **User Story 2 (P1)**: Depends on US1 CommandHandler for event delegation
- **User Story 3 (P2)**: Depends on US2 Component for integration into CartItems.Live

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Command struct before CommandHandler
- CommandHandler before Component
- Component before integration into CartItems.Live

### Parallel Opportunities

- T002, T003, T004, T005 can run in parallel (separate test cases)
- T006 can run in parallel with tests (different file)
- T008, T009 can run in parallel (separate test cases)
- T013, T014, T015 can run in parallel (separate test cases)

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test CommandHandler validates non-empty cart"
Task: "Unit test CommandHandler emits CartCleared event"
Task: "Unit test CommandHandler returns error for empty cart"
Task: "Integration test cart display shows empty state after clear"

# After tests written (failing), models in parallel:
Task: "Create ClearCart.Command struct"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (create directory)
2. Skip Phase 2: Foundational (already exists)
3. Complete Phase 3: User Story 1 (tests first, then implementation)
4. **STOP and VALIDATE**: Test clearing logic works
5. Can demo clearing cart (no confirmation yet)

### Incremental Delivery

1. Complete US1 → Core clear logic works (MVP)
2. Add US2 → Confirmation dialog added → Deploy/Demo
3. Add US3 → Button visibility conditional → Deploy/Demo (Complete feature)

### Single Developer Strategy

1. Complete Setup
2. Write all US1 tests (failing)
3. Implement US1 (tests pass)
4. Write all US2 tests (failing)
5. Implement US2 (tests pass)
6. Write all US3 tests (failing)
7. Implement US3 (tests pass)
8. Run polish phase

---

## Notes

- [P] tasks = different files or different test cases, no dependencies
- [Story] label maps task to specific user story for traceability
- CartCleared event already exists - no domain layer changes needed
- CartItemsView already handles CartCleared event - projection works automatically
- PubSub integration works automatically via existing cart stream subscription
- Verify tests fail before implementing
- Commit after each task or logical group
