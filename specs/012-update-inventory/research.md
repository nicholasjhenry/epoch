# Research: Update Product Inventory

**Feature**: 012-update-inventory  
**Date**: 2025-11-27

## Overview

Research findings for implementing inventory management following the existing event-sourcing patterns in the Epoch codebase.

## Decision 1: Event Structure Pattern

**Decision**: Use plain struct with `@type` and `defstruct` following `ItemAdded` pattern.

**Rationale**: The codebase has established a clear event structure pattern in `apps/epoch/lib/epoch/cart/events/`. Events are simple structs containing all data needed for state reconstruction and display. The `InventoryUpdated` event should include `product_id`, `quantity`, and `updated_at` timestamp.

**Alternatives considered**:
- Ecto embedded schema: Rejected - events are not persisted to database, they go through EventStore
- Maps: Rejected - structs provide better compile-time guarantees and pattern matching

**Reference**: `apps/epoch/lib/epoch/cart/events/item_added.ex`

## Decision 2: Context API Pattern

**Decision**: Follow Cart context pattern with public API functions returning `{:ok, result}` or `{:error, reason}` tuples.

**Rationale**: The Cart context at `apps/epoch/lib/epoch/cart/cart.ex` demonstrates the established pattern:
1. Public functions validate inputs using dependencies (Catalog.get_product/1)
2. Create event structs on success
3. Append to stream via EventStore
4. Return reconstructed state or error tuple

**Alternatives considered**:
- Slice architecture: Rejected per user requirement ("no vertical-slice architecture")
- Direct EventStore access from LiveView: Rejected - violates separation of concerns

**Reference**: `apps/epoch/lib/epoch/cart/cart.ex`

## Decision 3: Stream Naming Convention

**Decision**: Use `EventStore.stream_name("inventory", product_id)` producing streams like `"inventory-espresso-blend"`.

**Rationale**: The EventStore module provides a `stream_name/2` helper that concatenates type and ID with a hyphen. This matches existing patterns for cart streams (`"cart-{session_id}"`). One stream per product allows efficient retrieval of individual product inventory history.

**Alternatives considered**:
- Single global inventory stream: Rejected - would require filtering on read and doesn't support per-product versioning
- Stream per update: Rejected - loses aggregate state benefits

**Reference**: `apps/epoch/lib/epoch/event_store.ex` line 31 (`stream_name/2`)

## Decision 4: State Reconstruction Pattern

**Decision**: Create `InventoryState` module with `evolve/2` function following `CartSession` pattern.

**Rationale**: The Cart domain uses aggregate state modules that implement `evolve/2` to fold events into state. For inventory, state is simple: `%{product_id: string, quantity: integer}`. Initial state for new products defaults quantity to 0.

**Alternatives considered**:
- Inline state reconstruction in context: Rejected - violates separation and harder to test
- Read model only: Considered but aggregate state needed for validation

**Reference**: `apps/epoch/lib/epoch/cart/cart_session.ex`

## Decision 5: Product Validation

**Decision**: Validate product existence via `Catalog.get_product/1` before creating events.

**Rationale**: Per FR-003, system MUST return error for non-existent products. The Catalog context already provides `get_product/1` returning `{:ok, product}` or `{:error, :not_found}`. This matches how Cart validates products in `add_item/2`.

**Alternatives considered**:
- Skip validation: Rejected - violates FR-003 and could lead to orphan inventory records
- Raise exception: Rejected - tuples are idiomatic for expected failures

**Reference**: `apps/epoch/lib/epoch/catalog/catalog.ex`

## Decision 6: LiveView Implementation

**Decision**: Simple LiveView with form, calling context functions directly (no embedded components or slices).

**Rationale**: User explicitly requested "just a PhoenixView and context" without vertical-slice architecture. The `ProductsLive` module demonstrates a simple pattern: mount fetches data, assigns to socket, form events call context functions.

**Alternatives considered**:
- Slice architecture: Rejected per user requirement
- LiveComponent: Rejected - adds complexity without benefit for this simple form

**Reference**: `apps/epoch/apps/epoch_web/lib/epoch_web/live/products_live.ex`

## Decision 7: Quantity Validation

**Decision**: Validate quantity is non-negative integer in context before event creation.

**Rationale**: Per FR-002, quantities must be non-negative integers. Validation at the context layer ensures invalid data never reaches the EventStore. Return `{:error, :invalid_quantity}` for violations.

**Alternatives considered**:
- LiveView-only validation: Rejected - context should enforce invariants regardless of caller
- Changeset validation: Not applicable - no Ecto schema for inventory

## Decision 8: Default Inventory Quantity

**Decision**: Return 0 as default quantity for products without inventory events.

**Rationale**: Per FR-006, products without inventory records default to 0. The `get_quantity/1` function should return `{:ok, 0}` when no events exist for a product (empty stream).

**Reference**: Spec FR-006

## Decision 9: Testing Strategy

**Decision**: Fresh EventStore per test using `start_supervised!` with unique name.

**Rationale**: Existing tests in `cart_test.exs` demonstrate the pattern of starting a fresh EventStore instance per test to ensure isolation. This prevents test pollution and allows parallel test execution.

**Reference**: `apps/epoch/test/epoch/cart_test.exs`

## Outstanding Items

None - all technical decisions resolved through codebase exploration.
