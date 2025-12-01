# Quickstart: Display Cart Item Inventory

**Feature**: 013-cart-item-inventory
**Date**: 2025-11-27

## Prerequisites

- Elixir 1.19+ installed
- Project dependencies installed (`mix deps.get`)
- EventStore running (started with application)

## Quick Verification

### 1. Start the Application

```bash
cd /Users/nicholas/Workspaces/professional/projects/epoch
iex -S mix phx.server
```

### 2. Add Products to Cart

1. Navigate to http://localhost:4000/products
2. Click "Add Item" on any product
3. Navigate to http://localhost:4000/cart

### 3. Set Inventory via Backoffice

1. Open a new terminal
2. Run IEx session:

```bash
iex -S mix
```

3. Update inventory for a product:

```elixir
# Get a product ID from the catalog
{:ok, products} = Epoch.Catalog.list_products()
product = hd(products)

# Set inventory quantity
Epoch.Backoffice.Inventory.update_quantity(product.id, 10)
```

### 4. Verify Display

1. Return to cart page (http://localhost:4000/cart)
2. Each cart item should display "10 available" (or the quantity you set)

### 5. Test Real-time Updates

With the cart page open in browser:

```elixir
# In IEx session, update inventory
Epoch.Backoffice.Inventory.update_quantity(product.id, 3)
```

Cart page should update to show "3 available" with low-stock styling.

```elixir
# Set to zero
Epoch.Backoffice.Inventory.update_quantity(product.id, 0)
```

Cart page should show "Out of stock" indicator.

## Test Commands

### Run All Tests

```bash
mix test
```

### Run Feature Tests Only

```bash
mix test apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs
```

### Run with Coverage

```bash
mix test --cover
```

## Development Workflow

### 1. Write Failing Tests First

```bash
# Create test file
touch apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs

# Run tests (should fail - no implementation yet)
mix test apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs
```

### 2. Implement Nested LiveView

```bash
# Create slice directory and file
mkdir -p apps/epoch_web/lib/epoch_web/slices/cart_item_inventory
touch apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex
```

### 3. Update CartItemsView

Add `product_id` to cart item structure in:
`apps/epoch/lib/epoch/cart/cart_items_view.ex`

### 4. Embed Nested LiveView in CartItems.Live

Update template in:
`apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex`

### 5. Run Precommit Checks

```bash
mix precommit
```

## Key Files

| File | Purpose |
|------|---------|
| `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex` | NEW: Nested LiveView for inventory display |
| `apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex` | MODIFY: Embed nested inventory LiveView |
| `apps/epoch/lib/epoch/cart/cart_items_view.ex` | MODIFY: Add product_id to items |
| `apps/epoch_web/test/epoch_web/slices/cart_item_inventory_test.exs` | NEW: Feature tests |

## Troubleshooting

### Inventory Not Displaying

1. Check that `product_id` is included in cart item assigns
2. Verify PubSub subscription in component logs
3. Check EventStore for inventory stream:

```elixir
Epoch.EventStore.debug_all_streams()
# Should include "inventory-{product_id}" streams
```

### Real-time Updates Not Working

1. Verify Phoenix PubSub is running
2. Check browser console for LiveView connection
3. Inspect PubSub messages:

```elixir
# In IEx, subscribe to topic
Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:inventory")

# Update inventory and check for messages
Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 5)
# Should receive {:events_appended, "inventory-espresso-blend", [...]}
```

### Nested LiveView Not Rendering

1. Ensure LiveView is properly embedded with required session:
   - `id` (unique per instance)
   - `session: %{"product_id" => item.product_id}`
2. Check for compilation errors in LiveView module
