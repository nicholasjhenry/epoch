# Feature Specification: Submit Cart

**Feature Branch**: `015-submit-cart`  
**Created**: 2025-12-02  
**Status**: Draft  
**Input**: User description: "Submitting the cart. Given an item added to the cart When submitting the cart Then the cart is submitted. Given an item added to the cart And an Inventory Updated event for that cart item product is set to 0 Then an error is returned. Base the implementation on ./tmp/implementing-eventsourcing"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Submit Cart with Available Inventory (Priority: P1)

A shopper has added items to their cart and wants to complete their order by submitting the cart. The system validates that all items in the cart have available inventory before allowing the submission to proceed.

**Why this priority**: This is the primary happy path for cart submission - the core functionality that enables customers to complete their purchases.

**Independent Test**: Can be fully tested by adding an item to the cart, ensuring inventory is available, and submitting the cart. Delivers the core checkout value.

**Acceptance Scenarios**:

1. **Given** an item has been added to the cart, **And** the product has inventory greater than 0, **When** the shopper submits the cart, **Then** the cart is submitted successfully **And** a CartSubmitted event is recorded.

2. **Given** multiple items have been added to the cart, **And** all products have inventory greater than 0, **When** the shopper submits the cart, **Then** the cart is submitted successfully.

---

### User Story 2 - Reject Cart Submission When Product Out of Stock (Priority: P1)

A shopper attempts to submit a cart containing a product that is no longer in stock. The system prevents submission and notifies the shopper of the inventory issue.

**Why this priority**: Equal priority with P1 as this validation is critical for business integrity - prevents overselling and ensures customer trust.

**Independent Test**: Can be fully tested by adding an item to the cart, setting that product's inventory to 0, and attempting to submit. Validates inventory enforcement.

**Acceptance Scenarios**:

1. **Given** an item has been added to the cart, **And** an InventoryUpdated event for that cart item's product sets inventory to 0, **When** the shopper attempts to submit the cart, **Then** an error is returned **And** the cart is not submitted.

2. **Given** multiple items have been added to the cart, **And** one of the products has inventory set to 0, **When** the shopper attempts to submit the cart, **Then** an error is returned indicating which product is out of stock.

---

### User Story 3 - Reject Cart Submission When Cart is Empty (Priority: P1)

A shopper attempts to submit a cart that contains no items. The system prevents submission and notifies the shopper that the cart is empty.

**Why this priority**: Critical validation to prevent invalid orders and provide clear user feedback.

**Independent Test**: Can be fully tested by attempting to submit a cart with no items added. Validates empty cart handling.

**Acceptance Scenarios**:

1. **Given** no items in the cart, **When** the shopper attempts to submit the cart, **Then** an error is returned **And** the cart is not submitted.

---

### User Story 4 - Submit Cart After Item Removal (Priority: P2)

A shopper has removed some items from their cart (or items were archived due to price changes). The system only validates inventory for items currently in the cart.

**Why this priority**: Secondary scenario that handles edge cases from other cart operations.

**Independent Test**: Can be tested by adding items, removing one, and submitting. Validates cart state reconstruction.

**Acceptance Scenarios**:

1. **Given** items have been added and some removed from the cart, **And** remaining products have inventory greater than 0, **When** the shopper submits the cart, **Then** the cart is submitted successfully for the remaining items.

2. **Given** items have been added and the cart has been cleared, **When** the shopper attempts to submit the cart, **Then** an error is returned (empty cart).

---

### Edge Cases

- What happens when a product in the cart has no inventory record at all? (Treated as 0 inventory - submission rejected)
- What happens when submitting an empty cart? (Submission should fail gracefully)
- What happens when inventory changes between loading the cart view and clicking submit? (Validation occurs at submission time using current inventory state)
- How does the system handle archived items in the cart? (Archived items are excluded from submission validation)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST validate inventory availability for all active cart items before allowing submission
- **FR-002**: System MUST reject cart submission when any cart item's product has 0 inventory
- **FR-003**: System MUST emit a CartSubmitted event when cart submission succeeds
- **FR-004**: System MUST return an error when cart submission fails due to insufficient inventory
- **FR-005**: System MUST reconstruct current cart contents by processing ItemAdded, ItemRemoved, ItemArchived, and CartCleared events
- **FR-006**: System MUST read current inventory state from InventoryUpdated events to validate stock levels
- **FR-007**: System MUST exclude removed and archived items from inventory validation
- **FR-008**: System MUST reject cart submission when the cart is empty (no active items)

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: EventStore - Used to read cart events (cart stream) and inventory events (inventory stream). Cart submission command handler requires access to both streams. Tests will fail without EventStore being available.
- **Dependency**: Cart Events - Depends on existing ItemAdded, ItemRemoved, ItemArchived, and CartCleared event types from previous features.
- **Dependency**: Inventory Events - Depends on InventoryUpdated event type from Feature 012 (Update Inventory).
- **Configuration**: Cart stream naming convention - Uses `cart-{cart_id}` format for reading cart state.
- **Configuration**: Inventory stream naming convention - Uses `inventory-{product_id}` format for reading inventory state.

### Key Entities *(include if feature involves data)*

- **Cart**: Represents the shopping cart, identified by cart_id (aggregate_id). Contains items that can be added, removed, or archived.
- **CartItem**: An item in the cart, linked to a product_id. State determined by processing cart events.
- **Inventory**: Current stock level for a product, derived from InventoryUpdated events.
- **CartSubmitted Event**: Event emitted when cart is successfully submitted, containing the cart's aggregate_id.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test: Submit cart with single item and sufficient inventory returns CartSubmitted event
- Test: Submit cart with multiple items and sufficient inventory returns CartSubmitted event
- Test: Submit cart when product inventory is 0 raises error
- Test: Submit cart when product has no inventory record raises error
- Test: Submit cart correctly excludes removed items from validation
- Test: Submit cart correctly excludes archived items from validation
- Test: Submit cart with no items (empty cart) raises error
- Test: Submit cart after CartCleared event raises error (empty cart)
- Test: Cart state view correctly reconstructs active items from event sequence

### Integration Tests *(required for each cross-boundary interaction)*

- Test: Command handler reads from cart stream and inventory stream correctly
- Test: CartSubmitted event is appended to cart stream on successful submission
- Test: End-to-end flow from UI button click through event store persistence

## Failure Modes & Observability *(mandatory)*

- **Empty Cart**: When the cart has no active items, command handler throws an error. The UI should display an appropriate message to the user.
- **Insufficient Inventory**: When a product has 0 inventory, command handler throws an error with message "Cannot order products without quantity". The UI should catch this and display an appropriate error message to the user.
- **Missing Inventory Record**: When a product has no inventory events, it is treated as 0 inventory and submission is rejected.
- **Event Store Unavailable**: If event store is unavailable, the submission will fail. Standard error handling should apply.
- **Logging**: Cart submission attempts (success/failure) should be logged with cart_id and product_ids for debugging.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully submit a cart with in-stock items in a single action
- **SC-002**: Users receive clear feedback when cart submission fails due to out-of-stock items
- **SC-003**: Cart submission validation completes within acceptable response time (under 1 second for typical cart sizes)
- **SC-004**: 100% of cart submissions with out-of-stock items are prevented from completing
- **SC-005**: Users receive clear feedback when attempting to submit an empty cart

## Assumptions

- The inventory state is derived solely from InventoryUpdated events, not from a separate inventory database
- Cart items are uniquely identified by product_id within a cart
- The cart stream and inventory streams follow the naming conventions established in previous features
- A product with no inventory events is considered to have 0 inventory (fail-safe approach)
