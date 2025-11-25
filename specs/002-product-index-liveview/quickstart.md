# Quickstart: Product Index Page for Phoenix LiveView

**Branch**: `002-product-index-liveview` | **Date**: 2025-11-25

## Prerequisites

- Elixir 1.15+ installed
- PostgreSQL running (for test database)
- Project dependencies installed (`mix deps.get`)

## Quick Verification

After implementation, verify with these commands:

```bash
# Run all tests
mix test

# Run only this feature's tests
mix test apps/epoch/test/epoch/catalog_test.exs \
         apps/epoch/test/epoch/cart_test.exs \
         apps/epoch_web/test/epoch_web/live/products_live_test.exs

# Start the server
mix phx.server

# Visit in browser
open http://localhost:4000/products
```

## Implementation Order

Follow this order to maintain test-first development:

### Phase 1: Core Data Layer

1. **Create Product struct** (`apps/epoch/lib/epoch/catalog/product.ex`)
2. **Create Catalog context** (`apps/epoch/lib/epoch/catalog/catalog.ex`)
3. **Write Catalog tests** (`apps/epoch/test/epoch/catalog_test.exs`)
4. **Run tests** - should pass

### Phase 2: Cart Event Layer

1. **Create CartCreated event** (`apps/epoch/lib/epoch/cart/events/cart_created.ex`)
2. **Create ItemAddedToCart event** (`apps/epoch/lib/epoch/cart/events/item_added_to_cart.ex`)
3. **Create CartSession struct** (`apps/epoch/lib/epoch/cart/cart_session.ex`)
4. **Create Cart context** (`apps/epoch/lib/epoch/cart/cart.ex`)
5. **Write Cart tests** (`apps/epoch/test/epoch/cart_test.exs`)
6. **Run tests** - should pass

### Phase 3: Web Layer

1. **Add CDN links** to `root.html.heex`
2. **Add route** to `router.ex`
3. **Create ProductsLive** (`apps/epoch_web/lib/epoch_web/live/products_live.ex`)
4. **Create template** (`apps/epoch_web/lib/epoch_web/live/products_live.html.heex`)
5. **Write LiveView tests** (`apps/epoch_web/test/epoch_web/live/products_live_test.exs`)
6. **Run tests** - should pass

### Phase 4: Validation

1. **Run full test suite**: `mix test`
2. **Run precommit**: `mix precommit`
3. **Manual verification**: Browse to `/products`

## File Creation Checklist

```
apps/epoch/lib/epoch/
├── catalog/
│   ├── catalog.ex           □ Create
│   └── product.ex           □ Create
└── cart/
    ├── cart.ex              □ Create
    ├── cart_session.ex      □ Create
    └── events/
        ├── cart_created.ex      □ Create
        └── item_added_to_cart.ex □ Create

apps/epoch/test/epoch/
├── catalog_test.exs         □ Create
└── cart_test.exs            □ Create

apps/epoch_web/lib/epoch_web/
├── router.ex                □ Modify (add route)
├── components/layouts/
│   └── root.html.heex       □ Modify (add CDN links)
└── live/
    ├── products_live.ex         □ Create
    └── products_live.html.heex  □ Create

apps/epoch_web/test/epoch_web/live/
└── products_live_test.exs   □ Create
```

## Key Code Snippets

### Router Addition

```elixir
# apps/epoch_web/lib/epoch_web/router.ex
scope "/", EpochWeb do
  pipe_through :browser

  get "/", PageController, :home
  get "/health", HealthCheck, :health
  live "/products", ProductsLive  # ADD THIS
end
```

### CDN Links in Root Layout

```heex
<%!-- apps/epoch_web/lib/epoch_web/components/layouts/root.html.heex --%>
<head>
  ...
  <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
  
  <%!-- ADD THESE --%>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" />
  
  <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
  </script>
</head>
```

### LiveView Mount

```elixir
# apps/epoch_web/lib/epoch_web/live/products_live.ex
defmodule EpochWeb.ProductsLive do
  use EpochWeb, :live_view
  
  alias Epoch.Catalog
  alias Epoch.Cart
  
  @impl true
  def mount(_params, _session, socket) do
    session_id = Ecto.UUID.generate()
    Cart.create_session(session_id)
    products = Catalog.list_products()
    
    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:cart_session_id, session_id)}
  end
  
  @impl true
  def handle_event("add_to_cart", %{"product-id" => product_id}, socket) do
    Cart.add_item(socket.assigns.cart_session_id, product_id)
    {:noreply, push_navigate(socket, to: ~p"/cart")}
  end
end
```

## Common Issues

### Issue: Bulma styles not loading

**Symptom**: Page renders without styling  
**Check**: Browser network tab for CDN requests  
**Fix**: Verify CDN URLs are correct in `root.html.heex`

### Issue: Cart events not storing

**Symptom**: `add_to_cart` doesn't persist  
**Check**: EventStore process running in supervision tree  
**Fix**: Verify `Epoch.EventStore` in `Epoch.Application` children

### Issue: Route not found (404)

**Symptom**: `/products` returns 404  
**Check**: Router has `live "/products", ProductsLive`  
**Fix**: Ensure route is inside the `scope "/", EpochWeb` block

### Issue: Test failures with assigns

**Symptom**: Test can't access `view.assigns`  
**Check**: Using `Phoenix.LiveViewTest` correctly  
**Fix**: Use `live(conn, ~p"/products")` to get view

## Verification Checklist

After implementation:

- [ ] `mix test` passes all tests
- [ ] `mix precommit` passes (format, credo, dialyzer)
- [ ] Products page loads at `http://localhost:4000/products`
- [ ] 5 product cards display with names, descriptions, prices
- [ ] Navigation bar shows Products, Cart, Spec, Backoffice links
- [ ] "Add Item" button redirects to `/cart` (404 expected until cart page built)
- [ ] Page is styled with Bulma (cards in grid layout)
- [ ] Font Awesome icons appear in navigation
