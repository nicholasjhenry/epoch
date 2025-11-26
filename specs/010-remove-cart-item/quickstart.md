# Quickstart: Remove Item from Cart

**Feature**: 010-remove-cart-item
**Date**: 2025-11-26

## Prerequisites

- Elixir 1.15+ installed
- Project dependencies installed (`mix deps.get`)
- EventStore running (started automatically with application)

## Quick Verification

### 1. Start the Application

```bash
cd /Users/nicholas/Workspaces/professional/projects/epoch
mix phx.server
```

### 2. Manual Test Flow

1. Navigate to http://localhost:4000/products
2. Add 1-3 items to cart using "Add Item" buttons
3. Navigate to cart (click "Cart" in navbar)
4. Each item should show a "Remove" button
5. Click "Remove" on any item
6. Item should disappear immediately
7. Cart total should update
8. If removing last item, "Your cart is empty" should display

### 3. Run Tests

```bash
# Run all tests for this feature
mix test apps/epoch_web/test/epoch_web/slices/remove_item_test.exs

# Run with verbose output
mix test apps/epoch_web/test/epoch_web/slices/remove_item_test.exs --trace

# Run specific test by line number
mix test apps/epoch_web/test/epoch_web/slices/remove_item_test.exs:LINE
```

### 4. Key Files to Review

| File | Purpose |
|------|---------|
| `apps/epoch_web/lib/epoch_web/slices/remove_item/command.ex` | Command struct |
| `apps/epoch_web/lib/epoch_web/slices/remove_item/command_handler.ex` | Business logic |
| `apps/epoch_web/lib/epoch_web/slices/remove_item/component.ex` | Remove button UI |
| `apps/epoch_web/lib/epoch_web/live/cart_live.ex` | Cart page with PubSub subscription |
| `apps/epoch_web/lib/epoch_web/live/cart_live.html.heex` | Cart template with remove buttons |

### 5. Testing Error Cases

**Test item not found error**:
```elixir
# In IEx (iex -S mix)
alias Epoch.Slices.RemoveItem.{Command, CommandHandler}
alias Epoch.Cart

# Create a cart session
{:ok, session} = Cart.create_session(Ecto.UUID.generate())

# Try to remove non-existent item
{:error, :item_not_found} = CommandHandler.handle(%Command{
  session_id: session.session_id,
  item_id: "fake-item-id"
})
```

## Architecture Overview

```
User clicks "Remove" button
        │
        ▼
┌───────────────────────┐
│ RemoveItem.Component  │ (LiveComponent)
│ handle_event/3        │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ CommandHandler.handle │ (Business Logic)
│ - Get cart state      │
│ - Validate item exists│
│ - Append ItemRemoved  │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ EventStore            │
│ - Append event        │
│ - Broadcast to PubSub │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ CartLive              │ (LiveView)
│ - Receives broadcast  │
│ - Reloads cart state  │
│ - Updates UI          │
└───────────────────────┘
```

## Troubleshooting

### Remove button not appearing
- Check that `RemoveItem.Component` is rendered in cart template
- Verify `item_id` assign is passed to component

### Item not being removed
- Check browser console for JavaScript errors
- Verify PubSub subscription in CartLive mount
- Check EventStore logs for append errors

### Error flash not showing
- Verify parent LiveView handles `{:flash, :error, message}` info message
- Check that flash is being displayed in layout

### Real-time updates not working
- Verify `Phoenix.PubSub.subscribe` called in `mount/3` when `connected?(socket)`
- Check that `handle_info/2` pattern matches `{:events_appended, _, _}`
