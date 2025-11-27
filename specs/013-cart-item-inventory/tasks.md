# Tasks: Display Cart Item Inventory

**Input**: Design documents from `/specs/013-cart-item-inventory/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for every user story. Tests are written first and must fail before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story?] Description | Skills: [skill-list]`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **Skills**: Agent skills to invoke for that task
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/`, `apps/epoch_web/`
- **Slices**: `apps/epoch_web/lib/epoch_web/slices/`
- **Tests**: `apps/epoch_web/test/epoch_web/slices/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare workspace and validate environment

- [ ] T001 Verify branch is `013-cart-item-inventory` and working directory is clean | Skills: none
- [ ] T002 [P] Verify existing dependencies are available (Epoch.Backoffice.Inventory, Epoch.Cart.CartItemsView, Phoenix.PubSub) | Skills: elixir-core

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data structure changes that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Extend CartItemsView to include product_id in cart item structure in `apps/epoch/lib/epoch/cart/cart_items_view.ex` | Skills: elixir-core, ecto
- [ ] T004 Update CartItemsView typespec to include product_id in `apps/epoch/lib/epoch/cart/cart_items_view.ex` | Skills: elixir-typespec
- [ ] T005 Verify ItemAdded event includes product_id field in `apps/epoch/lib/epoch/cart/events/item_added.ex` | Skills: elixir-core

**Checkpoint**: Foundation ready - cart items now include product_id for inventory lookup

---

## Phase 3: User Story 1 - View Available Inventory While Shopping (Priority: P1) MVP

**Goal**: Display available inventory quantity for each product in the cart items list

**Independent Test**: Add items to cart and verify inventory quantity appears next to each cart item

### Tests for User Story 1 (MANDATORY - write these first)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T006 [P] [US1] Unit test: CartItemInventory.Live renders inventory quantity in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T007 [P] [US1] Unit test: CartItemInventory.Live shows "Out of stock" for quantity 0 in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T008 [P] [US1] Unit test: CartItemInventory.Live shows "Unknown" when inventory unavailable in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T009 [P] [US1] Integration test: Cart items display shows inventory for each product in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview

### Implementation for User Story 1

- [ ] T010 [US1] Create CartItemInventory.Live nested LiveView module in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-liveview, elixir-core
- [ ] T011 [US1] Implement mount/3 with initial inventory fetch via Epoch.Backoffice.Inventory.get_quantity/1 in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-liveview, elixir-core
- [ ] T012 [US1] Implement render/1 with inventory display template (quantity, "Out of stock", "Unknown") in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-liveview, phoenix-html
- [ ] T013 [US1] Add error handling for inventory fetch failures with graceful degradation to "Unknown" in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: elixir-core, phoenix-liveview
- [ ] T014 [US1] Embed CartItemInventory.Live in CartItems.Live template via live_render in `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex` | Skills: phoenix-liveview, phoenix-html
- [ ] T015 [US1] Run tests and verify User Story 1 acceptance scenarios pass | Skills: elixir-testing

**Checkpoint**: User Story 1 complete - cart items display static inventory quantities

---

## Phase 4: User Story 2 - Real-time Inventory Updates (Priority: P2)

**Goal**: Inventory display updates automatically when inventory changes without page refresh

**Independent Test**: Open cart in browser, update inventory via IEx, verify cart updates automatically

### Tests for User Story 2 (MANDATORY - write these first)

- [ ] T016 [P] [US2] Unit test: CartItemInventory.Live subscribes to stream_type:inventory on mount in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T017 [P] [US2] Unit test: CartItemInventory.Live handle_info processes matching inventory events in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T018 [P] [US2] Unit test: CartItemInventory.Live ignores inventory events for other products in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T019 [P] [US2] Integration test: Inventory update propagates to cart display in real-time in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview

### Implementation for User Story 2

- [ ] T020 [US2] Add PubSub subscription to stream_type:inventory in mount/3 when connected in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-liveview, elixir-otp
- [ ] T021 [US2] Implement handle_info/2 for {:events_appended, stream_name, events} messages in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-liveview, elixir-core
- [ ] T022 [US2] Filter events by product_id matching socket.assigns.product_id in handle_info/2 in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: elixir-core, phoenix-liveview
- [ ] T023 [US2] Extract and assign latest quantity from filtered events in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: elixir-core, phoenix-liveview
- [ ] T024 [US2] Run tests and verify User Story 2 acceptance scenarios pass | Skills: elixir-testing

**Checkpoint**: User Story 2 complete - inventory updates in real-time without page refresh

---

## Phase 5: User Story 3 - Low Stock Visual Indicator (Priority: P3)

**Goal**: Visual differentiation for low stock items (5 or fewer units) to help users prioritize purchases

**Independent Test**: Add low-stock item to cart and verify visual styling differs from normal stock items

### Tests for User Story 3 (MANDATORY - write these first)

- [ ] T025 [P] [US3] Unit test: CartItemInventory.Live applies low-stock styling for quantity <= 5 in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T026 [P] [US3] Unit test: CartItemInventory.Live applies normal styling for quantity > 5 in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview
- [ ] T027 [P] [US3] Unit test: CartItemInventory.Live applies out-of-stock styling for quantity 0 in `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | Skills: elixir-testing, phoenix-liveview

### Implementation for User Story 3

- [ ] T028 [US3] Define @low_stock_threshold module attribute (5) in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: elixir-core
- [ ] T029 [US3] Add helper functions low_stock?/1 and out_of_stock?/1 in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: elixir-core
- [ ] T030 [US3] Update render/1 template with conditional CSS classes for low-stock, out-of-stock, and normal states in `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | Skills: phoenix-html, phoenix-liveview
- [ ] T031 [US3] Run tests and verify User Story 3 acceptance scenarios pass | Skills: elixir-testing

**Checkpoint**: User Story 3 complete - low stock and out-of-stock items visually differentiated

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T032 [P] Run full test suite with `mix test` and ensure all tests pass | Skills: elixir-testing
- [ ] T033 [P] Run precommit checks with `mix precommit` | Skills: none
- [ ] T034 Run quickstart.md validation scenarios manually | Skills: none
- [ ] T035 [P] Review code for any Logger.warning calls for inventory fetch failures | Skills: elixir-core

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories should proceed sequentially in priority order (P1 -> P2 -> P3)
  - Each builds on previous (US2 adds PubSub to US1, US3 adds styling to both)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Core inventory display
- **User Story 2 (P2)**: Depends on US1 completion - Adds real-time updates to US1 implementation
- **User Story 3 (P3)**: Depends on US1 completion - Adds visual styling to US1 implementation

### Within Each User Story

- Tests MUST be written first and fail before implementation
- Implementation follows test-driven approach
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All tests for a user story marked [P] can run in parallel (write all tests first)
- Polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test: CartItemInventory.Live renders inventory quantity"
Task: "Unit test: CartItemInventory.Live shows 'Out of stock' for quantity 0"
Task: "Unit test: CartItemInventory.Live shows 'Unknown' when inventory unavailable"
Task: "Integration test: Cart items display shows inventory for each product"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (tests first, then implementation)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready - users can see inventory quantities

### Incremental Delivery

1. Complete Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test independently -> Demo (MVP!)
3. Add User Story 2 -> Test independently -> Demo (real-time updates)
4. Add User Story 3 -> Test independently -> Demo (visual indicators)
5. Each story adds value without breaking previous stories

---

## Skills Reference

| Skill | When to Use |
|-------|-------------|
| `elixir-core` | Pattern matching, error handling, data structures |
| `elixir-testing` | ExUnit tests, LiveView testing patterns |
| `elixir-typespec` | @type, @spec annotations |
| `elixir-otp` | PubSub subscriptions, GenServer patterns |
| `phoenix-liveview` | LiveView mount, handle_info, render patterns |
| `phoenix-html` | HEEx templates, conditional CSS classes |
| `ecto` | Schema changes, changeset patterns |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Skills listed after `|` indicate which agent skills to invoke for that task
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
