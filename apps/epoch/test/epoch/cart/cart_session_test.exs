defmodule Epoch.Cart.CartSessionTest do
  use ExUnit.Case, async: true

  alias Epoch.Cart.CartSession
  alias Epoch.Cart.Events.{CartCleared, CartCreated, ItemAdded, ItemArchived, ItemRemoved}

  describe "evolve/2 with CartCreated" do
    test "sets session_id and created_at" do
      state = %CartSession{}
      now = DateTime.utc_now()

      event = %CartCreated{session_id: "session-123", created_at: now}

      new_state = CartSession.evolve(state, event)

      assert new_state.session_id == "session-123"
      assert new_state.created_at == now
      assert new_state.items == []
    end
  end

  describe "evolve/2 with ItemAdded" do
    test "adds new item to empty cart" do
      state = %CartSession{session_id: "session-123"}

      event = %ItemAdded{
        item_id: "colombian-supremo-123456",
        product_id: "colombian-supremo",
        name: "Colombian Supremo",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).product_id == "colombian-supremo"
      assert hd(new_state.items).quantity == 1
    end

    test "increments quantity for existing product" do
      state = %CartSession{
        session_id: "session-123",
        items: [%{product_id: "colombian-supremo", quantity: 1}]
      }

      event = %ItemAdded{
        item_id: "colombian-supremo-789012",
        product_id: "colombian-supremo",
        name: "Colombian Supremo",
        price: 14.99,
        added_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).quantity == 2
    end
  end

  describe "evolve/2 with ItemRemoved" do
    test "decrements quantity when quantity > 1" do
      state = %CartSession{
        session_id: "session-123",
        items: [%{product_id: "colombian-supremo", quantity: 2}]
      }

      event = %ItemRemoved{
        item_id: "colombian-supremo-123456",
        removed_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert length(new_state.items) == 1
      assert hd(new_state.items).quantity == 1
    end

    test "removes item when quantity is 1" do
      state = %CartSession{
        session_id: "session-123",
        items: [%{product_id: "colombian-supremo", quantity: 1}]
      }

      event = %ItemRemoved{
        item_id: "colombian-supremo-123456",
        removed_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert new_state.items == []
    end

    test "handles non-existent item gracefully" do
      state = %CartSession{
        session_id: "session-123",
        items: [%{product_id: "espresso-blend", quantity: 1}]
      }

      event = %ItemRemoved{
        item_id: "non-existent-product-123456",
        removed_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert new_state.items == state.items
    end
  end

  describe "evolve/2 with ItemArchived" do
    test "removes item same as ItemRemoved" do
      state = %CartSession{
        session_id: "session-123",
        items: [%{product_id: "colombian-supremo", quantity: 1}]
      }

      event = %ItemArchived{
        item_id: "colombian-supremo-123456",
        archived_at: DateTime.utc_now()
      }

      new_state = CartSession.evolve(state, event)

      assert new_state.items == []
    end
  end

  describe "evolve/2 with CartCleared" do
    test "resets cart to initial state" do
      state = %CartSession{
        session_id: "session-123",
        items: [
          %{product_id: "colombian-supremo", quantity: 2},
          %{product_id: "espresso-blend", quantity: 1}
        ],
        created_at: DateTime.utc_now()
      }

      event = %CartCleared{cleared_at: DateTime.utc_now()}

      new_state = CartSession.evolve(state, event)

      assert new_state.items == []
      assert new_state.session_id == nil
      assert new_state.created_at == nil
    end
  end

  describe "regression: add -> remove -> add sequence" do
    test "handles full event sequence without error" do
      # This test prevents regression of the FunctionClauseError that occurred
      # when CartSession.evolve/2 was missing handlers for ItemRemoved events.
      # The bug manifested when: 1) add item, 2) remove item, 3) add item again
      # The third step failed because replaying events hit the unhandled ItemRemoved.

      initial_state = %CartSession{}
      now = DateTime.utc_now()
      timestamp = DateTime.to_unix(now, :microsecond)

      events = [
        %CartCreated{session_id: "session-123", created_at: now},
        %ItemAdded{
          item_id: "colombian-supremo-#{timestamp}",
          product_id: "colombian-supremo",
          name: "Colombian Supremo",
          price: 14.99,
          added_at: now
        },
        %ItemRemoved{
          item_id: "colombian-supremo-#{timestamp}",
          removed_at: now
        },
        %ItemAdded{
          item_id: "colombian-supremo-#{timestamp + 1000}",
          product_id: "colombian-supremo",
          name: "Colombian Supremo",
          price: 14.99,
          added_at: now
        }
      ]

      # This should not raise FunctionClauseError
      final_state = Enum.reduce(events, initial_state, &CartSession.evolve(&2, &1))

      assert final_state.session_id == "session-123"
      assert length(final_state.items) == 1
      assert hd(final_state.items).product_id == "colombian-supremo"
      assert hd(final_state.items).quantity == 1
    end

    test "handles multiple add/remove cycles" do
      initial_state = %CartSession{}
      now = DateTime.utc_now()

      events = [
        %CartCreated{session_id: "session-123", created_at: now},
        # First add
        %ItemAdded{
          item_id: "product-a-1000",
          product_id: "product-a",
          name: "Product A",
          price: 10.0,
          added_at: now
        },
        # Second add (same product)
        %ItemAdded{
          item_id: "product-a-2000",
          product_id: "product-a",
          name: "Product A",
          price: 10.0,
          added_at: now
        },
        # Remove one
        %ItemRemoved{item_id: "product-a-1000", removed_at: now},
        # Add different product
        %ItemAdded{
          item_id: "product-b-3000",
          product_id: "product-b",
          name: "Product B",
          price: 20.0,
          added_at: now
        },
        # Remove remaining product-a
        %ItemRemoved{item_id: "product-a-2000", removed_at: now},
        # Add product-a again
        %ItemAdded{
          item_id: "product-a-4000",
          product_id: "product-a",
          name: "Product A",
          price: 10.0,
          added_at: now
        }
      ]

      final_state = Enum.reduce(events, initial_state, &CartSession.evolve(&2, &1))

      assert length(final_state.items) == 2

      product_a = Enum.find(final_state.items, &(&1.product_id == "product-a"))
      product_b = Enum.find(final_state.items, &(&1.product_id == "product-b"))

      assert product_a.quantity == 1
      assert product_b.quantity == 1
    end
  end
end
