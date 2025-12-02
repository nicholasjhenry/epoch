# Implementation Plan: Submit Cart

**Branch**: `015-submit-cart` | **Date**: 2025-12-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-submit-cart/spec.md`

## Summary

Implement cart submission functionality that validates inventory availability for all active cart items before allowing submission. The system will read the current cart state from cart events (ItemAdded, ItemRemoved, ItemArchived, CartCleared), check inventory for each product using a dedicated slice-local `InventoriesView` read model (NOT the Backoffice.Inventory context), and emit a CartSubmitted event on success or return an error with details on failure.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1  
**Storage**: In-memory EventStore (GenServer-based); PostgreSQL via Ecto.Repo available for future persistence  
**Testing**: ExUnit with fresh EventStore per test via `start_supervised!/1`  
**Target Platform**: Web application (Phoenix LiveView)
**Project Type**: Umbrella application with `apps/epoch` (domain) and `apps/epoch_web` (web interface)  
**Performance Goals**: Cart submission validation completes within 1 second for typical cart sizes  
**Constraints**: Must validate inventory at submission time using current inventory state  
**Scale/Scope**: Single cart sessions, in-memory event storage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: Unit tests for command handler (happy path, inventory validation, empty cart), integration tests for stream reads and event appending
- [x] Cross-boundary interactions enumerated: Cart stream read, Inventory stream read (per product), CartSubmitted event append
- [x] Dependencies, configuration changes, and feature contracts documented explicitly: Uses existing EventStore, Cart context; dedicated InventoriesView read model (slice-local, no coupling to Backoffice)
- [x] Failure handling strategy captured: Empty cart → error, insufficient inventory → error with product details, missing inventory record → treated as 0 inventory
- [x] Demo data additions planned: Not required - uses existing cart and inventory events from prior features
- [x] Skill-driven implementation planned: Required skills identified - `elixir-core`, `elixir-testing`, `phoenix-liveview`, `phoenix-html`

## Project Structure

### Documentation (this feature)

```text
specs/015-submit-cart/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── epoch/
│   ├── lib/epoch/
│   │   ├── cart/
│   │   │   ├── cart.ex                    # Cart context (existing)
│   │   │   ├── cart_items_view.ex         # Cart items read model (existing)
│   │   │   ├── cart_session.ex            # Cart session aggregate (existing)
│   │   │   └── events/
│   │   │       ├── item_added.ex          # Existing event
│   │   │       ├── item_removed.ex        # Existing event
│   │   │       ├── item_archived.ex       # Existing event
│   │   │       ├── cart_cleared.ex        # Existing event
│   │   │       └── cart_submitted.ex      # NEW: CartSubmitted event
│   │   ├── backoffice/
│   │   │   ├── inventory.ex               # Inventory context (existing)
│   │   │   └── inventory_state.ex         # Inventory state view (existing)
│   │   └── event_store.ex                 # EventStore GenServer (existing)
│   └── test/epoch/
│       └── slices/
│           └── submit_cart/
│               └── command_handler_test.exs  # NEW: Unit tests
│
└── epoch_web/
    ├── lib/epoch_web/
    │   ├── slices/
    │   │   ├── cart_items/
    │   │   │   └── live.ex                # Cart items LiveView (modify to add submit button)
    │   │   └── submit_cart/
    │   │       ├── command.ex             # NEW: SubmitCart command struct
    │   │       ├── command_handler.ex     # NEW: Command handler with inventory validation
    │   │       ├── inventories_view.ex    # NEW: Slice-local inventory read model
    │   │       └── component.ex           # NEW: Submit button LiveComponent
    └── test/epoch_web/
        └── slices/
            └── submit_cart_test.exs       # NEW: Integration tests
```

**Structure Decision**: Following the existing vertical slice architecture pattern established by `clear_cart/`, `remove_item/`, and other slices. Command, CommandHandler, InventoriesView (slice-local read model), and Component in `epoch_web/lib/epoch_web/slices/submit_cart/`, with the CartSubmitted event in `epoch/lib/epoch/cart/events/`. The `InventoriesView` is a dedicated read model that avoids coupling to the `Epoch.Backoffice.Inventory` context.

## Complexity Tracking

No Constitution violations requiring justification. Implementation follows established patterns.

## Post-Design Constitution Re-Check

*Verified after Phase 1 design completion (2025-12-02)*

| Principle | Status | Evidence |
|-----------|--------|----------|
| **Test-First Development** | ✅ Pass | Test cases documented in [contracts/submit-cart.md](./contracts/submit-cart.md) - 8 unit test scenarios, 2 integration test scenarios |
| **Explicit Over Implicit** | ✅ Pass | All dependencies enumerated in [research.md](./research.md); command/event contracts typed in [data-model.md](./data-model.md) |
| **Fail Fast, Fail Loud** | ✅ Pass | Error handling strategy with specific error atoms documented; validation at submission time |
| **Skill-Driven Implementation** | ✅ Pass | Required skills identified: `elixir-core`, `elixir-testing`, `phoenix-liveview`, `phoenix-html` |
| **Pre-Commit Validation** | ✅ Ready | `mix precommit` will be run after implementation |

## Generated Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Implementation Plan | `specs/015-submit-cart/plan.md` | ✅ Complete |
| Research | `specs/015-submit-cart/research.md` | ✅ Complete |
| Data Model | `specs/015-submit-cart/data-model.md` | ✅ Complete |
| API Contract | `specs/015-submit-cart/contracts/submit-cart.md` | ✅ Complete |
| Quickstart Guide | `specs/015-submit-cart/quickstart.md` | ✅ Complete |
| Agent Context | `CLAUDE.md` | ✅ Updated |
| Task List | `specs/015-submit-cart/tasks.md` | ⏳ Pending (`/speckit.tasks`) |
