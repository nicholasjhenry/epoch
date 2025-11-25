# Implementation Plan: Product Index Page for Phoenix LiveView

**Branch**: `002-product-index-liveview` | **Date**: 2025-11-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-product-index-liveview/spec.md`

## Summary

Port the existing Next.js product index page to Phoenix LiveView at `/products`. The page displays 5 hardcoded coffee products in a responsive card grid (3 columns desktop) with navigation, Bulma CSS styling via CDN, and "Add Item" cart functionality using the existing in-memory EventStore for session/cart management.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Ecto 3.13, Jason 1.2  
**Storage**: PostgreSQL via Ecto (for future persistence); In-memory EventStore for cart sessions  
**Testing**: ExUnit with Phoenix.LiveViewTest, LazyHTML, Ecto.Adapters.SQL.Sandbox  
**Target Platform**: Web browser (responsive: desktop 3-col, smaller screens fewer columns)  
**Project Type**: Umbrella web application (apps/epoch core, apps/epoch_web Phoenix layer)  
**Performance Goals**: Page load < 1 second (per SC-001), static content with LiveView interactivity  
**Constraints**: CDN dependencies for Bulma CSS and Font Awesome (graceful degradation if unavailable)  
**Scale/Scope**: 5 hardcoded products, single-user session tracking via UUID

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
  - **Unit tests** (to fail first):
    - `test/epoch_web/live/products_live_test.exs`: Product list renders correct number of cards
    - `test/epoch_web/live/products_live_test.exs`: Each product card displays name, description, price
    - `test/epoch_web/live/products_live_test.exs`: Add Item button present on each card
    - `test/epoch_web/components/navigation_test.exs`: Navigation renders all required links with icons
  - **Integration tests** (to fail first):
    - `test/epoch_web/live/products_live_test.exs`: Full page render with all products displayed
    - `test/epoch_web/live/products_live_test.exs`: Add Item triggers cart update and redirects
    - `test/epoch_web/live/products_live_test.exs`: Cart session UUID generated on mount
    - `test/epoch_web/live/navigation_test.exs`: Navigation links route to correct pages

- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
  - **LiveView → EventStore**: Cart session creation, item additions (integration test for add_to_cart event)
  - **LiveView → Router**: Navigation between Products/Cart/Spec/Backoffice pages
  - **CDN → Browser**: Bulma CSS and Font Awesome loading (manual verification, graceful degradation)

- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
  - **CDN links**: Add Bulma and Font Awesome to root layout (`root.html.heex`)
  - **Route**: Add `live "/products", ProductsLive` to router scope
  - **EventStore**: Use existing `Epoch.EventStore` for cart session management
  - **Static data**: Hardcoded product list in LiveView module (no database schema)

- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
  - **CDN failure**: Page renders with degraded styling; no blocking behavior
  - **EventStore failure**: Log errors, display user-friendly message, continue with degraded cart experience
  - **Logging**: Use `Logger` for cart session creation, item additions, and errors

- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
  - N/A: Products are hardcoded in LiveView; no database seeds needed for this feature
  - Future: When products move to database, add 5 coffee products to seeds.exs

- [x] Skill-driven implementation planned: required skills identified and conventions documented.
  - **Required skills**:
    - `phoenix-liveview`: LiveView module structure, mount/handle_event, streams (if needed), testing
    - `phoenix-html`: HEEx templates, forms, component syntax, CDN asset loading
    - `elixir-core`: Pattern matching, function design, data structures
    - `elixir-testing`: ExUnit patterns, Phoenix.LiveViewTest usage
    - `task-based-ui`: Cart "Add Item" action as explicit user task
  - **Conventions**:
    - LiveViews named with `Live` suffix: `EpochWeb.ProductsLive`
    - Use `to_form/2` for any form handling
    - Use Phoenix.LiveViewTest functions: `render/1`, `render_click/3`, `has_element?/2`
    - Test against element IDs, not raw HTML text

## Project Structure

### Documentation (this feature)

```text
specs/002-product-index-liveview/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
apps/
├── epoch/                         # Core application
│   ├── lib/epoch/
│   │   ├── event_store.ex        # Existing - used for cart sessions
│   │   ├── cart/                 # NEW: Cart context (if needed)
│   │   │   └── cart.ex           # Cart session management
│   │   └── catalog/              # NEW: Catalog context
│   │       └── product.ex        # Product struct (hardcoded data)
│   └── test/epoch/
│       └── cart/
│           └── cart_test.exs     # Cart context tests
│
├── epoch_web/                     # Phoenix web application
│   ├── lib/epoch_web/
│   │   ├── router.ex             # MODIFIED: Add /products route
│   │   ├── components/
│   │   │   ├── layouts/
│   │   │   │   └── root.html.heex  # MODIFIED: Add CDN links
│   │   │   └── navigation.ex     # NEW: Navigation component
│   │   └── live/
│   │       ├── products_live.ex  # NEW: Products LiveView
│   │       └── products_live.html.heex  # NEW: Products template
│   ├── assets/
│   │   └── css/app.css           # MODIFIED: (if Bulma overrides needed)
│   └── test/epoch_web/
│       └── live/
│           └── products_live_test.exs  # NEW: LiveView tests
```

**Structure Decision**: Using existing umbrella structure with epoch (core) and epoch_web (web layer). New LiveView goes in `apps/epoch_web/lib/epoch_web/live/`. Product data structure in `apps/epoch/lib/epoch/catalog/` for future database migration path.

## Complexity Tracking

> No constitution violations to justify - feature uses existing infrastructure.

## Post-Design Constitution Re-Evaluation

*Completed after Phase 1 design artifacts generated.*

| Checkpoint | Status | Evidence |
|------------|--------|----------|
| Tests-first plan documented | ✅ PASS | `contracts/products-live.md` specifies unit/integration tests with exact test function names |
| Cross-boundary interactions | ✅ PASS | `data-model.md` documents LiveView→EventStore, LiveView→Router interactions |
| Dependencies documented | ✅ PASS | `research.md` lists Bulma 1.0.2, Font Awesome 6.5.2 CDN URLs |
| Failure handling | ✅ PASS | `contracts/products-live.md` Error States table covers CDN, EventStore failures |
| Demo data planned | ✅ PASS | N/A - products hardcoded; documented in `data-model.md` |
| Skill-driven implementation | ✅ PASS | `research.md` references `phoenix-liveview`, `phoenix-html` skill patterns |

### Artifacts Generated

| Artifact | Path | Purpose |
|----------|------|---------|
| research.md | `specs/002-product-index-liveview/research.md` | Technical decisions and rationale |
| data-model.md | `specs/002-product-index-liveview/data-model.md` | Entity definitions, events, relationships |
| quickstart.md | `specs/002-product-index-liveview/quickstart.md` | Implementation order and verification |
| products-live.md | `specs/002-product-index-liveview/contracts/products-live.md` | LiveView mount/event/template contract |
| catalog-context.md | `specs/002-product-index-liveview/contracts/catalog-context.md` | Catalog context API contract |
| cart-context.md | `specs/002-product-index-liveview/contracts/cart-context.md` | Cart context API contract |

### Ready for Task Generation

All Phase 0 and Phase 1 artifacts complete. Run `/speckit.tasks` to generate implementation tasks.
