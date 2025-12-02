defmodule Epoch.Cart.ItemsToArchiveTest do
  use ExUnit.Case, async: true

  alias Epoch.Cart.Events.{ItemArchived, ItemArchiveRequested}
  alias Epoch.Cart.ItemsToArchive

  describe "evolve/2 with ItemArchiveRequested" do
    test "given new item then adds to pending list" do
      state = ItemsToArchive.initial_state()

      event = %ItemArchiveRequested{
        cart_id: "cart-123",
        product_id: "espresso-blend",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      new_state = ItemsToArchive.evolve(state, event)

      assert length(new_state.pending) == 1
      item = hd(new_state.pending)
      assert item.cart_id == "cart-123"
      assert item.product_id == "espresso-blend"
      assert item.item_id == "espresso-blend-001"
      assert item.reason == "price_changed"
    end

    test "given duplicate item_id then does not add duplicate (idempotent)" do
      state = ItemsToArchive.initial_state()

      event = %ItemArchiveRequested{
        cart_id: "cart-123",
        product_id: "espresso-blend",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      # Apply same event twice
      state =
        state
        |> ItemsToArchive.evolve(event)
        |> ItemsToArchive.evolve(event)

      # Should only have one pending item
      assert length(state.pending) == 1
    end

    test "given different items then adds all to pending" do
      state = ItemsToArchive.initial_state()

      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "espresso-blend-001",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "espresso-blend",
          item_id: "espresso-blend-002",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        }
      ]

      state = Enum.reduce(events, state, &ItemsToArchive.evolve(&2, &1))

      assert length(state.pending) == 2
    end
  end

  describe "evolve/2 with ItemArchived" do
    test "given pending item then removes from pending list" do
      state = ItemsToArchive.initial_state()

      request_event = %ItemArchiveRequested{
        cart_id: "cart-123",
        product_id: "espresso-blend",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      archived_event = %ItemArchived{
        cart_id: "cart-123",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        archived_at: DateTime.utc_now()
      }

      state =
        state
        |> ItemsToArchive.evolve(request_event)
        |> ItemsToArchive.evolve(archived_event)

      assert state.pending == []
    end

    test "given non-pending item then state unchanged" do
      state = ItemsToArchive.initial_state()

      archived_event = %ItemArchived{
        cart_id: "cart-123",
        item_id: "nonexistent-item",
        reason: "price_changed",
        archived_at: DateTime.utc_now()
      }

      new_state = ItemsToArchive.evolve(state, archived_event)

      assert new_state.pending == []
    end
  end

  describe "all_pending/1" do
    test "given items pending then returns all pending items" do
      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "item-1",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "french-roast",
          item_id: "item-2",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        }
      ]

      state = ItemsToArchive.project(events)

      pending = ItemsToArchive.all_pending(state)
      assert length(pending) == 2
    end

    test "given no pending items then returns empty list" do
      state = ItemsToArchive.initial_state()
      assert ItemsToArchive.all_pending(state) == []
    end
  end

  describe "pending?/2" do
    test "given pending item then returns true" do
      state = ItemsToArchive.initial_state()

      event = %ItemArchiveRequested{
        cart_id: "cart-123",
        product_id: "espresso-blend",
        item_id: "espresso-blend-001",
        reason: "price_changed",
        requested_at: DateTime.utc_now()
      }

      state = ItemsToArchive.evolve(state, event)

      assert ItemsToArchive.pending?(state, "espresso-blend-001") == true
    end

    test "given non-pending item then returns false" do
      state = ItemsToArchive.initial_state()
      assert ItemsToArchive.pending?(state, "nonexistent") == false
    end
  end

  describe "pending_for_cart/2" do
    test "given items in multiple carts then returns only items for specified cart" do
      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "item-1",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        },
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "french-roast",
          item_id: "item-2",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "espresso-blend",
          item_id: "item-3",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        }
      ]

      state = ItemsToArchive.project(events)

      cart_123_items = ItemsToArchive.pending_for_cart(state, "cart-123")
      assert length(cart_123_items) == 2

      cart_456_items = ItemsToArchive.pending_for_cart(state, "cart-456")
      assert length(cart_456_items) == 1
    end
  end

  describe "pending_count/1" do
    test "given items pending then returns count" do
      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "item-1",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "french-roast",
          item_id: "item-2",
          reason: "price_changed",
          requested_at: DateTime.utc_now()
        }
      ]

      state = ItemsToArchive.project(events)

      assert ItemsToArchive.pending_count(state) == 2
    end

    test "given no pending items then returns 0" do
      state = ItemsToArchive.initial_state()
      assert ItemsToArchive.pending_count(state) == 0
    end
  end

  describe "project/1" do
    test "given sequence of events then builds correct final state" do
      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "item-1",
          reason: "price_changed",
          requested_at: ~U[2025-01-01 10:00:00Z]
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "french-roast",
          item_id: "item-2",
          reason: "price_changed",
          requested_at: ~U[2025-01-01 10:01:00Z]
        },
        %ItemArchived{
          cart_id: "cart-123",
          item_id: "item-1",
          reason: "price_changed",
          archived_at: ~U[2025-01-01 10:02:00Z]
        }
      ]

      state = ItemsToArchive.project(events)

      # item-1 was archived, only item-2 should remain
      assert length(state.pending) == 1
      assert hd(state.pending).item_id == "item-2"
    end
  end

  describe "oldest_pending/1" do
    test "given multiple pending items then returns oldest by requested_at" do
      events = [
        %ItemArchiveRequested{
          cart_id: "cart-123",
          product_id: "espresso-blend",
          item_id: "item-newer",
          reason: "price_changed",
          requested_at: ~U[2025-01-01 10:05:00Z]
        },
        %ItemArchiveRequested{
          cart_id: "cart-456",
          product_id: "french-roast",
          item_id: "item-oldest",
          reason: "price_changed",
          requested_at: ~U[2025-01-01 10:00:00Z]
        },
        %ItemArchiveRequested{
          cart_id: "cart-789",
          product_id: "decaf",
          item_id: "item-middle",
          reason: "price_changed",
          requested_at: ~U[2025-01-01 10:02:00Z]
        }
      ]

      state = ItemsToArchive.project(events)

      oldest = ItemsToArchive.oldest_pending(state)
      assert oldest.item_id == "item-oldest"
    end

    test "given no pending items then returns nil" do
      state = ItemsToArchive.initial_state()
      assert ItemsToArchive.oldest_pending(state) == nil
    end
  end
end
