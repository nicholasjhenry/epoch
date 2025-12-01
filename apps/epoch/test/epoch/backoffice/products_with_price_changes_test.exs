defmodule Epoch.Backoffice.ProductsWithPriceChangesTest do
  use ExUnit.Case, async: true

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Backoffice.ProductsWithPriceChanges

  describe "evolve/2 with PriceChanged" do
    test "adds product on first PriceChanged event" do
      state = ProductsWithPriceChanges.initial_state()

      event = %PriceChanged{
        product_id: "espresso-blend",
        old_price: nil,
        new_price: Decimal.new("15.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      new_state = ProductsWithPriceChanges.evolve(state, event)

      assert map_size(new_state.products) == 1
      product = new_state.products["espresso-blend"]
      assert product.product_id == "espresso-blend"
      assert Decimal.equal?(product.new_price, Decimal.new("15.99"))
      assert product.old_price == nil
    end

    test "tracks latest price per product" do
      state = ProductsWithPriceChanges.initial_state()

      event1 = %PriceChanged{
        product_id: "espresso-blend",
        old_price: nil,
        new_price: Decimal.new("14.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      event2 = %PriceChanged{
        product_id: "espresso-blend",
        old_price: Decimal.new("14.99"),
        new_price: Decimal.new("15.99"),
        changed_at: ~U[2025-12-01 11:00:00Z]
      }

      state =
        state
        |> ProductsWithPriceChanges.evolve(event1)
        |> ProductsWithPriceChanges.evolve(event2)

      # Should still have only one entry for the product
      assert map_size(state.products) == 1

      product = state.products["espresso-blend"]
      # Should have the latest price info
      assert Decimal.equal?(product.old_price, Decimal.new("14.99"))
      assert Decimal.equal?(product.new_price, Decimal.new("15.99"))
      assert product.last_changed_at == ~U[2025-12-01 11:00:00Z]
    end

    test "tracks multiple products independently" do
      state = ProductsWithPriceChanges.initial_state()

      event1 = %PriceChanged{
        product_id: "espresso-blend",
        old_price: nil,
        new_price: Decimal.new("15.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      event2 = %PriceChanged{
        product_id: "french-roast",
        old_price: nil,
        new_price: Decimal.new("13.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      state =
        state
        |> ProductsWithPriceChanges.evolve(event1)
        |> ProductsWithPriceChanges.evolve(event2)

      assert map_size(state.products) == 2
      assert state.products["espresso-blend"] != nil
      assert state.products["french-roast"] != nil
    end
  end

  describe "all_products/1" do
    test "returns all tracked products" do
      state = ProductsWithPriceChanges.initial_state()

      events = [
        %PriceChanged{
          product_id: "espresso-blend",
          old_price: nil,
          new_price: Decimal.new("15.99"),
          changed_at: ~U[2025-12-01 10:00:00Z]
        },
        %PriceChanged{
          product_id: "french-roast",
          old_price: nil,
          new_price: Decimal.new("13.99"),
          changed_at: ~U[2025-12-01 10:00:00Z]
        }
      ]

      state = Enum.reduce(events, state, &ProductsWithPriceChanges.evolve(&2, &1))

      products = ProductsWithPriceChanges.all_products(state)
      assert length(products) == 2

      product_ids = Enum.map(products, & &1.product_id)
      assert "espresso-blend" in product_ids
      assert "french-roast" in product_ids
    end

    test "returns empty list when no products tracked" do
      state = ProductsWithPriceChanges.initial_state()
      assert ProductsWithPriceChanges.all_products(state) == []
    end
  end

  describe "get_product/2" do
    test "returns product info when product exists" do
      state = ProductsWithPriceChanges.initial_state()

      event = %PriceChanged{
        product_id: "espresso-blend",
        old_price: nil,
        new_price: Decimal.new("15.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      state = ProductsWithPriceChanges.evolve(state, event)

      product = ProductsWithPriceChanges.get_product(state, "espresso-blend")
      assert product != nil
      assert product.product_id == "espresso-blend"
    end

    test "returns nil when product not found" do
      state = ProductsWithPriceChanges.initial_state()
      assert ProductsWithPriceChanges.get_product(state, "nonexistent") == nil
    end
  end

  describe "changed_since/2" do
    test "returns products changed after timestamp" do
      state = ProductsWithPriceChanges.initial_state()

      events = [
        %PriceChanged{
          product_id: "espresso-blend",
          old_price: nil,
          new_price: Decimal.new("15.99"),
          changed_at: ~U[2025-12-01 09:00:00Z]
        },
        %PriceChanged{
          product_id: "french-roast",
          old_price: nil,
          new_price: Decimal.new("13.99"),
          changed_at: ~U[2025-12-01 11:00:00Z]
        }
      ]

      state = Enum.reduce(events, state, &ProductsWithPriceChanges.evolve(&2, &1))

      # Query for changes after 10:00
      products = ProductsWithPriceChanges.changed_since(state, ~U[2025-12-01 10:00:00Z])

      assert length(products) == 1
      assert hd(products).product_id == "french-roast"
    end
  end

  describe "has_price_changes?/2" do
    test "returns true when product has price changes" do
      state = ProductsWithPriceChanges.initial_state()

      event = %PriceChanged{
        product_id: "espresso-blend",
        old_price: nil,
        new_price: Decimal.new("15.99"),
        changed_at: ~U[2025-12-01 10:00:00Z]
      }

      state = ProductsWithPriceChanges.evolve(state, event)

      assert ProductsWithPriceChanges.has_price_changes?(state, "espresso-blend") == true
    end

    test "returns false when product has no price changes" do
      state = ProductsWithPriceChanges.initial_state()
      assert ProductsWithPriceChanges.has_price_changes?(state, "espresso-blend") == false
    end
  end

  describe "project/1" do
    test "projects list of events into final state" do
      events = [
        %PriceChanged{
          product_id: "espresso-blend",
          old_price: nil,
          new_price: Decimal.new("14.99"),
          changed_at: ~U[2025-12-01 09:00:00Z]
        },
        %PriceChanged{
          product_id: "espresso-blend",
          old_price: Decimal.new("14.99"),
          new_price: Decimal.new("15.99"),
          changed_at: ~U[2025-12-01 10:00:00Z]
        },
        %PriceChanged{
          product_id: "french-roast",
          old_price: nil,
          new_price: Decimal.new("13.99"),
          changed_at: ~U[2025-12-01 11:00:00Z]
        }
      ]

      state = ProductsWithPriceChanges.project(events)

      assert map_size(state.products) == 2

      espresso = state.products["espresso-blend"]
      assert Decimal.equal?(espresso.new_price, Decimal.new("15.99"))
      assert Decimal.equal?(espresso.old_price, Decimal.new("14.99"))

      french = state.products["french-roast"]
      assert Decimal.equal?(french.new_price, Decimal.new("13.99"))
    end
  end
end
