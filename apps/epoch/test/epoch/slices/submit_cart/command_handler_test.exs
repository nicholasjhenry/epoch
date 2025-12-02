defmodule Epoch.Slices.SubmitCart.CommandHandlerTest do
  use ExUnit.Case, async: true

  alias Epoch.Backoffice.Events.InventoryUpdated
  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemArchived, ItemRemoved}
  alias Epoch.EventStore
  alias Epoch.Slices.SubmitCart.Command, as: SubmitCart
  alias Epoch.Slices.SubmitCart.CommandHandler

  setup do
    # Use unique session_id per test to ensure isolation
    # The global EventStore is started by the application
    session_id = Ecto.UUID.generate()
    cart_stream = "cart-#{session_id}"
    {:ok, session_id: session_id, cart_stream: cart_stream}
  end

  # Helper to add inventory for a product
  defp set_inventory(product_id, quantity) do
    event = %InventoryUpdated{
      product_id: product_id,
      quantity: quantity,
      updated_at: DateTime.utc_now()
    }

    stream_name = "inventory-#{product_id}"
    EventStore.append_to_stream(stream_name, [event])
  end

  # Helper to add an item to cart
  defp add_item_to_cart(cart_stream, product_id, opts \\ []) do
    item_id = Keyword.get(opts, :item_id, "#{product_id}-#{System.unique_integer([:positive])}")
    name = Keyword.get(opts, :name, "Product #{product_id}")
    price = Keyword.get(opts, :price, 10.0)

    event = %ItemAdded{
      cart_id: String.replace(cart_stream, "cart-", ""),
      item_id: item_id,
      product_id: product_id,
      name: name,
      price: price,
      added_at: DateTime.utc_now()
    }

    EventStore.append_to_stream(cart_stream, [event])
    item_id
  end

  # ===========================================================================
  # Phase 3: User Story 1 - Submit Cart with Available Inventory
  # ===========================================================================

  describe "US1: Submit cart with available inventory" do
    # T006: Submit cart with single item and sufficient inventory
    test "given single item with sufficient inventory then returns CartSubmitted event", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with one item
      add_item_to_cart(cart_stream, "espresso-blend")

      # STEP: Given - inventory is available
      set_inventory("espresso-blend", 10)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns success with CartSubmitted event
      assert {:ok, event} = result
      assert %Epoch.Cart.Events.CartSubmitted{} = event
      assert event.cart_id == session_id
      assert %DateTime{} = event.submitted_at
    end

    # T007: Submit cart with multiple items and sufficient inventory
    test "given multiple items with sufficient inventory then returns CartSubmitted event", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with multiple items
      add_item_to_cart(cart_stream, "espresso-blend")
      add_item_to_cart(cart_stream, "french-roast")
      add_item_to_cart(cart_stream, "colombian")

      # STEP: Given - inventory is available for all products
      set_inventory("espresso-blend", 5)
      set_inventory("french-roast", 3)
      set_inventory("colombian", 7)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns success with CartSubmitted event
      assert {:ok, event} = result
      assert %Epoch.Cart.Events.CartSubmitted{} = event
    end

    test "given successful submission then CartSubmitted event is appended to stream", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with item and inventory
      add_item_to_cart(cart_stream, "espresso-blend")
      set_inventory("espresso-blend", 10)

      # STEP: When - submit the cart
      {:ok, _event} = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - CartSubmitted event was appended to cart stream
      {:ok, %{events: events}} = EventStore.read_stream(cart_stream)
      cart_submitted = List.last(events)
      assert %Epoch.Cart.Events.CartSubmitted{cart_id: ^session_id} = cart_submitted
    end
  end

  # ===========================================================================
  # Phase 4: User Story 2 - Reject Cart When Out of Stock
  # ===========================================================================

  describe "US2: Reject cart when product out of stock" do
    # T010: Submit cart when product inventory is 0
    test "given product with zero inventory then returns insufficient_inventory error", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with one item
      add_item_to_cart(cart_stream, "espresso-blend")

      # STEP: Given - inventory is 0
      set_inventory("espresso-blend", 0)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error with product ID
      assert {:error, {:insufficient_inventory, product_ids}} = result
      assert "espresso-blend" in product_ids
    end

    # T011: Submit cart when product has no inventory record
    test "given product with no inventory record then returns insufficient_inventory error", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with one item
      add_item_to_cart(cart_stream, "no-inventory-product")

      # STEP: Given - NO inventory record exists (no InventoryUpdated events)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error (missing inventory treated as 0)
      assert {:error, {:insufficient_inventory, product_ids}} = result
      assert "no-inventory-product" in product_ids
    end

    # T012: Submit cart with multiple items where one has 0 inventory
    test "given multiple items where one has zero inventory then returns error listing out-of-stock product",
         %{
           session_id: session_id,
           cart_stream: cart_stream
         } do
      # STEP: Given - cart with multiple items
      add_item_to_cart(cart_stream, "espresso-blend")
      add_item_to_cart(cart_stream, "french-roast")

      # STEP: Given - only one product has inventory
      set_inventory("espresso-blend", 10)
      set_inventory("french-roast", 0)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error with out-of-stock product
      assert {:error, {:insufficient_inventory, product_ids}} = result
      assert "french-roast" in product_ids
      refute "espresso-blend" in product_ids
    end

    test "given multiple out-of-stock products then returns all product IDs in error", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with multiple items
      add_item_to_cart(cart_stream, "product-a")
      add_item_to_cart(cart_stream, "product-b")
      add_item_to_cart(cart_stream, "product-c")

      # STEP: Given - two products have no inventory
      set_inventory("product-a", 0)
      set_inventory("product-b", 5)
      set_inventory("product-c", 0)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error with both out-of-stock products
      assert {:error, {:insufficient_inventory, product_ids}} = result
      assert "product-a" in product_ids
      assert "product-c" in product_ids
      refute "product-b" in product_ids
    end
  end

  # ===========================================================================
  # Phase 5: User Story 3 - Reject Empty Cart Submission
  # ===========================================================================

  describe "US3: Reject empty cart submission" do
    # T015: Submit cart with no items
    test "given cart with no items then returns cart_empty error", %{
      session_id: session_id
    } do
      # STEP: Given - empty cart (no events)

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error
      assert {:error, :cart_empty} = result
    end

    # T016: Submit cart after CartCleared event
    test "given cart after CartCleared event then returns cart_empty error", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart had items but was cleared
      add_item_to_cart(cart_stream, "espresso-blend")
      set_inventory("espresso-blend", 10)

      cleared_event = %CartCleared{cleared_at: DateTime.utc_now()}
      EventStore.append_to_stream(cart_stream, [cleared_event])

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns error
      assert {:error, :cart_empty} = result
    end
  end

  # ===========================================================================
  # Phase 6: User Story 4 - Handle Removed/Archived Items
  # ===========================================================================

  describe "US4: Submit cart after item removal" do
    # T019: Submit cart correctly excludes removed items from validation
    test "given cart with removed item then excludes removed item from inventory validation", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with two items
      item_id_1 = add_item_to_cart(cart_stream, "espresso-blend", item_id: "item-1")
      add_item_to_cart(cart_stream, "french-roast", item_id: "item-2")

      # STEP: Given - remove one item
      removed_event = %ItemRemoved{item_id: item_id_1, removed_at: DateTime.utc_now()}
      EventStore.append_to_stream(cart_stream, [removed_event])

      # STEP: Given - only remaining product has inventory
      # (removed product has NO inventory - if it were checked, submission would fail)
      set_inventory("french-roast", 5)
      # espresso-blend has no inventory - but it's removed so shouldn't matter

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - submission succeeds (removed item not validated)
      assert {:ok, _event} = result
    end

    # T020: Submit cart correctly excludes archived items from validation
    test "given cart with archived item then excludes archived item from inventory validation", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with two items
      item_id_1 = add_item_to_cart(cart_stream, "espresso-blend", item_id: "item-1")
      add_item_to_cart(cart_stream, "french-roast", item_id: "item-2")

      # STEP: Given - archive one item
      archived_event = %ItemArchived{
        cart_id: session_id,
        item_id: item_id_1,
        reason: "price_changed",
        archived_at: DateTime.utc_now()
      }

      EventStore.append_to_stream(cart_stream, [archived_event])

      # STEP: Given - only remaining product has inventory
      set_inventory("french-roast", 5)
      # espresso-blend has no inventory - but it's archived so shouldn't matter

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - submission succeeds (archived item not validated)
      assert {:ok, _event} = result
    end

    test "given all items removed then returns cart_empty error", %{
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with item that was then removed
      item_id = add_item_to_cart(cart_stream, "espresso-blend", item_id: "item-1")

      removed_event = %ItemRemoved{item_id: item_id, removed_at: DateTime.utc_now()}
      EventStore.append_to_stream(cart_stream, [removed_event])

      # STEP: When - submit the cart
      result = CommandHandler.handle(%SubmitCart{session_id: session_id})

      # STEP: Then - returns empty cart error
      assert {:error, :cart_empty} = result
    end
  end
end
