# Feature Specification: Display Cart Items

**Feature Branch**: `009-display-cart-items`  
**Created**: 2025-11-26  
**Status**: Draft  
**Input**: User description: "Display the items in a cart, based on this page ./tmp/course-implementing-eventsourcing/app/cart/page.tsx"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Cart Items (Priority: P1)

As a shopper, I want to see all items currently in my shopping cart so that I can review what I'm about to purchase.

**Why this priority**: This is the core functionality - without displaying cart items, users cannot review their selections before checkout. It's the foundation for any cart experience.

**Independent Test**: Can be fully tested by adding items to a cart and navigating to the cart page. Delivers immediate value by showing users their cart contents.

**Acceptance Scenarios**:

1. **Given** a cart with items has been populated via ItemAdded events, **When** the user views the cart page, **Then** each item displays with its name and price
2. **Given** a cart with multiple items, **When** the user views the cart page, **Then** all items are displayed in a list format with clear visual separation
3. **Given** a cart with items, **When** the user views the cart page, **Then** each item's price is formatted as currency (e.g., $10.00)

---

### User Story 2 - View Cart Total (Priority: P1)

As a shopper, I want to see the total cost of all items in my cart so that I know how much I'll be paying.

**Why this priority**: The cart total is essential information for purchase decisions. Users need to see aggregate cost alongside individual items.

**Independent Test**: Can be tested by adding items with known prices and verifying the sum is displayed correctly.

**Acceptance Scenarios**:

1. **Given** a cart with multiple items, **When** the user views the cart page, **Then** the total price is displayed as the sum of all item prices
2. **Given** a cart with items totaling $45.50, **When** the user views the cart page, **Then** the total displays as "$45.50"

---

### User Story 3 - View Empty Cart State (Priority: P2)

As a shopper, I want to see a clear message when my cart is empty so that I understand there are no items to purchase.

**Why this priority**: Provides clear feedback for edge case. Important for UX but secondary to displaying actual items.

**Independent Test**: Can be tested by viewing the cart page with no ItemAdded events for the session.

**Acceptance Scenarios**:

1. **Given** a cart with no items, **When** the user views the cart page, **Then** a message "Your cart is empty" is displayed
2. **Given** a cart with no items, **When** the user views the cart page, **Then** the items table and total are not displayed

---

### User Story 4 - Cart Reflects Item Removal (Priority: P2)

As a shopper, I want the cart display to reflect items that have been removed so that I see an accurate representation of my cart.

**Why this priority**: Ensures data consistency between events and display. Users expect removed items to disappear from the view.

**Independent Test**: Can be tested by adding items, then processing an ItemRemoved event and verifying the item no longer appears.

**Acceptance Scenarios**:

1. **Given** a cart with item "Widget" and an ItemRemoved event for "Widget", **When** the user views the cart page, **Then** "Widget" does not appear in the cart
2. **Given** a cart with items A and B where item A was removed, **When** the user views the cart page, **Then** only item B appears and total reflects only item B's price

---

### User Story 5 - Cart Reflects Cart Cleared (Priority: P3)

As a shopper, I want the cart display to be empty after the cart has been cleared so that I see an accurate state.

**Why this priority**: Handles the clear cart action. Lower priority as it's less common than individual item operations.

**Independent Test**: Can be tested by adding items, processing a CartCleared event, and verifying empty cart state displays.

**Acceptance Scenarios**:

1. **Given** a cart with items followed by a CartCleared event, **When** the user views the cart page, **Then** the empty cart message is displayed
2. **Given** a cart cleared event, **When** the user views the cart page, **Then** the total is not displayed

---

### Edge Cases

- What happens when the same item is added multiple times? (Assumption: Each ItemAdded event creates a separate line item)
- How does the system handle items with zero or negative prices? (Assumption: Prices are always positive; validation occurs at event creation)
- What happens if the cart stream has no events yet? (Display empty cart state)
- How does the system handle archived items? (ItemArchived events should remove the item from display)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a list of all active cart items derived from the cart event stream
- **FR-002**: System MUST display the name and price for each cart item
- **FR-003**: System MUST display prices formatted as currency with two decimal places (e.g., $10.00)
- **FR-004**: System MUST display a cart total that sums all active item prices
- **FR-005**: System MUST display an empty cart message when no active items exist
- **FR-006**: System MUST process ItemAdded events to add items to the cart display
- **FR-007**: System MUST process ItemRemoved events to remove items from the cart display
- **FR-008**: System MUST process CartCleared events to clear all items from the cart display
- **FR-009**: System MUST process ItemArchived events to remove archived items from the cart display
- **FR-010**: System MUST rebuild cart state from the event stream on page load

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: EventStore - The existing in-memory event store (from Feature 001) must be available. Cart events are read from the Cart stream. Tests will fail if EventStore is not running or Cart stream is unavailable.
- **Dependency**: Cart Event Types - ItemAdded, ItemRemoved, CartCleared, and ItemArchived event types must be defined. Tests will fail if event types are missing or malformed.
- **Configuration**: Session/Aggregate ID - The cart is identified by a session or aggregate ID passed to the view component. If not provided, cart cannot be loaded.

### Key Entities *(include if feature involves data)*

- **CartItem**: Represents an item in the shopping cart. Key attributes: itemId (unique identifier), name (display name), price (numeric value). Derived from ItemAdded events.
- **Cart Event Stream**: The sequence of events (ItemAdded, ItemRemoved, CartCleared, ItemArchived) that represents the cart's history. Read from EventStore using Cart stream identifier.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test that cartItemsStateView returns empty list when given empty event list
- Test that cartItemsStateView adds item when processing ItemAdded event
- Test that cartItemsStateView removes item when processing ItemRemoved event with matching itemId
- Test that cartItemsStateView clears all items when processing CartCleared event
- Test that cartItemsStateView removes item when processing ItemArchived event
- Test that cartItemsStateView correctly processes a sequence of mixed events
- Test that cart total calculation sums all item prices correctly
- Test that cart total is zero when cart is empty

### Integration Tests *(required for each cross-boundary interaction)*

- Test that cart page loads and displays items from EventStore
- Test that cart page displays empty state when no events exist for cart
- Test that cart page correctly renders item names and formatted prices
- Test that cart page displays correct total after processing events
- Test real-time updates when new events are appended to cart stream (if applicable)

## Failure Modes & Observability *(mandatory)*

- **EventStore unavailable**: If the event store cannot be reached, display an error message to the user and log the failure. The cart page should not crash.
- **Invalid event data**: If an event in the stream has malformed data (missing name or price), skip the event and log a warning. Continue processing remaining events.
- **Empty stream**: If no events exist for the cart stream, this is not an error - display the empty cart state.
- **Logging**: Log when cart state is rebuilt, including number of events processed and final item count. Log any skipped events due to validation failures.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can view all items in their cart within 1 second of page load
- **SC-002**: Cart total accurately reflects the sum of all displayed item prices (100% accuracy)
- **SC-003**: Empty cart state displays appropriately when no items exist
- **SC-004**: Cart display correctly reflects all event types (ItemAdded, ItemRemoved, CartCleared, ItemArchived)
- **SC-005**: Users can clearly distinguish individual items in the cart list

## Assumptions

- Each ItemAdded event creates a distinct line item (no quantity aggregation)
- Prices in events are already validated and always positive numeric values
- The cart stream identifier (session/aggregate ID) is provided by the calling context
- Currency is assumed to be USD; no multi-currency support required
- Cart state is rebuilt from events on each page load (no caching)
