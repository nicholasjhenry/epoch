# Implementation Plan: Display Cart Items

**Branch**: `009-display-cart-items` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-display-cart-items/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Display shopping cart items derived from event stream, showing item names, prices, and cart total. Implements a read model (state view) that projects cart events (ItemAdded, ItemRemoved, CartCleared, ItemArchived) into a displayable cart state. Uses Phoenix LiveView with Bulma CSS, following existing patterns from ProductsLive and the reference TypeScript implementation.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1
**Storage**: In-memory EventStore (GenServer-based, Feature 001)
**Testing**: ExUnit with Phoenix.LiveViewTest
**Target Platform**: Web browser (Phoenix LiveView)
**Project Type**: Umbrella (apps/epoch for business logic, apps/epoch_web for web layer)
**Performance Goals**: Cart state rebuild < 1 second on page load (per SC-001)
**Constraints**: None specific; follow existing patterns
**Scale/Scope**: Single-user cart sessions; in-memory event storage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: Unit tests for cart state view evolve functions, integration tests for LiveView rendering
- [x] Cross-boundary interactions enumerated: EventStore → Cart context → LiveView; PubSub for real-time updates
- [x] Dependencies, configuration changes, and feature contracts documented explicitly: Uses existing EventStore, adds new event types
- [x] Failure handling strategy captured: EventStore unavailable shows error message; malformed events are skipped with logging
- [x] Demo data additions planned: Not applicable (cart is session-based, not seeded)
- [x] Skill-driven implementation planned: Required skills identified below

**Required Skills**:
- `elixir-core`: Pattern matching for event evolve functions
- `phoenix-liveview`: LiveView mount, streams, PubSub subscriptions
- `phoenix-html`: HEEx templates for cart display
- `elixir-testing`: ExUnit tests for state view and LiveView

## Project Structure

### Documentation (this feature)

```text
specs/009-display-cart-items/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
# Umbrella application structure
apps/
├── epoch/                           # Core business logic
│   ├── lib/epoch/
│   │   ├── cart/
│   │   │   ├── cart.ex              # Cart context (existing)
│   │   │   ├── cart_session.ex      # CartSession struct (existing)
│   │   │   ├── cart_items_view.ex   # NEW: Cart items state view
│   │   │   └── events/
│   │   │       ├── cart_created.ex      # Existing
│   │   │       ├── item_added_to_cart.ex # Existing
│   │   │       ├── item_removed.ex       # NEW
│   │   │       ├── cart_cleared.ex       # NEW
│   │   │       └── item_archived.ex      # NEW
│   │   └── event_store.ex           # EventStore (existing)
│   └── test/epoch/
│       └── cart/
│           └── cart_items_view_test.exs  # NEW: State view tests
│
├── epoch_web/                       # Phoenix web application
│   ├── lib/epoch_web/
│   │   └── live/
│   │       ├── cart_live.ex         # NEW: Cart LiveView
│   │       └── cart_live.html.heex  # NEW: Cart template
│   └── test/epoch_web/
│       └── live/
│           └── cart_live_test.exs   # NEW: LiveView tests
│
└── fs_new/                          # Filesystem utilities (unchanged)
```

**Structure Decision**: Follows existing umbrella structure with business logic in `apps/epoch` and web layer in `apps/epoch_web`. Cart items view follows the "state view" pattern from the reference TypeScript implementation.

## Constitution Check (Post-Design Verification)

*Re-evaluated after Phase 1 design completion.*

- [x] **Tests-first plan documented**: 
  - Unit tests defined in `contracts/cart-items-api.md` for `CartItemsView.evolve/2`
  - Integration tests defined for `CartLive` mount and rendering
  - Test file locations: `cart_items_view_test.exs`, `cart_live_test.exs`

- [x] **Cross-boundary interactions enumerated**:
  - EventStore → Cart.get_cart_items/1 → CartLive (documented in contracts)
  - Event types defined with full structs in data-model.md
  - PubSub integration noted for future real-time updates

- [x] **Dependencies documented explicitly**:
  - No new external dependencies
  - Four new event types: ItemAdded, ItemRemoved, CartCleared, ItemArchived
  - New modules: CartItemsView, CartLive
  - Route addition: `/cart/:session_id`

- [x] **Failure handling strategy captured**:
  - EventStore errors return empty cart state (graceful degradation)
  - Unknown events ignored in evolve function
  - Malformed events handled via pattern match fallback

- [x] **Demo data**: Not applicable (cart sessions are ephemeral)

- [x] **Skill-driven implementation**: Skills documented, conventions in quickstart.md

**Gate Status**: PASS - Ready for Phase 2 (task generation via /speckit.tasks)

## Complexity Tracking

> No Constitution Check violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

## Generated Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Plan | `specs/009-display-cart-items/plan.md` | Complete |
| Research | `specs/009-display-cart-items/research.md` | Complete |
| Data Model | `specs/009-display-cart-items/data-model.md` | Complete |
| API Contract | `specs/009-display-cart-items/contracts/cart-items-api.md` | Complete |
| Quickstart | `specs/009-display-cart-items/quickstart.md` | Complete |
| Tasks | `specs/009-display-cart-items/tasks.md` | Pending (/speckit.tasks) |
