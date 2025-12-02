# Research: Submit Cart

**Feature**: 015-submit-cart  
**Date**: 2025-12-02

## Research Tasks Completed

### 1. Command Handler Pattern

**Decision**: Follow vertical slice architecture with Command, CommandHandler, and Component in `epoch_web/lib/epoch_web/slices/submit_cart/`

**Rationale**: Consistent with existing slices (`clear_cart/`, `remove_item/`). The command handler pattern separates the command struct definition from the handling logic, enabling:
- Clear command interface with typed struct
- Testable business logic in isolation
- LiveComponent integration for UI interaction

**Alternatives Considered**:
- Adding `submit_cart/1` directly to `Epoch.Cart` context: Rejected because it would bypass the vertical slice organization and mix UI-driven commands with core domain operations
- Using a GenServer-based command bus: Over-engineering for current scale

**Reference Implementation**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/command_handler.ex`

### 2. Inventory Validation Strategy

**Decision**: Create a dedicated `SubmitCartInventoriesView` read model within the submit_cart slice that projects InventoryUpdated events into a map of `{product_id => quantity}` for cart submission validation.

**Rationale**: 
- **Decoupling**: Avoids coupling the submit cart feature to the existing `Epoch.Backoffice.Inventory` context
- **Single Responsibility**: Each read model serves a specific use case (submission validation vs. backoffice management)
- **Reference Pattern**: Matches `implementing-eventsourcing/app/slices/submitcart/InventoriesStateView.ts` which defines its own inventory projection
- **Testability**: Slice-local read model can be tested in isolation without depending on Backoffice module
- Products with no inventory events return quantity 0 (fail-safe)

**Alternatives Considered**:
- Reusing `Epoch.Backoffice.Inventory.get_quantity/1`: Rejected because it creates coupling between slices and violates vertical slice isolation principles
- Creating a shared inventory projection: Over-engineering; each slice should own its read models

**Read Model Design**:
```elixir
# SubmitCartInventoriesView projects inventory events for cart submission
defmodule Epoch.Slices.SubmitCart.InventoriesView do
  @type state :: %{String.t() => non_neg_integer()}  # product_id => quantity
  
  def initial_state, do: %{}
  
  def evolve(state, %InventoryUpdated{product_id: id, quantity: qty}) do
    Map.put(state, id, qty)
  end
  
  def get_quantity(state, product_id) do
    Map.get(state, product_id, 0)  # Default to 0 if no inventory record
  end
end
```

**Event Sourcing Pattern**:
The InventoriesView is NOT a live subscription. The CommandHandler reads inventory events **on-demand** from the EventStore at submission time:

1. For each `product_id` in cart items, read `inventory-{product_id}` stream
2. Project events through `InventoriesView.evolve/2` to build current state
3. Extract quantity via `InventoriesView.get_quantity/2`

This ensures validation uses the **current** inventory state, not stale cached data.

**Reference Implementation**: `implementing-eventsourcing/app/slices/submitcart/InventoriesStateView.ts`

### 3. Cart State Reconstruction

**Decision**: Use existing `Cart.get_cart_items/1` to get current active items, which already handles ItemAdded, ItemRemoved, ItemArchived, and CartCleared events

**Rationale**: The `CartItemsView` module already correctly projects cart events into current state with items list. Reusing this ensures consistency and avoids duplicating event handling logic.

**Reference Implementation**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

### 4. Event Structure for CartSubmitted

**Decision**: Create `CartSubmitted` event with minimal data - just `cart_id` and `submitted_at` timestamp

**Rationale**: 
- Reference implementation from `implementing-eventsourcing` only includes `aggregateId`
- Item details are already recorded in ItemAdded events
- Keeping the event minimal follows event sourcing best practices (facts, not state)

**Alternatives Considered**:
- Including full item list in CartSubmitted: Rejected as redundant (items already in stream) and could cause consistency issues if items change between reads
- Including total price: Could be derived from events, not needed in the event itself

**Event Schema**:
```elixir
%CartSubmitted{
  cart_id: String.t(),
  submitted_at: DateTime.t()
}
```

### 5. Error Handling Strategy

**Decision**: Return tagged tuples with specific error atoms for different failure modes

**Rationale**: Consistent with existing pattern in `ClearCart.CommandHandler`. Enables UI to display specific error messages.

**Error Types**:
- `{:error, :cart_empty}` - No active items in cart
- `{:error, {:insufficient_inventory, product_ids}}` - One or more products have 0 inventory

**Reference**: `implementing-eventsourcing` throws `Error("Cannot order products without quantity")` - we'll adapt this to Elixir tagged tuples

### 6. UI Integration Pattern

**Decision**: Add SubmitCart LiveComponent to CartItems LiveView, following the pattern of ClearCart component

**Rationale**: 
- Button appears in cart footer alongside Clear Cart button
- Uses `phx-click` event handled by LiveComponent
- Sends flash message to parent LiveView for error display

**UI Placement**: Right side of cart footer, next to Clear Cart button (but styled as primary action)

**Reference Implementation**: `apps/epoch_web/lib/epoch_web/slices/clear_cart/component.ex`

### 7. Testing Strategy

**Decision**: Unit tests for CommandHandler in `apps/epoch/test/epoch/slices/submit_cart/`, integration tests in `apps/epoch_web/test/epoch_web/slices/`

**Rationale**: Matches existing test organization. Unit tests verify business logic in isolation; integration tests verify full flow through LiveView.

**Test Scenarios** (from spec):
1. Submit cart with single item and sufficient inventory → success
2. Submit cart with multiple items and sufficient inventory → success
3. Submit cart when product inventory is 0 → error
4. Submit cart when product has no inventory record → error (treated as 0)
5. Submit cart correctly excludes removed items
6. Submit cart correctly excludes archived items
7. Submit empty cart → error
8. Submit cart after CartCleared → error

**Reference Implementation**: `apps/epoch/test/epoch/cart_test.exs`

## Dependencies Verified

| Dependency | Purpose | Verified |
|------------|---------|----------|
| `Epoch.EventStore` | Read cart/inventory streams, append CartSubmitted | ✅ |
| `Epoch.Cart.get_cart_items/1` | Get current active cart items | ✅ |
| `SubmitCart.InventoriesView` | Slice-local inventory projection (NEW) | ✅ Designed |
| `CartItemsView` | Project cart events to items/total | ✅ |
| `Phoenix.PubSub` | Real-time UI updates | ✅ |

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| What happens when a product has no inventory record? | Treated as 0 inventory - submission rejected |
| What happens when submitting an empty cart? | Submission fails with `:cart_empty` error |
| What happens when inventory changes between loading and submitting? | Validation at submission time uses current state |
| How are archived items handled? | Excluded from validation (already handled by CartItemsView) |

## Best Practices from Reference Implementation

From `implementing-eventsourcing/app/slices/submitcart/commandHandler.ts`:

1. **Reconstruct active product IDs from events** - Reduce over events, adding on ItemAdded, removing on ItemRemoved/ItemArchived, clearing on CartCleared
2. **Validate each product against inventory** - Check that inventory exists and quantity > 0
3. **Throw on validation failure** - In Elixir, return `{:error, reason}` tuple
4. **Emit minimal event** - CartSubmitted with just aggregateId

These patterns are already accounted for in the Elixir implementation plan.
