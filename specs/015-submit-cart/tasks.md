# Tasks: Submit Cart

**Input**: Design documents from `/specs/015-submit-cart/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Tests are REQUIRED for every user story. List the failing unit tests first and include integration coverage for every cross-boundary change.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description | Skills: [skill-list]`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **Skills**: Agent skills to invoke before implementing this task
- Include exact file paths in descriptions

## Path Conventions

- **Domain app**: `apps/epoch/lib/epoch/` and `apps/epoch/test/epoch/`
- **Web app**: `apps/epoch_web/lib/epoch_web/` and `apps/epoch_web/test/epoch_web/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature directory structure and shared event types

- [X] T001 Create CartSubmitted event struct in `apps/epoch/lib/epoch/cart/events/cart_submitted.ex` | Skills: elixir-core
- [X] T002 [P] Create SubmitCart command struct in `apps/epoch_web/lib/epoch_web/slices/submit_cart/command.ex` | Skills: elixir-core
- [X] T003 [P] Create InventoriesView read model in `apps/epoch_web/lib/epoch_web/slices/submit_cart/inventories_view.ex` | Skills: elixir-core

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create CommandHandler scaffold with handle/1 function signature in `apps/epoch_web/lib/epoch_web/slices/submit_cart/command_handler.ex` | Skills: elixir-core
- [X] T005 Create unit test file with empty test module in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Submit Cart with Available Inventory (Priority: P1) 🎯 MVP

**Goal**: A shopper can submit their cart when all items have available inventory, resulting in a CartSubmitted event being recorded.

**Independent Test**: Add an item to the cart, ensure inventory is available, submit the cart. Verify CartSubmitted event in stream.

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T006 [US1] Unit test: Submit cart with single item and sufficient inventory returns CartSubmitted event in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing
- [X] T007 [P] [US1] Unit test: Submit cart with multiple items and sufficient inventory returns CartSubmitted event in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing

### Implementation for User Story 1

- [X] T008 [US1] Implement CommandHandler.handle/1 happy path: read cart items, build inventory map via InventoriesView, validate inventory > 0, append CartSubmitted event in `apps/epoch_web/lib/epoch_web/slices/submit_cart/command_handler.ex` | Skills: elixir-core
- [X] T009 [US1] Verify tests T006-T007 pass and CartSubmitted event is appended to cart stream | Skills: elixir-testing

**Checkpoint**: User Story 1 is complete - cart submission with available inventory works

---

## Phase 4: User Story 2 - Reject Cart Submission When Product Out of Stock (Priority: P1)

**Goal**: A shopper attempting to submit a cart with an out-of-stock product receives an error with details on which product is unavailable.

**Independent Test**: Add an item to the cart, set that product's inventory to 0, attempt to submit. Verify error returned with product ID.

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [X] T010 [US2] Unit test: Submit cart when product inventory is 0 returns {:error, {:insufficient_inventory, [product_id]}} in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing
- [X] T011 [P] [US2] Unit test: Submit cart when product has no inventory record returns {:error, {:insufficient_inventory, [product_id]}} in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing
- [X] T012 [P] [US2] Unit test: Submit cart with multiple items where one has 0 inventory returns error listing out-of-stock product in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing

### Implementation for User Story 2

- [X] T013 [US2] Implement inventory validation in CommandHandler: check each product_id has quantity > 0, return {:error, {:insufficient_inventory, product_ids}} on failure in `apps/epoch_web/lib/epoch_web/slices/submit_cart/command_handler.ex` | Skills: elixir-core
- [X] T014 [US2] Verify tests T010-T012 pass | Skills: elixir-testing

**Checkpoint**: User Story 2 is complete - out-of-stock products are rejected with details

---

## Phase 5: User Story 3 - Reject Cart Submission When Cart is Empty (Priority: P1)

**Goal**: A shopper attempting to submit an empty cart receives a clear error message.

**Independent Test**: Attempt to submit a cart with no items added. Verify {:error, :cart_empty} returned.

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [X] T015 [US3] Unit test: Submit cart with no items returns {:error, :cart_empty} in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing
- [X] T016 [P] [US3] Unit test: Submit cart after CartCleared event returns {:error, :cart_empty} in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing

### Implementation for User Story 3

- [X] T017 [US3] Implement empty cart validation in CommandHandler: check cart.items is not empty, return {:error, :cart_empty} if empty in `apps/epoch_web/lib/epoch_web/slices/submit_cart/command_handler.ex` | Skills: elixir-core
- [X] T018 [US3] Verify tests T015-T016 pass | Skills: elixir-testing

**Checkpoint**: User Story 3 is complete - empty cart submissions are rejected

---

## Phase 6: User Story 4 - Submit Cart After Item Removal (Priority: P2)

**Goal**: The system correctly handles carts where items have been removed or archived, only validating inventory for currently active items.

**Independent Test**: Add items, remove one, submit. Verify submission succeeds for remaining items.

### Tests for User Story 4 (MANDATORY - write these first) ⚠️

- [X] T019 [US4] Unit test: Submit cart correctly excludes removed items from validation in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing
- [X] T020 [P] [US4] Unit test: Submit cart correctly excludes archived items from validation in `apps/epoch/test/epoch/slices/submit_cart/command_handler_test.exs` | Skills: elixir-testing

### Implementation for User Story 4

- [X] T021 [US4] Verify existing CartItemsView correctly filters removed/archived items (no new code needed, tests should pass) | Skills: elixir-testing
- [X] T022 [US4] Verify tests T019-T020 pass | Skills: elixir-testing

**Checkpoint**: User Story 4 is complete - removed/archived items are correctly handled

---

## Phase 7: UI Integration

**Purpose**: Add Submit Cart button to CartItems LiveView

### Tests for UI Integration (MANDATORY - write these first) ⚠️

- [X] T023 Integration test: End-to-end cart submission success flow in `apps/epoch_web/test/epoch_web/slices/submit_cart_test.exs` | Skills: elixir-testing, phoenix-liveview
- [X] T024 [P] Integration test: End-to-end cart submission failure shows error flash in `apps/epoch_web/test/epoch_web/slices/submit_cart_test.exs` | Skills: elixir-testing, phoenix-liveview

### Implementation for UI Integration

- [X] T025 Create SubmitCart LiveComponent with submit button in `apps/epoch_web/lib/epoch_web/slices/submit_cart/component.ex` | Skills: phoenix-liveview, phoenix-html
- [X] T026 Add SubmitCart component to CartItems LiveView in `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex` | Skills: phoenix-liveview
- [X] T027 Handle flash messages from SubmitCart component in CartItems LiveView | Skills: phoenix-liveview
- [X] T028 Verify tests T023-T024 pass | Skills: elixir-testing

**Checkpoint**: UI integration complete - Submit Cart button works in browser

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T029 Run `mix precommit` to verify all tests pass and code quality checks | Skills: elixir-testing
- [X] T030 Run quickstart.md manual validation scenarios | Skills: phoenix-liveview
- [X] T031 Verify PubSub broadcasts CartSubmitted event for real-time UI updates | Skills: elixir-otp

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Can proceed independently after Phase 2
  - US2 (P1): Can proceed independently after Phase 2 (same priority as US1)
  - US3 (P1): Can proceed independently after Phase 2 (same priority as US1)
  - US4 (P2): Can proceed after Phase 2
- **UI Integration (Phase 7)**: Depends on at least US1 being complete
- **Polish (Phase 8)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories - core happy path
- **User Story 2 (P1)**: No dependencies on other stories - validation path
- **User Story 3 (P1)**: No dependencies on other stories - empty cart validation
- **User Story 4 (P2)**: Depends on existing CartItemsView behavior (already implemented)

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Implementation follows test requirements
- Verification step confirms all tests pass

### Parallel Opportunities

**Phase 1 (Setup)**:
```bash
# All setup tasks can run in parallel after T001:
T002, T003 can run in parallel
```

**Phase 3-6 (User Stories)** - All P1 stories can start in parallel:
```bash
# US1, US2, US3 can be worked on simultaneously by different developers
# Within each story, tests marked [P] can run in parallel
```

---

## Parallel Example: Setup Phase

```bash
# Launch T001 first (CartSubmitted event needed by others):
Task: "Create CartSubmitted event struct in apps/epoch/lib/epoch/cart/events/cart_submitted.ex"

# Then launch T002 and T003 in parallel:
Task: "Create SubmitCart command struct in apps/epoch_web/lib/epoch_web/slices/submit_cart/command.ex"
Task: "Create InventoriesView read model in apps/epoch_web/lib/epoch_web/slices/submit_cart/inventories_view.ex"
```

## Parallel Example: User Story 2 Tests

```bash
# All US2 tests can run in parallel:
Task: "Unit test: Submit cart when product inventory is 0"
Task: "Unit test: Submit cart when product has no inventory record"
Task: "Unit test: Submit cart with multiple items where one has 0 inventory"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T005)
3. Complete Phase 3: User Story 1 (T006-T009)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Cart submission with available inventory is now functional

### Full Feature Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Core happy path works
3. Add User Story 2 → Test independently → Inventory validation works
4. Add User Story 3 → Test independently → Empty cart handling works
5. Add User Story 4 → Test independently → Removed/archived item handling works
6. Add UI Integration → Test independently → Button works in browser
7. Polish → Run precommit, quickstart validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (happy path)
   - Developer B: User Story 2 (inventory validation)
   - Developer C: User Story 3 (empty cart)
3. After core stories complete:
   - Developer A: User Story 4 (edge cases)
   - Developer B: UI Integration
4. Team completes Polish together

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Skills listed after `|` indicate which agent skills to invoke for that task
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The `InventoriesView` is slice-local - does NOT call `Epoch.Backoffice.Inventory`

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 31 |
| **Setup Tasks** | 3 |
| **Foundational Tasks** | 2 |
| **User Story 1 Tasks** | 4 |
| **User Story 2 Tasks** | 5 |
| **User Story 3 Tasks** | 4 |
| **User Story 4 Tasks** | 4 |
| **UI Integration Tasks** | 6 |
| **Polish Tasks** | 3 |
| **Parallel Opportunities** | 12 tasks marked [P] |
| **MVP Scope** | T001-T009 (9 tasks) |
