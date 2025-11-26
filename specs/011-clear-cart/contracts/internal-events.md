# Internal Event Contracts: Clear Cart

**Feature**: 011-clear-cart
**Date**: 2025-11-26

## Overview

This feature has no external API contracts. All interactions are internal to the Phoenix LiveView application via LiveComponent events and the internal EventStore.

## Internal Event: CartCleared

**Stream**: `cart-{session_id}`
**Event Type**: `Epoch.Cart.Events.CartCleared`

### Schema

```elixir
%Epoch.Cart.Events.CartCleared{
  cleared_at: ~U[2025-11-26 12:00:00Z]  # DateTime.t()
}
```

### Emitted When

- User confirms the "Clear Cart" action
- Cart contains at least one item

### Not Emitted When

- User cancels the confirmation dialog
- Cart is already empty

### Consumers

| Consumer | Behavior |
|----------|----------|
| `CartItemsView.evolve/2` | Resets state to `%{items: [], total: 0.0}` |
| `CartItems.Live` | Receives PubSub broadcast, reloads cart state |

## LiveComponent Event: "clear_cart"

**Source**: `ClearCart.Component`
**Target**: `ClearCart.Component` (via `phx-target={@myself}`)

### Trigger

- Button click with `phx-confirm` attribute (browser confirmation dialog)

### Handler Response

| Scenario | Response |
|----------|----------|
| Success | `{:noreply, socket}` |
| Cart empty | `{:noreply, socket}` with flash error |
| EventStore error | `{:noreply, socket}` with flash error |
