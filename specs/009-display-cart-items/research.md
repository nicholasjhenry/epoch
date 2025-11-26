# Research: Display Cart Items

**Feature**: 009-display-cart-items
**Date**: 2025-11-26

## Research Summary

This document captures design decisions and best practices research for implementing the cart items display feature.

---

## Decision 1: State View Pattern for Cart Projection

**Decision**: Implement a `CartItemsView` module that projects cart events into a displayable cart state using a fold/reduce pattern.

**Rationale**:
- Follows event sourcing best practices: read models are derived from event streams
- Matches the reference TypeScript implementation (`cartItemsStateView`)
- Separates the display concern from cart behavior/commands
- Enables easy testing of state projections in isolation

**Alternatives Considered**:
1. **Extend existing CartSession**: Rejected because CartSession currently stores `{product_id, quantity}` pairs for command validation, not displayable items with names and prices
2. **Query product catalog per render**: Rejected due to coupling display to catalog availability and performance concerns
3. **Materialize state in database**: Rejected as overkill for in-memory EventStore; adds unnecessary persistence complexity

**Implementation Notes**:
- Create `Epoch.Cart.CartItemsView` module with `project/2` function
- State structure: list of `%{item_id, name, price}` maps
- Event handler for each event type: ItemAdded, ItemRemoved, CartCleared, ItemArchived

---

## Decision 2: Event Structure Design

**Decision**: Define four new/modified event types to support cart display requirements.

### ItemAdded Event (Enhanced from ItemAddedToCart)

The existing `ItemAddedToCart` event stores only `product_id` and `quantity`. For display purposes, we need to denormalize product information into the event.

**Decision**: Create a new `ItemAdded` event type for the display use case OR enhance the existing event.

**Chosen Approach**: Enhance event payload to include display data at write time.

**Event Structure**:
```elixir
%ItemAdded{
  item_id: String.t(),      # Unique line item identifier
  product_id: String.t(),   # Reference to catalog product
  name: String.t(),         # Denormalized product name
  price: Decimal.t(),       # Denormalized price at time of add
  added_at: DateTime.t()
}
```

**Rationale**:
- Denormalizing name/price into the event captures point-in-time data
- Avoids needing to look up catalog during projection
- Matches reference TypeScript `ItemAddedEvent` structure
- Each add creates a unique `item_id` (not aggregated by product)

### ItemRemoved Event

**Event Structure**:
```elixir
%ItemRemoved{
  item_id: String.t(),      # The line item to remove
  removed_at: DateTime.t()
}
```

### CartCleared Event

**Event Structure**:
```elixir
%CartCleared{
  cleared_at: DateTime.t()
}
```

### ItemArchived Event

**Event Structure**:
```elixir
%ItemArchived{
  item_id: String.t(),      # The line item to archive
  archived_at: DateTime.t()
}
```

**Alternatives Considered**:
1. **Reuse ItemRemoved for archive**: Rejected for semantic clarity; archiving may have different business meaning
2. **Store item_id as UUID**: Acceptable but using string allows flexibility (e.g., `"item-{uuid}"`)

---

## Decision 3: LiveView Implementation Pattern

**Decision**: Create a dedicated `CartLive` LiveView module following existing `ProductsLive` patterns.

**Rationale**:
- Separation of concerns: cart display is distinct from product browsing
- Follows existing codebase patterns for consistency
- Enables future real-time updates via PubSub

**Implementation Notes**:
- Mount loads cart state via `EventStore.aggregate_stream/4`
- Uses LiveView streams for efficient DOM updates (future real-time)
- Empty state handled with conditional rendering
- Currency formatting via helper function

**Template Structure** (from reference):
```heex
<div class="box">
  <h3 class="title is-4">Shopping Cart</h3>
  
  <%= if @cart_empty? do %>
    <div class="notification is-light">Your cart is empty</div>
  <% else %>
    <table class="table is-fullwidth is-striped">
      <thead>
        <tr><th>Product</th><th>Price</th></tr>
      </thead>
      <tbody>
        <tr :for={item <- @cart_items}>
          <td>{item.name}</td>
          <td>{format_price(item.price)}</td>
        </tr>
      </tbody>
      <tfoot>
        <tr>
          <th class="has-text-right">Total:</th>
          <th>{format_price(@cart_total)}</th>
        </tr>
      </tfoot>
    </table>
  <% end %>
</div>
```

---

## Decision 4: Session ID Handling

**Decision**: Pass session_id to CartLive via URL parameter or socket assigns.

**Rationale**:
- Cart is identified by session_id (established in ProductsLive)
- Need consistent session across pages
- Matches existing pattern where ProductsLive creates session

**Implementation Notes**:
- Route: `/cart` or `/cart/:session_id`
- Session ID stored in socket assigns on ProductsLive, passed via navigation
- Alternative: store in browser session/cookie (future consideration)

---

## Decision 5: Price Formatting

**Decision**: Format prices as USD currency with two decimal places (e.g., "$14.99").

**Rationale**:
- Matches spec requirement FR-003
- Consistent with existing ProductsLive display
- Simple implementation using Elixir number formatting

**Implementation**:
```elixir
defp format_price(price) when is_number(price) do
  "$#{:erlang.float_to_binary(price / 1, decimals: 2)}"
end
```

Or using `Number.Currency` if available, but keeping it simple aligns with existing patterns.

---

## Decision 6: Real-time Updates (Deferred)

**Decision**: Implement basic page-load projection first; real-time updates via PubSub as enhancement.

**Rationale**:
- Core spec focuses on display, not live updates
- Simpler initial implementation
- Infrastructure (PubSub) already exists from EventStore

**Future Enhancement**:
- Subscribe to cart stream on mount
- Handle `:events_appended` message to update state
- Use LiveView streams for efficient DOM patching

---

## Best Practices Applied

### From Elixir Core
- Use pattern matching in evolve functions
- Return tagged tuples for error cases
- Prefer `Enum.reduce` for folding events

### From Phoenix LiveView
- Use streams for collections that may update
- Set unique DOM IDs on key elements
- Handle mount with `connected?/1` check for subscriptions

### From Event Sourcing
- Events are immutable facts
- State is derived, never stored directly
- Projections can be rebuilt from events

---

## Open Questions (Resolved)

1. **Q**: Should ItemAdded aggregate quantity like CartSession?
   **A**: No. Per spec assumption, each ItemAdded creates a distinct line item.

2. **Q**: How to handle same product added twice?
   **A**: Two separate line items with unique item_ids, both displayed.

3. **Q**: What if product catalog changes after item added?
   **A**: Display uses denormalized data from event; price/name captured at add time.

---

## References

- Reference implementation: `tmp/course-implementing-eventsourcing/app/slices/cartitems/`
- Existing EventStore: `apps/epoch/lib/epoch/event_store.ex`
- Existing Cart context: `apps/epoch/lib/epoch/cart/`
- ProductsLive pattern: `apps/epoch_web/lib/epoch_web/live/products_live.ex`
