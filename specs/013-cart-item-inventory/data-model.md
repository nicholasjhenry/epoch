# Data Model: Display Cart Item Inventory

**Feature**: 013-cart-item-inventory
**Date**: 2025-11-27

## Entities

### 1. Cart Item (Extended)

**Purpose**: Represents a line item in the cart display, now including product_id for inventory lookup.

**Location**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

**Current Structure**:
```elixir
@type cart_item :: %{
  item_id: String.t(),
  name: String.t(),
  price: float()
}
```

**Extended Structure**:
```elixir
@type cart_item :: %{
  item_id: String.t(),
  product_id: String.t(),   # NEW: Required for inventory lookup
  name: String.t(),
  price: float()
}
```

**Validation Rules**:
- `item_id`: Required, non-empty string (format: `{product_id}-{timestamp}`)
- `product_id`: Required, non-empty string (references catalog product)
- `name`: Required, non-empty string
- `price`: Required, non-negative float

**State Transitions**: N/A (read model projected from events)

### 2. Inventory Display State

**Purpose**: Nested LiveView state for rendering inventory in cart item row.

**Location**: `apps/epoch_web/lib/epoch_web/slices/cart_item_inventory/live.ex`

**Structure**:
```elixir
@type inventory_state :: non_neg_integer() | :unknown

# Socket assigns
%{
  product_id: String.t(),       # From parent component
  inventory: inventory_state(), # Current quantity or :unknown
  subscribed: boolean()         # PubSub subscription tracking
}
```

**Display States**:
| State | Condition | Display |
|-------|-----------|---------|
| Normal | `quantity > 5` | `"{quantity} available"` |
| Low Stock | `0 < quantity <= 5` | `"{quantity} available"` (warning style) |
| Out of Stock | `quantity == 0` | `"Out of stock"` (error style) |
| Unknown | `:unknown` | `"Unknown"` (muted style) |

### 3. Inventory Updated Event (Existing)

**Purpose**: Event emitted when inventory quantity changes.

**Location**: `apps/epoch/lib/epoch/backoffice/events/inventory_updated.ex`

**Structure** (unchanged):
```elixir
@type t :: %__MODULE__{
  product_id: String.t(),
  quantity: non_neg_integer(),
  updated_at: DateTime.t()
}

defstruct [:product_id, :quantity, :updated_at]
```

**Validation Rules**:
- `product_id`: Required, must reference existing catalog product
- `quantity`: Required, non-negative integer
- `updated_at`: Required, UTC datetime

## Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                      CartItems.Live                          │
│  (Nested LiveView - subscribes to stream_type:cart)         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                    Cart Item Row                     │   │
│   │  ┌──────────┐  ┌─────────┐  ┌────────────────────┐  │   │
│   │  │  Name    │  │  Price  │  │ CartItemInventory  │  │   │
│   │  │          │  │         │  │      .Live         │  │   │
│   │  │          │  │         │  │  (nested LiveView) │  │   │
│   │  └──────────┘  └─────────┘  └────────────────────┘  │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                              │
│   (repeated for each cart item)                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ PubSub: stream_type:inventory
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      EventStore                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ inventory-{product_id} stream                        │    │
│  │  └─► InventoryUpdated events                        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ aggregate_stream/4
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               Epoch.Backoffice.Inventory                     │
│  get_quantity(product_id) → {:ok, quantity}                 │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Initial Load (on nested LiveView mount)

```
1. CartItems.Live renders cart items from CartItemsView
2. For each item, embeds CartItemInventory.Live via live_render with product_id in session
3. CartItemInventory.Live.mount/3 is called (separate process):
   a. Subscribe to "stream_type:inventory" PubSub topic
   b. Call Inventory.get_quantity(product_id)
   c. Assign inventory quantity to socket
4. Nested LiveView renders inventory display
```

### Real-time Update (on inventory change)

```
1. Backoffice updates inventory via Inventory.update_quantity/2
2. EventStore appends InventoryUpdated event to inventory-{product_id}
3. EventStore broadcasts to "stream_type:inventory":
   {:events_appended, "inventory-{product_id}", [%EventEnvelope{event: %InventoryUpdated{...}}]}
4. ALL CartItemInventory.Live instances receive message in their handle_info/2
5. Each nested LiveView filters events by event.product_id == socket.assigns.product_id
   (matches InventoriesStateView.ts pattern from reference)
6. Matching LiveView extracts new quantity from filtered event(s)
7. Nested LiveView re-renders with updated inventory
```

**Key Pattern**: The `stream_type:inventory` topic is a single topic that receives events from ALL `inventory-{product_id}` streams. Each widget instance receives ALL inventory events but only processes events where `event.product_id` matches its own `product_id` assign. This mirrors the TypeScript reference implementation in `InventoriesStateView.ts`.

## Schema Changes Required

### CartItemsView Modification

**File**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

**Change**: Add `product_id` to cart item structure in `evolve/2`

```elixir
# Current
def evolve(state, %ItemAdded{item_id: id, name: name, price: price}) do
  item = %{item_id: id, name: name, price: price}
  %{state | items: state.items ++ [item], total: state.total + price}
end

# Updated
def evolve(state, %ItemAdded{item_id: id, product_id: product_id, name: name, price: price}) do
  item = %{item_id: id, product_id: product_id, name: name, price: price}
  %{state | items: state.items ++ [item], total: state.total + price}
end
```

**Type Update**:
```elixir
@type cart_item :: %{
  item_id: String.t(),
  product_id: String.t(),  # Added
  name: String.t(),
  price: float()
}
```

## No Database Migrations Required

This feature:
- Uses existing in-memory EventStore
- Reads from existing inventory streams
- No persistent storage changes
- No new Ecto schemas
