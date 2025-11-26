# Contract: Remove Item from Cart

**Feature**: 010-remove-cart-item
**Date**: 2025-11-26

## Overview

This feature uses LiveView events rather than REST APIs. The contract defines the internal module interfaces.

---

## CommandHandler Contract

**Module**: `Epoch.Slices.RemoveItem.CommandHandler`

### handle/1

Processes a remove item command by validating item existence and appending an ItemRemoved event.

**Input**:
```elixir
%Epoch.Slices.RemoveItem.Command{
  session_id: String.t(),  # Cart session identifier
  item_id: String.t()      # Item to remove
}
```

**Output**:
```elixir
{:ok, Epoch.Cart.CartSession.t()}     # Success - returns updated cart session
| {:error, :item_not_found}            # Item does not exist in cart
| {:error, :not_found}                 # Cart session does not exist
| {:error, term()}                     # EventStore append failure
```

**Behavior**:
1. Retrieves current cart state via `Cart.get_cart_items/1`
2. Validates `item_id` exists in `state.items`
3. If not found, returns `{:error, :item_not_found}`
4. If found, creates `ItemRemoved` event with current timestamp
5. Appends event to cart stream
6. Returns updated cart session

**Example**:
```elixir
alias Epoch.Slices.RemoveItem.{Command, CommandHandler}

# Success case
{:ok, session} = CommandHandler.handle(%Command{
  session_id: "abc-123",
  item_id: "espresso-blend-1234567890"
})

# Error case - item not in cart
{:error, :item_not_found} = CommandHandler.handle(%Command{
  session_id: "abc-123",
  item_id: "nonexistent-item"
})
```

---

## LiveComponent Contract

**Module**: `Epoch.Slices.RemoveItem.Component`

### Required Assigns

| Assign | Type | Description |
|--------|------|-------------|
| cart_session_id | String.t() | Cart session identifier |
| item_id | String.t() | Item identifier for removal |

### Events

**Outgoing** (to parent LiveView):
- `{:flash, :error, message}` - Sent when removal fails

### Render

Renders a remove button with:
- `id="remove-item-{item_id}"` for testing
- `phx-click="remove_from_cart"` event
- `phx-target={@myself}` to route to component

---

## PubSub Contract

**Topic**: `stream_type:cart`

**Message** (broadcast by EventStore on append):
```elixir
{:events_appended, stream_name, events}
```

Where:
- `stream_name` is `"cart-{session_id}"`
- `events` is list of `EventEnvelope` structs containing the appended events

**Handler** (in CartLive):
```elixir
def handle_info({:events_appended, _stream_name, _events}, socket) do
  # Reload cart state and update assigns
  {:noreply, load_cart_items(socket)}
end
```

---

## Error Messages

| Error Code | User-Facing Message | Log Level |
|------------|---------------------|-----------|
| `:item_not_found` | "Item not found in cart." | warning |
| `:not_found` | "Cart session not found." | error |
| Other | "Unable to remove item. Please try again." | error |
