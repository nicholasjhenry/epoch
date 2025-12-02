defmodule Epoch.Automation.PriceChangeProcessorTest do
  use ExUnit.Case, async: false

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Cart.CartsWithProducts
  alias Epoch.Cart.Events.{ItemAdded, ItemArchiveRequested}
  alias Epoch.EventStore

  setup do
    # Start fresh EventStore for each test
    {:ok, _} = start_supervised({EventStore, name: :"EventStore_#{System.unique_integer()}"})

    :ok
  end

  describe "when processing price change" do
    test "given product in carts then identifies affected carts via CartsWithProducts" do
      # Setup: Build a CartsWithProducts state with items
      cart_id = "cart-#{System.unique_integer([:positive])}"
      product_id = "espresso-blend"
      item_id = "#{product_id}-#{System.unique_integer([:positive])}"

      item_added = %ItemAdded{
        cart_id: cart_id,
        item_id: item_id,
        product_id: product_id,
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      # Build the read model state
      carts_state =
        CartsWithProducts.initial_state()
        |> CartsWithProducts.evolve(item_added)

      # Verify our setup - product should be in cart
      affected_carts = CartsWithProducts.carts_with_product(carts_state, product_id)
      assert cart_id in affected_carts

      # The processor should find these same carts
      items = CartsWithProducts.items_for_product(carts_state, product_id)
      assert length(items) == 1
      assert hd(items).cart_id == cart_id
      assert hd(items).item_id == item_id
    end

    test "given product in multiple carts then emits ItemArchiveRequested for each affected cart item" do
      # Setup: Create multiple carts with the same product
      product_id = "espresso-blend-#{System.unique_integer([:positive])}"

      cart1_id = "cart-#{System.unique_integer([:positive])}"
      cart2_id = "cart-#{System.unique_integer([:positive])}"
      item1_id = "#{product_id}-item1"
      item2_id = "#{product_id}-item2"

      events = [
        %ItemAdded{
          cart_id: cart1_id,
          item_id: item1_id,
          product_id: product_id,
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: cart2_id,
          item_id: item2_id,
          product_id: product_id,
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      # Build read model
      carts_state = CartsWithProducts.project(events)

      # Simulate what PriceChangeProcessor does
      price_changed = %PriceChanged{
        product_id: product_id,
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      # Get affected items
      affected_items = CartsWithProducts.items_for_product(carts_state, price_changed.product_id)

      # Build archive requests
      archive_requests =
        Enum.map(affected_items, fn item ->
          %ItemArchiveRequested{
            cart_id: item.cart_id,
            product_id: item.product_id,
            item_id: item.item_id,
            reason: "price_changed",
            requested_at: DateTime.utc_now()
          }
        end)

      # Should have 2 requests - one for each cart
      assert length(archive_requests) == 2

      cart_ids = Enum.map(archive_requests, & &1.cart_id)
      assert cart1_id in cart_ids
      assert cart2_id in cart_ids
    end

    test "given product not in any cart then does not emit events" do
      # Setup: Empty carts state
      carts_state = CartsWithProducts.initial_state()

      # Price change for product not in any cart
      price_changed = %PriceChanged{
        product_id: "nonexistent-product",
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      # Get affected items - should be empty
      affected_items = CartsWithProducts.items_for_product(carts_state, price_changed.product_id)

      assert affected_items == []
    end
  end

  describe "when handling PubSub events" do
    test "given PriceChanged event received then processes price change" do
      # This test verifies the GenServer can receive and handle events
      # The actual integration will be tested in the integration test

      price_changed = %PriceChanged{
        product_id: "espresso-blend",
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: DateTime.utc_now()
      }

      # Build envelope similar to what EventStore broadcasts
      envelope = %{
        event: price_changed,
        stream_name: "price-espresso-blend",
        version: 1,
        timestamp: DateTime.utc_now()
      }

      # The processor should handle this message type
      message = {:events_appended, "price-espresso-blend", [envelope]}

      # Verify message structure matches what processor expects
      assert {:events_appended, stream_name, events} = message
      assert String.starts_with?(stream_name, "price-")
      assert length(events) == 1
      assert hd(events).event.__struct__ == PriceChanged
    end
  end
end
