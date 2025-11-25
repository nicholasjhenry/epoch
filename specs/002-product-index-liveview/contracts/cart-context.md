# Contract: Epoch.Cart Context

**Type**: Phoenix Context  
**Module**: `Epoch.Cart`  
**Location**: `apps/epoch/lib/epoch/cart/cart.ex`

## Overview

Context module for managing shopping cart sessions using the EventStore for persistence. Provides cart creation and item addition functionality.

## Public API

### `create_session/1`

Creates a new cart session in the EventStore.

**Signature**:
```elixir
@spec create_session(String.t()) :: {:ok, CartSession.t()} | {:error, term()}
```

**Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| `session_id` | `String.t()` | UUID for the cart session |

**Returns**: 
- `{:ok, %CartSession{}}` on success
- `{:error, reason}` on failure

**Behavior**:
1. Create `CartCreated` event with session_id and timestamp
2. Append to EventStore stream `"cart-#{session_id}"`
3. Return reconstructed session state

**Example**:
```elixir
iex> Epoch.Cart.create_session("550e8400-e29b-41d4-a716-446655440000")
{:ok, %Epoch.Cart.CartSession{
  session_id: "550e8400-e29b-41d4-a716-446655440000",
  items: [],
  created_at: ~U[2025-11-25 10:00:00Z]
}}
```

### `add_item/3`

Adds a product to the cart.

**Signature**:
```elixir
@spec add_item(String.t(), String.t(), pos_integer()) :: 
  {:ok, CartSession.t()} | {:error, term()}
```

**Parameters**:
| Param | Type | Description | Default |
|-------|------|-------------|---------|
| `session_id` | `String.t()` | Cart session UUID | required |
| `product_id` | `String.t()` | Product to add | required |
| `quantity` | `pos_integer()` | Number to add | 1 |

**Returns**:
- `{:ok, %CartSession{}}` with updated items
- `{:error, :not_found}` if product doesn't exist
- `{:error, reason}` on EventStore failure

**Behavior**:
1. Validate product exists in catalog
2. Create `ItemAddedToCart` event
3. Append to cart stream
4. Return reconstructed session state

**Example**:
```elixir
iex> Epoch.Cart.add_item(session_id, "espresso-blend", 1)
{:ok, %Epoch.Cart.CartSession{
  session_id: "...",
  items: [%{product_id: "espresso-blend", quantity: 1}],
  created_at: ~U[...]
}}
```

### `get_session/1`

Retrieves the current state of a cart session.

**Signature**:
```elixir
@spec get_session(String.t()) :: {:ok, CartSession.t()} | {:error, :not_found}
```

**Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| `session_id` | `String.t()` | Cart session UUID |

**Returns**:
- `{:ok, %CartSession{}}` if session exists
- `{:error, :not_found}` if no events in stream

**Example**:
```elixir
iex> Epoch.Cart.get_session("550e8400-e29b-41d4-a716-446655440000")
{:ok, %Epoch.Cart.CartSession{items: [...], ...}}
```

## Implementation

```elixir
defmodule Epoch.Cart do
  @moduledoc """
  The Cart context for managing shopping cart sessions.
  
  Cart state is event-sourced using Epoch.EventStore.
  """
  
  alias Epoch.Catalog
  alias Epoch.EventStore
  alias Epoch.Cart.CartSession
  alias Epoch.Cart.Events.{CartCreated, ItemAddedToCart}
  
  @spec create_session(String.t()) :: {:ok, CartSession.t()} | {:error, term()}
  def create_session(session_id) do
    event = %CartCreated{
      session_id: session_id,
      created_at: DateTime.utc_now()
    }
    
    stream_name = stream_name(session_id)
    
    case EventStore.append_to_stream(stream_name, [event], expected_version: 0) do
      {:ok, _} -> get_session(session_id)
      {:error, _} = error -> error
    end
  end
  
  @spec add_item(String.t(), String.t(), pos_integer()) :: 
    {:ok, CartSession.t()} | {:error, term()}
  def add_item(session_id, product_id, quantity \\ 1) do
    with {:ok, _product} <- Catalog.get_product(product_id) do
      event = %ItemAddedToCart{
        product_id: product_id,
        quantity: quantity,
        added_at: DateTime.utc_now()
      }
      
      stream_name = stream_name(session_id)
      
      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> get_session(session_id)
        {:error, _} = error -> error
      end
    end
  end
  
  @spec get_session(String.t()) :: {:ok, CartSession.t()} | {:error, :not_found}
  def get_session(session_id) do
    stream_name = stream_name(session_id)
    
    case EventStore.aggregate_stream(
      stream_name, 
      %CartSession{}, 
      &CartSession.evolve/2
    ) do
      {:ok, %{state: %CartSession{session_id: nil}, version: 0}} ->
        {:error, :not_found}
      {:ok, %{state: session}} ->
        {:ok, session}
    end
  end
  
  defp stream_name(session_id), do: "cart-#{session_id}"
end
```

## Event Structures

### CartCreated

```elixir
defmodule Epoch.Cart.Events.CartCreated do
  @moduledoc "Event emitted when a cart session is created."
  
  @type t :: %__MODULE__{
    session_id: String.t(),
    created_at: DateTime.t()
  }
  
  defstruct [:session_id, :created_at]
end
```

### ItemAddedToCart

```elixir
defmodule Epoch.Cart.Events.ItemAddedToCart do
  @moduledoc "Event emitted when an item is added to cart."
  
  @type t :: %__MODULE__{
    product_id: String.t(),
    quantity: pos_integer(),
    added_at: DateTime.t()
  }
  
  defstruct [:product_id, :quantity, :added_at]
end
```

## Test Contract

```elixir
defmodule Epoch.CartTest do
  use ExUnit.Case
  
  alias Epoch.Cart
  alias Epoch.Cart.CartSession
  
  setup do
    # Start a fresh EventStore for each test
    {:ok, _pid} = Epoch.EventStore.start_link(name: :test_event_store)
    :ok
  end
  
  describe "create_session/1" do
    test "creates new cart session" do
      session_id = UUID.generate()
      
      assert {:ok, %CartSession{session_id: ^session_id}} = 
        Cart.create_session(session_id)
    end
    
    test "initializes empty items list" do
      session_id = UUID.generate()
      {:ok, session} = Cart.create_session(session_id)
      
      assert session.items == []
    end
    
    test "sets created_at timestamp" do
      session_id = UUID.generate()
      {:ok, session} = Cart.create_session(session_id)
      
      assert %DateTime{} = session.created_at
    end
  end
  
  describe "add_item/3" do
    setup do
      session_id = UUID.generate()
      {:ok, _} = Cart.create_session(session_id)
      {:ok, session_id: session_id}
    end
    
    test "adds valid product to cart", %{session_id: session_id} do
      assert {:ok, session} = Cart.add_item(session_id, "espresso-blend", 1)
      assert [%{product_id: "espresso-blend", quantity: 1}] = session.items
    end
    
    test "increments quantity for existing item", %{session_id: session_id} do
      {:ok, _} = Cart.add_item(session_id, "espresso-blend", 1)
      {:ok, session} = Cart.add_item(session_id, "espresso-blend", 2)
      
      assert [%{product_id: "espresso-blend", quantity: 3}] = session.items
    end
    
    test "rejects invalid product", %{session_id: session_id} do
      assert {:error, :not_found} = 
        Cart.add_item(session_id, "invalid-product", 1)
    end
  end
  
  describe "get_session/1" do
    test "returns session when exists" do
      session_id = UUID.generate()
      {:ok, _} = Cart.create_session(session_id)
      
      assert {:ok, %CartSession{session_id: ^session_id}} = 
        Cart.get_session(session_id)
    end
    
    test "returns error when not found" do
      assert {:error, :not_found} = Cart.get_session("nonexistent")
    end
  end
end
```

## Dependencies

- `Epoch.EventStore` - Event persistence
- `Epoch.Catalog` - Product validation

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `{:error, :not_found}` | Product ID invalid | Return error to caller |
| `{:error, %VersionMismatchError{}}` | Concurrent modification | Retry or return error |
| EventStore unavailable | Process crashed | Supervisor restarts, caller retries |
