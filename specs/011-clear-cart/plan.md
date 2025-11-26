# Implementation Plan: Clear All Items from Cart

**Branch**: `011-clear-cart` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-clear-cart/spec.md`

## Summary

Implement a "Clear Cart" feature allowing users to remove all items from their cart with a single action. Following the vertical slice architecture pattern (like `add_item` and `remove_item`), this feature will include a Command, CommandHandler, and Component. The clear action requires user confirmation before emitting a `CartCleared` event to the EventStore.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1
**Storage**: In-memory EventStore (GenServer-based, Feature 001)
**Testing**: ExUnit with Phoenix.LiveViewTest
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella (apps/epoch, apps/epoch_web)
**Performance Goals**: Cart display updates within 500ms of confirmation (per SC-002)
**Constraints**: Maximum 2 interactions to clear cart (click clear, confirm)
**Scale/Scope**: Single-session cart operations, real-time UI updates via PubSub

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: Unit tests for CommandHandler, Component rendering, and integration tests for LiveView interaction documented in spec.md
- [x] Cross-boundary interactions enumerated: LiveComponent → CommandHandler → EventStore → PubSub → CartItems.Live
- [x] Dependencies, configuration changes, and feature contracts documented explicitly: CartCleared event exists, EventStore API documented
- [x] Failure handling strategy captured: EventStore errors display user message, confirmation dialog failure prevents action
- [x] Demo data additions planned: N/A - cart clearing operates on existing cart state
- [x] Skill-driven implementation planned: Required skills identified below

**Required Skills for Implementation**:
- `elixir-core`: Pattern matching, structs, error handling with tagged tuples
- `phoenix-liveview`: LiveComponent, handle_event, PubSub subscription patterns
- `phoenix-html`: HEEx templates, conditional rendering, button components
- `elixir-testing`: ExUnit patterns, LiveViewTest assertions

## Project Structure

### Documentation (this feature)

```text
specs/011-clear-cart/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # Phase 1 output (minimal - internal event only)
```

### Source Code (repository root)

```text
apps/
├── epoch/                                    # Domain layer
│   └── lib/epoch/cart/
│       └── events/
│           └── cart_cleared.ex              # EXISTS - CartCleared event already defined
│
└── epoch_web/                               # Web layer
    ├── lib/epoch_web/slices/
    │   └── clear_cart/                      # NEW - vertical slice
    │       ├── command.ex                   # ClearCart command struct
    │       ├── command_handler.ex           # Validates empty cart, appends event
    │       └── component.ex                 # LiveComponent with confirmation
    │
    └── test/epoch_web/slices/
        └── clear_cart_test.exs              # Unit + integration tests
```

**Structure Decision**: Following existing vertical slice pattern established by `add_item` and `remove_item` slices. The `clear_cart` slice will be placed under `apps/epoch_web/lib/epoch_web/slices/clear_cart/`.

## Complexity Tracking

> No Constitution violations - standard vertical slice implementation following established patterns.

| Aspect | Approach | Rationale |
|--------|----------|-----------|
| Confirmation Dialog | Browser `confirm()` | Per spec assumptions, simple browser confirm is acceptable |
| Event Location | CartCleared in `apps/epoch` | Event already exists per spec dependencies |
| Component Location | `slices/clear_cart/` | Consistent with existing slice architecture |
