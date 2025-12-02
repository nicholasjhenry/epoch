defmodule Epoch.Slices.SubmitCartTest do
  use EpochWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Epoch.Backoffice.Events.InventoryUpdated
  alias Epoch.Cart.Events.ItemAdded
  alias Epoch.EventStore

  setup do
    session_id = Ecto.UUID.generate()
    cart_stream = "cart-#{session_id}"
    {:ok, session_id: session_id, cart_stream: cart_stream}
  end

  # Helper to add inventory for a product
  defp set_inventory(product_id, quantity) do
    event = %InventoryUpdated{
      product_id: product_id,
      quantity: quantity,
      updated_at: DateTime.utc_now()
    }

    stream_name = "inventory-#{product_id}"
    EventStore.append_to_stream(stream_name, [event])
  end

  # ===========================================================================
  # Phase 7: UI Integration Tests (T023-T024)
  # ===========================================================================

  describe "Submit Cart button" do
    # T023: End-to-end cart submission success flow
    test "given cart with items and inventory then clicking submit shows success flash", %{
      conn: conn,
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with items
      events = [
        %ItemAdded{
          cart_id: session_id,
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(cart_stream, events)

      # STEP: Given - inventory is available
      set_inventory("espresso-blend", 10)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # Verify submit button is visible
      assert has_element?(cart_items_view, "#submit-cart-button")

      # STEP: When - click submit cart button
      cart_items_view
      |> element("#submit-cart-button")
      |> render_click()

      # STEP: Then - success flash is shown
      assert render(cart_items_view) =~ "Cart submitted successfully!"
    end

    # T024: End-to-end cart submission failure shows error flash
    test "given cart with items but no inventory then clicking submit shows error flash", %{
      conn: conn,
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with items
      events = [
        %ItemAdded{
          cart_id: session_id,
          item_id: "item-1",
          product_id: "out-of-stock-product",
          name: "Out of Stock Product",
          price: 19.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(cart_stream, events)

      # STEP: Given - inventory is 0
      set_inventory("out-of-stock-product", 0)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Get the nested CartItems LiveView
      cart_items_view = find_live_child(view, "cart-items-live")

      # Verify submit button is visible
      assert has_element?(cart_items_view, "#submit-cart-button")

      # STEP: When - click submit cart button
      cart_items_view
      |> element("#submit-cart-button")
      |> render_click()

      # STEP: Then - error flash is shown
      assert render(cart_items_view) =~ "Cannot order products without quantity"
    end

    test "given cart with items and inventory then CartSubmitted event is appended", %{
      conn: conn,
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with items
      events = [
        %ItemAdded{
          cart_id: session_id,
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(cart_stream, events)
      set_inventory("espresso-blend", 10)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: When - click submit cart button
      cart_items_view
      |> element("#submit-cart-button")
      |> render_click()

      # STEP: Then - CartSubmitted event was appended
      {:ok, %{events: all_events}} = EventStore.read_stream(cart_stream)
      cart_submitted = List.last(all_events)
      assert %Epoch.Cart.Events.CartSubmitted{cart_id: ^session_id} = cart_submitted
    end
  end

  describe "Submit Cart button visibility" do
    test "given cart has items then Submit Cart button is visible", %{
      conn: conn,
      session_id: session_id,
      cart_stream: cart_stream
    } do
      # STEP: Given - cart with items
      events = [
        %ItemAdded{
          cart_id: session_id,
          item_id: "item-1",
          product_id: "espresso-blend",
          name: "Espresso Blend",
          price: 14.99,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(cart_stream, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: Then - Submit Cart button is visible
      assert has_element?(cart_items_view, "#submit-cart-button")
    end

    test "given cart is empty then Submit Cart button is NOT visible", %{
      conn: conn,
      session_id: session_id
    } do
      # STEP: Given - empty cart (no events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      cart_items_view = find_live_child(view, "cart-items-live")

      # STEP: Then - Submit Cart button is not visible (empty cart shows empty state)
      refute has_element?(cart_items_view, "#submit-cart-button")
    end
  end
end
