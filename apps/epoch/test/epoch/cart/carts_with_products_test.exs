defmodule Epoch.Cart.CartsWithProductsTest do
  use ExUnit.Case, async: true

  alias Epoch.Cart.CartsWithProducts
  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemArchived, ItemRemoved}

  describe "evolve/2 with ItemAdded" do
    test "adds mapping on ItemAdded event" do
      state = CartsWithProducts.initial_state()

      event = %ItemAdded{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      new_state = CartsWithProducts.evolve(state, event)

      assert length(new_state.mappings) == 1
      assert hd(new_state.mappings).cart_id == "cart-123"
      assert hd(new_state.mappings).product_id == "espresso-blend"
      assert hd(new_state.mappings).item_id == "espresso-blend-001"
    end

    test "skips ItemAdded events without cart_id" do
      state = CartsWithProducts.initial_state()

      # Legacy event without cart_id
      event = %ItemAdded{
        cart_id: nil,
        item_id: "espresso-blend-001",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      new_state = CartsWithProducts.evolve(state, event)

      assert new_state.mappings == []
    end
  end

  describe "evolve/2 with ItemRemoved" do
    test "removes mapping on ItemRemoved event" do
      state = CartsWithProducts.initial_state()

      add_event = %ItemAdded{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      remove_event = %ItemRemoved{
        item_id: "espresso-blend-001",
        removed_at: DateTime.utc_now()
      }

      state =
        state
        |> CartsWithProducts.evolve(add_event)
        |> CartsWithProducts.evolve(remove_event)

      assert state.mappings == []
    end
  end

  describe "evolve/2 with ItemArchived" do
    test "removes mapping on ItemArchived event" do
      state = CartsWithProducts.initial_state()

      add_event = %ItemAdded{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      archive_event = %ItemArchived{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        archived_at: DateTime.utc_now()
      }

      state =
        state
        |> CartsWithProducts.evolve(add_event)
        |> CartsWithProducts.evolve(archive_event)

      assert state.mappings == []
    end
  end

  describe "evolve/2 with CartCleared" do
    test "CartCleared without cart_id does not affect state" do
      # CartCleared event doesn't have cart_id field currently.
      # The read model handles this gracefully by doing nothing.
      # In a real projection, cart_id would come from stream context.
      state = CartsWithProducts.initial_state()

      events = [
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "espresso-blend-001",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "french-roast-001",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      state = Enum.reduce(events, state, &CartsWithProducts.evolve(&2, &1))
      assert length(state.mappings) == 2

      # CartCleared without cart_id - no effect on state
      clear_event = %CartCleared{cleared_at: DateTime.utc_now()}

      new_state = CartsWithProducts.evolve(state, clear_event)

      # State unchanged since CartCleared has no cart_id
      assert length(new_state.mappings) == 2
    end
  end

  describe "carts_with_product/2" do
    test "returns all carts containing product" do
      state = CartsWithProducts.initial_state()

      events = [
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "espresso-blend-001",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-456",
          item_id: "espresso-blend-002",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-789",
          item_id: "french-roast-001",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      state = Enum.reduce(events, state, &CartsWithProducts.evolve(&2, &1))

      carts = CartsWithProducts.carts_with_product(state, "espresso-blend")
      assert length(carts) == 2
      assert "cart-123" in carts
      assert "cart-456" in carts
      refute "cart-789" in carts
    end

    test "returns empty list when no carts contain product" do
      state = CartsWithProducts.initial_state()
      assert CartsWithProducts.carts_with_product(state, "espresso-blend") == []
    end
  end

  describe "items_for_product/2" do
    test "returns all items for product across carts" do
      state = CartsWithProducts.initial_state()

      events = [
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "espresso-blend-001",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-456",
          item_id: "espresso-blend-002",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      state = Enum.reduce(events, state, &CartsWithProducts.evolve(&2, &1))

      items = CartsWithProducts.items_for_product(state, "espresso-blend")
      assert length(items) == 2

      item_ids = Enum.map(items, & &1.item_id)
      assert "espresso-blend-001" in item_ids
      assert "espresso-blend-002" in item_ids
    end
  end

  describe "products_in_cart/2" do
    test "returns all products in a cart" do
      state = CartsWithProducts.initial_state()

      events = [
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "espresso-blend-001",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "french-roast-001",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      state = Enum.reduce(events, state, &CartsWithProducts.evolve(&2, &1))

      products = CartsWithProducts.products_in_cart(state, "cart-123")
      assert length(products) == 2
    end
  end

  describe "item_exists?/2" do
    test "returns true when item exists" do
      state = CartsWithProducts.initial_state()

      event = %ItemAdded{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      state = CartsWithProducts.evolve(state, event)

      assert CartsWithProducts.item_exists?(state, "espresso-blend-001") == true
    end

    test "returns false when item does not exist" do
      state = CartsWithProducts.initial_state()
      assert CartsWithProducts.item_exists?(state, "nonexistent") == false
    end
  end

  describe "project/1" do
    test "projects list of events into final state" do
      events = [
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "espresso-blend-001",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          cart_id: "cart-123",
          item_id: "french-roast-001",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        },
        %ItemRemoved{
          item_id: "french-roast-001",
          removed_at: DateTime.utc_now()
        }
      ]

      state = CartsWithProducts.project(events)

      assert length(state.mappings) == 1
      assert hd(state.mappings).item_id == "espresso-blend-001"
    end
  end
end
