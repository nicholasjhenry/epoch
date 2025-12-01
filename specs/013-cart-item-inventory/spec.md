# Feature Specification: Display Cart Item Inventory

**Feature Branch**: `013-cart-item-inventory`  
**Created**: 2025-11-27  
**Status**: Draft  
**Input**: User description: "Display the available inventory (i.e. quantity) next to matching product in the cart, i.e. cart item"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Available Inventory While Shopping (Priority: P1)

As a shopper viewing my cart, I want to see the available inventory quantity for each product in my cart so that I can make informed purchasing decisions and understand product availability before checkout.

**Why this priority**: This is the core feature request. Without showing inventory quantities, the entire feature has no value. This enables users to see stock levels which directly impacts their purchasing confidence and decisions.

**Independent Test**: Can be fully tested by adding items to a cart and verifying that the available inventory quantity appears next to each cart item. Delivers immediate value by informing users of product availability.

**Acceptance Scenarios**:

1. **Given** a cart contains items and each product has inventory tracked, **When** the user views the cart, **Then** each cart item displays the available inventory quantity for that product.
2. **Given** a cart contains an item for a product with 5 units in inventory, **When** the user views the cart, **Then** the cart item shows "5 available" or similar indicator next to the product.
3. **Given** a cart contains multiple items of the same product, **When** the user views the cart, **Then** the available inventory shown reflects the total inventory (not reduced by cart quantity).

---

### User Story 2 - Real-time Inventory Updates (Priority: P2)

As a shopper viewing my cart, I want the available inventory to update in real-time so that I always see the current stock level without refreshing the page.

**Why this priority**: Provides a better user experience by keeping information current, but the core functionality (displaying inventory) works without real-time updates.

**Independent Test**: Can be tested by viewing cart in one browser, updating inventory in another session, and verifying the cart view updates automatically.

**Acceptance Scenarios**:

1. **Given** a user is viewing their cart with inventory displayed, **When** the inventory for a product in the cart changes (e.g., stock is updated), **Then** the displayed inventory quantity updates without requiring a page refresh.
2. **Given** a user is viewing their cart, **When** inventory is updated for a product not in their cart, **Then** the cart view remains unchanged.

---

### User Story 3 - Low Stock Visual Indicator (Priority: P3)

As a shopper, I want a visual indicator when inventory is low so that I can prioritize purchasing items that may soon be unavailable.

**Why this priority**: Enhances user experience with visual cues but is not essential for the core feature of displaying inventory quantities.

**Independent Test**: Can be tested by adding a low-stock item to cart and verifying visual differentiation appears.

**Acceptance Scenarios**:

1. **Given** a cart item has a product with inventory of 5 or fewer units, **When** the user views the cart, **Then** the inventory quantity is visually highlighted (e.g., different color, icon, or text style).
2. **Given** a cart item has a product with inventory greater than 5 units, **When** the user views the cart, **Then** the inventory quantity displays in standard styling.

---

### Edge Cases

- What happens when a product in the cart has no inventory record? Display "Unknown" or "0 available" with appropriate styling.
- What happens when inventory becomes 0 while viewing the cart? Display "Out of stock" indicator and update in real-time if P2 is implemented.
- What happens when a product is added to cart but inventory hasn't been initialized? Treat as 0 inventory and display accordingly.
- How does this interact with multiple users adding the same product to their carts? Each user sees the same global available inventory; cart quantities do not reserve stock.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display the available inventory quantity for each product shown in the cart items list.
- **FR-002**: System MUST show inventory as a numeric quantity (e.g., "5 available") next to each cart item.
- **FR-003**: System MUST retrieve current inventory from the existing inventory system for each product in the cart.
- **FR-004**: System MUST handle products with no inventory record by displaying "0 available" or equivalent indicator.
- **FR-005**: System MUST update the displayed inventory in real-time when inventory changes for products in the cart.
- **FR-006**: System MUST visually differentiate low stock items (5 or fewer units) from items with normal stock levels.
- **FR-007**: System MUST display "Out of stock" when inventory quantity is 0.

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: Epoch.Backoffice.Inventory - Provides `get_quantity/1` function to retrieve current inventory for a product_id. Without this, inventory cannot be displayed. Tests for cart item display will fail if this module is unavailable.
- **Dependency**: Epoch.Cart - Provides `get_cart_items/1` function to retrieve cart items. Must include product_id in returned data structure for inventory lookup. Tests for cart display will fail if product_id is not available.
- **Dependency**: Phoenix.PubSub (Epoch.PubSub) - Used for real-time inventory updates. If unavailable, initial load will work but updates will not propagate. Connection failure should gracefully degrade to showing last known inventory.
- **Configuration**: Low stock threshold - Default value of 5 units. Configured at application level. If configuration is missing, uses default of 5.

### Key Entities *(include if feature involves data)*

- **Cart Item (Display)**: Represents a line item in the cart view. Key attributes: item_id, product_id, name, price, available_inventory (new attribute).
- **Inventory State**: Represents the current stock level for a product. Key attributes: product_id, quantity. Relationship: One inventory state per product; cart items reference products via product_id.
- **Product**: The catalog item being purchased. Relationship: A cart item references one product; a product has one inventory state.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test that cart item display includes available_inventory field when inventory exists
- Test that cart item display shows 0 for products with no inventory record
- Test that low stock threshold correctly identifies items with 5 or fewer units
- Test that inventory quantity formatting displays correctly (e.g., "5 available")
- Test that "Out of stock" displays when quantity is 0

### Integration Tests *(required for each cross-boundary interaction)*

- Test that CartItems LiveView fetches and displays inventory from Epoch.Backoffice.Inventory
- Test that inventory updates via PubSub propagate to cart display in real-time
- Test that cart with multiple items correctly shows inventory for each product
- Test that adding item to cart displays correct inventory immediately
- Test end-to-end flow: inventory update triggers PubSub event, LiveView receives and updates display

## Failure Modes & Observability *(mandatory)*

- **Inventory service unavailable**: If Epoch.Backoffice.Inventory fails to return quantity, display "Unknown" and log warning. Cart functionality continues without blocking.
- **PubSub subscription failure**: If real-time subscription fails, log error and continue with static inventory display. Users can refresh to get current values.
- **Product not found in inventory**: When no inventory record exists for a product_id, treat as 0 quantity and display "Out of stock". Log info-level message for tracking.
- **Timeout on inventory fetch**: If inventory fetch exceeds reasonable timeout (default 5 seconds), display cached/last-known value or "Unknown". Log warning with product_id for investigation.
- **Observability**: Log all inventory fetch failures with product_id and error reason. Track metrics for inventory fetch latency and error rates.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see available inventory for all cart items within 1 second of the cart loading.
- **SC-002**: Inventory display updates within 2 seconds of an inventory change event occurring.
- **SC-003**: 100% of cart items display either a numeric inventory value, "Out of stock", or "Unknown" (no missing/blank inventory displays).
- **SC-004**: Users can identify low-stock items (5 or fewer) at a glance through visual differentiation.
- **SC-005**: Cart page remains fully functional even when inventory service experiences issues (graceful degradation).

## Assumptions

- The existing `Epoch.Backoffice.Inventory.get_quantity/1` API is performant enough to call for each cart item without significant latency.
- Cart items can be enhanced to include `product_id` in the view model returned by `Cart.get_cart_items/1`.
- The PubSub topic for inventory events follows the pattern `"stream_type:inventory"` or similar, consistent with existing patterns.
- Low stock threshold of 5 units is an appropriate default for this e-commerce domain.
- Inventory quantity shown is the global available stock, not reduced by the current user's cart quantities (cart does not reserve stock).
