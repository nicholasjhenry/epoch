defmodule Epoch.Automation.FullFlowIntegrationTest do
  @moduledoc """
  End-to-end integration test for the complete price change automation flow:

  1. Add item to cart
  2. Change product price in backoffice
  3. Verify item is automatically archived from cart
  """
  use ExUnit.Case, async: false

  alias Epoch.Cart.Events.{ItemAdded, ItemArchived, ItemArchiveRequested}
  alias Epoch.EventStore

  @moduletag :integration

  setup do
    # Use existing application-started EventStore and processors
    :ok
  end

  describe "full automation flow" do
    test "price change in backoffice triggers item archived from cart" do
      # Setup: Create unique IDs for this test
      cart_id = "cart-full-flow-#{System.unique_integer([:positive])}"
      product_id = "full-flow-product-#{System.unique_integer([:positive])}"
      item_id = "#{product_id}-item-#{System.unique_integer([:positive])}"

      # Step 1: Simulate adding an item to a cart
      # (In real usage, this would go through Cart.add_item, but we're testing the automation)
      item_added = %ItemAdded{
        cart_id: cart_id,
        item_id: item_id,
        product_id: product_id,
        name: "Full Flow Test Product",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      cart_stream = "cart-#{cart_id}"
      {:ok, _} = EventStore.append_to_stream(cart_stream, [item_added])

      # Verify item was added
      {:ok, %{events: cart_events_before}} = EventStore.read_stream(cart_stream)
      assert length(cart_events_before) == 1

      # Step 2: Change the product price (triggers PriceChangeProcessor)
      # We need to create a catalog product first for validation
      # For this test, we'll directly emit the price change event
      price_changed_event = %Epoch.Backoffice.Events.PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("16.99"),
        changed_at: DateTime.utc_now()
      }

      price_stream = "price-#{product_id}"
      {:ok, _} = EventStore.append_to_stream(price_stream, [price_changed_event])

      # Step 3: Wait for automation to process
      # PriceChangeProcessor receives PriceChanged -> emits ItemArchiveRequested
      # ArchiveProcessor receives ItemArchiveRequested -> emits ItemArchived
      Process.sleep(200)

      # Step 4: Verify the full chain of events occurred
      {:ok, %{events: cart_events_after}} = EventStore.read_stream(cart_stream)

      # Should have: ItemAdded, ItemArchiveRequested, ItemArchived
      event_types = Enum.map(cart_events_after, & &1.__struct__)

      assert ItemAdded in event_types, "ItemAdded should be in cart events"
      assert ItemArchiveRequested in event_types, "ItemArchiveRequested should be in cart events"
      assert ItemArchived in event_types, "ItemArchived should be in cart events"

      # Verify the archived event has correct data
      archived_event =
        Enum.find(cart_events_after, fn e -> e.__struct__ == ItemArchived end)

      assert archived_event.cart_id == cart_id
      assert archived_event.item_id == item_id
      assert archived_event.reason == "price_changed"
    end

    test "multiple carts with same product all get items archived" do
      # Setup: Multiple carts with the same product
      product_id = "multi-cart-flow-#{System.unique_integer([:positive])}"
      cart1_id = "cart-flow-1-#{System.unique_integer([:positive])}"
      cart2_id = "cart-flow-2-#{System.unique_integer([:positive])}"
      cart3_id = "cart-flow-3-#{System.unique_integer([:positive])}"
      item1_id = "#{product_id}-item1-#{System.unique_integer([:positive])}"
      item2_id = "#{product_id}-item2-#{System.unique_integer([:positive])}"
      item3_id = "#{product_id}-item3-#{System.unique_integer([:positive])}"

      # Add items to all three carts
      items = [
        {cart1_id, item1_id},
        {cart2_id, item2_id},
        {cart3_id, item3_id}
      ]

      for {cart_id, item_id} <- items do
        event = %ItemAdded{
          cart_id: cart_id,
          item_id: item_id,
          product_id: product_id,
          name: "Multi Cart Test Product",
          price: 19.99,
          added_at: DateTime.utc_now()
        }

        {:ok, _} = EventStore.append_to_stream("cart-#{cart_id}", [event])
      end

      # Change the price
      price_changed = %Epoch.Backoffice.Events.PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("19.99"),
        new_price: Decimal.new("21.99"),
        changed_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("price-#{product_id}", [price_changed])

      # Wait for automation
      Process.sleep(200)

      # Verify all three carts have archived items
      for {cart_id, item_id} <- items do
        {:ok, %{events: events}} = EventStore.read_stream("cart-#{cart_id}")

        archived_events =
          Enum.filter(events, fn e ->
            e.__struct__ == ItemArchived and e.item_id == item_id
          end)

        assert length(archived_events) >= 1,
               "Cart #{cart_id} should have ItemArchived for item #{item_id}"
      end
    end

    test "cart items for different products are not affected by single price change" do
      # Setup: Cart with multiple products, only one changes price
      cart_id = "cart-multi-product-#{System.unique_integer([:positive])}"
      product_a_id = "product-a-#{System.unique_integer([:positive])}"
      product_b_id = "product-b-#{System.unique_integer([:positive])}"
      item_a_id = "#{product_a_id}-item-#{System.unique_integer([:positive])}"
      item_b_id = "#{product_b_id}-item-#{System.unique_integer([:positive])}"

      # Add both items to cart
      item_a = %ItemAdded{
        cart_id: cart_id,
        item_id: item_a_id,
        product_id: product_a_id,
        name: "Product A",
        price: 10.0,
        added_at: DateTime.utc_now()
      }

      item_b = %ItemAdded{
        cart_id: cart_id,
        item_id: item_b_id,
        product_id: product_b_id,
        name: "Product B",
        price: 15.0,
        added_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("cart-#{cart_id}", [item_a, item_b])

      # Change price only for product A
      price_changed = %Epoch.Backoffice.Events.PriceChanged{
        product_id: product_a_id,
        old_price: Decimal.new("10.0"),
        new_price: Decimal.new("12.0"),
        changed_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("price-#{product_a_id}", [price_changed])

      # Wait for automation
      Process.sleep(200)

      # Verify only product A item was archived
      {:ok, %{events: events}} = EventStore.read_stream("cart-#{cart_id}")

      item_a_archived =
        Enum.any?(events, fn e ->
          e.__struct__ == ItemArchived and e.item_id == item_a_id
        end)

      item_b_archived =
        Enum.any?(events, fn e ->
          e.__struct__ == ItemArchived and e.item_id == item_b_id
        end)

      assert item_a_archived, "Product A item should be archived"
      refute item_b_archived, "Product B item should NOT be archived"
    end
  end
end
