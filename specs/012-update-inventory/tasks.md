# Tasks: Update Product Inventory

**Input**: Design documents from `/specs/012-update-inventory/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/inventory-api.md, quickstart.md

**Tests**: Tests are REQUIRED - write failing tests first per constitution requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- **Domain layer**: `apps/epoch/lib/epoch/`
- **Web layer**: `apps/epoch_web/lib/epoch_web/`
- **Domain tests**: `apps/epoch/test/epoch/`
- **Web tests**: `apps/epoch_web/test/epoch_web/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure for Backoffice namespace

**Skills**: None required (file system operations only)

- [x] T001 Create backoffice directories: `apps/epoch/lib/epoch/backoffice/` and `apps/epoch/lib/epoch/backoffice/events/`
- [x] T002 [P] Create test directory: `apps/epoch/test/epoch/backoffice/`
- [x] T003 [P] Create LiveView directories: `apps/epoch_web/lib/epoch_web/live/backoffice/` and `apps/epoch_web/test/epoch_web/live/backoffice/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core event and state modules that MUST be complete before User Story 1 can be implemented

**Skills**: `elixir-core`, `elixir-typespec`

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create InventoryUpdated event struct with typespec in `apps/epoch/lib/epoch/backoffice/events/inventory_updated.ex`
  - **Skill**: `elixir-core`, `elixir-typespec`
  - Fields: product_id (String.t()), quantity (non_neg_integer()), updated_at (DateTime.t())
- [x] T005 [P] Create InventoryState aggregate with evolve/2 function in `apps/epoch/lib/epoch/backoffice/inventory_state.ex`
  - **Skill**: `elixir-core`, `elixir-typespec`
  - Initial state with quantity: 0
  - evolve/2 to apply InventoryUpdated events

**Checkpoint**: Foundation ready - User Story 1 implementation can now begin

---

## Phase 3: User Story 1 - Update Inventory Quantity (Priority: P1)

**Goal**: Allow store administrator to update inventory quantity for a specific product

**Independent Test**: Update a product's quantity, verify the new quantity is persisted and retrievable

### Tests for User Story 1 (MANDATORY - write these first)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

**Skills**: `elixir-testing`, `phoenix-liveview` (for LiveView tests)

- [x] T006 [P] [US1] Unit tests for Inventory context in `apps/epoch/test/epoch/backoffice/inventory_test.exs`
  - **Skill**: `elixir-testing`
  - Test update_quantity/2 success with valid product
  - Test update_quantity/2 to 0 succeeds (out of stock)
  - Test update_quantity/2 with negative value returns {:error, :invalid_quantity}
  - Test update_quantity/2 with non-integer returns {:error, :invalid_quantity}
  - Test update_quantity/2 with non-existent product returns {:error, :not_found}
  - Test get_quantity/1 for product with existing inventory
  - Test get_quantity/1 for product without inventory returns 0
  - Test get_state/1 returns full InventoryState
- [x] T007 [P] [US1] Integration tests for event persistence in `apps/epoch/test/epoch/backoffice/inventory_test.exs`
  - **Skill**: `elixir-testing`
  - Test events are persisted to EventStore stream "inventory-{product_id}"
  - Test state is recovered after reading events from stream
- [x] T008 [P] [US1] LiveView tests in `apps/epoch_web/test/epoch_web/live/backoffice/inventory_live_test.exs`
  - **Skill**: `elixir-testing`, `phoenix-liveview`
  - Test form renders with product_id and quantity fields
  - Test successful form submission shows success message
  - Test form submission with invalid product shows error
  - Test form submission with negative quantity shows error

### Implementation for User Story 1

**Skills**: `phoenix-contexts`, `elixir-core`, `phoenix-liveview`, `phoenix-html`, `phoenix`

- [x] T009 [US1] Implement Inventory context module in `apps/epoch/lib/epoch/backoffice/inventory.ex`
  - **Skill**: `phoenix-contexts`, `elixir-core`
  - update_quantity/2: validate product exists via Catalog.get_product/1, validate quantity >= 0, create event, append to stream, return state
  - get_quantity/1: read stream, fold events, return quantity (default 0)
  - get_state/1: read stream, fold events with InventoryState.evolve/2
- [x] T010 [US1] Implement InventoryLive in `apps/epoch_web/lib/epoch_web/live/backoffice/inventory_live.ex`
  - **Skill**: `phoenix-liveview`, `phoenix-html`
  - mount/3: initialize form with to_form/2
  - handle_event "save": parse quantity, call Inventory.update_quantity/2, assign result
  - render/1: form with product_id text input, quantity number input, submit button, result display
- [x] T011 [US1] Add route to router in `apps/epoch_web/lib/epoch_web/router.ex`
  - **Skill**: `phoenix`
  - Add `live "/backoffice/inventory", Backoffice.InventoryLive` in browser scope

**Checkpoint**: User Story 1 complete - inventory can be updated and retrieved via context and LiveView

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Validation, logging, and manual verification

**Skills**: `elixir-core`, `elixir-testing`

- [x] T012 [P] Add logging for inventory operations in `apps/epoch/lib/epoch/backoffice/inventory.ex`
  - **Skill**: `elixir-core`
  - Log product_id, old quantity, new quantity on updates
  - Log errors with appropriate level
- [x] T013 Run quickstart.md validation: verify all IEx examples work as documented
  - **Skill**: None (manual verification)
- [x] T014 Run full test suite: `mix test apps/epoch/test/epoch/backoffice/ apps/epoch_web/test/epoch_web/live/backoffice/`
  - **Skill**: `elixir-testing`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS User Story 1
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **Polish (Phase 4)**: Depends on User Story 1 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Sole user story, no cross-story dependencies

### Within User Story 1

- Tests (T006, T007, T008) MUST be written first and fail before implementation
- Context module (T009) before LiveView (T010)
- Route (T011) after LiveView exists
- Story complete before moving to Polish phase

### Parallel Opportunities

- T002, T003 can run in parallel (different directories)
- T004, T005 can run in parallel (different files, no code dependencies)
- T006, T007, T008 can run in parallel (test files, written before implementation)

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (write first, should fail):
Task: "Unit tests for Inventory context in apps/epoch/test/epoch/backoffice/inventory_test.exs"
Task: "Integration tests for event persistence in apps/epoch/test/epoch/backoffice/inventory_test.exs"
Task: "LiveView tests in apps/epoch_web/test/epoch_web/live/backoffice/inventory_live_test.exs"

# Then implement sequentially:
Task: "Implement Inventory context module"
Task: "Implement InventoryLive"
Task: "Add route to router"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (3 tasks)
2. Complete Phase 2: Foundational (2 tasks)
3. Complete Phase 3: User Story 1 Tests (3 tasks - write first, fail)
4. Complete Phase 3: User Story 1 Implementation (3 tasks)
5. **STOP and VALIDATE**: Run tests, verify all pass
6. Complete Phase 4: Polish (3 tasks)
7. Deploy/demo ready

### Skill Application by Phase

| Phase | Primary Skills |
|-------|---------------|
| Setup | None |
| Foundational | `elixir-core`, `elixir-typespec` |
| US1 Tests | `elixir-testing`, `phoenix-liveview` |
| US1 Implementation | `phoenix-contexts`, `phoenix-liveview`, `phoenix-html`, `phoenix` |
| Polish | `elixir-core`, `elixir-testing` |

---

## Notes

- [P] tasks = different files, no dependencies
- [US1] label maps all tasks to User Story 1 (the only user story in this feature)
- Follow EventStore patterns from Cart context (research.md Decision 3, 4)
- Use `EventStore.stream_name("inventory", product_id)` for stream naming
- Tests use fresh EventStore per test via `start_supervised!` (research.md Decision 9)
- Default quantity for new products is 0 (FR-006)
- Validate product exists before updating (FR-003)
