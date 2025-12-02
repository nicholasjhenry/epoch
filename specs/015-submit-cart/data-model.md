# Data Model: Submit Cart

**Feature**: 015-submit-cart  
**Date**: 2025-12-02

## Entities

### CartSubmitted Event (NEW)

The core event emitted when a cart is successfully submitted.

**Module**: `Epoch.Cart.Events.CartSubmitted`  
**Location**: `apps/epoch/lib/epoch/cart/events/cart_submitted.ex`

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `cart_id` | `String.t()` | Unique identifier for the cart session | Yes |
| `submitted_at` | `DateTime.t()` | UTC timestamp of submission | Yes |

**Validation Rules**:
- `cart_id` must be a non-empty string (UUID format)
- `submitted_at` must be a valid UTC DateTime

**State Transitions**:
- Cart with active items → Submitted cart
- A submitted cart cannot be modified (future: add CartReopened event if needed)

### SubmitCart Command (NEW)

Command struct representing the intent to submit a cart.

**Module**: `Epoch.Slices.SubmitCart.Command`  
**Location**: `apps/epoch_web/lib/epoch_web/slices/submit_cart/command.ex`

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `session_id` | `String.t()` | Cart session identifier | Yes |

### SubmitCart InventoriesView (NEW)

Slice-local read model for inventory validation during cart submission. Projects InventoryUpdated events into a map of product quantities.

**Module**: `Epoch.Slices.SubmitCart.InventoriesView`  
**Location**: `apps/epoch_web/lib/epoch_web/slices/submit_cart/inventories_view.ex`

| Field | Type | Description |
|-------|------|-------------|
| state | `%{String.t() => non_neg_integer()}` | Map of product_id to quantity |

**Design Rationale**:
- Dedicated read model avoids coupling to `Epoch.Backoffice.Inventory` context
- Follows vertical slice architecture - each slice owns its read models
- Matches reference implementation pattern from `implementing-eventsourcing`

**Events Handled**:
| Event | Action |
|-------|--------|
| `InventoryUpdated` | `Map.put(state, product_id, quantity)` |

**How Events Are Read**:
The InventoriesView does NOT subscribe to PubSub. Instead, the CommandHandler reads inventory events on-demand from the EventStore when validating a cart submission:

```elixir
# In CommandHandler - for each product_id in cart:
stream_name = EventStore.stream_name("inventory", product_id)
{:ok, %{events: events}} = EventStore.read_stream(stream_name)

# Project events through InventoriesView to get current quantity
inventory_state = Enum.reduce(events, InventoriesView.initial_state(), &InventoriesView.evolve(&2, &1))
quantity = InventoriesView.get_quantity(inventory_state, product_id)
```

This ensures the command handler always validates against the **current** inventory state at submission time.

**Usage**: Command handler reads inventory streams for each product in cart, projects events through this view, then validates each product has quantity > 0.

### Existing Entities (Referenced)

#### CartItemsView State

Read model for current cart items state.

**Module**: `Epoch.Cart.CartItemsView`  
**Location**: `apps/epoch/lib/epoch/cart/cart_items_view.ex`

| Field | Type | Description |
|-------|------|-------------|
| `items` | `[cart_item()]` | List of active cart items |
| `total` | `float()` | Sum of item prices |

Where `cart_item()` is:
| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String.t()` | Unique item identifier |
| `product_id` | `String.t()` | Product reference |
| `name` | `String.t()` | Product name (denormalized) |
| `price` | `float()` | Item price (denormalized) |

#### InventoryState (NOT USED - for reference only)

Read model for product inventory in Backoffice context.

**Module**: `Epoch.Backoffice.InventoryState`  
**Location**: `apps/epoch/lib/epoch/backoffice/inventory_state.ex`

**Note**: This module is NOT used by SubmitCart to maintain slice isolation. The SubmitCart slice uses its own `InventoriesView` instead.

| Field | Type | Description |
|-------|------|-------------|
| `product_id` | `String.t() \| nil` | Product identifier |
| `quantity` | `non_neg_integer()` | Current inventory quantity |

## Event Streams

### Cart Stream

**Pattern**: `cart-{cart_id}`  
**Events**: CartCreated, ItemAdded, ItemRemoved, ItemArchived, CartCleared, **CartSubmitted** (NEW)

### Inventory Stream

**Pattern**: `inventory-{product_id}`  
**Events**: InventoryUpdated

## Relationships

```
┌─────────────────────┐
│   Cart Session      │
│   (cart-{id})       │
├─────────────────────┤
│ CartCreated         │
│ ItemAdded*          │──────┐
│ ItemRemoved*        │      │
│ ItemArchived*       │      │
│ CartCleared*        │      │
│ CartSubmitted       │      │
└─────────────────────┘      │
                             │ references
                             ▼
┌─────────────────────┐    ┌─────────────────────┐
│   Product           │◄───│   Inventory         │
│   (catalog)         │    │   (inventory-{id})  │
├─────────────────────┤    ├─────────────────────┤
│ id, name, price     │    │ InventoryUpdated*   │
└─────────────────────┘    └─────────────────────┘
```

## Command Handler Flow

```
SubmitCart Command
       │
       ▼
┌──────────────────────────────────────────┐
│ 1. Read cart stream                       │
│    EventStore.read_stream("cart-{id}")   │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 2. Project to CartItemsView               │
│    Get active items (excluding removed/   │
│    archived)                              │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 3. Validate cart not empty               │
│    Return {:error, :cart_empty} if empty │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 4. Build inventory map using              │
│    InventoriesView (slice-local)         │
│    For each product_id in cart:          │
│    - Read inventory-{product_id} stream  │
│    - Project via InventoriesView.evolve  │
│    - Result: %{product_id => quantity}   │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 5. Validate all products have inventory  │
│    Check inventory[product_id] > 0       │
│    Return {:error, {:insufficient_       │
│    inventory, product_ids}} if any == 0  │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 6. Append CartSubmitted event            │
│    EventStore.append_to_stream(          │
│      "cart-{id}", [%CartSubmitted{}])    │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ 7. Return {:ok, cart_state}              │
└──────────────────────────────────────────┘
```

## Error States

| Error | Atom | Description |
|-------|------|-------------|
| Empty Cart | `:cart_empty` | No active items in cart |
| Insufficient Inventory | `{:insufficient_inventory, [product_id]}` | One or more products have 0 inventory |
| Persistence Failed | `:persistence_failed` | EventStore append failed |

## Typespecs

```elixir
# CartSubmitted Event
@type t :: %CartSubmitted{
  cart_id: String.t(),
  submitted_at: DateTime.t()
}

# SubmitCart Command
@type t :: %Command{
  session_id: String.t()
}

# InventoriesView State (NEW - slice-local)
@type state :: %{String.t() => non_neg_integer()}

# InventoriesView.evolve/2
@spec evolve(state(), InventoryUpdated.t()) :: state()

# InventoriesView.get_quantity/2
@spec get_quantity(state(), String.t()) :: non_neg_integer()

# CommandHandler.handle/1
@spec handle(Command.t()) :: 
  {:ok, CartItemsView.state()} | 
  {:error, :cart_empty | {:insufficient_inventory, [String.t()]} | term()}
```
