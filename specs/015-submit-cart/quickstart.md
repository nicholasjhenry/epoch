# Quickstart: Submit Cart

**Feature**: 015-submit-cart  
**Date**: 2025-12-02

## Prerequisites

- Elixir 1.19+ / OTP 28+
- Running Phoenix server with EventStore started
- Existing cart session with items added
- Inventory set for products in cart

## Quick Test (Manual)

1. Start the application:
   ```bash
   cd /Users/nicholas/Workspaces/professional/projects/epoch
   iex -S mix phx.server
   ```

2. Open browser to `http://localhost:4000/products`

3. Add an item to cart (click "Add to Cart" on any product)

4. Navigate to cart page

5. In a separate terminal, set inventory for the product:
   ```elixir
   # In IEx
   Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 10)
   ```

6. Click "Submit Cart" button - should succeed

7. To test failure, set inventory to 0:
   ```elixir
   Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 0)
   ```

8. Add item again and try to submit - should show error

## Run Tests

```bash
# Run all tests for this feature
mix test apps/epoch/test/epoch/slices/submit_cart/
mix test apps/epoch_web/test/epoch_web/slices/submit_cart_test.exs

# Run with verbose output
mix test apps/epoch/test/epoch/slices/submit_cart/ --trace
```

## Key Files

| File | Purpose |
|------|---------|
| `apps/epoch/lib/epoch/cart/events/cart_submitted.ex` | CartSubmitted event struct |
| `apps/epoch_web/lib/epoch_web/slices/submit_cart/command.ex` | SubmitCart command struct |
| `apps/epoch_web/lib/epoch_web/slices/submit_cart/command_handler.ex` | Business logic |
| `apps/epoch_web/lib/epoch_web/slices/submit_cart/inventories_view.ex` | Slice-local inventory read model |
| `apps/epoch_web/lib/epoch_web/slices/submit_cart/component.ex` | LiveComponent UI |
| `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex` | Parent LiveView (modified) |

## IEx Exploration

```elixir
# Create a cart session
session_id = Ecto.UUID.generate()
{:ok, _} = Epoch.Cart.create_session(session_id)

# Add an item
{:ok, _} = Epoch.Cart.add_item(session_id, "espresso-blend")

# Check cart state
{:ok, cart} = Epoch.Cart.get_cart_items(session_id)
IO.inspect(cart.items, label: "Cart Items")

# Set inventory
{:ok, _} = Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 10)

# Check inventory
{:ok, qty} = Epoch.Backoffice.Inventory.get_quantity("espresso-blend")
IO.inspect(qty, label: "Inventory")

# Submit cart (via command handler)
alias Epoch.Slices.SubmitCart.{Command, CommandHandler}
cmd = %Command{session_id: session_id}
result = CommandHandler.handle(cmd)
IO.inspect(result, label: "Submit Result")

# Verify CartSubmitted event
{:ok, %{events: events}} = Epoch.EventStore.read_stream("cart-#{session_id}")
events |> Enum.map(& &1.__struct__) |> IO.inspect(label: "Event Types")
```

## Common Issues

### "Cart is empty" error when cart has items
- Items may have been removed or archived
- Check cart state with `Cart.get_cart_items/1`

### "Cannot order products without quantity" error
- Product has no inventory record or inventory is 0
- Set inventory with `Inventory.update_quantity/2`

### Button not appearing
- Ensure cart has items (not empty state)
- Check component is correctly mounted in LiveView

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    CartItems LiveView                     │
│  ┌─────────────────────┐  ┌──────────────────────────┐   │
│  │  Cart Items Table   │  │  Actions                 │   │
│  │  - Product Name     │  │  ┌────────────────────┐  │   │
│  │  - Price            │  │  │ Submit Cart Button │  │   │
│  │  - Inventory        │  │  └────────────────────┘  │   │
│  │  - Remove Button    │  │  ┌────────────────────┐  │   │
│  └─────────────────────┘  │  │ Clear Cart Button  │  │   │
│                           │  └────────────────────┘  │   │
│                           └──────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────┐
│              SubmitCart.CommandHandler                    │
│  1. Read cart items from EventStore                      │
│  2. Validate cart not empty                              │
│  3. Build inventory map via InventoriesView (slice-local)│
│  4. Validate all products have inventory > 0             │
│  5. Append CartSubmitted event                           │
└──────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┴────────────────────┐
         ▼                                         ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│   InventoriesView       │    │      EventStore         │
│   (slice-local)         │    │  cart-{id}: [...]       │
│   Projects inventory    │    │  inventory-{id}: [...]  │
│   events for validation │    └─────────────────────────┘
└─────────────────────────┘
```

**Note**: `InventoriesView` is a slice-local read model that does NOT call `Epoch.Backoffice.Inventory`. This maintains vertical slice isolation.

## Reference Implementation

The design is based on `implementing-eventsourcing/app/slices/submitcart/`:
- `commandHandler.ts` - Command handling logic
- `SubmitCartTests.tsx` - Test scenarios
- `InventoriesStateView.ts` - Inventory projection
