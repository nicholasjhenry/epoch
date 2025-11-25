# Contract: ProductsLive

**Type**: Phoenix LiveView  
**Module**: `EpochWeb.ProductsLive`  
**Route**: `GET /products`

## Overview

LiveView for displaying the product catalog with navigation and "Add Item" cart functionality.

## Mount Lifecycle

### `mount/3`

**Signature**: 
```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Behavior**:
1. Generate cart session UUID (or retrieve from session)
2. Create cart session in EventStore
3. Load products from catalog
4. Assign products and session_id to socket

**Socket Assigns**:
| Assign | Type | Description |
|--------|------|-------------|
| `products` | `[Product.t()]` | List of catalog products |
| `cart_session_id` | `String.t()` | UUID for cart EventStore stream |

**Example**:
```elixir
def mount(_params, _session, socket) do
  session_id = UUID.generate()
  Epoch.Cart.create_session(session_id)
  products = Epoch.Catalog.list_products()
  
  {:ok,
   socket
   |> assign(:products, products)
   |> assign(:cart_session_id, session_id)}
end
```

## Event Handlers

### `handle_event("add_to_cart", params, socket)`

**Trigger**: Click on "Add Item" button

**Params**:
```elixir
%{"product-id" => product_id}
```

**Behavior**:
1. Validate product exists in catalog
2. Append `ItemAddedToCart` event to cart stream
3. Redirect to cart page

**Response**:
```elixir
{:noreply, push_navigate(socket, to: ~p"/cart")}
```

**Error Handling**:
- Invalid product_id: Log error, show flash message, stay on page

## Template Contract

### Required Elements

| Element | ID | Purpose |
|---------|-----|---------|
| Navigation bar | `nav-main` | Site navigation |
| Product list container | `product-list` | Contains all product cards |
| Product card | `product-{product_id}` | Individual product display |
| Product name | `product-name-{product_id}` | Product heading |
| Product price | `product-price-{product_id}` | Formatted price |
| Add button | `add-item-{product_id}` | Cart add action |

### Template Structure

```heex
<nav id="nav-main" class="navbar" role="navigation">
  <.link navigate={~p"/products"} id="nav-products">
    <i class="fas fa-store"></i> Products
  </.link>
  <.link navigate={~p"/cart"} id="nav-cart">
    <i class="fas fa-shopping-cart"></i> Cart
  </.link>
  <.link navigate={~p"/spec"} id="nav-spec">
    <i class="fas fa-vial"></i> Spec
  </.link>
  <.link navigate={~p"/backoffice"} id="nav-backoffice">
    <i class="fas fa-cogs"></i> Backoffice
  </.link>
</nav>

<div id="product-list" class="columns is-multiline">
  <div :for={product <- @products} 
       id={"product-#{product.product_id}"} 
       class="column is-one-third">
    <div class="card">
      <div class="card-content">
        <p id={"product-name-#{product.product_id}"} class="title is-4">
          {product.name}
        </p>
        <p class="content">{product.description}</p>
        <p id={"product-price-#{product.product_id}"} class="subtitle is-5">
          {format_price(product.price)}
        </p>
      </div>
      <footer class="card-footer">
        <button 
          id={"add-item-#{product.product_id}"}
          class="card-footer-item button is-primary"
          phx-click="add_to_cart"
          phx-value-product-id={product.product_id}>
          Add Item
        </button>
      </footer>
    </div>
  </div>
</div>
```

## CSS Dependencies

### Bulma Classes Used

| Class | Element | Purpose |
|-------|---------|---------|
| `navbar` | `<nav>` | Navigation container |
| `columns` | Product list | Grid container |
| `is-multiline` | Product list | Wrap columns |
| `column` | Product card wrapper | Grid item |
| `is-one-third` | Product card wrapper | 3-column layout |
| `card` | Product card | Card container |
| `card-content` | Product details | Content area |
| `card-footer` | Add button area | Footer area |
| `card-footer-item` | Add button | Footer action |
| `title` | Product name | Heading style |
| `subtitle` | Product price | Subheading style |
| `button` | Add button | Button style |
| `is-primary` | Add button | Primary color |

### Font Awesome Icons

| Icon | Class | Element |
|------|-------|---------|
| Store | `fas fa-store` | Products nav link |
| Shopping cart | `fas fa-shopping-cart` | Cart nav link |
| Vial | `fas fa-vial` | Spec nav link |
| Cogs | `fas fa-cogs` | Backoffice nav link |

## Test Contract

### Unit Tests

```elixir
describe "ProductsLive mount" do
  test "assigns products list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    assert length(view.assigns.products) == 5
  end
  
  test "generates cart session id", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    assert is_binary(view.assigns.cart_session_id)
  end
end

describe "ProductsLive template" do
  test "renders all products", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    
    assert has_element?(view, "#product-espresso-blend")
    assert has_element?(view, "#product-french-roast")
    assert has_element?(view, "#product-colombian-supremo")
    assert has_element?(view, "#product-ethiopian-yirgacheffe")
    assert has_element?(view, "#product-sumatra-mandheling")
  end
  
  test "renders product details", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    
    assert has_element?(view, "#product-name-espresso-blend")
    assert has_element?(view, "#product-price-espresso-blend")
    assert has_element?(view, "#add-item-espresso-blend")
  end
  
  test "renders navigation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    
    assert has_element?(view, "#nav-products")
    assert has_element?(view, "#nav-cart")
    assert has_element?(view, "#nav-spec")
    assert has_element?(view, "#nav-backoffice")
  end
end
```

### Integration Tests

```elixir
describe "add to cart" do
  test "adds item and redirects to cart", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    
    view
    |> element("#add-item-espresso-blend")
    |> render_click()
    
    # Verify redirect
    assert_redirect(view, "/cart")
  end
  
  test "creates event in store", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    session_id = view.assigns.cart_session_id
    
    view
    |> element("#add-item-espresso-blend")
    |> render_click()
    
    # Verify event stored
    {:ok, %{events: events}} = 
      Epoch.EventStore.read_stream("cart-#{session_id}")
    
    assert Enum.any?(events, fn
      %Epoch.Cart.Events.ItemAddedToCart{product_id: "espresso-blend"} -> true
      _ -> false
    end)
  end
end
```

## Error States

| Condition | Behavior | User Feedback |
|-----------|----------|---------------|
| EventStore unavailable | Log error, continue without cart | Flash: "Cart temporarily unavailable" |
| Invalid product_id | Log warning, ignore click | Flash: "Product not found" |
| CDN unavailable | Graceful degradation | Page functional, unstyled |
