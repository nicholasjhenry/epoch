# Feature Specification: Price Change TODO List & Automation

**Feature Branch**: `014-price-change-automation`  
**Created**: 2025-12-01  
**Status**: Draft  
**Input**: User description: "Implement Price Change TODO List & Automation based on ./tmp/implementing-eventsourcing. An external Price changed event published from the backoffice (same page as inventory change) is consumed by a translator invoking a ChangePrice command, emitting an internal PriceChanged event. A read model 'products with price changes' is built from PriceChanged events along with a 'carts with products' read model built from cart related events. These read models are consumed by Item Archiver automation which invokes a Request to archive event, emitting an Item Archive Requested event. This event is used to build an Items to archive read model. The Item archiver invokes an archive item command, emitting an Item Archived event updating the cart items read model used when viewing the cart."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publish Price Change from Backoffice (Priority: P1)

As a store administrator, I want to publish a price change for a product from the backoffice so that the system can track products with changed prices and take appropriate actions on affected carts.

**Why this priority**: This is the entry point for the entire price change workflow. Without the ability to publish price changes, no downstream automation can occur.

**Independent Test**: Can be fully tested by publishing a price change event for a product and verifying a PriceChanged event is emitted to the internal event stream.

**Acceptance Scenarios**:

1. **Given** a product exists with product_id "espresso-blend", **When** an administrator changes the price to $15.99 in the backoffice, **Then** an external PriceChanged event is published and translated to an internal PriceChanged event.
2. **Given** a price change is published for product_id "french-roast", **When** the translator processes the external event, **Then** a ChangePrice command is invoked and an internal PriceChanged event is emitted to the price stream.

---

### User Story 2 - Track Products with Price Changes (Priority: P2)

As the system, I want to maintain a read model of products with price changes so that downstream automations can identify which products have had their prices modified.

**Why this priority**: The "products with price changes" read model is essential for the Item Archiver automation to identify affected products. Without it, the automation cannot determine which cart items need archiving.

**Independent Test**: Can be tested by publishing price change events and verifying the read model correctly tracks all products with price changes.

**Acceptance Scenarios**:

1. **Given** a PriceChanged event is emitted for product_id "espresso-blend", **When** the read model is updated, **Then** the "products with price changes" read model includes "espresso-blend".
2. **Given** multiple PriceChanged events are emitted for different products, **When** the read model is queried, **Then** it returns all products that have had price changes.

---

### User Story 3 - Track Carts with Products (Priority: P2)

As the system, I want to maintain a read model of carts with their products so that the Item Archiver automation can identify which carts contain products affected by price changes.

**Why this priority**: The "carts with products" read model is essential for correlating price changes with affected cart items. Without it, the system cannot determine which cart items need to be archived.

**Independent Test**: Can be tested by adding items to carts and verifying the read model correctly tracks cart-to-product relationships.

**Acceptance Scenarios**:

1. **Given** a user adds product "espresso-blend" to cart "cart-123", **When** the read model is updated, **Then** the "carts with products" read model shows cart "cart-123" contains product "espresso-blend".
2. **Given** a user removes an item from a cart, **When** the read model is updated, **Then** the cart no longer shows that product.
3. **Given** a user clears their cart, **When** the read model is updated, **Then** the cart shows no products.

---

### User Story 4 - Request Item Archive on Price Change (Priority: P1)

As the system, when a product's price changes, I want to automatically request archiving of that item in all affected carts so that customers see updated pricing or are notified of changes.

**Why this priority**: This is the core automation that ties price changes to cart item archival. It's the primary business value of this feature.

**Independent Test**: Can be tested by publishing a price change for a product that exists in one or more carts and verifying ItemArchiveRequested events are emitted for each affected cart item.

**Acceptance Scenarios**:

1. **Given** cart "cart-123" contains product "espresso-blend" and a PriceChanged event occurs for "espresso-blend", **When** the Item Archiver automation runs, **Then** an ItemArchiveRequested event is emitted for that cart item.
2. **Given** product "french-roast" exists in multiple carts, **When** a PriceChanged event occurs for "french-roast", **Then** ItemArchiveRequested events are emitted for each cart containing that product.
3. **Given** a price change occurs for a product not in any cart, **When** the Item Archiver automation runs, **Then** no ItemArchiveRequested events are emitted.

---

### User Story 5 - Build Items to Archive TODO List (Priority: P2)

As the system, I want to maintain a TODO list (read model) of items pending archive so that the archive process can track and complete archival of all affected items.

**Why this priority**: The "items to archive" read model provides visibility into pending work and enables the archival process to track completion.

**Independent Test**: Can be tested by emitting ItemArchiveRequested events and verifying they appear in the TODO list, then verifying they are removed when archived.

**Acceptance Scenarios**:

1. **Given** an ItemArchiveRequested event is emitted, **When** the read model is updated, **Then** the item appears in the "items to archive" TODO list.
2. **Given** an item exists in the TODO list and an ItemArchived event is emitted, **When** the read model is updated, **Then** the item is removed from the TODO list.

---

### User Story 6 - Archive Cart Items (Priority: P1)

As the system, I want to automatically archive cart items that have pending archive requests so that the cart items read model reflects the archived state.

**Why this priority**: This completes the automation loop by actually archiving items, which updates the cart view for customers.

**Independent Test**: Can be tested by creating archive requests and verifying the archive command is invoked, emitting ItemArchived events that update the cart items read model.

**Acceptance Scenarios**:

1. **Given** an item exists in the "items to archive" TODO list, **When** the Item Archiver processor runs, **Then** an ArchiveItem command is invoked and an ItemArchived event is emitted.
2. **Given** an ItemArchived event is emitted for a cart item, **When** the cart items read model is updated, **Then** the archived item is no longer visible in the cart.

---

### Edge Cases

- What happens when a price change occurs for a product that was previously archived and re-added? The new cart item is treated as a new item and will be archived if another price change occurs.
- What happens when the same product's price changes multiple times in quick succession? Each price change triggers the automation; items already archived from previous changes are not re-processed.
- What happens when a cart item is removed before the archive process completes? The ItemArchived event still processes but has no effect since the item no longer exists in the cart.
- What happens when the automation processing is interrupted mid-way? The TODO list persists incomplete items; processing resumes on restart by re-processing pending items.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow administrators to publish price changes for products from the backoffice interface (same page as inventory changes).
- **FR-002**: System MUST translate external PriceChanged events to internal PriceChanged events via a ChangePrice command.
- **FR-003**: System MUST maintain a "products with price changes" read model built from PriceChanged events.
- **FR-004**: System MUST maintain a "carts with products" read model built from cart-related events (ItemAdded, ItemRemoved, CartCleared, ItemArchived).
- **FR-005**: System MUST automatically invoke RequestToArchiveItem commands when a price change occurs for products in active carts.
- **FR-006**: System MUST emit ItemArchiveRequested events when archive requests are created.
- **FR-007**: System MUST maintain an "items to archive" TODO list read model built from ItemArchiveRequested and ItemArchived events.
- **FR-008**: System MUST automatically invoke ArchiveItem commands for items in the TODO list.
- **FR-009**: System MUST emit ItemArchived events when items are archived.
- **FR-010**: System MUST update the cart items read model when ItemArchived events occur (removing archived items from cart view).

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: Epoch.Backoffice - Provides the price change UI on the same page as inventory management. Tests will fail if the backoffice module is unavailable.
- **Dependency**: Epoch.EventStore - All events (PriceChanged, ItemArchiveRequested, ItemArchived) must be persisted. Tests will fail if EventStore is unavailable.
- **Dependency**: Epoch.Cart - Provides cart events (ItemAdded, ItemRemoved, CartCleared) for building the "carts with products" read model. Tests will fail if Cart events are not available.
- **Dependency**: Phoenix.PubSub (Epoch.PubSub) - Used for event propagation to processors and read model updates. If unavailable, automation will not trigger.
- **Configuration**: Price stream name - Default "price" stream for PriceChanged events.
- **Configuration**: Cart stream name - Default "cart" stream for cart and archive events.

### Key Entities *(include if feature involves data)*

- **PriceChanged Event**: Represents a price change for a product. Key attributes: product_id, new_price, timestamp.
- **Products with Price Changes (Read Model)**: Tracks products that have had price changes. Key attributes: product_id, last_price_change_timestamp.
- **Carts with Products (Read Model)**: Tracks which carts contain which products. Key attributes: cart_id, list of (product_id, cart_item_id) tuples.
- **ItemArchiveRequested Event**: Represents a request to archive a cart item. Key attributes: cart_id (aggregate_id), product_id, item_id.
- **Items to Archive (Read Model/TODO List)**: Tracks pending archive requests. Key attributes: cart_id, product_id, item_id.
- **ItemArchived Event**: Represents a completed archive action. Key attributes: cart_id (aggregate_id), product_id, item_id.
- **ArchiveItem Command**: Command to archive a specific cart item. Key attributes: cart_id (aggregate_id), product_id, item_id.

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test ChangePrice command handler emits PriceChanged event with correct product_id and price
- Test "products with price changes" read model adds products on PriceChanged event
- Test "carts with products" read model adds cart-product mapping on ItemAdded event
- Test "carts with products" read model removes mapping on ItemRemoved event
- Test "carts with products" read model clears cart on CartCleared event
- Test "carts with products" read model removes item on ItemArchived event
- Test price change processor identifies affected carts correctly
- Test price change processor emits ItemArchiveRequested for each affected cart item
- Test price change processor does not emit events for products not in any cart
- Test "items to archive" read model adds items on ItemArchiveRequested event
- Test "items to archive" read model removes items on ItemArchived event
- Test ArchiveItem command handler emits ItemArchived event
- Test cart items read model removes archived items

### Integration Tests *(required for each cross-boundary interaction)*

- Test end-to-end: price change in backoffice triggers PriceChanged event via translator
- Test end-to-end: PriceChanged event triggers ItemArchiveRequested for affected carts
- Test end-to-end: ItemArchiveRequested triggers ArchiveItem command and ItemArchived event
- Test end-to-end: ItemArchived event updates cart items read model (item removed from cart view)
- Test automation resilience: interrupted processing resumes from TODO list
- Test concurrent price changes: multiple price changes processed correctly
- Test PubSub integration: events propagate to all relevant processors

## Failure Modes & Observability *(mandatory)*

- **EventStore unavailable**: Log error and return {:error, :persistence_failed}; automation processing halts until restored. TODO list preserves pending items.
- **PubSub unavailable**: Log warning; events are persisted but automation does not trigger. Manual restart or event replay may be needed.
- **Price change for non-existent product**: Log info and proceed; no validation required as price changes are informational.
- **Cart not found during archive**: Log warning and skip; ItemArchived still emitted but has no effect on read model.
- **Processor timeout**: If price change processing exceeds 30 seconds, log warning and continue; partial progress is preserved in TODO list.
- **Logging**: All events logged with correlation_id, event_type, and relevant entity IDs (product_id, cart_id, item_id).
- **Metrics**: Track price_changes_processed, archive_requests_created, items_archived, processing_latency.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can publish price changes from the backoffice within 2 seconds.
- **SC-002**: Price change events are translated and processed within 5 seconds of publication.
- **SC-003**: All affected cart items are identified and archive-requested within 10 seconds of a price change.
- **SC-004**: Archive TODO list accurately reflects all pending archive requests (100% accuracy).
- **SC-005**: Archived items are removed from cart view within 5 seconds of the archive event.
- **SC-006**: System correctly handles 100 concurrent carts affected by a single price change without data loss.
- **SC-007**: Automation resumes processing pending items within 30 seconds of system restart.

## Assumptions

- The backoffice page for inventory changes already exists and can be extended to include price changes.
- External PriceChanged events follow the same pattern as InventoryUpdated events (published directly to event stream from backoffice).
- The translator pattern (external event → command → internal event) is the desired architecture for processing external events.
- Cart items are identified by a unique item_id within each cart.
- Archiving an item removes it from the cart view; archived items are not recoverable by the customer.
- The automation processes synchronously in response to events (not batch-scheduled).
- The low stock threshold of 5 from Feature 013 does not apply to archived items (they are simply removed).
