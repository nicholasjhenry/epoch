# Tasks: Display Cart Items

**Input**: Design documents from `/specs/009-display-cart-items/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/cart-items-api.md

**Tests**: Tests are REQUIRED for every user story per the spec's Test Plan section.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` for business logic, `apps/epoch_web/` for web layer
- Tests in respective `test/` directories

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new event struct modules required by all user stories

- [ ] T001 [P] Create ItemAdded event struct in apps/epoch/lib/epoch/cart/events/item_added.ex
- [ ] T002 [P] Create ItemRemoved event struct in apps/epoch/lib/epoch/cart/events/item_removed.ex
- [ ] T003 [P] Create CartCleared event struct in apps/epoch/lib/epoch/cart/events/cart_cleared.ex
- [ ] T004 [P] Create ItemArchived event struct in apps/epoch/lib/epoch/cart/events/item_archived.ex

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core CartItemsView module that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create CartItemsView module with initial_state/0 and empty?/1 in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T006 Implement CartItemsView.evolve/2 for ItemAdded event in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T007 Implement CartItemsView.evolve/2 for ItemRemoved event in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T008 Implement CartItemsView.evolve/2 for CartCleared event in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T009 Implement CartItemsView.evolve/2 for ItemArchived event in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T010 Implement CartItemsView.evolve/2 fallback for unknown events in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T011 Implement CartItemsView.project/1 convenience function in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T012 Add get_cart_items/1 function to Cart context in apps/epoch/lib/epoch/cart/cart.ex
- [ ] T013 Add /cart/:session_id route to router in apps/epoch_web/lib/epoch_web/router.ex

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Cart Items (Priority: P1) 🎯 MVP

**Goal**: Display all items currently in shopping cart with name and price

**Independent Test**: Add items to cart via ItemAdded events, navigate to cart page, verify items display with names and prices

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

- [ ] T014 [P] [US1] Unit test: CartItemsView returns empty list for empty event list in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T015 [P] [US1] Unit test: CartItemsView adds item when processing ItemAdded event in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T016 [P] [US1] Unit test: CartItemsView processes sequence of ItemAdded events correctly in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T017 [P] [US1] Integration test: Cart page loads and displays items from EventStore in apps/epoch_web/test/epoch_web/live/cart_live_test.exs
- [ ] T018 [P] [US1] Integration test: Cart page correctly renders item names and formatted prices in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

### Implementation for User Story 1

- [ ] T019 [US1] Create CartLive module with mount/3 that loads cart items via Cart.get_cart_items/1 in apps/epoch_web/lib/epoch_web/live/cart_live.ex
- [ ] T020 [US1] Create cart_live.html.heex template with items table showing name and price in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex
- [ ] T021 [US1] Implement format_price/1 helper for currency formatting ($X.XX) in apps/epoch_web/lib/epoch_web/live/cart_live.ex
- [ ] T022 [US1] Add DOM IDs per contract (#cart, #cart-items, #cart-item-{id}) in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - View Cart Total (Priority: P1)

**Goal**: Display total cost of all items in cart as sum of prices

**Independent Test**: Add items with known prices, verify total displays as correct sum formatted as currency

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [ ] T023 [P] [US2] Unit test: Cart total calculation sums all item prices correctly in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T024 [P] [US2] Unit test: Cart total is 0.0 when cart is empty in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T025 [P] [US2] Integration test: Cart page displays correct total after processing events in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

### Implementation for User Story 2

- [ ] T026 [US2] Add cart total display to template footer with #cart-total ID in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex
- [ ] T027 [US2] Ensure @cart_total assign is populated from CartItemsView state in apps/epoch_web/lib/epoch_web/live/cart_live.ex

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - View Empty Cart State (Priority: P2)

**Goal**: Display clear message when cart is empty

**Independent Test**: View cart page with no ItemAdded events, verify "Your cart is empty" message displays

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [ ] T028 [P] [US3] Unit test: CartItemsView.empty?/1 returns true for empty cart state in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T029 [P] [US3] Unit test: CartItemsView.empty?/1 returns false for cart with items in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T030 [P] [US3] Integration test: Cart page displays empty state message when no events exist in apps/epoch_web/test/epoch_web/live/cart_live_test.exs
- [ ] T031 [P] [US3] Integration test: Cart page hides items table and total when empty in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

### Implementation for User Story 3

- [ ] T032 [US3] Add conditional rendering for empty cart message (#cart-empty) in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex
- [ ] T033 [US3] Hide items table and total when @cart_empty? is true in apps/epoch_web/lib/epoch_web/live/cart_live.html.heex

**Checkpoint**: User Stories 1, 2, and 3 should all work independently

---

## Phase 6: User Story 4 - Cart Reflects Item Removal (Priority: P2)

**Goal**: Cart display reflects items that have been removed via ItemRemoved events

**Independent Test**: Add items, process ItemRemoved event, verify item no longer appears and total adjusts

### Tests for User Story 4 (MANDATORY - write these first) ⚠️

- [ ] T034 [P] [US4] Unit test: CartItemsView removes item when processing ItemRemoved event with matching itemId in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T035 [P] [US4] Unit test: CartItemsView total decreases when item removed in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T036 [P] [US4] Unit test: CartItemsView handles ItemRemoved for non-existent item gracefully in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T037 [P] [US4] Integration test: Cart page shows only remaining items after ItemRemoved event in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

### Implementation for User Story 4

- [ ] T038 [US4] Verify CartItemsView.evolve/2 correctly handles ItemRemoved (implemented in Phase 2) in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T039 [US4] Add integration test fixture with ItemAdded then ItemRemoved sequence in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

**Checkpoint**: User Stories 1-4 should all work independently

---

## Phase 7: User Story 5 - Cart Reflects Cart Cleared (Priority: P3)

**Goal**: Cart display shows empty state after CartCleared event

**Independent Test**: Add items, process CartCleared event, verify empty cart state displays

### Tests for User Story 5 (MANDATORY - write these first) ⚠️

- [ ] T040 [P] [US5] Unit test: CartItemsView clears all items when processing CartCleared event in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T041 [P] [US5] Unit test: CartItemsView total is 0.0 after CartCleared in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T042 [P] [US5] Integration test: Cart page displays empty state after CartCleared event in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

### Implementation for User Story 5

- [ ] T043 [US5] Verify CartItemsView.evolve/2 correctly handles CartCleared (implemented in Phase 2) in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T044 [US5] Add integration test fixture with items then CartCleared sequence in apps/epoch_web/test/epoch_web/live/cart_live_test.exs

**Checkpoint**: All user stories should now be independently functional

---

## Phase 8: Edge Cases & ItemArchived

**Goal**: Handle ItemArchived events and edge cases

### Tests (MANDATORY - write these first) ⚠️

- [ ] T045 [P] Unit test: CartItemsView removes item when processing ItemArchived event in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T046 [P] Unit test: CartItemsView ignores unknown event types in apps/epoch/test/epoch/cart/cart_items_view_test.exs
- [ ] T047 [P] Unit test: CartItemsView correctly processes mixed event sequence in apps/epoch/test/epoch/cart/cart_items_view_test.exs

### Implementation

- [ ] T048 Verify CartItemsView.evolve/2 correctly handles ItemArchived (implemented in Phase 2) in apps/epoch/lib/epoch/cart/cart_items_view.ex
- [ ] T049 Add logging for skipped/unknown events in apps/epoch/lib/epoch/cart/cart_items_view.ex

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and validation

- [ ] T050 Ensure all tests pass with `mix test`
- [ ] T051 Run quickstart.md validation steps
- [ ] T052 Verify Cart context error handling for EventStore unavailability in apps/epoch/lib/epoch/cart/cart.ex

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Edge Cases (Phase 8)**: Can run after Foundational, parallel with user stories
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 5 (P3)**: Can start after Foundational (Phase 2) - No dependencies on other stories

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks (T001-T004) can run in parallel
- All test tasks within a user story can run in parallel
- Different user stories can be worked on in parallel after Foundational phase

---

## Parallel Example: Setup Phase

```bash
# Launch all event struct creation tasks together:
T001: "Create ItemAdded event struct in apps/epoch/lib/epoch/cart/events/item_added.ex"
T002: "Create ItemRemoved event struct in apps/epoch/lib/epoch/cart/events/item_removed.ex"
T003: "Create CartCleared event struct in apps/epoch/lib/epoch/cart/events/cart_cleared.ex"
T004: "Create ItemArchived event struct in apps/epoch/lib/epoch/cart/events/item_archived.ex"
```

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
T014: "Unit test: CartItemsView returns empty list for empty event list"
T015: "Unit test: CartItemsView adds item when processing ItemAdded event"
T016: "Unit test: CartItemsView processes sequence of ItemAdded events correctly"
T017: "Integration test: Cart page loads and displays items from EventStore"
T018: "Integration test: Cart page correctly renders item names and formatted prices"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (event structs)
2. Complete Phase 2: Foundational (CartItemsView + route)
3. Complete Phase 3: User Story 1 (view items)
4. Complete Phase 4: User Story 2 (view total)
5. **STOP and VALIDATE**: Test MVP independently
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 + 2 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 3 → Test independently → Deploy/Demo (empty state)
4. Add User Story 4 → Test independently → Deploy/Demo (item removal)
5. Add User Story 5 → Test independently → Deploy/Demo (cart cleared)
6. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
