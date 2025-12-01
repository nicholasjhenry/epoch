# Tasks: Price Change TODO List & Automation

**Input**: Design documents from `/specs/014-price-change-automation/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Tests are REQUIRED for every user story. List the failing unit tests first and include integration coverage for every cross-boundary change.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description | Skills: [skill-list]`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **Skills**: Agent skills to invoke before implementing this task
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` (core domain), `apps/epoch_web/` (web layer)
- **Events**: `apps/epoch/lib/epoch/{context}/events/`
- **Read models**: `apps/epoch/lib/epoch/{context}/`
- **Commands/Slices**: `apps/epoch_web/lib/epoch_web/slices/`
- **LiveViews**: `apps/epoch_web/lib/epoch_web/live/`
- **Tests**: `apps/epoch/test/epoch/`, `apps/epoch_web/test/epoch_web/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Event definitions and base infrastructure for all user stories

- [ ] T001 [P] Create PriceChanged event struct in apps/epoch/lib/epoch/backoffice/events/price_changed.ex | Skills: elixir-core
- [ ] T002 [P] Create ItemArchiveRequested event struct in apps/epoch/lib/epoch/cart/events/item_archive_requested.ex | Skills: elixir-core
- [ ] T003 [P] Extend ItemArchived event with cart_id and reason fields in apps/epoch/lib/epoch/cart/events/item_archived.ex | Skills: elixir-core
- [ ] T004 [P] Add cart_id field to ItemAdded event in apps/epoch/lib/epoch/cart/events/item_added.ex | Skills: elixir-core

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core read models and command infrastructure that MUST be complete before ANY user story automation can work

**⚠️ CRITICAL**: User stories 4-6 (automation) cannot function until CartsWithProducts read model is complete

### Read Model Infrastructure

- [ ] T005 [P] Create CartsWithProducts read model in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T006 [P] Create ItemsToArchive read model (TODO list) in apps/epoch/lib/epoch/cart/items_to_archive.ex | Skills: elixir-core
- [ ] T007 [P] Create ProductsWithPriceChanges read model in apps/epoch/lib/epoch/backoffice/products_with_price_changes.ex | Skills: elixir-core

### Command Slices

- [ ] T008 [P] Create ChangePrice command struct in apps/epoch_web/lib/epoch_web/slices/change_price/command.ex | Skills: elixir-core
- [ ] T009 [P] Create RequestToArchiveItem command struct in apps/epoch_web/lib/epoch_web/slices/request_to_archive_item/command.ex | Skills: elixir-core
- [ ] T010 [P] Create ArchiveItem command struct in apps/epoch_web/lib/epoch_web/slices/archive_item/command.ex | Skills: elixir-core

**Checkpoint**: Foundation ready - all events, read models, and command structs defined

---

## Phase 3: User Story 1 - Publish Price Change from Backoffice (Priority: P1) 🎯 MVP

**Goal**: Allow administrators to publish price changes for products from the backoffice interface

**Independent Test**: Publish a price change and verify a PriceChanged event is emitted to the price stream

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

- [ ] T011 [P] [US1] Unit test ChangePrice command handler emits PriceChanged event in apps/epoch_web/test/epoch_web/slices/change_price_test.exs | Skills: elixir-testing
- [ ] T012 [P] [US1] Unit test ChangePrice validates product exists in Catalog in apps/epoch_web/test/epoch_web/slices/change_price_test.exs | Skills: elixir-testing
- [ ] T013 [P] [US1] Unit test ChangePrice rejects invalid prices (<=0) in apps/epoch_web/test/epoch_web/slices/change_price_test.exs | Skills: elixir-testing
- [ ] T014 [P] [US1] LiveView test for price change form submission in apps/epoch_web/test/epoch_web/live/backoffice/inventory_live_test.exs | Skills: elixir-testing, phoenix-liveview

### Implementation for User Story 1

- [ ] T015 [US1] Implement ChangePrice command handler in apps/epoch_web/lib/epoch_web/slices/change_price/command_handler.ex | Skills: elixir-core
- [ ] T016 [US1] Create Epoch.Backoffice.Price context with change_price/1 function in apps/epoch/lib/epoch/backoffice/price.ex | Skills: elixir-core, phoenix-contexts
- [ ] T017 [US1] Extend InventoryLive with price change form in apps/epoch_web/lib/epoch_web/live/backoffice/inventory_live.ex | Skills: phoenix-liveview, phoenix-html
- [ ] T018 [US1] Add handle_event for "change_price" in InventoryLive in apps/epoch_web/lib/epoch_web/live/backoffice/inventory_live.ex | Skills: phoenix-liveview

**Checkpoint**: Administrators can change product prices from backoffice UI → PriceChanged event emitted to price stream

---

## Phase 4: User Story 2 - Track Products with Price Changes (Priority: P2)

**Goal**: Maintain a read model of products with price changes for downstream automation

**Independent Test**: Publish price change events and verify the ProductsWithPriceChanges read model correctly tracks all products

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [ ] T019 [P] [US2] Unit test ProductsWithPriceChanges adds product on PriceChanged event in apps/epoch/test/epoch/backoffice/products_with_price_changes_test.exs | Skills: elixir-testing
- [ ] T020 [P] [US2] Unit test ProductsWithPriceChanges tracks latest price per product in apps/epoch/test/epoch/backoffice/products_with_price_changes_test.exs | Skills: elixir-testing
- [ ] T021 [P] [US2] Unit test ProductsWithPriceChanges.all_products/1 returns all tracked products in apps/epoch/test/epoch/backoffice/products_with_price_changes_test.exs | Skills: elixir-testing

### Implementation for User Story 2

- [ ] T022 [US2] Implement evolve/2 for PriceChanged in ProductsWithPriceChanges in apps/epoch/lib/epoch/backoffice/products_with_price_changes.ex | Skills: elixir-core
- [ ] T023 [US2] Implement query functions (get_product, all_products, changed_since) in ProductsWithPriceChanges in apps/epoch/lib/epoch/backoffice/products_with_price_changes.ex | Skills: elixir-core
- [ ] T024 [US2] Implement build/0 function to construct read model from price streams in apps/epoch/lib/epoch/backoffice/products_with_price_changes.ex | Skills: elixir-core

**Checkpoint**: ProductsWithPriceChanges read model correctly tracks all products with price changes

---

## Phase 5: User Story 3 - Track Carts with Products (Priority: P2)

**Goal**: Maintain a read model of carts with their products for correlating price changes with affected carts

**Independent Test**: Add items to carts and verify the CartsWithProducts read model correctly tracks cart-to-product relationships

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [ ] T025 [P] [US3] Unit test CartsWithProducts adds mapping on ItemAdded event in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing
- [ ] T026 [P] [US3] Unit test CartsWithProducts removes mapping on ItemRemoved event in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing
- [ ] T027 [P] [US3] Unit test CartsWithProducts removes mapping on ItemArchived event in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing
- [ ] T028 [P] [US3] Unit test CartsWithProducts clears cart on CartCleared event in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing
- [ ] T029 [P] [US3] Unit test CartsWithProducts.carts_with_product/2 returns all carts containing product in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing
- [ ] T030 [P] [US3] Unit test CartsWithProducts.items_for_product/2 returns all items for product across carts in apps/epoch/test/epoch/cart/carts_with_products_test.exs | Skills: elixir-testing

### Implementation for User Story 3

- [ ] T031 [US3] Implement evolve/2 for ItemAdded in CartsWithProducts in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T032 [US3] Implement evolve/2 for ItemRemoved in CartsWithProducts in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T033 [US3] Implement evolve/2 for ItemArchived in CartsWithProducts in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T034 [US3] Implement evolve/2 for CartCleared in CartsWithProducts in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T035 [US3] Implement query functions (carts_with_product, items_for_product, products_in_cart) in CartsWithProducts in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core
- [ ] T036 [US3] Implement build/0 function to construct read model from cart streams in apps/epoch/lib/epoch/cart/carts_with_products.ex | Skills: elixir-core

**Checkpoint**: CartsWithProducts read model correctly tracks which carts contain which products

---

## Phase 6: User Story 4 - Request Item Archive on Price Change (Priority: P1)

**Goal**: Automatically request archiving of cart items when their product's price changes

**Independent Test**: Publish a price change for a product in one or more carts and verify ItemArchiveRequested events are emitted

**Depends on**: User Story 2 (ProductsWithPriceChanges), User Story 3 (CartsWithProducts)

### Tests for User Story 4 (MANDATORY - write these first) ⚠️

- [ ] T037 [P] [US4] Unit test PriceChangeProcessor identifies affected carts via CartsWithProducts in apps/epoch/test/epoch/automation/price_change_processor_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T038 [P] [US4] Unit test PriceChangeProcessor emits ItemArchiveRequested for each affected cart item in apps/epoch/test/epoch/automation/price_change_processor_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T039 [P] [US4] Unit test PriceChangeProcessor does not emit events for products not in any cart in apps/epoch/test/epoch/automation/price_change_processor_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T040 [P] [US4] Unit test RequestToArchiveItem command handler emits ItemArchiveRequested event in apps/epoch_web/test/epoch_web/slices/request_to_archive_item_test.exs | Skills: elixir-testing
- [ ] T041 [P] [US4] Unit test RequestToArchiveItem is idempotent (returns error if already requested) in apps/epoch_web/test/epoch_web/slices/request_to_archive_item_test.exs | Skills: elixir-testing
- [ ] T042 [P] [US4] Integration test end-to-end: PriceChanged triggers ItemArchiveRequested for affected carts in apps/epoch/test/epoch/automation/price_change_processor_integration_test.exs | Skills: elixir-testing, elixir-otp

### Implementation for User Story 4

- [ ] T043 [US4] Implement RequestToArchiveItem command handler in apps/epoch_web/lib/epoch_web/slices/request_to_archive_item/command_handler.ex | Skills: elixir-core
- [ ] T044 [US4] Add request_archive/1 function to Epoch.Cart context in apps/epoch/lib/epoch/cart.ex | Skills: elixir-core, phoenix-contexts
- [ ] T045 [US4] Create PriceChangeProcessor GenServer in apps/epoch/lib/epoch/automation/price_change_processor.ex | Skills: elixir-otp
- [ ] T046 [US4] Implement handle_info for :events_appended in PriceChangeProcessor in apps/epoch/lib/epoch/automation/price_change_processor.ex | Skills: elixir-otp
- [ ] T047 [US4] Subscribe PriceChangeProcessor to stream_type:price PubSub topic in apps/epoch/lib/epoch/automation/price_change_processor.ex | Skills: elixir-otp
- [ ] T048 [US4] Add PriceChangeProcessor to application supervision tree in apps/epoch/lib/epoch/application.ex | Skills: elixir-otp

**Checkpoint**: Price changes automatically trigger ItemArchiveRequested events for all affected cart items

---

## Phase 7: User Story 5 - Build Items to Archive TODO List (Priority: P2)

**Goal**: Maintain a TODO list (read model) of items pending archive

**Independent Test**: Emit ItemArchiveRequested events and verify they appear in the TODO list, then verify they are removed when ItemArchived is emitted

### Tests for User Story 5 (MANDATORY - write these first) ⚠️

- [ ] T049 [P] [US5] Unit test ItemsToArchive adds item on ItemArchiveRequested event in apps/epoch/test/epoch/cart/items_to_archive_test.exs | Skills: elixir-testing
- [ ] T050 [P] [US5] Unit test ItemsToArchive removes item on ItemArchived event in apps/epoch/test/epoch/cart/items_to_archive_test.exs | Skills: elixir-testing
- [ ] T051 [P] [US5] Unit test ItemsToArchive is idempotent (same ItemArchiveRequested doesn't duplicate) in apps/epoch/test/epoch/cart/items_to_archive_test.exs | Skills: elixir-testing
- [ ] T052 [P] [US5] Unit test ItemsToArchive.all_pending/1 returns all pending items in apps/epoch/test/epoch/cart/items_to_archive_test.exs | Skills: elixir-testing
- [ ] T053 [P] [US5] Unit test ItemsToArchive.is_pending?/2 correctly checks item status in apps/epoch/test/epoch/cart/items_to_archive_test.exs | Skills: elixir-testing

### Implementation for User Story 5

- [ ] T054 [US5] Implement evolve/2 for ItemArchiveRequested in ItemsToArchive in apps/epoch/lib/epoch/cart/items_to_archive.ex | Skills: elixir-core
- [ ] T055 [US5] Implement evolve/2 for ItemArchived in ItemsToArchive in apps/epoch/lib/epoch/cart/items_to_archive.ex | Skills: elixir-core
- [ ] T056 [US5] Implement query functions (all_pending, pending_for_cart, is_pending?, pending_count) in ItemsToArchive in apps/epoch/lib/epoch/cart/items_to_archive.ex | Skills: elixir-core
- [ ] T057 [US5] Implement build/0 function to construct read model from cart streams in apps/epoch/lib/epoch/cart/items_to_archive.ex | Skills: elixir-core

**Checkpoint**: ItemsToArchive TODO list correctly tracks pending archive requests

---

## Phase 8: User Story 6 - Archive Cart Items (Priority: P1)

**Goal**: Automatically archive cart items that have pending archive requests

**Independent Test**: Create archive requests and verify the ArchiveItem command is invoked, emitting ItemArchived events

**Depends on**: User Story 5 (ItemsToArchive TODO list)

### Tests for User Story 6 (MANDATORY - write these first) ⚠️

- [ ] T058 [P] [US6] Unit test ArchiveItem command handler emits ItemArchived event in apps/epoch_web/test/epoch_web/slices/archive_item_test.exs | Skills: elixir-testing
- [ ] T059 [P] [US6] Unit test ArchiveItem is idempotent (returns error if already archived) in apps/epoch_web/test/epoch_web/slices/archive_item_test.exs | Skills: elixir-testing
- [ ] T060 [P] [US6] Unit test ArchiveProcessor processes pending items from ItemsToArchive in apps/epoch/test/epoch/automation/archive_processor_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T061 [P] [US6] Integration test end-to-end: ItemArchiveRequested triggers ArchiveItem and ItemArchived in apps/epoch/test/epoch/automation/archive_processor_integration_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T062 [P] [US6] Integration test ItemArchived removes item from cart items view in apps/epoch/test/epoch/cart/cart_items_integration_test.exs | Skills: elixir-testing

### Implementation for User Story 6

- [ ] T063 [US6] Implement ArchiveItem command handler in apps/epoch_web/lib/epoch_web/slices/archive_item/command_handler.ex | Skills: elixir-core
- [ ] T064 [US6] Add archive_item/1 function to Epoch.Cart context in apps/epoch/lib/epoch/cart.ex | Skills: elixir-core, phoenix-contexts
- [ ] T065 [US6] Create ArchiveProcessor GenServer in apps/epoch/lib/epoch/automation/archive_processor.ex | Skills: elixir-otp
- [ ] T066 [US6] Implement processing logic to iterate ItemsToArchive TODO list in ArchiveProcessor in apps/epoch/lib/epoch/automation/archive_processor.ex | Skills: elixir-otp
- [ ] T067 [US6] Subscribe ArchiveProcessor to stream_type:cart PubSub topic for ItemArchiveRequested events in apps/epoch/lib/epoch/automation/archive_processor.ex | Skills: elixir-otp
- [ ] T068 [US6] Add ArchiveProcessor to application supervision tree in apps/epoch/lib/epoch/application.ex | Skills: elixir-otp
- [ ] T069 [US6] Update cart items read model to remove items on ItemArchived event in apps/epoch/lib/epoch/cart/cart_items.ex | Skills: elixir-core

**Checkpoint**: Pending archive requests are automatically processed and items removed from cart view

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation and cleanup

- [ ] T070 [P] Add end-to-end integration test: price change in backoffice → item archived from cart view in apps/epoch/test/epoch/automation/full_flow_integration_test.exs | Skills: elixir-testing
- [ ] T071 [P] Add test for automation resilience: processor restart continues pending items in apps/epoch/test/epoch/automation/resilience_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T072 [P] Add test for concurrent price changes processed correctly in apps/epoch/test/epoch/automation/concurrency_test.exs | Skills: elixir-testing, elixir-otp
- [ ] T073 Run quickstart.md validation scenarios manually
- [ ] T074 Verify all tests pass with mix test

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (events defined) - BLOCKS all user story automation
- **User Story 1 (Phase 3)**: Depends on Phase 2 - Can proceed independently
- **User Story 2 (Phase 4)**: Depends on Phase 2 - Can proceed in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Phase 2 - Can proceed in parallel with US1, US2
- **User Story 4 (Phase 6)**: Depends on Phases 4 & 5 (read models) - Requires US2 + US3 complete
- **User Story 5 (Phase 7)**: Depends on Phase 2 - Can proceed in parallel with US1-US3
- **User Story 6 (Phase 8)**: Depends on Phase 7 (TODO list) - Requires US5 complete
- **Polish (Phase 9)**: Depends on all user stories complete

### User Story Dependencies Graph

```
Phase 1: Setup (Events)
    │
    ▼
Phase 2: Foundational (Read Models, Commands)
    │
    ├──────────────────────────────────────────────┐
    │                                              │
    ▼                                              ▼
Phase 3: US1 (P1)          Phase 4: US2 (P2)      Phase 5: US3 (P2)      Phase 7: US5 (P2)
(Price Change UI)          (Price Read Model)     (Carts Read Model)     (TODO List)
    │                          │                       │                       │
    │                          └───────────┬───────────┘                       │
    │                                      │                                   │
    │                                      ▼                                   │
    │                              Phase 6: US4 (P1)                           │
    │                              (Archive Requests)                          │
    │                                      │                                   │
    │                                      └─────────────────────────┬─────────┘
    │                                                                │
    │                                                                ▼
    │                                                        Phase 8: US6 (P1)
    │                                                        (Archive Items)
    │                                                                │
    └────────────────────────────────────────────────────────────────┘
                                                                     │
                                                                     ▼
                                                             Phase 9: Polish
```

### Parallel Opportunities

**Within Phase 1** (Setup):
- All event definitions (T001-T004) can run in parallel

**Within Phase 2** (Foundational):
- All read model skeletons (T005-T007) can run in parallel
- All command structs (T008-T010) can run in parallel

**After Phase 2 completes**:
- US1 (Phase 3), US2 (Phase 4), US3 (Phase 5), US5 (Phase 7) can all start in parallel
- Tests within each user story can run in parallel

**After US2 + US3 complete**:
- US4 (Phase 6) can begin

**After US5 complete**:
- US6 (Phase 8) can begin

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all read model skeletons together:
Task: T005 "Create CartsWithProducts read model"
Task: T006 "Create ItemsToArchive read model"
Task: T007 "Create ProductsWithPriceChanges read model"

# Launch all command structs together:
Task: T008 "Create ChangePrice command struct"
Task: T009 "Create RequestToArchiveItem command struct"
Task: T010 "Create ArchiveItem command struct"
```

## Parallel Example: User Stories 1-3 + 5 (after Phase 2)

```bash
# All these user stories can start in parallel after Foundational phase:
Phase 3: US1 - Price Change UI
Phase 4: US2 - ProductsWithPriceChanges read model
Phase 5: US3 - CartsWithProducts read model
Phase 7: US5 - ItemsToArchive TODO list
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 4 + 6)

The P1 stories form the core automation loop:

1. Complete Phase 1: Setup (all events)
2. Complete Phase 2: Foundational (read models + commands)
3. Complete Phase 3: User Story 1 (Price Change UI) - **Entry point**
4. Complete Phase 4: User Story 2 (ProductsWithPriceChanges) - **Required for automation**
5. Complete Phase 5: User Story 3 (CartsWithProducts) - **Required for automation**
6. Complete Phase 6: User Story 4 (Archive Requests) - **Core automation**
7. Complete Phase 7: User Story 5 (TODO List) - **Required for archive**
8. Complete Phase 8: User Story 6 (Archive Items) - **Completes loop**
9. **STOP and VALIDATE**: Full price change → archive flow works
10. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test price change UI independently → Demo backoffice
3. Add US2 + US3 → Read models track state → Demo read model queries
4. Add US4 → Archive requests created automatically → Demo automation trigger
5. Add US5 + US6 → Full loop completes → Demo end-to-end flow
6. Polish phase → Production ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Skills listed after `|` indicate which agent skills to invoke for that task
- Each user story should be independently testable where possible
- US4 and US6 depend on other stories' read models but can still be tested with mocked data
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
