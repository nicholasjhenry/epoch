# Implementation Plan: Update Product Inventory

**Branch**: `012-update-inventory` | **Date**: 2025-11-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-update-inventory/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement inventory management functionality that allows updating the quantity for a product identified by product_id. The system submits `InventoryUpdated` events to the `inventory` stream following the existing event-sourcing patterns. Implementation follows a simple approach: a Phoenix LiveView under the Backoffice namespace with a context module (no vertical-slice architecture).

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1  
**Storage**: In-memory EventStore (GenServer-based); events persisted to streams  
**Testing**: ExUnit with fresh EventStore per test  
**Target Platform**: Phoenix web application  
**Project Type**: Umbrella app (apps/epoch for domain, apps/epoch_web for web layer)  
**Performance Goals**: Inventory updates under 1 second, queries under 500ms  
**Constraints**: Non-negative integer quantities only; validate product exists before updating  
**Scale/Scope**: Single product inventory updates; read model for product listings with inventory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
  - Unit: update_quantity/2 success, update to 0, negative value rejection, get_quantity/1 existing/new product
  - Integration: events persisted to EventStore, state recovery after restart
- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
  - Inventory → Catalog: validate product_id exists via Catalog.get_product/1
  - Inventory → EventStore: append InventoryUpdated events, read/aggregate streams
- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
  - Depends on: Catalog context (product validation), EventStore (event persistence)
  - No new configuration required
- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
  - Invalid product_id: return {:error, :not_found}
  - Invalid quantity: return {:error, :invalid_quantity}
  - EventStore failure: return {:error, :persistence_failed}
  - All operations logged with product_id and quantity
- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
  - Seed initial inventory quantities for existing catalog products
- [x] Skill-driven implementation planned: required skills identified (e.g., phoenix-contexts, ecto, elixir-testing) and conventions documented for code generation compliance.
  - Required skills: elixir-core, phoenix-contexts, phoenix-liveview, phoenix-html, elixir-testing

## Project Structure

### Documentation (this feature)

```text
specs/012-update-inventory/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Umbrella application structure
apps/epoch/lib/epoch/
├── backoffice/
│   ├── inventory.ex              # Context module (public API)
│   ├── inventory_state.ex        # Aggregate state + evolve/2
│   └── events/
│       └── inventory_updated.ex  # Event struct
└── catalog/
    ├── catalog.ex                # Existing (used for product validation)
    └── product.ex                # Existing

apps/epoch/test/epoch/
└── backoffice/
    └── inventory_test.exs        # Unit + integration tests

apps/epoch_web/lib/epoch_web/
├── live/
│   └── backoffice/
│       └── inventory_live.ex     # LiveView for inventory management
└── router.ex                     # Add backoffice inventory route

apps/epoch_web/test/epoch_web/live/
└── backoffice/
    └── inventory_live_test.exs   # LiveView tests
```

**Structure Decision**: Follow existing Cart context pattern - context module with public API, aggregate state module with evolve/2 function, events in subdirectory. Simple LiveView (no slices) per user request. All inventory management code namespaced under `Backoffice` for admin/management functionality separation.

**Namespace Mapping**:
- Domain context: `Epoch.Backoffice.Inventory`
- Inventory state: `Epoch.Backoffice.InventoryState`
- Event: `Epoch.Backoffice.Events.InventoryUpdated`
- LiveView: `EpochWeb.Backoffice.InventoryLive`

## Complexity Tracking

> No Constitution Check violations requiring justification.
