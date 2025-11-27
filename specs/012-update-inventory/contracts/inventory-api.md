# Inventory API Contract

**Feature**: 012-update-inventory  
**Date**: 2025-11-27

## Overview

This document defines the public API contract for the Backoffice.Inventory context. The API follows Phoenix/Elixir conventions with tagged tuple returns.

## Context Module: `Epoch.Backoffice.Inventory`

### update_quantity/2

Updates the inventory quantity for a product.

```elixir
@spec update_quantity(String.t(), integer()) ::
        {:ok, InventoryState.t()} | {:error, :not_found | :invalid_quantity | :persistence_failed}
def update_quantity(product_id, quantity)
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `product_id` | `String.t()` | Product identifier (e.g., "espresso-blend") |
| `quantity` | `integer()` | New inventory quantity |

**Returns**:
| Result | Description |
|--------|-------------|
| `{:ok, %InventoryState{}}` | Success with updated state |
| `{:error, :not_found}` | Product does not exist in Catalog |
| `{:error, :invalid_quantity}` | Quantity is negative or non-integer |
| `{:error, :persistence_failed}` | EventStore append failed |

**Side Effects**:
- Appends `InventoryUpdated` event to `"inventory-{product_id}"` stream

**Example**:
```elixir
iex> Epoch.Backoffice.Inventory.update_quantity("espresso-blend", 50)
{:ok, %Epoch.Backoffice.InventoryState{product_id: "espresso-blend", quantity: 50}}

iex> Epoch.Backoffice.Inventory.update_quantity("nonexistent", 10)
{:error, :not_found}

iex> Epoch.Backoffice.Inventory.update_quantity("espresso-blend", -5)
{:error, :invalid_quantity}
```

---

### get_quantity/1

Retrieves the current inventory quantity for a product.

```elixir
@spec get_quantity(String.t()) :: {:ok, non_neg_integer()}
def get_quantity(product_id)
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `product_id` | `String.t()` | Product identifier |

**Returns**:
| Result | Description |
|--------|-------------|
| `{:ok, quantity}` | Current quantity (0 if no inventory events exist) |

**Notes**:
- Always succeeds - returns 0 for products without inventory records (FR-006)
- Does not validate product existence (read-only operation)

**Example**:
```elixir
iex> Epoch.Backoffice.Inventory.get_quantity("espresso-blend")
{:ok, 50}

iex> Epoch.Backoffice.Inventory.get_quantity("new-product-no-inventory")
{:ok, 0}
```

---

### get_state/1

Retrieves the full inventory state for a product.

```elixir
@spec get_state(String.t()) :: {:ok, InventoryState.t()}
def get_state(product_id)
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `product_id` | `String.t()` | Product identifier |

**Returns**:
| Result | Description |
|--------|-------------|
| `{:ok, %InventoryState{}}` | Current inventory state |

**Example**:
```elixir
iex> Epoch.Backoffice.Inventory.get_state("espresso-blend")
{:ok, %Epoch.Backoffice.InventoryState{product_id: "espresso-blend", quantity: 50}}
```

---

## LiveView: `EpochWeb.Backoffice.InventoryLive`

### Route

```elixir
live "/backoffice/inventory", Backoffice.InventoryLive
```

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `form` | `Phoenix.HTML.Form.t()` | Form for inventory update |
| `result` | `{:ok, InventoryState.t()} \| {:error, atom()} \| nil` | Last operation result |

### Events

| Event | Params | Description |
|-------|--------|-------------|
| `"validate"` | `%{"product_id" => string, "quantity" => string}` | Validates form input |
| `"save"` | `%{"product_id" => string, "quantity" => string}` | Submits inventory update |

### Form Fields

| Field | Type | Validation |
|-------|------|------------|
| `product_id` | `text` | Required, non-empty |
| `quantity` | `number` | Required, non-negative integer |

---

## Event Stream Contract

### Stream Name

Pattern: `"inventory-{product_id}"`

Examples:
- `"inventory-espresso-blend"`
- `"inventory-french-roast"`

### Event Types

| Event | Fields | Description |
|-------|--------|-------------|
| `InventoryUpdated` | `product_id`, `quantity`, `updated_at` | Inventory quantity set |

### Event Ordering

Events are ordered by append time. The latest `InventoryUpdated` event contains the current quantity.

---

## Error Codes

| Code | HTTP Equivalent | Description |
|------|-----------------|-------------|
| `:not_found` | 404 | Product does not exist in Catalog |
| `:invalid_quantity` | 422 | Quantity validation failed |
| `:persistence_failed` | 500 | EventStore operation failed |
