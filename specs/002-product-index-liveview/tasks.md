# Tasks: Product Index Page for Phoenix LiveView

**Input**: Design documents from `/specs/002-product-index-liveview/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Tests are REQUIRED for every user story per constitution and plan.md. Write failing tests first.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/epoch/` (core), `apps/epoch_web/` (web layer)
- Tests mirror source structure in `test/` directories

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: CDN dependencies and routing setup

- [X] T001 Add Bulma CSS CDN link to `apps/epoch_web/lib/epoch_web/components/layouts/root.html.heex`
- [X] T002 [P] Add Font Awesome CDN link to `apps/epoch_web/lib/epoch_web/components/layouts/root.html.heex`
- [X] T003 Add `/products` LiveView route to `apps/epoch_web/lib/epoch_web/router.ex`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data structures and contexts that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation (MANDATORY - write these first) ⚠️

- [X] T004 [P] Write Catalog context tests in `apps/epoch/test/epoch/catalog_test.exs`
- [X] T005 [P] Write Cart context tests in `apps/epoch/test/epoch/cart_test.exs`

### Implementation for Foundation

- [X] T006 [P] Create Product struct in `apps/epoch/lib/epoch/catalog/product.ex`
- [X] T007 [P] Create CartCreated event struct in `apps/epoch/lib/epoch/cart/events/cart_created.ex`
- [X] T008 [P] Create ItemAddedToCart event struct in `apps/epoch/lib/epoch/cart/events/item_added_to_cart.ex`
- [X] T009 Create CartSession struct with evolve/2 in `apps/epoch/lib/epoch/cart/cart_session.ex` (depends on T007, T008)
- [X] T010 Create Catalog context with list_products/0, get_product/1, get_product!/1 in `apps/epoch/lib/epoch/catalog/catalog.ex` (depends on T006)
- [X] T011 Create Cart context with create_session/1, add_item/3, get_session/1 in `apps/epoch/lib/epoch/cart/cart.ex` (depends on T009, T010)

**Checkpoint**: Foundation ready - all tests pass, user story implementation can begin

---

## Phase 3: User Story 1 - View Product Catalog (Priority: P1) 🎯 MVP

**Goal**: Display 5 coffee products in a responsive card grid with name, description, and price

**Independent Test**: Visit `/products` and verify all 5 products display with correct details in card layout

### Tests for User Story 1 (MANDATORY - write these first) ⚠️

- [X] T012 [US1] Write LiveView mount tests in `apps/epoch_web/test/epoch_web/live/products_live_test.exs` (test assigns products list, test generates cart session id)
- [X] T013 [US1] Write product card rendering tests in `apps/epoch_web/test/epoch_web/live/products_live_test.exs` (test renders all 5 products, test renders product name/price/description elements with correct IDs)

### Implementation for User Story 1

- [X] T014 [US1] Create ProductsLive module with mount/3 in `apps/epoch_web/lib/epoch_web/live/products_live.ex`
- [X] T015 [US1] Create ProductsLive template with product cards in `apps/epoch_web/lib/epoch_web/live/products_live.html.heex`
- [X] T016 [US1] Add format_price/1 helper function to ProductsLive module in `apps/epoch_web/lib/epoch_web/live/products_live.ex`

**Checkpoint**: User Story 1 complete - products display in responsive grid, tests pass

---

## Phase 4: User Story 2 - Navigate Between Pages (Priority: P2)

**Goal**: Navigation bar with links to Products, Cart, Spec, and Backoffice with Font Awesome icons

**Independent Test**: Click each navigation link and verify correct routing

### Tests for User Story 2 (MANDATORY - write these first) ⚠️

- [X] T017 [US2] Write navigation rendering tests in `apps/epoch_web/test/epoch_web/live/products_live_test.exs` (test nav-main exists, test nav-products/nav-cart/nav-spec/nav-backoffice links exist with icons)

### Implementation for User Story 2

- [X] T018 [US2] Add navigation bar HTML to ProductsLive template in `apps/epoch_web/lib/epoch_web/live/products_live.html.heex`

**Checkpoint**: User Story 2 complete - navigation bar displays with all links and icons, tests pass

---

## Phase 5: User Story 3 - Add Product to Cart (Priority: P3)

**Goal**: "Add Item" button on each product card that adds to cart and redirects to /cart

**Independent Test**: Click "Add Item" on any product, verify redirect to /cart and item stored in EventStore

### Tests for User Story 3 (MANDATORY - write these first) ⚠️

- [X] T019 [US3] Write add_to_cart button rendering tests in `apps/epoch_web/test/epoch_web/live/products_live_test.exs` (test add-item-{product_id} button exists on each card)
- [X] T020 [US3] Write add_to_cart event handler tests in `apps/epoch_web/test/epoch_web/live/products_live_test.exs` (test clicking add button redirects to /cart, test event stored in EventStore)

### Implementation for User Story 3

- [X] T021 [US3] Add handle_event("add_to_cart", ...) to ProductsLive in `apps/epoch_web/lib/epoch_web/live/products_live.ex`
- [X] T022 [US3] Add "Add Item" button with phx-click to product cards in `apps/epoch_web/lib/epoch_web/live/products_live.html.heex`

**Checkpoint**: User Story 3 complete - add to cart works, redirects to /cart, event stored, tests pass

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T023 Run full test suite with `mix test`
- [X] T024 Run precommit checks with `mix precommit` (format, credo, dialyzer)
- [X] T025 Manual verification per quickstart.md checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed sequentially in priority order (P1 → P2 → P3)
  - US2 and US3 can technically parallel after US1 foundation but share template file
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Adds to same template as US1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Uses Cart context from foundational, adds to same template

### Within Each Phase

- Tests MUST be written first and fail before implementation
- Structs/events before contexts that use them
- Contexts before LiveViews that use them
- LiveView module before template

### Parallel Opportunities

**Phase 1 (Setup)**:
```
T001 + T002 can run in parallel (different lines in same file, but simple additions)
```

**Phase 2 (Foundational)**:
```
# All tests can run in parallel:
T004 + T005

# All structs/events can run in parallel:
T006 + T007 + T008

# Then sequential:
T009 (depends on T007, T008)
T010 (depends on T006)
T011 (depends on T009, T010)
```

**User Story Phases**:
```
# Within each story, tests first, then implementation
# Stories are best done sequentially due to shared template file
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (CDN links + route)
2. Complete Phase 2: Foundational (Product struct + Catalog context + Cart context)
3. Complete Phase 3: User Story 1 (Product display)
4. **STOP and VALIDATE**: Test `/products` renders all 5 products correctly
5. Can demo/deploy MVP at this point

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → **MVP Ready!**
3. Add User Story 2 → Test independently → Navigation added
4. Add User Story 3 → Test independently → Cart functionality added
5. Each story adds value without breaking previous stories

### File Touch Summary

| File | Phases | Operations |
|------|--------|------------|
| `root.html.heex` | 1 | Add 2 CDN links |
| `router.ex` | 1 | Add 1 route |
| `product.ex` | 2 | Create |
| `cart_created.ex` | 2 | Create |
| `item_added_to_cart.ex` | 2 | Create |
| `cart_session.ex` | 2 | Create |
| `catalog.ex` | 2 | Create |
| `cart.ex` | 2 | Create |
| `catalog_test.exs` | 2 | Create |
| `cart_test.exs` | 2 | Create |
| `products_live.ex` | 3, 5 | Create, then add handler |
| `products_live.html.heex` | 3, 4, 5 | Create, add nav, add button |
| `products_live_test.exs` | 3, 4, 5 | Create, add nav tests, add cart tests |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Cart page route does not exist yet - redirect will 404 until cart page is built (expected)
