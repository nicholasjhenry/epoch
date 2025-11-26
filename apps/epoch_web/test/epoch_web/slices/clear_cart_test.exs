defmodule Epoch.Slices.ClearCartTest do
  use EpochWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemAdded
  alias Epoch.EventStore
  alias Epoch.Slices.ClearCart.Command, as: ClearCart
  alias Epoch.Slices.ClearCart.CommandHandler

  setup do
    session_id = Ecto.UUID.generate()
    stream_name = "cart-#{session_id}"
    {:ok, session_id: session_id, stream_name: stream_name}
  end

  # ===========================================================================
  # User Story 1: Unit Tests for CommandHandler (T002-T004)
  # ===========================================================================

  describe "CommandHandler.handle/1" do
    test "given non-empty cart then validates successfully", %{
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # STEP: When - clear the cart
      result = CommandHandler.handle(%ClearCart{session_id: session_id})

      # STEP: Then - command succeeds
      assert {:ok, _state} = result
    end

    test "given non-empty cart then emits CartCleared event", %{
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # STEP: When - clear the cart
      {:ok, _state} = CommandHandler.handle(%ClearCart{session_id: session_id})

      # STEP: Then - CartCleared event was appended
      {:ok, %{events: all_events}} = EventStore.read_stream(stream_name)
      assert length(all_events) == 2

      cleared_event = List.last(all_events)
      assert %Cart.Events.CartCleared{cleared_at: _} = cleared_event
    end

    test "given empty cart then returns error", %{session_id: session_id} do
      # STEP: Given - empty cart (no events)

      # STEP: When - attempt to clear the cart
      result = CommandHandler.handle(%ClearCart{session_id: session_id})

      # STEP: Then - returns error
      assert {:error, :cart_empty} = result
    end

    test "given multiple items then clearing returns empty cart state", %{
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

      # STEP: When - clear the cart
      {:ok, state} = CommandHandler.handle(%ClearCart{session_id: session_id})

      # STEP: Then - returned state is empty
      assert state.items == []
      assert state.total == 0.0
    end
  end

  # ===========================================================================
  # User Story 1: Integration Test (T005)
  # ===========================================================================

  describe "cart display after clearing" do
    test "given items in cart then clearing shows empty cart state", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # Verify items are displayed
      assert has_element?(cart_items_view, "#cart-item-item-1")
      assert has_element?(cart_items_view, "#cart-item-item-2")
      refute has_element?(cart_items_view, "#cart-empty")

      # STEP: When - click clear cart button and confirm
      cart_items_view
      |> element("#clear-cart-button")
      |> render_click()

      # STEP: Then - empty cart state is shown
      assert has_element?(cart_items_view, "#cart-empty")
      refute has_element?(cart_items_view, "#cart-item-item-1")
      refute has_element?(cart_items_view, "#cart-item-item-2")
    end
  end

  # ===========================================================================
  # User Story 2: Confirmation Dialog Tests (T008-T009)
  # ===========================================================================

  describe "ClearCart.Component rendering" do
    test "given component then renders with phx-confirm attribute", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: Then - clear cart button has phx-confirm attribute
      html = render(cart_items_view)
      assert html =~ ~r/phx-confirm=/
      assert html =~ "Are you sure"
    end

    test "given confirmation dialog then clicking confirm clears cart", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # Verify item is displayed
      assert has_element?(cart_items_view, "#cart-item-item-1")

      # STEP: When - click clear cart button (simulates user confirming)
      cart_items_view
      |> element("#clear-cart-button")
      |> render_click()

      # STEP: Then - cart is cleared
      assert has_element?(cart_items_view, "#cart-empty")
      refute has_element?(cart_items_view, "#cart-item-item-1")
    end
  end

  # ===========================================================================
  # User Story 3: Button Visibility Tests (T013-T015)
  # ===========================================================================

  describe "Clear Cart button visibility" do
    test "given cart has items then Clear Cart button is visible", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: Then - Clear Cart button is visible
      assert has_element?(cart_items_view, "#clear-cart-button")
    end

    test "given cart is empty then Clear Cart button is NOT visible", %{
      conn: conn,
      session_id: session_id
    } do
      # STEP: Given - empty cart (no events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: Then - Clear Cart button is not visible
      refute has_element?(cart_items_view, "#clear-cart-button")
    end

    test "given items in cart then button disappears after clearing", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # Verify button is visible
      assert has_element?(cart_items_view, "#clear-cart-button")

      # STEP: When - click clear cart button
      cart_items_view
      |> element("#clear-cart-button")
      |> render_click()

      # STEP: Then - button is no longer visible
      refute has_element?(cart_items_view, "#clear-cart-button")
    end
  end

  # ===========================================================================
  # Error Handling Tests
  # ===========================================================================

  describe "error handling" do
    test "given error then flash message is displayed", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # STEP: Given - cart with items
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

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: When - send flash message to nested view (simulates component error handling)
      send(cart_items_view.pid, {:flash, :error, "Unable to clear cart"})

      # STEP: Then - flash message is displayed
      assert render(cart_items_view) =~ "Unable to clear cart"
    end
  end
end
