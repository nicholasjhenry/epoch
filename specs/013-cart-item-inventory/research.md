# Research: Display Cart Item Inventory

**Feature**: 013-cart-item-inventory
**Date**: 2025-11-27

## Research Tasks Completed

### 1. Vertical Slice Architecture Pattern

**Decision**: Follow existing slice pattern with nested LiveView for per-item inventory display

**Rationale**:
- Existing slices (`add_item`, `remove_item`, `clear_cart`, `cart_items`) use command/component/handler structure
- `CartItems.Live` is a nested LiveView that subscribes to `stream_type:cart` for real-time updates
- New `CartItemInventory.Live` will be a nested LiveView embedded in `CartItems.Live`
- Nested LiveView required because LiveComponents cannot have their own `handle_info/2` for PubSub messages
- Each inventory widget needs to independently subscribe and receive real-time updates

**Alternatives Considered**:
- LiveComponent: Rejected - cannot receive PubSub messages in its own `handle_info/2` (runs in parent process)
- Single component fetching all inventory: Rejected - doesn't match reference pattern, harder to maintain

**Reference Implementation**:
```typescript
// tmp/course-implementing-eventsourcing/app/slices/inventory/Inventories.tsx
export default function Inventories(props: { productId: string }) {
    const [inventory, setInventory] = useState<number>(0)
    
    useEffect(() => {
        let subscription = subscribeStream(Streams.Inventory, (nextExpectedStreamVersion, events) => {
            setInventory((prevState) => {
                return inventoriesStateView(prevState, events, {productId: props.productId})
            })
        })
        return () => unsubscribeStream(Streams.Inventory, subscription)
    }, []);
    
    return <div className="tag is-light is-info">Available: {inventory}</div>
}
```

### 2. PubSub Topic Pattern for Inventory Events

**Decision**: Subscribe to `stream_type:inventory` topic

**Rationale**:
- EventStore already broadcasts to `stream_type:{type}` when events are appended (see `event_store.ex:364-372`)
- Inventory events are appended to streams named `inventory-{product_id}`
- `extract_stream_type/1` extracts "inventory" from "inventory-{product_id}"
- Message format: `{:events_appended, stream_name, events}`

**Code Evidence**:
```elixir
# apps/epoch/lib/epoch/event_store.ex:364-372
defp broadcast_to_stream_type(stream_name, events) do
  stream_type = extract_stream_type(stream_name)
  topic = "stream_type:#{stream_type}"
  
  Phoenix.PubSub.broadcast(
    Epoch.PubSub,
    topic,
    {:events_appended, stream_name, events}
  )
end
```

### 3. Inventory Context API

**Decision**: Use existing `Epoch.Backoffice.Inventory.get_quantity/1`

**Rationale**:
- API already exists and returns `{:ok, non_neg_integer()}`
- Reads from event-sourced stream `inventory-{product_id}`
- Returns 0 for non-existent streams (via `InventoryState.initial_state()`)

**API Signature**:
```elixir
@spec get_quantity(String.t()) :: {:ok, non_neg_integer()}
def get_quantity(product_id) do
  {:ok, state} = get_state(product_id)
  {:ok, state.quantity}
end
```

### 4. Event Structure for Inventory Updates

**Decision**: Handle `Epoch.Backoffice.Events.InventoryUpdated` events

**Rationale**:
- Single event type for inventory changes (absolute quantity, not delta)
- Contains `product_id`, `quantity`, `updated_at`
- StateView pattern filters events by product_id

**Event Structure**:
```elixir
defmodule Epoch.Backoffice.Events.InventoryUpdated do
  @type t :: %__MODULE__{
          product_id: String.t(),
          quantity: non_neg_integer(),
          updated_at: DateTime.t()
        }
  defstruct [:product_id, :quantity, :updated_at]
end
```

### 5. Cart Item Data Structure

**Decision**: Extend cart item display to include `product_id` for inventory lookup

**Rationale**:
- `CartItemsView` currently returns `%{item_id, name, price}` per item
- `item_id` format is `{product_id}-{timestamp}` but product_id should be explicit
- Need to add `product_id` to cart item for inventory component

**Current Structure**:
```elixir
# From ItemAdded event handling in CartItemsView
item = %{item_id: id, name: name, price: price}
```

**Required Change**: Add `product_id` to cart item structure in `CartItemsView.evolve/2`

### 6. Nested LiveView PubSub Subscription Pattern

**Decision**: Use nested LiveView with PubSub subscription in `mount/3`, filter events by `product_id` in `handle_info/2`

**Rationale**:
- Nested LiveViews run as separate processes with their own lifecycle
- Each instance has its own `mount/3` and `handle_info/2` callbacks
- Follows existing pattern of `CartItems.Live` which subscribes to `stream_type:cart`
- PubSub messages are received directly by each nested LiveView
- **Key**: `stream_type:inventory` topic receives events from ALL `inventory-{product_id}` streams
- Each widget filters events by `product_id` field in the event (like `InventoriesStateView.ts` reference)

**Reference Pattern from TypeScript**:
```typescript
// InventoriesStateView.ts - filters events by productId
export const inventoriesStateView =
    (state: number, events: InventoryUpdatedEvent[], query: { productId: string} ): number => {
    let result:number = state
    events.forEach(event => {
        switch (event.type) {
            case "InventoryUpdated":
                if(event.data.productId == query.productId) {
                    result = event.data.inventory
                }
                break
        }
    })
    return result
}
```

**Elixir Pattern**:
```elixir
def mount(_params, %{"product_id" => product_id}, socket) do
  if connected?(socket) do
    # Subscribe to ALL inventory events (single topic for all products)
    Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:inventory")
  end
  
  # Initial load - get current quantity for this product
  {:ok, quantity} = Epoch.Backoffice.Inventory.get_quantity(product_id)
  
  socket =
    socket
    |> assign(:product_id, product_id)
    |> assign(:inventory, quantity)
  
  {:ok, socket}
end

def handle_info({:events_appended, _stream_name, events}, socket) do
  # Filter events by product_id (like InventoriesStateView in reference)
  # Events contain product_id field - find matching events for this widget
  quantity = 
    events
    |> Enum.filter(fn envelope -> 
      envelope.event.product_id == socket.assigns.product_id
    end)
    |> case do
      [] -> socket.assigns.inventory  # No matching events, keep current
      matching -> List.last(matching).event.quantity  # Latest quantity
    end
  
  {:noreply, assign(socket, :inventory, quantity)}
end
```

**Embedding in parent template**:
```heex
<%= live_render(@socket, Epoch.Slices.CartItemInventory.Live,
      id: "inventory-#{item.product_id}",
      session: %{"product_id" => item.product_id}) %>
```

### 7. Low Stock Threshold Implementation

**Decision**: Hardcode threshold of 5 units initially

**Rationale**:
- Spec defines 5 as default threshold
- Simple conditional in template for styling
- Can extract to application config in future if needed

**Implementation**:
```elixir
@low_stock_threshold 5

defp low_stock?(quantity), do: quantity <= @low_stock_threshold and quantity > 0
defp out_of_stock?(quantity), do: quantity == 0
```

### 8. Error Handling Strategy

**Decision**: Graceful degradation with "Unknown" display

**Rationale**:
- Cart must remain functional even if inventory unavailable
- Display "Unknown" if `get_quantity/1` fails
- Display "Out of stock" if quantity is 0
- Log warnings for troubleshooting

**Implementation**:
```elixir
defp load_inventory(socket) do
  case Epoch.Backoffice.Inventory.get_quantity(socket.assigns.product_id) do
    {:ok, quantity} ->
      assign(socket, :inventory, quantity)
    {:error, reason} ->
      Logger.warning("Failed to load inventory for #{socket.assigns.product_id}: #{inspect(reason)}")
      assign(socket, :inventory, :unknown)
  end
end
```

## Resolved Clarifications

| Original Unknown | Resolution |
|------------------|------------|
| Component type (LiveView vs LiveComponent) | Nested LiveView - required for independent PubSub subscriptions per widget |
| PubSub topic format | `stream_type:inventory` - single topic receives events from ALL inventory streams |
| Initial data load | `Epoch.Backoffice.Inventory.get_quantity/1` on LiveView mount |
| Event filtering | Filter by `event.product_id` in handle_info (like `InventoriesStateView.ts`) |
| Cart item structure | Must add `product_id` to `CartItemsView` output |
| Low stock threshold | Hardcode 5 initially, can extract to config later |

## Dependencies Confirmed

1. **Epoch.Backoffice.Inventory** - Existing, provides `get_quantity/1`
2. **Epoch.EventStore** - Existing, provides PubSub broadcasts on append
3. **Phoenix.PubSub (Epoch.PubSub)** - Existing, configured in application
4. **CartItemsView** - Needs modification to include `product_id` in items
