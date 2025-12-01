# Quickstart: Price Change TODO List & Automation

**Feature**: 014-price-change-automation  
**Date**: 2025-12-01

## Prerequisites

- Elixir 1.19.2+ / OTP 28+
- Phoenix 1.8.1 with LiveView
- Running Epoch application (`mix phx.server`)
- Existing cart with items for testing

## Quick Test Flow

### 1. Start the Application

```bash
cd /Users/nicholas/Workspaces/professional/projects/epoch
mix deps.get
mix phx.server
```

### 2. Create a Cart with Items

```elixir
# In IEx console (iex -S mix phx.server)

# Create a cart session
session_id = Ecto.UUID.generate()
{:ok, _} = Epoch.Cart.create_session(session_id)

# Add some items
{:ok, _} = Epoch.Cart.add_item(session_id, "espresso-blend")
{:ok, _} = Epoch.Cart.add_item(session_id, "french-roast")

# Verify items are in cart
{:ok, session} = Epoch.Cart.get_session(session_id)
IO.inspect(session.items)
```

### 3. Trigger a Price Change

```elixir
# Change price of espresso-blend
{:ok, event} = Epoch.Backoffice.Price.change_price(%{
  product_id: "espresso-blend",
  new_price: Decimal.new("15.99")
})

IO.puts("Price changed: #{event.product_id} from #{event.old_price} to #{event.new_price}")
```

### 4. Verify Automation Triggered

```elixir
# Check if archive requests were created
{:ok, %{events: events}} = Epoch.EventStore.read_stream("cart-#{session_id}")

archive_requests = Enum.filter(events, fn e ->
  match?(%Epoch.Cart.Events.ItemArchiveRequested{}, e.event)
end)

IO.puts("Archive requests created: #{length(archive_requests)}")
```

### 5. Verify Items Archived

```elixir
# Check cart items view
{:ok, cart_view} = Epoch.Cart.get_cart_items(session_id)

IO.puts("Remaining items in cart: #{length(cart_view.items)}")
# Should show french-roast only (espresso-blend was archived)
```

## UI Testing Flow

### 1. Open Backoffice

Navigate to: `http://localhost:4000/backoffice/inventory`

### 2. Change a Price

1. Select a product from the dropdown
2. Enter new price
3. Click "Update Price"

### 3. View Cart Impact

Navigate to: `http://localhost:4000/cart/{session_id}`

- Items affected by price change should be removed
- Cart total should be recalculated

### 4. View Event Stream

Navigate to: `http://localhost:4000/dev/events`

- See `PriceChanged` event in price stream
- See `ItemArchiveRequested` events in cart streams
- See `ItemArchived` events in cart streams

## Common Scenarios

### Scenario: Price Change with No Affected Carts

```elixir
# Change price for product not in any cart
{:ok, _} = Epoch.Backoffice.Price.change_price(%{
  product_id: "dark-roast",
  new_price: Decimal.new("12.99")
})

# No archive requests created (product not in any cart)
```

### Scenario: Price Change Affecting Multiple Carts

```elixir
# Create multiple carts with same product
cart1 = Ecto.UUID.generate()
cart2 = Ecto.UUID.generate()

{:ok, _} = Epoch.Cart.create_session(cart1)
{:ok, _} = Epoch.Cart.create_session(cart2)

{:ok, _} = Epoch.Cart.add_item(cart1, "espresso-blend")
{:ok, _} = Epoch.Cart.add_item(cart2, "espresso-blend")

# Change price
{:ok, _} = Epoch.Backoffice.Price.change_price(%{
  product_id: "espresso-blend",
  new_price: Decimal.new("16.99")
})

# Both carts should have archive requests
```

### Scenario: Multiple Price Changes

```elixir
# Multiple price changes in succession
{:ok, _} = Epoch.Backoffice.Price.change_price(%{
  product_id: "espresso-blend",
  new_price: Decimal.new("15.99")
})

# Second price change
{:ok, _} = Epoch.Backoffice.Price.change_price(%{
  product_id: "espresso-blend",
  new_price: Decimal.new("14.99")
})

# Already-archived items are not re-processed
```

## Debugging

### Check Read Model State

```elixir
# Products with price changes
state = Epoch.Backoffice.ProductsWithPriceChanges.build()
IO.inspect(state)

# Carts with products
state = Epoch.Cart.CartsWithProducts.build()
IO.inspect(state)

# Items pending archive
state = Epoch.Cart.ItemsToArchive.build()
IO.inspect(state)
```

### Check Event Streams

```elixir
# All price events
{:ok, %{events: events}} = Epoch.EventStore.read_by_stream_type("price")
IO.inspect(events)

# All cart events for specific cart
{:ok, %{events: events}} = Epoch.EventStore.read_stream("cart-#{session_id}")
IO.inspect(events)

# All events globally (paginated)
{:ok, %{events: events}} = Epoch.EventStore.read_all_events(page_size: 50)
IO.inspect(events)
```

### Check Processor Status

```elixir
# Verify processor is running
Process.whereis(Epoch.Automation.PriceChangeProcessor)
# Should return PID, not nil
```

## Test Commands

```bash
# Run all tests
mix test

# Run feature-specific tests
mix test test/epoch/backoffice/price_test.exs
mix test test/epoch/cart/carts_with_products_test.exs
mix test test/epoch/cart/items_to_archive_test.exs
mix test test/epoch/automation/price_change_processor_test.exs

# Run with verbose output
mix test --trace

# Run specific test
mix test test/epoch/automation/price_change_processor_test.exs:42
```

## Key Modules

| Module | Purpose |
|--------|---------|
| `Epoch.Backoffice.Price` | Price change command handler |
| `Epoch.Backoffice.ProductsWithPriceChanges` | Price changes read model |
| `Epoch.Cart.CartsWithProducts` | Cart-product mapping read model |
| `Epoch.Cart.ItemsToArchive` | TODO list read model |
| `Epoch.Automation.PriceChangeProcessor` | Automation that triggers archives |
| `EpochWeb.Backoffice.PriceLive` | Backoffice UI for price changes |

## Configuration

No additional configuration required. Uses existing:

- `Epoch.EventStore` for event persistence
- `Epoch.PubSub` for event broadcasting
- `Epoch.Catalog` for product validation
