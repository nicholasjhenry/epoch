# Feature Specification: Product Index Page for Phoenix LiveView

**Feature Branch**: `002-product-index-liveview`  
**Created**: 2025-11-25  
**Status**: Draft  
**Input**: User description: "Port Next.js product index page to Phoenix LiveView, including CSS styles"

## Overview

Port the existing Next.js product index page to Phoenix LiveView. The page displays a catalog of coffee products in a card-based grid layout, with each product showing its name, description, price, and an "Add Item" button. The page includes navigation and uses Bulma CSS framework for styling.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Product Catalog (Priority: P1)

As a shopper, I want to see a list of available coffee products so that I can browse what's available for purchase.

**Why this priority**: This is the core functionality of the page - without product display, there's no value delivered.

**Independent Test**: Can be fully tested by visiting the products page and verifying all products are displayed with their details.

**Acceptance Scenarios**:

1. **Given** I am on the home page, **When** the page loads, **Then** I see a grid of 5 coffee products displayed as cards
2. **Given** I am viewing the product catalog, **When** I look at a product card, **Then** I see the product name as a heading, description text, and price displayed
3. **Given** I am viewing the product catalog, **When** I resize the browser window, **Then** the product grid adjusts responsively (3 columns on desktop, fewer on smaller screens)

---

### User Story 2 - Navigate Between Pages (Priority: P2)

As a shopper, I want to navigate between different sections of the application so that I can access the products page, cart, specs, and backoffice.

**Why this priority**: Navigation is essential for multi-page applications but the product display delivers value even without full navigation.

**Independent Test**: Can be fully tested by clicking navigation links and verifying correct page routing.

**Acceptance Scenarios**:

1. **Given** I am on any page, **When** I view the navigation bar, **Then** I see links for Products, Cart, Spec, and Backoffice with appropriate icons
2. **Given** I am viewing the navigation, **When** I click on "Products", **Then** I am taken to the products index page
3. **Given** I am viewing the navigation, **When** I click on "Cart", **Then** I am taken to the cart page

---

### User Story 3 - Add Product to Cart (Priority: P3)

As a shopper, I want to add a product to my cart so that I can purchase it later.

**Why this priority**: Cart functionality depends on product display and is part of the e-commerce flow, but the catalog can be browsed without cart functionality.

**Independent Test**: Can be fully tested by clicking "Add Item" on a product and verifying the item appears in the cart.

**Acceptance Scenarios**:

1. **Given** I am viewing a product card, **When** I look at the card, **Then** I see an "Add Item" button
2. **Given** I am viewing a product card, **When** I click "Add Item", **Then** the product is added to my cart session
3. **Given** I have clicked "Add Item" on a product, **When** the action completes, **Then** I am redirected to the cart page

---

### Edge Cases

- What happens when JavaScript is disabled? The page should still render products as static content.
- How does the page handle an empty product list? Display a message indicating no products are available.
- What happens if the cart session expires? A new cart session should be created automatically.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a navigation bar with links to Products, Cart, Spec, and Backoffice pages
- **FR-002**: System MUST display product cards in a responsive grid layout (3 columns on desktop)
- **FR-003**: Each product card MUST display the product name as a heading
- **FR-004**: Each product card MUST display the product description
- **FR-005**: Each product card MUST display the product price formatted as currency
- **FR-006**: Each product card MUST include an "Add Item" button
- **FR-007**: System MUST maintain a cart session identifier using a UUID
- **FR-008**: System MUST use Bulma CSS framework classes for consistent styling with the original design
- **FR-009**: Navigation items MUST include Font Awesome icons (store, shopping-cart, vial, cogs)
- **FR-010**: Product data MUST include: productId, name, description, and price

### Explicit Dependencies & Configuration *(mandatory)*

- **Dependency**: Bulma CSS - CSS framework loaded via CDN (https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css), no validation needed as styling gracefully degrades
- **Dependency**: Font Awesome - Icon library loaded via CDN (https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css), icons will be invisible if unavailable but functionality unaffected
- **Configuration**: Product data - Hardcoded list of 5 coffee products for initial implementation

### Key Entities *(include if feature involves data)*

- **Product**: Represents a purchasable item with productId (string), name (string), description (string), and price (decimal)
- **CartSession**: Represents a shopping session identified by a UUID, associated with cart items

## Test Plan *(mandatory before implementation)*

### Unit Tests *(write these first)*

- Test that product list renders correct number of product cards
- Test that each product card displays name, description, and price
- Test that navigation component renders all required links with icons
- Test that Add Item button is present on each product card

### Integration Tests *(required for each cross-boundary interaction)*

- Test full page render with all products displayed
- Test navigation links route to correct pages
- Test Add Item button triggers cart update and redirects to cart page
- Test cart session UUID is generated on page mount

## Failure Modes & Observability *(mandatory)*

- **CDN Failure**: If Bulma or Font Awesome CDN is unavailable, page renders with degraded styling but remains functional
- **Cart Session**: If cart operations fail, display user-friendly error message and log error details
- **Logging**: Log cart session creation and item additions for debugging

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Product catalog page loads and displays all 5 products within 1 second
- **SC-002**: Users can visually identify product name, description, and price on each card
- **SC-003**: Navigation allows users to move between all 4 sections of the application
- **SC-004**: Add Item functionality successfully adds products to cart 100% of the time
- **SC-005**: Page layout matches the original Next.js design visually (same grid layout, card styling, colors)

## Assumptions

- The Phoenix application already has a basic router and layout configured
- Bulma CSS and Font Awesome will be loaded via CDN links in the root layout
- Cart functionality will integrate with an existing or new event store implementation
- The 5 coffee products are static data that will be hardcoded in the LiveView initially
