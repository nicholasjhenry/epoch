defmodule EpochWeb.CartLiveTest do
  use EpochWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Epoch.Cart.Events.{CartCleared, ItemAdded, ItemRemoved}
  alias Epoch.EventStore

  setup do
    session_id = Ecto.UUID.generate()
    stream_name = "cart-#{session_id}"
    {:ok, session_id: session_id, stream_name: stream_name}
  end

  describe "mount - empty cart" do
    test "displays empty cart message when no events exist", %{conn: conn, session_id: session_id} do
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      assert has_element?(view, "#cart")
      assert has_element?(view, "#cart-empty")
      refute has_element?(view, "#cart-items")
    end

    test "hides items table and total when empty", %{conn: conn, session_id: session_id} do
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      refute has_element?(view, "#cart-items")
      refute has_element?(view, "#cart-total")
    end
  end

  describe "mount - cart with items" do
    test "displays items when cart has items", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
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

      refute has_element?(view, "#cart-empty")
      assert has_element?(view, "#cart-items")
      assert has_element?(view, "#cart-item-item-1")
    end

    test "correctly renders item names and formatted prices", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
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

      # Check item names
      assert has_element?(view, "#cart-item-name-item-1", "Espresso Blend")
      assert has_element?(view, "#cart-item-name-item-2", "French Roast")

      # Check formatted prices
      assert has_element?(view, "#cart-item-price-item-1", "$14.99")
      assert has_element?(view, "#cart-item-price-item-2", "$13.99")
    end

    test "displays correct total", %{conn: conn, session_id: session_id, stream_name: stream_name} do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "Product 1",
          price: 10.00,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "Product 2",
          price: 15.50,
          added_at: DateTime.utc_now()
        }
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      assert has_element?(view, "#cart-total", "$25.50")
    end
  end

  describe "item removal" do
    test "shows only remaining items after ItemRemoved event", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "Product 1",
          price: 10.00,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "Product 2",
          price: 20.00,
          added_at: DateTime.utc_now()
        },
        %ItemRemoved{item_id: "item-1", removed_at: DateTime.utc_now()}
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      refute has_element?(view, "#cart-item-item-1")
      assert has_element?(view, "#cart-item-item-2")
      assert has_element?(view, "#cart-total", "$20.00")
    end
  end

  describe "navigation" do
    test "renders navigation bar", %{conn: conn, session_id: session_id} do
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      assert has_element?(view, "#nav-main")
    end

    test "renders products navigation link", %{conn: conn, session_id: session_id} do
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      assert has_element?(view, "#nav-products")
    end

    test "renders cart navigation link with current session", %{
      conn: conn,
      session_id: session_id
    } do
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      assert has_element?(view, "#nav-cart")

      # Verify the cart link points to the current session
      html = render(view)
      assert html =~ ~r{href="/cart/#{session_id}"}
    end

    test "products link navigates back without creating new cart", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      # Add an item to the cart first
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

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")
      assert has_element?(view, "#cart-item-item-1")

      # Verify products link exists and can be clicked
      assert has_element?(view, "#nav-products")
    end
  end

  describe "cart cleared" do
    test "displays empty state after CartCleared event", %{
      conn: conn,
      session_id: session_id,
      stream_name: stream_name
    } do
      events = [
        %ItemAdded{
          item_id: "item-1",
          product_id: "p1",
          name: "Product 1",
          price: 10.00,
          added_at: DateTime.utc_now()
        },
        %ItemAdded{
          item_id: "item-2",
          product_id: "p2",
          name: "Product 2",
          price: 20.00,
          added_at: DateTime.utc_now()
        },
        %CartCleared{cleared_at: DateTime.utc_now()}
      ]

      {:ok, _} = EventStore.append_to_stream(stream_name, events)

      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      assert has_element?(view, "#cart-empty")
      refute has_element?(view, "#cart-items")
    end
  end
end
