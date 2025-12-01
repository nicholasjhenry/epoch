# Contracts: Display Cart Item Inventory

**Feature**: 013-cart-item-inventory
**Date**: 2025-11-27

## API Contracts

This feature does not introduce new public APIs. It consumes existing APIs:

### Consumed APIs

#### 1. Epoch.Backoffice.Inventory.get_quantity/1

```elixir
@spec get_quantity(String.t()) :: {:ok, non_neg_integer()}
```

**Purpose**: Retrieve current inventory quantity for a product.
**Input**: `product_id` - String identifying the product
**Output**: `{:ok, quantity}` where quantity is a non-negative integer

#### 2. Phoenix.PubSub.subscribe/2

```elixir
Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:inventory")
```

**Purpose**: Subscribe to inventory event notifications.
**Topic**: `"stream_type:inventory"`
**Message Format**: `{:events_appended, stream_name, events}`

### Internal Component Contract

#### CartItemInventory.Live (Nested LiveView)

```elixir
# Required session params from parent
%{
  "product_id" => String.t()    # Product to display inventory for
}

# Example usage in parent template
<%= live_render(@socket, Epoch.Slices.CartItemInventory.Live,
      id: "inventory-#{item.product_id}",
      session: %{"product_id" => item.product_id}) %>
```

## Event Contracts

### InventoryUpdated (Existing)

```elixir
%Epoch.Backoffice.Events.InventoryUpdated{
  product_id: String.t(),      # Product identifier
  quantity: non_neg_integer(), # New absolute quantity
  updated_at: DateTime.t()     # When the update occurred
}
```

**Stream**: `inventory-{product_id}`
**Broadcast Topic**: `stream_type:inventory`
