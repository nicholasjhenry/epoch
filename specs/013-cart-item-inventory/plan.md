# Implementation Plan: Display Cart Item Inventory

**Branch**: `013-cart-item-inventory` | **Date**: 2025-11-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/013-cart-item-inventory/spec.md`

## Summary

Display available inventory quantity next to each product in the cart items list, with real-time updates when inventory changes. Implementation follows vertical slice architecture with an embedded LiveView component that subscribes to the `inventory` stream type for reactive updates, matching the pattern established in the TypeScript reference implementation (`Inventories.tsx`).

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1
**Storage**: In-memory EventStore (GenServer-based) for inventory events; stream format `inventory-{product_id}`
**Testing**: ExUnit with Phoenix.LiveViewTest
**Target Platform**: Web application (Phoenix LiveView)
**Project Type**: Umbrella app (apps/epoch, apps/epoch_web)
**Performance Goals**: Inventory display within 1 second of cart load; updates within 2 seconds of inventory change
**Constraints**: Must not block cart rendering if inventory service unavailable; graceful degradation to "Unknown"
**Scale/Scope**: Single cart view, multiple products per cart

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
  - Unit: `CartItemInventory.Component` renders inventory quantity
  - Unit: `CartItemInventory.Component` shows "Out of stock" for quantity 0
  - Unit: `CartItemInventory.Component` shows "Unknown" when inventory unavailable
  - Unit: `CartItemInventory.Component` applies low-stock styling for quantity <= 5
  - Integration: LiveView subscribes to `stream_type:inventory` and updates on events
  - Integration: Cart items display shows inventory for each product
  - Integration: Inventory update propagates to cart display in real-time
- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
  - Cart slice → Inventory context: `Epoch.Backoffice.Inventory.get_quantity/1`
  - EventStore → PubSub: `stream_type:inventory` broadcasts
  - LiveView ← PubSub: subscription in `mount/3`
- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
  - Depends on: `Epoch.Backoffice.Inventory` (existing), `Epoch.Cart.CartItemsView` (existing)
  - No new dependencies required
  - Low stock threshold: 5 (hardcoded default, can be extracted to config later)
- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
  - Inventory fetch failure: Display "Unknown", log warning, continue rendering
  - PubSub subscription failure: Static display only, log error
  - Product not in inventory system: Display "0 available" / "Out of stock"
- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
  - Inventory events for seed products already exist via backoffice
  - No additional seed data required
- [x] Skill-driven implementation planned: required skills identified for code generation compliance.
  - `phoenix-liveview`: LiveView patterns, PubSub subscriptions, component lifecycle
  - `phoenix-html`: HEEx template syntax, conditional styling
  - `elixir-core`: Pattern matching, error handling with tagged tuples
  - `elixir-testing`: ExUnit patterns, LiveView testing

## Project Structure

### Documentation (this feature)

```text
specs/013-cart-item-inventory/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (minimal - no new APIs)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
apps/epoch_web/lib/epoch_web/slices/
├── cart_items/
│   └── live.ex                      # Existing - will embed new nested LiveView
└── cart_item_inventory/
    └── live.ex                      # NEW: Nested LiveView for inventory display

apps/epoch_web/test/epoch_web/slices/
└── cart_item_inventory_test.exs     # NEW: Tests for inventory display
```

**Structure Decision**: Following vertical slice architecture, create a new slice `cart_item_inventory` with a **nested LiveView** that:
1. Receives `product_id` via session from parent `CartItems.Live`
2. Subscribes to `stream_type:inventory` PubSub topic on mount (own process)
3. Fetches initial inventory via `Epoch.Backoffice.Inventory.get_quantity/1`
4. Handles `{:events_appended, stream_name, events}` in its own `handle_info/2` for matching product
5. Renders inventory quantity with appropriate styling (normal, low-stock, out-of-stock)

## Architecture Decision: Nested LiveView (not LiveComponent)

Based on research of the TypeScript reference (`Inventories.tsx`) and existing Elixir patterns:

**Choice**: Nested LiveView (embedded LiveView)

**Rationale**:
- LiveComponents run in the parent process and cannot have their own `handle_info/2` for PubSub
- Each inventory widget needs to independently subscribe and receive real-time updates
- Nested LiveViews run as separate processes with their own lifecycle and message handling
- Follows the existing pattern of `CartItems.Live` which is itself a nested LiveView subscribing to `stream_type:cart`
- TypeScript reference uses per-component subscriptions; Elixir equivalent requires nested LiveView

**Existing pattern from CartItems.Live**:
```elixir
# apps/epoch_web/lib/epoch_web/slices/cart_items/live.ex
def mount(_params, %{"session_id" => session_id}, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:cart")
  end
  # ...
end

def handle_info({:events_appended, stream_name, _events}, socket) do
  # Handles its own PubSub messages
end
```

**Pattern for CartItemInventory.Live**:
```elixir
# In CartItemInventory.Live (nested LiveView)
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

**Key Design Point**: The `stream_type:inventory` topic receives events from ALL `inventory-{product_id}` streams. Each widget filters events by checking `event.product_id` against its own `product_id` assign, matching the reference pattern in `InventoriesStateView.ts`.

**Embedding in parent template**:
```heex
<%= live_render(@socket, Epoch.Slices.CartItemInventory.Live,
      id: "inventory-#{item.product_id}",
      session: %{"product_id" => item.product_id}) %>
```

## Complexity Tracking

> No Constitution Check violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
