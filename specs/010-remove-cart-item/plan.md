# Implementation Plan: Remove Item from Cart

**Branch**: `010-remove-cart-item` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-remove-cart-item/spec.md`

## Summary

Implement the ability for users to remove items from their shopping cart using the vertical-slice architecture pattern. The feature follows the existing `add_item` slice pattern with Command, CommandHandler, and Component modules. The command handler rebuilds cart state from events to validate business rules (item existence) before appending an ItemRemoved event. The cart page subscribes to the event store via PubSub to receive real-time updates when items are removed.

## Technical Context

**Language/Version**: Elixir 1.19.2 / OTP 28.1.1 (requirement: ~> 1.15)
**Primary Dependencies**: Phoenix 1.8.1, Phoenix LiveView 1.1.17, Phoenix PubSub 2.1
**Storage**: In-memory EventStore (GenServer-based, Feature 001)
**Testing**: ExUnit with Phoenix.LiveViewTest
**Target Platform**: Web application (Phoenix LiveView)
**Project Type**: Umbrella app with `epoch` (core) and `epoch_web` (web) apps
**Performance Goals**: Cart display updates within 500ms of removal action
**Constraints**: Cart operations must be event-sourced; real-time UI updates via PubSub
**Scale/Scope**: Single-user cart sessions; max 3 items per cart

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Tests-first plan documented: list the failing unit and integration tests that will be authored before any implementation.
- [x] Cross-boundary interactions enumerated with required integration tests and supporting data setup.
- [x] Dependencies, configuration changes, and feature contracts documented explicitly; no hidden coupling.
- [x] Failure handling strategy captured for each external dependency (timeouts, retries, structured logging).
- [x] Demo data additions planned for priv/repo/seeds.exs so manual verification remains possible.
- [x] Skill-driven implementation planned: required skills identified (e.g., phoenix-contexts, ecto, elixir-testing) and conventions documented for code generation compliance.

### Tests-First Plan

**Unit Tests** (write first, must fail before implementation):
1. `test "handle/1 returns error when item_id not in cart"` - CommandHandler returns `{:error, :item_not_found}`
2. `test "handle/1 appends ItemRemoved event when item exists"` - CommandHandler appends event to stream
3. `test "handle/1 returns updated cart session after removal"` - CommandHandler returns `{:ok, session}` with item removed
4. `test "CartItemsView.evolve/2 removes item and updates total"` - State projection removes item correctly

**Integration Tests** (write second, must fail before implementation):
1. `test "clicking remove button removes item from cart display"` - LiveView integration
2. `test "cart total updates after item removal"` - LiveView shows new total
3. `test "removing last item shows empty cart state"` - LiveView transitions to empty state
4. `test "removing non-existent item shows error flash"` - LiveView displays error message

### Cross-Boundary Interactions

| Boundary | Source | Target | Test Strategy |
|----------|--------|--------|---------------|
| LiveComponent → CommandHandler | RemoveItem.Component | RemoveItem.CommandHandler | Unit test CommandHandler; LiveView test for component |
| CommandHandler → EventStore | CommandHandler.handle/1 | EventStore.append_to_stream/3 | Integration test verifying event appended |
| CommandHandler → Cart | CommandHandler.handle/1 | Cart.get_cart_items/1 | Unit test state reconstruction |
| EventStore → PubSub | EventStore broadcast | CartLive subscription | LiveView test for real-time update |

### Dependencies & Configuration

- **Existing**: `Epoch.Cart.Events.ItemRemoved` event type already defined
- **Existing**: `Epoch.Cart.CartItemsView` already handles ItemRemoved in `evolve/2`
- **Existing**: EventStore broadcasts to `stream_type:cart` topic on append
- **New**: CartLive must subscribe to cart stream PubSub topic for real-time updates
- **No new configuration required**

### Failure Handling

| Failure Mode | Strategy | Logging |
|--------------|----------|---------|
| Item not found in cart | Return `{:error, :item_not_found}`, display flash message | Log warning with item_id and session_id |
| EventStore append failure | Return `{:error, reason}`, display "Unable to remove item" flash | Log error with event details |
| PubSub broadcast failure | Non-blocking (EventStore handles internally) | EventStore logs broadcast errors |

### Demo Data

No changes to seeds.exs required - cart sessions are created dynamically per browser session.

### Required Skills

- `elixir-core`: Pattern matching, tagged tuples, function design
- `phoenix-liveview`: LiveComponent, handle_event, PubSub subscription in mount
- `phoenix-html`: HEEx templates, button with phx-click and phx-target
- `elixir-testing`: ExUnit, Phoenix.LiveViewTest

## Project Structure

### Documentation (this feature)

```text
specs/010-remove-cart-item/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
apps/
├── epoch/
│   └── lib/epoch/
│       └── cart/
│           ├── cart.ex              # Existing - may need remove_item/2 function
│           ├── cart_items_view.ex   # Existing - already handles ItemRemoved
│           └── events/
│               └── item_removed.ex  # Existing - ItemRemoved event defined
└── epoch_web/
    ├── lib/epoch_web/
    │   ├── live/
    │   │   ├── cart_live.ex         # Modify: add PubSub subscription
    │   │   └── cart_live.html.heex  # Modify: add remove button to each item
    │   └── slices/
    │       └── remove_item/         # NEW: vertical slice
    │           ├── command.ex       # RemoveItem command struct
    │           ├── command_handler.ex # Business logic + event append
    │           └── component.ex     # LiveComponent for remove button
    └── test/epoch_web/
        └── slices/
            └── remove_item_test.exs # NEW: unit + integration tests
```

**Structure Decision**: Following the existing vertical-slice pattern established by `add_item` slice. New files are created in `slices/remove_item/` directory. Cart context and event types already exist and will be reused.

## Complexity Tracking

> No violations - implementation follows existing patterns.
