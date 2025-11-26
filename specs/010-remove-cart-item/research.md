# Research: Remove Item from Cart

**Feature**: 010-remove-cart-item
**Date**: 2025-11-26

## Research Summary

All technical decisions are resolved. The feature leverages existing patterns and infrastructure with no unknowns.

---

## Decision 1: Vertical Slice Architecture Pattern

**Decision**: Follow the existing `add_item` slice pattern with Command, CommandHandler, and Component modules.

**Rationale**: 
- Consistent with existing codebase (see `apps/epoch_web/lib/epoch_web/slices/add_item/`)
- Clear separation of concerns: Command (data), CommandHandler (business logic), Component (UI)
- Enables independent testing of each layer

**Alternatives Considered**:
- Inline in CartLive: Rejected - violates vertical slice pattern, harder to test
- Context function only: Rejected - loses UI component encapsulation

**Evidence**: Existing `add_item` slice structure:
```
slices/add_item/
├── command.ex          # Struct with session_id, product_id
├── command_handler.ex  # Validates limits, appends ItemAdded event
└── component.ex        # LiveComponent with phx-click handler
```

---

## Decision 2: Command Handler State Reconstruction

**Decision**: CommandHandler rebuilds cart state from events using `Cart.get_cart_items/1` to validate item existence before appending ItemRemoved event.

**Rationale**:
- User requirement: "command handler should rebuild the state based to apply business rules, e.g. when an item is not in the cart"
- Consistent with event sourcing: derive current state from events
- Enables validation without separate read model

**Alternatives Considered**:
- Trust UI (item exists if button shown): Rejected - race conditions, no validation
- Separate read model query: Rejected - unnecessary complexity, Cart.get_cart_items already provides state

**Evidence**: Existing `Cart.get_cart_items/1` returns `{:ok, %{items: [...], total: float}}` with item_id in each item.

---

## Decision 3: Real-Time Cart Updates via PubSub

**Decision**: CartLive subscribes to the cart stream's PubSub topic to receive ItemRemoved events and rebuild state.

**Rationale**:
- User requirement: "cart page should subscribe to the event store to rebuild the state when an item is deleted"
- EventStore already broadcasts to `stream_type:cart` topic on append
- Enables real-time UI updates without polling

**Alternatives Considered**:
- Return updated state from component: Rejected - doesn't handle multi-tab scenarios
- WebSocket push from CommandHandler: Rejected - PubSub already exists and is simpler

**Evidence**: EventStore broadcasts in `do_append/4`:
```elixir
defp broadcast_to_stream_type(stream_name, events) do
  stream_type = extract_stream_type(stream_name)
  topic = "stream_type:#{stream_type}"
  Phoenix.PubSub.broadcast(Epoch.PubSub, topic, {:events_appended, stream_name, events})
end
```

---

## Decision 4: Error Handling for Non-Existent Items

**Decision**: Return `{:error, :item_not_found}` when attempting to remove an item that doesn't exist in the cart.

**Rationale**:
- Spec requirement FR-007: "System MUST return an error when attempting to remove an item that does not exist in the cart"
- Explicit error provides clear feedback to UI layer
- Consistent with tagged tuple pattern used throughout codebase

**Alternatives Considered**:
- Silent success (idempotent): Rejected - spec explicitly requires error
- Raise exception: Rejected - errors are expected flow, not exceptional

**Evidence**: Spec FR-007 and edge case: "The system should return an error indicating the item was not found."

---

## Decision 5: ItemRemoved Event Structure

**Decision**: Use existing `Epoch.Cart.Events.ItemRemoved` event with `item_id` and `removed_at` fields.

**Rationale**:
- Event type already defined in codebase
- `CartItemsView.evolve/2` already handles ItemRemoved events
- No changes needed to event infrastructure

**Alternatives Considered**:
- Add more fields (product_id, name): Rejected - unnecessary, item_id sufficient for removal
- New event type: Rejected - existing type matches requirements

**Evidence**: Existing event at `apps/epoch/lib/epoch/cart/events/item_removed.ex`:
```elixir
defmodule Epoch.Cart.Events.ItemRemoved do
  @type t :: %__MODULE__{
          item_id: String.t(),
          removed_at: DateTime.t()
        }
  defstruct [:item_id, :removed_at]
end
```

---

## Decision 6: Remove Button Placement

**Decision**: Add remove button to each cart item row in the cart table, using a LiveComponent similar to AddItem.Component.

**Rationale**:
- Spec requirement FR-001: "System MUST display a remove control for each item in the cart"
- LiveComponent encapsulates event handling and CommandHandler invocation
- Consistent with AddItem.Component pattern

**Alternatives Considered**:
- Handle in CartLive directly: Rejected - loses encapsulation, mixes concerns
- Static link/form: Rejected - requires page reload, not real-time

**Evidence**: Cart template shows item rows that can be extended:
```heex
<tr :for={item <- @cart_items} id={"cart-item-#{item.item_id}"}>
  <td id={"cart-item-name-#{item.item_id}"}>{item.name}</td>
  <td id={"cart-item-price-#{item.item_id}"}>{format_price(item.price)}</td>
  <!-- Add remove button here -->
</tr>
```

---

## Best Practices Applied

### Phoenix LiveView PubSub Subscription
- Subscribe in `mount/3` when `connected?(socket)` is true
- Unsubscription handled automatically by LiveView process termination
- Handle PubSub message in `handle_info/2`

### Event Sourcing Command Validation
- Rebuild state before command execution to validate business rules
- Never trust external input; always verify against current state
- Return explicit error tuples for validation failures

### LiveComponent Event Handling
- Use `phx-target={@myself}` to route events to component
- Send messages to parent LiveView for cross-component updates (flash messages)
- Keep component focused on single responsibility (remove action)
