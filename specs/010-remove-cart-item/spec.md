# Feature Specification: Remove Item from Cart

**Feature Branch**: `010-remove-cart-item`  
**Created**: 2025-11-26  
**Status**: Draft  
**Input**: User description: "Remove an item from the cart"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remove Single Item from Cart (Priority: P1)

As a shopper, I want to remove an item from my cart so that I can change my mind about a purchase before checkout.

**Why this priority**: This is the core functionality - allowing users to remove items they no longer want is essential for any shopping cart experience.

**Independent Test**: Can be fully tested by adding items to a cart, clicking remove on one item, and verifying it disappears from the cart display.

**Acceptance Scenarios**:

1. **Given** a cart with item "Widget" displayed, **When** the user clicks the remove button for "Widget", **Then** "Widget" is removed from the cart display
2. **Given** a cart with items "Widget" ($10.00) and "Gadget" ($15.00), **When** the user removes "Widget", **Then** only "Gadget" remains and the cart total updates to $15.00
3. **Given** a cart with a single item, **When** the user removes that item, **Then** the empty cart state is displayed

---

### User Story 2 - Visual Feedback on Item Removal (Priority: P2)

As a shopper, I want to see immediate feedback when I remove an item so that I know my action was successful.

**Why this priority**: Provides essential user experience feedback. Users need confirmation that their action was processed.

**Independent Test**: Can be tested by removing an item and observing the UI updates immediately without page reload.

**Acceptance Scenarios**:

1. **Given** a cart with items displayed, **When** the user clicks remove on an item, **Then** the item disappears from the list immediately (within 500ms)
2. **Given** a cart with items, **When** the user removes an item, **Then** the cart total updates immediately to reflect the removal

---

### User Story 3 - Remove Button Accessibility (Priority: P2)

As a shopper, I want each cart item to have a clearly visible remove option so that I can easily identify how to remove items.

**Why this priority**: Usability is important - users should not have to hunt for the remove action.

**Independent Test**: Can be tested by viewing the cart and verifying each item has a visible, accessible remove control.

**Acceptance Scenarios**:

1. **Given** a cart with multiple items displayed, **When** the user views the cart, **Then** each item row displays a remove button or link
2. **Given** a cart item row, **When** the user views the item, **Then** the remove control is visually distinct and clearly labeled

---

### Edge Cases

- What happens when the user tries to remove an item that does not exist in the cart? The system should return an error indicating the item was not found.
- What happens if the remove action fails due to a system error? Display an error message and keep the item in the cart display.
- What happens when removing the last item in the cart? Transition to empty cart state with "Your cart is empty" message.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a remove control (button or link) for each item in the cart
- **FR-002**: System MUST emit an ItemRemoved event when a user initiates item removal
- **FR-003**: The ItemRemoved event MUST contain the itemId of the item being removed
- **FR-004**: System MUST update the cart display to remove the item after successful event emission
- **FR-005**: System MUST update the cart total to exclude the removed item's price
- **FR-006**: System MUST display the empty cart state when the last item is removed
- **FR-007**: System MUST return an error when attempting to remove an item that does not exist in the cart

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: EventStore - The existing in-memory event store (from Feature 001) must be available for appending ItemRemoved events. Tests will fail if EventStore is not running.
- **Dependency**: Cart Display (Feature 009) - The cart item display must be implemented, as remove buttons are added to each cart item row. Tests will fail if cart display is not functional.
- **Dependency**: ItemRemoved Event Type - Must be defined with itemId field. Tests will fail if event type is missing or malformed.
- **Configuration**: Cart Stream ID - The cart is identified by a session or aggregate ID. Remove events are appended to this stream.

### Key Entities *(include if feature involves data)*

- **ItemRemoved Event**: Event emitted when a user removes an item from the cart. Key attributes: itemId (identifier of the item to remove), timestamp (when removal occurred).
- **CartItem**: The item being removed, identified by its itemId. Must match an existing item in the cart.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test that clicking remove button emits ItemRemoved event with correct itemId
- Test that cart state removes item when processing ItemRemoved event
- Test that cart total recalculates after item removal
- Test that removing last item results in empty cart state
- Test that removing a non-existent item returns an error

### Integration Tests *(required for each cross-boundary interaction)*

- Test that remove button click appends ItemRemoved event to EventStore
- Test that cart display updates after ItemRemoved event is appended
- Test that cart total updates correctly after item removal
- Test that empty cart state displays when last item is removed
- Test LiveView updates cart in real-time after removal action

## Failure Modes & Observability *(mandatory)*

- **EventStore unavailable**: If the event store cannot append the ItemRemoved event, display an error message to the user ("Unable to remove item. Please try again.") and keep the item in the cart display. Log the failure with event details.
- **Invalid itemId**: If an ItemRemoved event references an itemId not in the current cart, return an error to the caller indicating the item was not found. Display an error message to the user ("Item not found in cart.").
- **Logging**: Log when ItemRemoved events are emitted, including itemId and cart stream ID. Log any failures during event append.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can remove any item from their cart with a single click/tap
- **SC-002**: Cart display updates within 500ms of removal action
- **SC-003**: Cart total accurately reflects remaining items after removal (100% accuracy)
- **SC-004**: Remove action is available and visible for every item in the cart
- **SC-005**: Users successfully complete item removal on first attempt (no confusion about how to remove)

## Assumptions

- The ItemRemoved event type is already defined (from Feature 009 cart display requirements)
- Items are identified by a unique itemId that is consistent between ItemAdded and ItemRemoved events
- No confirmation dialog is required before removal (immediate action)
- Undo functionality is not required for this feature
- The remove control will be a button or link within each cart item row
