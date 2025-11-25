# Research: Product Index Page for Phoenix LiveView

**Branch**: `002-product-index-liveview` | **Date**: 2025-11-25

## Research Tasks Completed

### 1. Phoenix LiveView Best Practices

**Decision**: Use standard Phoenix LiveView patterns with function components (not LiveComponents).

**Rationale**: 
- LiveComponents add complexity; function components suffice for static product cards
- `phoenix-liveview` skill explicitly states "AVOID LiveComponents unless you have a strong, specific need"
- Product cards are presentation-only; no independent state management needed

**Alternatives Considered**:
- LiveComponents: Rejected - overkill for static display, adds unnecessary complexity
- Server-rendered controller: Rejected - loses LiveView reactivity for cart updates

### 2. Navigation Implementation

**Decision**: Create a reusable `navigation` function component in `core_components.ex`.

**Rationale**:
- Navigation is shared across multiple pages (Products, Cart, Spec, Backoffice)
- Function components are the recommended pattern for stateless UI elements
- Can be easily tested independently

**Implementation Pattern**:
```elixir
# In core_components.ex
def navigation(assigns) do
  ~H"""
  <nav class="navbar" role="navigation">
    <.link navigate={~p"/products"}>Products</.link>
    <.link navigate={~p"/cart"}>Cart</.link>
    ...
  </nav>
  """
end
```

**Alternatives Considered**:
- Separate NavigationComponent module: Rejected - unnecessary file overhead for simple component
- Include in layout directly: Rejected - harder to test, violates single responsibility

### 3. CDN Asset Loading Strategy

**Decision**: Add Bulma CSS and Font Awesome CDN links to `root.html.heex` layout.

**Rationale**:
- CDN links provide fastest initial load without build complexity
- Graceful degradation if CDN unavailable (per FR-008, FR-009)
- Keeps asset pipeline simple; Tailwind still handles app-specific styles

**CDN URLs** (from spec):
- Bulma: `https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css`
- Font Awesome: `https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css`

**Placement**: After app CSS link to allow Bulma overrides if needed.

**Alternatives Considered**:
- npm install + bundling: Rejected - adds build complexity for single page
- Inline styles: Rejected - violates consistency requirement with original Next.js design

### 4. Cart Session Management

**Decision**: Use existing `Epoch.EventStore` for cart session state with UUID-based stream names.

**Rationale**:
- EventStore already exists and is tested (from 001-elixir-event-store feature)
- Event sourcing provides audit trail of cart actions
- Stream name pattern: `"cart-{uuid}"` aligns with EventStore conventions
- Session UUID stored in LiveView socket assigns

**Event Schema**:
```elixir
# Cart events
%ItemAddedToCart{product_id: String.t(), quantity: integer()}
%CartCreated{session_id: String.t()}
```

**State Reconstruction**:
```elixir
EventStore.aggregate_stream("cart-#{session_id}", %Cart{}, &Cart.evolve/2)
```

**Alternatives Considered**:
- Phoenix session storage: Rejected - loses event history, not event-sourced
- ETS table: Rejected - reinvents wheel when EventStore exists
- Database persistence: Deferred - can migrate later; in-memory sufficient for MVP

### 5. Product Data Structure

**Decision**: Hardcoded list of 5 products as structs in a `Epoch.Catalog.Product` module.

**Rationale**:
- Spec explicitly states "static data that will be hardcoded"
- Struct provides compile-time field validation
- Separate module creates migration path to database-backed products later
- Located in `apps/epoch/lib/epoch/catalog/` following Phoenix context conventions

**Product Struct**:
```elixir
defmodule Epoch.Catalog.Product do
  defstruct [:product_id, :name, :description, :price]
  
  @type t :: %__MODULE__{
    product_id: String.t(),
    name: String.t(),
    description: String.t(),
    price: Decimal.t()
  }
end
```

**Hardcoded Products** (5 coffee products per spec):
1. Espresso Blend - Rich, bold espresso roast - $14.99
2. French Roast - Dark and smoky - $13.99
3. Colombian Supremo - Smooth and balanced - $15.99
4. Ethiopian Yirgacheffe - Fruity and bright - $17.99
5. Sumatra Mandheling - Earthy and full-bodied - $16.99

**Alternatives Considered**:
- Map-based products: Rejected - no compile-time validation
- Database schema: Deferred - overkill for 5 static products in MVP
- JSON file: Rejected - adds unnecessary I/O, complicates testing

### 6. LiveView Testing Strategy

**Decision**: Use `Phoenix.LiveViewTest` with element selectors and unique DOM IDs.

**Rationale**:
- `phoenix-liveview` skill mandates testing against element IDs, not raw HTML
- `LazyHTML` already available in test suite for HTML inspection
- Constitution requires tests-first development

**Testing Patterns**:
```elixir
# Test element presence
assert has_element?(view, "#product-espresso-blend")
assert has_element?(view, "#add-item-espresso-blend")

# Test interactions
view |> element("#add-item-espresso-blend") |> render_click()
```

**DOM ID Conventions**:
- Product cards: `product-{product_id}`
- Add buttons: `add-item-{product_id}`
- Navigation links: `nav-{page_name}`
- Product form (if any): `product-form`

**Alternatives Considered**:
- Text content assertions: Rejected - fragile, breaks on content changes
- CSS class selectors: Rejected - less specific than IDs

### 7. LiveView Route Configuration

**Decision**: Add `live "/products", ProductsLive` to existing browser scope in router.

**Rationale**:
- `phoenix-liveview` skill states: "The `:browser` scope already aliases `MyAppWeb`, so use short names"
- Route follows naming convention with `Live` suffix
- No authentication required for product browsing

**Router Change**:
```elixir
scope "/", EpochWeb do
  pipe_through :browser
  
  get "/", PageController, :home
  get "/health", HealthCheck, :health
  live "/products", ProductsLive  # NEW
end
```

**Alternatives Considered**:
- Separate live_session block: Rejected - no auth requirements for products page
- Nested route structure: Rejected - overkill for single page feature

### 8. Price Formatting

**Decision**: Use Elixir's built-in formatting with explicit currency display.

**Rationale**:
- No external dependencies needed for simple USD formatting
- Decimal type prevents floating-point precision issues
- Format: `"$#{Decimal.to_string(price)}"` or helper function

**Helper Function**:
```elixir
def format_price(%Decimal{} = price) do
  "$#{Decimal.round(price, 2)}"
end
```

**Alternatives Considered**:
- Money library (ex_money): Rejected - overkill for single currency display
- Float storage: Rejected - precision issues with financial data

## Technical Unknowns Resolved

| Unknown | Resolution | Confidence |
|---------|------------|------------|
| LiveView vs Controller | LiveView for reactivity | High |
| Cart state storage | EventStore with UUID streams | High |
| CDN loading | root.html.heex links | High |
| Product data source | Hardcoded struct list | High |
| Navigation pattern | Function component | High |
| Testing approach | Element selectors + IDs | High |

## Dependencies Confirmed

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| Phoenix LiveView | 1.1.17 | Real-time UI | Already installed |
| Epoch.EventStore | N/A | Cart session state | Already implemented |
| Bulma CSS | 1.0.2 | Card/grid styling | CDN link |
| Font Awesome | 6.5.2 | Navigation icons | CDN link |

## Risk Assessment

| Risk | Mitigation | Impact |
|------|------------|--------|
| CDN unavailable | Graceful degradation; page functional without styling | Low |
| EventStore memory growth | Session cleanup on cart completion; future: persistence | Medium |
| Bulma/Tailwind conflicts | Load Bulma after Tailwind; scope Bulma to products page if needed | Low |

## Next Steps

1. **Phase 1**: Generate data-model.md with Product and Cart entities
2. **Phase 1**: Generate contracts/ with LiveView event handlers
3. **Phase 1**: Generate quickstart.md with implementation steps
