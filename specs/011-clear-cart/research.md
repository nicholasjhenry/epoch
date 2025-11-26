# Research: Clear All Items from Cart

**Feature**: 011-clear-cart
**Date**: 2025-11-26

## Research Tasks

### 1. Existing Vertical Slice Pattern

**Decision**: Follow the established vertical slice pattern from `add_item` and `remove_item` slices.

**Rationale**: The codebase already has a well-defined pattern for cart operations:
- Command struct in `command.ex` - defines the operation parameters
- CommandHandler in `command_handler.ex` - validates and executes the operation
- Component in `component.ex` - LiveComponent for UI interaction

**Evidence**:
- `apps/epoch_web/lib/epoch_web/slices/add_item/` - 3 files (command, handler, component)
- `apps/epoch_web/lib/epoch_web/slices/remove_item/` - 3 files (command, handler, component)

**Alternatives Considered**:
- Adding clear logic directly to CartItems.Live - Rejected: violates vertical slice isolation
- Creating a context function in Cart module - Rejected: inconsistent with existing slice pattern

### 2. CartCleared Event Structure

**Decision**: Use the existing `Epoch.Cart.Events.CartCleared` event.

**Rationale**: The event already exists in `apps/epoch/lib/epoch/cart/events/cart_cleared.ex` with the structure:
```elixir
defstruct [:cleared_at]
```

**Evidence**: The `CartItemsView` already handles this event in its `evolve/2` function:
```elixir
def evolve(_state, %CartCleared{}) do
  initial_state()
end
```

**Alternatives Considered**:
- Creating a new event type - Rejected: event already exists and is integrated

### 3. Confirmation Dialog Approach

**Decision**: Use browser's native `confirm()` via `phx-confirm` attribute.

**Rationale**: Per spec assumptions, "A simple browser confirm dialog is acceptable for the confirmation UX (no custom modal required)."

**Evidence**: Phoenix LiveView supports `phx-confirm` attribute out of the box:
```heex
<button phx-click="clear_cart" phx-confirm="Are you sure you want to remove all items from your cart?">
  Clear Cart
</button>
```

**Alternatives Considered**:
- Custom modal component - Rejected: spec explicitly allows simple browser confirm
- No confirmation - Rejected: FR-003 requires confirmation dialog

### 4. Empty Cart Validation

**Decision**: Validate cart is non-empty before emitting CartCleared event (FR-007).

**Rationale**: The spec requires "System MUST NOT emit a CartCleared event if the cart is already empty." This prevents unnecessary events in the event stream.

**Implementation Pattern** (from RemoveItem.CommandHandler):
```elixir
with {:ok, cart_state} <- Cart.get_cart_items(command.session_id),
     :ok <- validate_not_empty(cart_state) do
  # emit event
end
```

**Alternatives Considered**:
- Allow event emission for empty carts - Rejected: violates FR-007
- Client-side only validation - Rejected: server must be source of truth

### 5. Button Visibility Logic

**Decision**: Conditionally render Clear Cart button based on cart empty state.

**Rationale**: FR-001 and FR-002 specify button visibility rules:
- MUST display when cart has items
- MUST NOT display when cart is empty

**Implementation**: The `CartItems.Live` already tracks `@cart_empty?` assign which can drive conditional rendering.

**Alternatives Considered**:
- Disable button instead of hiding - Rejected: spec says "MUST NOT display"
- Separate component for visibility - Rejected: unnecessary complexity

### 6. Component Integration Location

**Decision**: Embed ClearCart.Component in `CartItems.Live` template.

**Rationale**: The clear button should appear alongside cart items where the user is viewing their cart. Following the pattern of RemoveItem.Component embedded in CartItems.Live.

**Evidence**: RemoveItem.Component is rendered within CartItems.Live:
```heex
<.live_component
  module={Epoch.Slices.RemoveItem.Component}
  id={"remove-component-#{item.item_id}"}
  ...
/>
```

**Alternatives Considered**:
- Place in parent CartLive - Rejected: CartItems.Live owns cart state and PubSub subscription
- Standalone button outside table - Acceptable but keeping within CartItems.Live maintains cohesion

### 7. PubSub Integration

**Decision**: Leverage existing PubSub pattern - no additional work needed.

**Rationale**: The EventStore already broadcasts to `stream_type:cart` topic. CartItems.Live subscribes and reloads on any cart stream changes.

**Evidence**: From CartItems.Live:
```elixir
def handle_info({:events_appended, stream_name, _events}, socket) do
  if stream_name == "cart-#{socket.assigns.session_id}" do
    {:noreply, load_cart_items(socket)}
  else
    {:noreply, socket}
  end
end
```

The CartCleared event will trigger the same flow, and `load_cart_items/1` will project the empty state.

## Resolved Clarifications

| Item | Resolution |
|------|------------|
| CartCleared event type | Already defined in `Epoch.Cart.Events.CartCleared` |
| Confirmation UX | Browser `confirm()` via `phx-confirm` attribute |
| Button location | Within CartItems.Live, conditional on non-empty cart |
| Event handling | CartItemsView.evolve/2 already handles CartCleared |
| Real-time updates | Existing PubSub subscription handles automatically |

## Dependencies Verified

- [x] EventStore - Available and functioning
- [x] CartCleared Event - Already defined
- [x] CartItemsView - Already handles CartCleared event
- [x] PubSub - Already configured for cart stream updates
- [x] Cart.get_cart_items/1 - Available for empty validation
