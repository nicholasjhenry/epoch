# Data Model: Product Index Page for Phoenix LiveView

**Branch**: `002-product-index-liveview` | **Date**: 2025-11-25

## Overview

This feature uses a hybrid data model:
- **Products**: Hardcoded struct list (no database persistence)
- **Cart Sessions**: Event-sourced via `Epoch.EventStore` (in-memory)

## Entities

### Product

A purchasable coffee product displayed in the catalog.

**Module**: `Epoch.Catalog.Product`

**Location**: `apps/epoch/lib/epoch/catalog/product.ex`

```elixir
defmodule Epoch.Catalog.Product do
  @moduledoc """
  Represents a coffee product in the catalog.
  
  Products are currently hardcoded but structured to support
  future database migration.
  """
  
  @type t :: %__MODULE__{
    product_id: String.t(),
    name: String.t(),
    description: String.t(),
    price: Decimal.t()
  }
  
  defstruct [:product_id, :name, :description, :price]
end
```

**Fields**:

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `product_id` | `String.t()` | Unique identifier (slug-style) | Required, unique |
| `name` | `String.t()` | Display name | Required |
| `description` | `String.t()` | Product description | Required |
| `price` | `Decimal.t()` | Price in USD | Required, > 0 |

**Hardcoded Product Data**:

| product_id | name | description | price |
|------------|------|-------------|-------|
| `espresso-blend` | Espresso Blend | Rich, bold espresso roast perfect for your morning cup | 14.99 |
| `french-roast` | French Roast | Dark and smoky with a smooth finish | 13.99 |
| `colombian-supremo` | Colombian Supremo | Smooth and balanced with hints of caramel | 15.99 |
| `ethiopian-yirgacheffe` | Ethiopian Yirgacheffe | Fruity and bright with floral notes | 17.99 |
| `sumatra-mandheling` | Sumatra Mandheling | Earthy and full-bodied with low acidity | 16.99 |

### CartSession

Represents a shopping cart session, reconstructed from events.

**Module**: `Epoch.Cart.CartSession`

**Location**: `apps/epoch/lib/epoch/cart/cart_session.ex`

```elixir
defmodule Epoch.Cart.CartSession do
  @moduledoc """
  Represents the current state of a shopping cart session.
  
  State is reconstructed from events stored in EventStore.
  Stream name format: "cart-{session_id}"
  """
  
  @type t :: %__MODULE__{
    session_id: String.t(),
    items: [cart_item()],
    created_at: DateTime.t() | nil
  }
  
  @type cart_item :: %{
    product_id: String.t(),
    quantity: pos_integer()
  }
  
  defstruct session_id: nil, items: [], created_at: nil
end
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `String.t()` | UUID identifying the cart session |
| `items` | `[cart_item()]` | List of products and quantities |
| `created_at` | `DateTime.t()` | When the cart was created |

## Events

Events are appended to EventStore streams for cart operations.

### CartCreated

Emitted when a new cart session is initialized.

```elixir
defmodule Epoch.Cart.Events.CartCreated do
  @type t :: %__MODULE__{
    session_id: String.t(),
    created_at: DateTime.t()
  }
  
  defstruct [:session_id, :created_at]
end
```

### ItemAddedToCart

Emitted when a product is added to the cart.

```elixir
defmodule Epoch.Cart.Events.ItemAddedToCart do
  @type t :: %__MODULE__{
    product_id: String.t(),
    quantity: pos_integer(),
    added_at: DateTime.t()
  }
  
  defstruct [:product_id, :quantity, :added_at]
end
```

## State Reconstruction

The `CartSession` state is reconstructed by evolving events:

```elixir
defmodule Epoch.Cart.CartSession do
  alias Epoch.Cart.Events.{CartCreated, ItemAddedToCart}
  
  @doc """
  Evolves cart state by applying an event.
  """
  def evolve(state, %CartCreated{session_id: id, created_at: at}) do
    %{state | session_id: id, created_at: at}
  end
  
  def evolve(state, %ItemAddedToCart{product_id: pid, quantity: qty}) do
    updated_items = add_or_update_item(state.items, pid, qty)
    %{state | items: updated_items}
  end
  
  defp add_or_update_item(items, product_id, quantity) do
    case Enum.find_index(items, &(&1.product_id == product_id)) do
      nil ->
        items ++ [%{product_id: product_id, quantity: quantity}]
      index ->
        List.update_at(items, index, fn item ->
          %{item | quantity: item.quantity + quantity}
        end)
    end
  end
end
```

## Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                        LiveView                             │
│                    (ProductsLive)                           │
└─────────────────────────────────────────────────────────────┘
         │                                    │
         │ reads                              │ writes
         ▼                                    ▼
┌─────────────────────┐            ┌─────────────────────────┐
│   Epoch.Catalog     │            │     Epoch.Cart          │
│                     │            │                         │
│  ┌───────────────┐  │            │  ┌───────────────────┐  │
│  │   Product     │  │            │  │   CartSession     │  │
│  │ (hardcoded)   │  │            │  │  (event-sourced)  │  │
│  └───────────────┘  │            │  └───────────────────┘  │
│                     │            │           │             │
│  list_products/0    │            │           │ evolves     │
│  get_product!/1     │            │           ▼             │
└─────────────────────┘            │  ┌───────────────────┐  │
                                   │  │ CartCreated       │  │
                                   │  │ ItemAddedToCart   │  │
                                   │  └───────────────────┘  │
                                   │           │             │
                                   │           │ stored in   │
                                   │           ▼             │
                                   │  ┌───────────────────┐  │
                                   │  │ Epoch.EventStore  │  │
                                   │  │ stream: cart-{id} │  │
                                   │  └───────────────────┘  │
                                   └─────────────────────────┘
```

## Validation Rules

### Product
- `product_id`: Non-empty string, unique within catalog
- `name`: Non-empty string
- `description`: Non-empty string  
- `price`: Decimal > 0

### CartSession
- `session_id`: Valid UUID format
- `items[].product_id`: Must exist in catalog
- `items[].quantity`: Positive integer

## State Transitions

### Cart Lifecycle

```
[No Cart] ──mount──> [Empty Cart] ──add_item──> [Cart with Items]
                          │                            │
                          │                            │ add_item
                          │                            ▼
                          │                     [Cart with Items]
                          │                            │
                          └────────────────────────────┘
                                    (future: checkout)
```

### Event Flow

1. **Mount**: LiveView mounts → generate session UUID → emit `CartCreated`
2. **Add Item**: User clicks "Add Item" → emit `ItemAddedToCart` → redirect to cart

## File Locations

```
apps/epoch/lib/epoch/
├── catalog/
│   ├── catalog.ex           # Context module with list_products/0
│   └── product.ex           # Product struct
└── cart/
    ├── cart.ex              # Context module with add_item/2
    ├── cart_session.ex      # CartSession struct + evolve/2
    └── events/
        ├── cart_created.ex
        └── item_added_to_cart.ex
```

## Future Considerations

1. **Database Migration**: When products move to PostgreSQL:
   - Create `products` table with Ecto schema
   - Migrate `Epoch.Catalog.Product` to Ecto schema
   - Update `list_products/0` to query database

2. **Cart Persistence**: When cart needs durability:
   - Add PostgreSQL projection of cart state
   - Subscribe to cart events for real-time sync
   - Or migrate EventStore to persistent storage

3. **Quantity Management**: Currently adds 1 item per click:
   - Future: quantity input field
   - Future: update quantity events
   - Future: remove item events
