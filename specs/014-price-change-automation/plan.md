# Implementation Plan: Price Change TODO List & Automation

**Branch**: `014-price-change-automation` | **Date**: 2025-12-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-price-change-automation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a price change automation system that:
1. Allows administrators to publish price changes from the backoffice (same page as inventory)
2. Translates external PriceChanged events via a ChangePrice command to internal PriceChanged events
3. Maintains read models for "products with price changes" and "carts with products"
4. Automatically archives cart items affected by price changes via an Item Archiver automation
5. Tracks pending archive requests in a TODO list read model
6. Updates the cart items read model when items are archived

The system follows the existing event-sourcing patterns with GenServer-based EventStore, command/handler slices, and read model projections.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)  
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1, Jason 1.2  
**Storage**: In-memory EventStore (GenServer-based); PostgreSQL via Ecto.Repo available for future persistence  
**Testing**: ExUnit with BDD-style tests, start_supervised! for fresh EventStore per test  
**Target Platform**: Linux server (Phoenix web application)  
**Project Type**: Umbrella web application (apps/epoch + apps/epoch_web)  
**Performance Goals**: Price change processing within 5 seconds; archive requests within 10 seconds of price change  
**Constraints**: <200ms p95 for individual event processing; handle 100 concurrent affected carts  
**Scale/Scope**: 5 products in catalog (in-memory); multiple concurrent cart sessions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Pre-Phase 0 Status**: ✅ PASSED  
**Post-Phase 1 Status**: ✅ PASSED (re-evaluated 2025-12-01)

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
  - Unit: ChangePrice command handler, read model evolution tests for all 3 read models, archive command handler
  - Integration: end-to-end price change → archive flow, PubSub event propagation
  - **Post-design**: Tests enumerated in contracts/commands.md and contracts/read-models.md
- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
  - Backoffice UI → ChangePrice command → EventStore → PubSub
  - PubSub → Price change processor → Archive requests
  - Archive processor → Cart stream → Cart items view
  - **Post-design**: Event flow documented in contracts/events.md with stream correlation
- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
  - Dependency on Epoch.EventStore, Epoch.Cart, Epoch.Catalog, Phoenix.PubSub (Epoch.PubSub)
  - New stream: "price-{product_id}" for PriceChanged events
  - No new external dependencies required
  - **Post-design**: Full contracts in contracts/ directory; data model in data-model.md
- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
  - EventStore unavailable: {:error, :persistence_failed}, halt automation
  - PubSub unavailable: events persist but automation doesn't trigger
  - Cart not found during archive: log warning, emit ItemArchived anyway
  - Processor timeout: log warning after 30s, continue with partial progress
  - **Post-design**: Error handling documented in contracts/commands.md
- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
  - Add price change scenarios to seeds
  - Pre-populate carts with items for testing price change impact
  - **Post-design**: Test scenarios documented in quickstart.md
- [x] Skill-driven implementation planned: required skills identified for this feature (list them: elixir-core, elixir-otp, ecto, phoenix-liveview, phoenix-html, elixir-testing). Task-level skill assignment will use patterns from `~/.claude/skills/*/SKILL.md` frontmatter.
  - **Post-design**: Skills confirmed; elixir-otp for GenServer processor, phoenix-liveview for backoffice UI

## Project Structure

### Documentation (this feature)

```text
specs/014-price-change-automation/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
apps/
├── epoch/                              # Core domain logic
│   ├── lib/epoch/
│   │   ├── backoffice/
│   │   │   ├── price.ex               # NEW: Price change context
│   │   │   ├── price_state.ex         # NEW: Price aggregate state
│   │   │   └── events/
│   │   │       └── price_changed.ex   # NEW: Internal PriceChanged event
│   │   ├── cart/
│   │   │   ├── carts_with_products.ex # NEW: Read model for cart-product mappings
│   │   │   ├── items_to_archive.ex    # NEW: TODO list read model
│   │   │   └── events/
│   │   │       ├── item_archive_requested.ex  # NEW
│   │   │       └── item_archived.ex   # EXISTS: from feature 013
│   │   └── automation/
│   │       └── price_change_processor.ex  # NEW: Automation processor
│   └── test/epoch/
│       ├── backoffice/
│       │   └── price_test.exs         # NEW: Unit tests
│       ├── cart/
│       │   ├── carts_with_products_test.exs  # NEW: Read model tests
│       │   └── items_to_archive_test.exs     # NEW: TODO list tests
│       └── automation/
│           └── price_change_processor_test.exs  # NEW: Processor tests
│
└── epoch_web/                          # Web layer
    ├── lib/epoch_web/
    │   ├── live/backoffice/
    │   │   └── price_live.ex          # NEW: Or extend inventory_live.ex
    │   └── slices/
    │       ├── change_price/          # NEW: Slice for price change command
    │       │   ├── command.ex
    │       │   └── command_handler.ex
    │       └── archive_item/          # NEW: Slice for archive command
    │           ├── command.ex
    │           └── command_handler.ex
    └── test/epoch_web/
        ├── live/backoffice/
        │   └── price_live_test.exs    # NEW: LiveView tests
        └── slices/
            ├── change_price_test.exs  # NEW: Command handler tests
            └── archive_item_test.exs  # NEW: Command handler tests
```

**Structure Decision**: Umbrella application structure following existing patterns. New modules added to both `epoch` (domain logic) and `epoch_web` (UI/commands) apps. Automation processor added to new `automation/` directory in epoch app to keep processors separate from aggregates and read models.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New automation/ directory | Separates processor concerns from domain | Putting processor in backoffice/ would conflate admin UI with automation logic |
| Two new read models | Spec requires "products with price changes" AND "carts with products" for Item Archiver to correlate | Single read model cannot efficiently track both dimensions |
