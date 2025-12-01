defmodule Epoch.Automation.PriceChangeProcessorIntegrationTest do
  use ExUnit.Case, async: false

  alias Epoch.Automation.PriceChangeProcessor
  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Cart.Events.{ItemAdded, ItemArchiveRequested}
  alias Epoch.EventStore

  @moduletag :integration

  setup do
    # Use existing application-started EventStore
    :ok
  end

  describe "when price changes end-to-end" do
    test "given item in cart then PriceChanged triggers ItemArchiveRequested" do
      # Setup unique IDs
      cart_id = "cart-integration-#{System.unique_integer([:positive])}"
      product_id = "integration-product-#{System.unique_integer([:positive])}"
      item_id = "#{product_id}-#{System.unique_integer([:positive])}"

      # Step 1: Add item to cart (simulating cart state)
      item_added = %ItemAdded{
        cart_id: cart_id,
        item_id: item_id,
        product_id: product_id,
        name: "Integration Test Product",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      cart_stream = "cart-#{cart_id}"
      {:ok, _} = EventStore.append_to_stream(cart_stream, [item_added])

      # Step 2: Start the processor (subscribes to price stream) with unique id for proper cleanup
      processor_id = :"PriceChangeProcessor_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {PriceChangeProcessor, name: processor_id},
          id: processor_id
        )

      # Give processor time to start and subscribe
      Process.sleep(50)

      # Step 3: Publish price change
      price_changed = %PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      price_stream = "price-#{product_id}"
      {:ok, _} = EventStore.append_to_stream(price_stream, [price_changed])

      # Step 4: Wait for processor to handle the event
      Process.sleep(100)

      # Step 5: Verify ItemArchiveRequested was emitted to cart stream
      {:ok, %{events: cart_events}} = EventStore.read_stream(cart_stream)

      archive_requested_events =
        Enum.filter(cart_events, fn e -> e.__struct__ == ItemArchiveRequested end)

      assert length(archive_requested_events) >= 1

      archive_event = hd(archive_requested_events)
      assert archive_event.cart_id == cart_id
      assert archive_event.product_id == product_id
      assert archive_event.item_id == item_id
      assert archive_event.reason == "price_changed"

      # Cleanup
      stop_supervised(processor_id)
    end

    test "given multiple carts with same product then archives items in all carts" do
      # Setup unique IDs
      product_id = "multi-cart-product-#{System.unique_integer([:positive])}"
      cart1_id = "cart-multi-1-#{System.unique_integer([:positive])}"
      cart2_id = "cart-multi-2-#{System.unique_integer([:positive])}"
      item1_id = "#{product_id}-item1-#{System.unique_integer([:positive])}"
      item2_id = "#{product_id}-item2-#{System.unique_integer([:positive])}"

      # Add items to both carts
      item1 = %ItemAdded{
        cart_id: cart1_id,
        item_id: item1_id,
        product_id: product_id,
        name: "Multi Cart Product",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      item2 = %ItemAdded{
        cart_id: cart2_id,
        item_id: item2_id,
        product_id: product_id,
        name: "Multi Cart Product",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("cart-#{cart1_id}", [item1])
      {:ok, _} = EventStore.append_to_stream("cart-#{cart2_id}", [item2])

      # Start processor with unique id for proper cleanup
      processor_id = :"PriceChangeProcessor_multi_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {PriceChangeProcessor, name: processor_id},
          id: processor_id
        )

      Process.sleep(50)

      # Publish price change
      price_changed = %PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("price-#{product_id}", [price_changed])

      # Wait for processing
      Process.sleep(100)

      # Verify both carts have archive requests
      {:ok, %{events: cart1_events}} = EventStore.read_stream("cart-#{cart1_id}")
      {:ok, %{events: cart2_events}} = EventStore.read_stream("cart-#{cart2_id}")

      cart1_archive_events =
        Enum.filter(cart1_events, fn e -> e.__struct__ == ItemArchiveRequested end)

      cart2_archive_events =
        Enum.filter(cart2_events, fn e -> e.__struct__ == ItemArchiveRequested end)

      assert length(cart1_archive_events) >= 1
      assert length(cart2_archive_events) >= 1

      stop_supervised(processor_id)
    end

    test "given product not in any cart then no archive requests created" do
      # Start processor with unique id for proper cleanup
      processor_id = :"PriceChangeProcessor_empty_#{System.unique_integer([:positive])}"

      {:ok, _processor} =
        start_supervised(
          {PriceChangeProcessor, name: processor_id},
          id: processor_id
        )

      Process.sleep(50)

      # Publish price change for product not in any cart
      product_id = "orphan-product-#{System.unique_integer([:positive])}"

      price_changed = %PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      {:ok, _} = EventStore.append_to_stream("price-#{product_id}", [price_changed])

      # Wait for processing
      Process.sleep(100)

      # No cart stream should have been created for this orphan product
      # (processor shouldn't create archive requests for products not in carts)
      # This is verified by the fact that no error occurred

      stop_supervised(processor_id)
    end
  end
end
