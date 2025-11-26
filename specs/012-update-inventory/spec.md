# Feature Specification: Update Product Inventory

**Feature Branch**: `012-update-inventory`  
**Created**: 2025-11-26  
**Status**: Draft  
**Input**: User description: "Update the product inventory - Inventory management involves update quantity for a product id"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Update Inventory Quantity (Priority: P1)

As a store administrator, I want to update the inventory quantity for a specific product so that the system accurately reflects the current stock levels.

**Why this priority**: Core inventory management functionality - without the ability to update quantities, the system cannot track stock accurately.

**Independent Test**: Can be fully tested by updating a product's quantity and verifying the new quantity is persisted and retrievable.

**Acceptance Scenarios**:

1. **Given** a product exists with product_id "espresso-blend", **When** an administrator updates the quantity to 50, **Then** the product's inventory quantity is set to 50
2. **Given** a product exists with product_id "french-roast" and quantity 30, **When** an administrator updates the quantity to 0, **Then** the product's inventory quantity is set to 0 (out of stock)

---

### Edge Cases

- What happens when updating quantity with a negative number? System rejects negative quantities with a validation error.
- What happens when updating quantity with a non-integer value? System rejects non-integer quantities with a validation error.
- What happens when updating quantity for a product while a customer has it in their cart? The cart retains the item; availability is checked at checkout time.
- What happens when quantity exceeds maximum storage capacity? System accepts any non-negative integer; business limits are handled separately.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow updating the inventory quantity for a product identified by product_id
- **FR-002**: System MUST validate that quantity is a non-negative integer (0 or greater)
- **FR-003**: System MUST return an error when attempting to update inventory for a non-existent product
- **FR-004**: System MUST persist inventory quantity changes so they survive system restarts
- **FR-005**: System MUST provide a way to retrieve the current inventory quantity for a specific product
- **FR-006**: System MUST return 0 as the default quantity for products without an existing inventory record
- **FR-007**: System MUST include inventory quantity when listing products

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: Catalog Context - The inventory system depends on the existing Catalog module to validate that product_ids exist. Tests will fail if Catalog.get_product/1 is unavailable.
- **Dependency**: EventStore - Inventory updates will be persisted as events. Tests will fail if EventStore is unavailable or misconfigured.

### Key Entities *(include if feature involves data)*

- **Inventory**: Represents the stock level for a product. Key attributes: product_id (reference to Product), quantity (non-negative integer representing units in stock).
- **Product**: Existing entity in Catalog context. Inventory references products by product_id.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test updating inventory quantity for a valid product_id succeeds
- Test updating inventory quantity to 0 succeeds (out of stock)
- Test updating inventory quantity with negative value fails validation
- Test retrieving inventory quantity for a product with existing record
- Test retrieving inventory quantity for a product without record returns 0
- Test listing products includes inventory quantities

### Integration Tests *(required for each cross-boundary interaction)*

- Test inventory updates are persisted to EventStore
- Test inventory state is recovered after system restart
- Test concurrent inventory updates are handled correctly

## Failure Modes & Observability *(mandatory)*

- **Invalid product_id**: System logs warning and returns {:error, :not_found} to caller
- **Invalid quantity (negative/non-integer)**: System returns {:error, :invalid_quantity} with descriptive message
- **EventStore unavailable**: System logs error and returns {:error, :persistence_failed}; operation can be retried
- **Logging**: All inventory updates log product_id, old quantity, new quantity, and timestamp
- **Trace context**: Inventory operations include correlation IDs for debugging

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can update any product's inventory quantity in under 1 second
- **SC-002**: Inventory quantities persist correctly across system restarts with 100% accuracy
- **SC-003**: System correctly rejects 100% of invalid quantity values (negative or non-integer)
- **SC-004**: Inventory queries return current quantities within 500ms
- **SC-005**: All products in the catalog display their current inventory level when listed
