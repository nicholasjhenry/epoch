# Contract: Epoch.Catalog Context

**Type**: Phoenix Context  
**Module**: `Epoch.Catalog`  
**Location**: `apps/epoch/lib/epoch/catalog/catalog.ex`

## Overview

Context module for managing the product catalog. Initially provides hardcoded products; structured for future database migration.

## Public API

### `list_products/0`

Returns all products in the catalog.

**Signature**:
```elixir
@spec list_products() :: [Product.t()]
```

**Returns**: List of 5 hardcoded coffee products, ordered by name.

**Example**:
```elixir
iex> Epoch.Catalog.list_products()
[
  %Epoch.Catalog.Product{
    product_id: "colombian-supremo",
    name: "Colombian Supremo",
    description: "Smooth and balanced with hints of caramel",
    price: Decimal.new("15.99")
  },
  ...
]
```

### `get_product/1`

Retrieves a single product by ID.

**Signature**:
```elixir
@spec get_product(String.t()) :: {:ok, Product.t()} | {:error, :not_found}
```

**Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| `product_id` | `String.t()` | Product identifier (slug) |

**Returns**: 
- `{:ok, product}` if found
- `{:error, :not_found}` if not found

**Example**:
```elixir
iex> Epoch.Catalog.get_product("espresso-blend")
{:ok, %Epoch.Catalog.Product{product_id: "espresso-blend", ...}}

iex> Epoch.Catalog.get_product("invalid")
{:error, :not_found}
```

### `get_product!/1`

Retrieves a single product by ID, raises on not found.

**Signature**:
```elixir
@spec get_product!(String.t()) :: Product.t()
```

**Raises**: `ArgumentError` if product not found.

**Example**:
```elixir
iex> Epoch.Catalog.get_product!("espresso-blend")
%Epoch.Catalog.Product{product_id: "espresso-blend", ...}

iex> Epoch.Catalog.get_product!("invalid")
** (ArgumentError) Product not found: invalid
```

## Implementation

```elixir
defmodule Epoch.Catalog do
  @moduledoc """
  The Catalog context for managing products.
  """
  
  alias Epoch.Catalog.Product
  
  @products [
    %Product{
      product_id: "espresso-blend",
      name: "Espresso Blend",
      description: "Rich, bold espresso roast perfect for your morning cup",
      price: Decimal.new("14.99")
    },
    %Product{
      product_id: "french-roast",
      name: "French Roast",
      description: "Dark and smoky with a smooth finish",
      price: Decimal.new("13.99")
    },
    %Product{
      product_id: "colombian-supremo",
      name: "Colombian Supremo",
      description: "Smooth and balanced with hints of caramel",
      price: Decimal.new("15.99")
    },
    %Product{
      product_id: "ethiopian-yirgacheffe",
      name: "Ethiopian Yirgacheffe",
      description: "Fruity and bright with floral notes",
      price: Decimal.new("17.99")
    },
    %Product{
      product_id: "sumatra-mandheling",
      name: "Sumatra Mandheling",
      description: "Earthy and full-bodied with low acidity",
      price: Decimal.new("16.99")
    }
  ]
  
  @spec list_products() :: [Product.t()]
  def list_products do
    Enum.sort_by(@products, & &1.name)
  end
  
  @spec get_product(String.t()) :: {:ok, Product.t()} | {:error, :not_found}
  def get_product(product_id) do
    case Enum.find(@products, &(&1.product_id == product_id)) do
      nil -> {:error, :not_found}
      product -> {:ok, product}
    end
  end
  
  @spec get_product!(String.t()) :: Product.t()
  def get_product!(product_id) do
    case get_product(product_id) do
      {:ok, product} -> product
      {:error, :not_found} -> 
        raise ArgumentError, "Product not found: #{product_id}"
    end
  end
end
```

## Test Contract

```elixir
defmodule Epoch.CatalogTest do
  use ExUnit.Case, async: true
  
  alias Epoch.Catalog
  alias Epoch.Catalog.Product
  
  describe "list_products/0" do
    test "returns all 5 products" do
      products = Catalog.list_products()
      assert length(products) == 5
    end
    
    test "returns products sorted by name" do
      products = Catalog.list_products()
      names = Enum.map(products, & &1.name)
      assert names == Enum.sort(names)
    end
    
    test "all products have required fields" do
      for product <- Catalog.list_products() do
        assert %Product{} = product
        assert is_binary(product.product_id)
        assert is_binary(product.name)
        assert is_binary(product.description)
        assert %Decimal{} = product.price
      end
    end
  end
  
  describe "get_product/1" do
    test "returns product when found" do
      assert {:ok, %Product{product_id: "espresso-blend"}} = 
        Catalog.get_product("espresso-blend")
    end
    
    test "returns error when not found" do
      assert {:error, :not_found} = Catalog.get_product("invalid-id")
    end
  end
  
  describe "get_product!/1" do
    test "returns product when found" do
      assert %Product{product_id: "espresso-blend"} = 
        Catalog.get_product!("espresso-blend")
    end
    
    test "raises when not found" do
      assert_raise ArgumentError, ~r/Product not found/, fn ->
        Catalog.get_product!("invalid-id")
      end
    end
  end
end
```

## Dependencies

- `Decimal` - For price representation (already in deps via Ecto)

## Future Migration Path

When migrating to database-backed products:

1. Create Ecto schema in `Epoch.Catalog.Product`
2. Create migration for `products` table
3. Update `list_products/0` to query Repo
4. Update `get_product/1` to use Repo.get_by
5. Add seeds for initial products
6. Remove hardcoded `@products` module attribute
