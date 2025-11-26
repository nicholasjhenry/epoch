defmodule Epoch.Slices.RemoveItemTest do
  use EpochWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemAdded
  alias Epoch.EventStore
  alias Epoch.Slices.RemoveItem.Command, as: RemoveItem
  alias Epoch.Slices.RemoveItem.CommandHandler

  setup do
    session_id = Ecto.UUID.generate()
    stream_name = "cart-#{session_id}"
    {:ok, session_id: session_id, stream_name: stream_name}
  end

  # ===========================================================================
  # User Story 1: Unit Tests for CommandHandler (T007-T009)
  # ===========================================================================

  describe "CommandHandler.handle/1" do
    test "given item not in cart then returns error", %{
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with one item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      # STEP: Then - trying to remove non-existent item returns error
      assert {:error, :item_not_found} =
               CommandHandler.handle(%RemoveItem{
                 session_id: session_id,
                 item_id: "non-existent-item"
               })
    end

    test "given item exists then ItemRemoved event appended", %{
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with one item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      # STEP: When - remove the item
      {:ok, _state} =
        CommandHandler.handle(%RemoveItem{
          session_id: session_id,
          item_id: "item-1"
        })

      # STEP: Then - ItemRemoved event was appended
      {:ok, %{events: all_events}} = EventStore.read_stream(stream_name)
      assert length(all_events) == 2

      removed_event = List.last(all_events)
      assert %Cart.Events.ItemRemoved{item_id: "item-1"} = removed_event
    end

    test "given two items then removing one returns updated cart state", %{
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with two items
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      # STEP: When - remove item-1
      {:ok, state} =
        CommandHandler.handle(%RemoveItem{
          session_id: session_id,
          item_id: "item-1"
        })

      # STEP: Then - returned state only has item-2
      assert length(state.items) == 1
      assert [%{item_id: "item-2", name: "French Roast"}] = state.items
      assert state.total == 13.99
    end
  end

  # ===========================================================================
  # User Story 1: Integration Tests (T010-T013)
  # ===========================================================================

  describe "clicking remove button" do
    test "given two items then clicking remove removes item from display", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with two items
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify both items are displayed
      assert has_element?(view, "#cart-item-item-1")
      assert has_element?(view, "#cart-item-item-2")

      # STEP: When - click remove button for item-1
      view
      |> element("#remove-item-item-1")
      |> render_click()

      # STEP: Then - item-1 is removed, item-2 remains
      refute has_element?(view, "#cart-item-item-1")
      assert has_element?(view, "#cart-item-item-2")
    end

    test "given two items then removing one updates cart total", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with two items
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify initial total
      assert has_element?(view, "#cart-total", "$28.98")

      # STEP: When - remove item-1
      view
      |> element("#remove-item-item-1")
      |> render_click()

      # STEP: Then - total updates to only item-2's price
      assert has_element?(view, "#cart-total", "$13.99")
    end

    test "given one item then removing it shows empty cart state", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with one item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify item is displayed
      assert has_element?(view, "#cart-item-item-1")
      refute has_element?(view, "#cart-empty")

      # STEP: When - remove the only item
      view
      |> element("#remove-item-item-1")
      |> render_click()

      # STEP: Then - empty cart state is shown
      assert has_element?(view, "#cart-empty")
      refute has_element?(view, "#cart-items")
    end

    test "given error flash message then it is displayed", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with one item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # STEP: When - send flash message (simulates component error handling)
      send(view.pid, {:flash, :error, "Item not found in cart"})

      # STEP: Then - flash message is displayed
      assert render(view) =~ "Item not found in cart"
    end
  end

  # ===========================================================================
  # User Story 2: Visual Feedback Tests (T018)
  # ===========================================================================

  describe "visual feedback on removal" do
    test "given item in cart then clicking remove makes it disappear immediately", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      assert has_element?(view, "#cart-item-item-1")

      # STEP: When - click remove
      view
      |> element("#remove-item-item-1")
      |> render_click()

      # STEP: Then - item is gone (PubSub triggers reload within same request cycle)
      refute has_element?(view, "#cart-item-item-1")
    end
  end

  # ===========================================================================
  # User Story 3: Accessibility Tests (T021-T022)
  # ===========================================================================

  describe "remove button accessibility" do
    test "given multiple items then each displays a remove button", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with multiple items
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "french-roast",
          name: "French Roast",
          price: 13.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # STEP: Then - each item row has a remove button
      assert has_element?(view, "#remove-item-item-1")
      assert has_element?(view, "#remove-item-item-2")
    end

    test "given item in cart then remove button has accessible label", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with item
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # STEP: Then - remove button has aria-label for accessibility
      html = render(view)
      assert html =~ ~r/aria-label="Remove Espresso Blend from cart"/
    end
  end
end
