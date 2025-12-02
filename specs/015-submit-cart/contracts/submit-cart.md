# Contract: Submit Cart

**Feature**: 015-submit-cart  
**Date**: 2025-12-02

## Overview

This contract defines the interface for submitting a shopping cart. The operation validates inventory availability for all active cart items before completing the submission.

## Command Interface

### SubmitCart Command

**Module**: `Epoch.Slices.SubmitCart.Command`

```elixir
%Epoch.Slices.SubmitCart.Command{
  session_id: String.t()  # Required: Cart session identifier (UUID)
}
```

### CommandHandler

**Module**: `Epoch.Slices.SubmitCart.CommandHandler`

```elixir
@spec handle(Command.t()) :: 
  {:ok, CartItemsView.state()} | 
  {:error, error_reason()}

@type error_reason :: 
  :cart_empty | 
  {:insufficient_inventory, [String.t()]} | 
  :persistence_failed
```

## Event Contract

### CartSubmitted Event

**Module**: `Epoch.Cart.Events.CartSubmitted`  
**Stream**: `cart-{cart_id}`

```elixir
%Epoch.Cart.Events.CartSubmitted{
  cart_id: String.t(),      # Cart session that was submitted
  submitted_at: DateTime.t() # UTC timestamp of submission
}
```

## LiveView Interface

### SubmitCart Component

**Module**: `Epoch.Slices.SubmitCart.Component`

**Assigns Required**:
| Assign | Type | Description |
|--------|------|-------------|
| `cart_session_id` | `String.t()` | Cart session to submit |

**Events Handled**:
| Event | Source | Description |
|-------|--------|-------------|
| `"submit_cart"` | Button click | Triggers cart submission |

**Messages Sent to Parent**:
| Message | Condition | Description |
|---------|-----------|-------------|
| `{:flash, :info, message}` | Success | Submission success notification |
| `{:flash, :error, message}` | Failure | Error notification |

## Success Response

When cart submission succeeds:

```elixir
{:ok, %{
  items: [],  # Items remain in state but cart is "submitted"
  total: 0.0
}}
```

**Side Effects**:
1. CartSubmitted event appended to cart stream
2. PubSub broadcast on `stream_type:cart` topic
3. UI receives real-time update

## Error Responses

### Empty Cart

```elixir
{:error, :cart_empty}
```

**Condition**: Cart has no active items (all removed, archived, or cleared)

**UI Message**: "Your cart is empty"

### Insufficient Inventory

```elixir
{:error, {:insufficient_inventory, ["product-id-1", "product-id-2"]}}
```

**Condition**: One or more products have quantity = 0 in inventory

**UI Message**: "Cannot order products without quantity" (matches reference implementation)

### Persistence Failed

```elixir
{:error, :persistence_failed}
```

**Condition**: EventStore append operation failed

**UI Message**: "Unable to submit cart. Please try again."

## Validation Rules

1. **Cart Not Empty**: At least one active item must exist in the cart
2. **Inventory Available**: Each product in cart must have `quantity > 0` in its inventory stream
3. **No Inventory Record = Zero**: Products without any InventoryUpdated events are treated as having quantity 0

## Sequence Diagram

```
User          Component       CommandHandler      Cart       InventoriesView   EventStore
 │                │                 │               │               │              │
 │  Click Submit  │                 │               │               │              │
 │───────────────>│                 │               │               │              │
 │                │  handle(cmd)    │               │               │              │
 │                │────────────────>│               │               │              │
 │                │                 │ get_cart_items│               │              │
 │                │                 │──────────────>│               │              │
 │                │                 │    {:ok, state}               │              │
 │                │                 │<──────────────│               │              │
 │                │                 │               │               │              │
 │                │                 │ [for each product_id]         │              │
 │                │                 │─────────────────────────────────────────────>│
 │                │                 │    read_stream("inventory-{product_id}")    │
 │                │                 │<─────────────────────────────────────────────│
 │                │                 │               │               │              │
 │                │                 │ project via InventoriesView   │              │
 │                │                 │───────────────────────────────>│              │
 │                │                 │    evolve/2 -> %{id => qty}   │              │
 │                │                 │<───────────────────────────────│              │
 │                │                 │               │               │              │
 │                │                 │ [if all inventory > 0]        │              │
 │                │                 │─────────────────────────────────────────────>│
 │                │                 │    append_to_stream(CartSubmitted)          │
 │                │                 │<─────────────────────────────────────────────│
 │                │                 │               │               │              │
 │                │  {:ok, state}   │               │               │              │
 │                │<────────────────│               │               │              │
 │                │                 │               │               │              │
 │  Flash: Success│                 │               │               │              │
 │<───────────────│                 │               │               │              │
```

**Note**: `InventoriesView` is a slice-local read model that projects InventoryUpdated events. It does NOT call the Backoffice.Inventory context.

## Integration Points

| Integration | Direction | Purpose |
|-------------|-----------|---------|
| `Epoch.Cart.get_cart_items/1` | Read | Get current active cart items |
| `Epoch.Slices.SubmitCart.InventoriesView` | Read | Slice-local inventory projection (NOT Backoffice.Inventory) |
| `Epoch.EventStore.read_stream/2` | Read | Read inventory streams for each product |
| `Epoch.EventStore.append_to_stream/3` | Write | Persist CartSubmitted event |
| `Phoenix.PubSub` | Broadcast | Notify subscribers of cart change |

**Note**: The `InventoriesView` is a dedicated read model within the submit_cart slice to avoid coupling with the `Epoch.Backoffice.Inventory` context. This follows vertical slice architecture principles.

## Testing Contract

### Unit Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Submit with inventory | Cart with item, inventory > 0 | `{:ok, state}` + CartSubmitted event |
| Submit empty cart | Cart with no items | `{:error, :cart_empty}` |
| Submit without inventory | Cart with item, inventory = 0 | `{:error, {:insufficient_inventory, [id]}}` |
| Submit no inventory record | Cart with item, no inventory events | `{:error, {:insufficient_inventory, [id]}}` |
| Submit after item removed | Cart with removed item | `{:error, :cart_empty}` or success if other items |
| Submit after item archived | Cart with archived item | `{:error, :cart_empty}` or success if other items |

### Integration Test Cases

| Test | Setup | Action | Verification |
|------|-------|--------|--------------|
| End-to-end success | Add item, set inventory > 0 | Click submit | CartSubmitted in stream, UI updates |
| End-to-end failure | Add item, set inventory = 0 | Click submit | Error flash, no CartSubmitted event |
