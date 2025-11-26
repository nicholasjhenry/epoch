defmodule Epoch.Cart.CartItemsViewTest do
  use ExUnit.Case, async: true

  alias Epoch.Cart.CartItemsView
  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemArchived, ItemRemoved}

  describe "initial_state/0" do
    test "returns empty items list and zero total" do
      state = CartItemsView.initial_state()

      assert state.items == []
      assert state.total == 0.0
    end
  end

  describe "empty?/1" do
    test "returns true for empty cart state" do
      state = CartItemsView.initial_state()
      assert CartItemsView.empty?(state)
    end

    test "returns false for cart with items" do
      state = %{items: [%{item_id: "item-1", name: "Test", price: 10.0}], total: 10.0}
      refute CartItemsView.empty?(state)
    end
  end

  describe "evolve/2 with ItemAdded" do
    test "adds item to empty cart" do
      state = CartItemsView.initial_state()

      event = %ItemAdded{
        item_id: "item-1",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      new_state = CartItemsView.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).item_id == "item-1"
      assert hd(new_state.items).name == "Espresso Blend"
      assert hd(new_state.items).price == 14.99
      assert new_state.total == 14.99
    end

    test "adds multiple items correctly" do
      state = CartItemsView.initial_state()

      event1 = %ItemAdded{
        item_id: "item-1",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      event2 = %ItemAdded{
        item_id: "item-2",
        product_id: "french-roast",
        name: "French Roast",
        price: 13.99,
        added_at: DateTime.utc_now()
      }

      new_state =
        state
        |> CartItemsView.evolve(event1)
        |> CartItemsView.evolve(event2)

      assert length(new_state.items) == 2
      assert new_state.total == 28.98
    end

    test "processes sequence of ItemAdded events correctly" do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "Product 1",
          price: 10.0,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "Product 2",
          price: 20.0,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-3",
          product_id: "p3",
          name: "Product 3",
          price: 30.0,
          added_at: DateTime.utc_now()
        }
      ]

      state = CartItemsView.project(events)

      assert length(state.items) == 3
      assert state.total == 60.0

      item_names = Enum.map(state.items, & &1.name)
      assert item_names == ["Product 1", "Product 2", "Product 3"]
    end
  end

  describe "evolve/2 with ItemRemoved" do
    test "removes item with matching item_id" do
      state = %{
        items: [
          %{item_id: "item-1", name: "Espresso Blend", price: 14.99},
          %{item_id: "item-2", name: "French Roast", price: 13.99}
        ],
        total: 28.98
      }

      event = %ItemRemoved{item_id: "item-1", removed_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).item_id == "item-2"
      assert_in_delta new_state.total, 13.99, 0.01
    end

    test "decreases total when item removed" do
      state = %{
        items: [%{item_id: "item-1", name: "Test", price: 25.50}],
        total: 25.50
      }

      event = %ItemRemoved{item_id: "item-1", removed_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert new_state.items == []
      assert new_state.total == 0.0
    end

    test "handles ItemRemoved for non-existent item gracefully" do
      state = %{
        items: [%{item_id: "item-1", name: "Test", price: 10.0}],
        total: 10.0
      }

      event = %ItemRemoved{item_id: "non-existent", removed_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert new_state.items == state.items
      assert new_state.total == state.total
    end
  end

  describe "evolve/2 with CartCleared" do
    test "clears all items when processing CartCleared event" do
      state = %{
        items: [
          %{item_id: "item-1", name: "Product 1", price: 10.0},
          %{item_id: "item-2", name: "Product 2", price: 20.0}
        ],
        total: 30.0
      }

      event = %CartCleared{cleared_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert new_state.items == []
      assert new_state.total == 0.0
    end

    test "total is 0.0 after CartCleared" do
      state = %{
        items: [%{item_id: "item-1", name: "Test", price: 100.0}],
        total: 100.0
      }

      event = %CartCleared{cleared_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert new_state.total == 0.0
    end
  end

  describe "evolve/2 with ItemArchived" do
    test "removes item when processing ItemArchived event" do
      state = %{
        items: [
          %{item_id: "item-1", name: "Product 1", price: 10.0},
          %{item_id: "item-2", name: "Product 2", price: 20.0}
        ],
        total: 30.0
      }

      event = %ItemArchived{item_id: "item-1", archived_at: DateTime.utc_now()}

      new_state = CartItemsView.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).item_id == "item-2"
      assert new_state.total == 20.0
    end
  end

  describe "evolve/2 with unknown events" do
    test "ignores unknown event types" do
      state = %{items: [%{item_id: "item-1", name: "Test", price: 10.0}], total: 10.0}

      # Use an arbitrary struct as unknown event
      unknown_event = %Epoch.Cart.Events.CartCreated{
        session_id: "test",
        created_at: DateTime.utc_now()
      }

      new_state = CartItemsView.evolve(state, unknown_event)

      assert new_state == state
    end
  end

  describe "project/1" do
    test "returns empty state for empty event list" do
      state = CartItemsView.project([])

      assert state.items == []
      assert state.total == 0.0
    end

    test "correctly processes mixed event sequence" do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "Product 1",
          price: 10.0,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "Product 2",
          price: 20.0,
          added_at: DateTime.utc_now()
        },
        %ItemRemoved{item_id: "item-1", removed_at: DateTime.utc_now()},
        %ItemAdded{
          item_id: "item-3",
          product_id: "p3",
          name: "Product 3",
          price: 15.0,
          added_at: DateTime.utc_now()
        }
      ]

      state = CartItemsView.project(events)

      assert length(state.items) == 2
      item_ids = Enum.map(state.items, & &1.item_id)
      assert item_ids == ["item-2", "item-3"]
      assert state.total == 35.0
    end
  end

  describe "total calculation" do
    test "sums all item prices correctly" do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "P1",
          price: 10.50,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "P2",
          price: 20.25,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-3",
          product_id: "p3",
          name: "P3",
          price: 5.75,
          added_at: DateTime.utc_now()
        }
      ]

      state = CartItemsView.project(events)

      assert_in_delta state.total, 36.50, 0.01
    end

    test "returns 0.0 for empty cart" do
      state = CartItemsView.initial_state()
      assert state.total == 0.0
    end
  end
end
