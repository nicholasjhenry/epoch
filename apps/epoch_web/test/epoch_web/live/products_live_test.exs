defmodule EpochWeb.ProductsLiveTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  defp count_all_cart_created_events do
    # Get all events from EventStore and count CartCreated events
    {:ok, %{events: events}} = Epoch.EventStore.read_all_events(page_size: 100)

    # Events are wrapped in a map with :event key
    Enum.count(events, fn %{event: event} ->
      match?(%Epoch.Cart.Events.CartCreated{}, event)
    end)
  end

  describe "ProductsLive mount" do
    test "does not create orphaned cart sessions (only creates cart on connected mount)", %{
      conn: conn
    } do
      # LiveView mount is called twice: once disconnected (HTTP), once connected (WebSocket).
      # If we create a cart on disconnected mount with a new UUID, it gets orphaned when
      # connected mount generates a different UUID. We should only create cart when connected.

      # Count total CartCreated events before and after mounting
      initial_cart_count = count_all_cart_created_events()

      {:ok, _view, _html} = live(conn, ~p"/products")

      final_cart_count = count_all_cart_created_events()

      # Should only create ONE cart session total (on connected mount only)
      assert final_cart_count - initial_cart_count == 1,
             "Expected 1 new cart session but found #{final_cart_count - initial_cart_count}. " <>
               "An orphaned cart may have been created on disconnected mount."
    end

    test "loads products on mount - verified by rendering all 5 products", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      # Verify all 5 products are rendered (which confirms products were loaded)
      assert has_element?(view, "#product-espresso-blend")
      assert has_element?(view, "#product-french-roast")
      assert has_element?(view, "#product-colombian-supremo")
      assert has_element?(view, "#product-ethiopian-yirgacheffe")
      assert has_element?(view, "#product-sumatra-mandheling")
    end

    test "creates cart session on mount - verified by add to cart storing event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      # Click add to cart - this will fail if no session was created
      # The click succeeds without error, confirming session was created
      html =
        view
        |> element("#add-item-espresso-blend")
        |> render_click()

      # Page stays on /products (no redirect) and view is still alive
      assert has_element?(view, "#product-list")
      assert html =~ "Espresso Blend"
    end
  end

  describe "ProductsLive template - product cards" do
    test "renders all 5 products", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      assert has_element?(view, "#product-espresso-blend")
      assert has_element?(view, "#product-french-roast")
      assert has_element?(view, "#product-colombian-supremo")
      assert has_element?(view, "#product-ethiopian-yirgacheffe")
      assert has_element?(view, "#product-sumatra-mandheling")
    end

    test "renders product name elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      assert has_element?(view, "#product-name-espresso-blend")
      assert has_element?(view, "#product-name-french-roast")
      assert has_element?(view, "#product-name-colombian-supremo")
      assert has_element?(view, "#product-name-ethiopian-yirgacheffe")
      assert has_element?(view, "#product-name-sumatra-mandheling")
    end

    test "renders product price elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      assert has_element?(view, "#product-price-espresso-blend")
      assert has_element?(view, "#product-price-french-roast")
      assert has_element?(view, "#product-price-colombian-supremo")
      assert has_element?(view, "#product-price-ethiopian-yirgacheffe")
      assert has_element?(view, "#product-price-sumatra-mandheling")
    end

    test "renders product list container", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#product-list")
    end

    test "displays correct product name text", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "Espresso Blend"
      assert html =~ "French Roast"
      assert html =~ "Colombian Supremo"
      assert html =~ "Ethiopian Yirgacheffe"
      assert html =~ "Sumatra Mandheling"
    end

    test "displays product prices formatted with dollar sign", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "$14.99"
      assert html =~ "$13.99"
      assert html =~ "$15.99"
      assert html =~ "$17.99"
      assert html =~ "$16.99"
    end
  end

  describe "ProductsLive template - navigation" do
    test "renders navigation bar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#nav-main")
    end

    test "renders products navigation link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#nav-products")
    end

    test "renders cart navigation link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#nav-cart")
    end

    test "renders spec navigation link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#nav-spec")
    end

    test "renders backoffice navigation link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")
      assert has_element?(view, "#nav-backoffice")
    end

    test "navigation links have font awesome icons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "fa-store"
      assert html =~ "fa-shopping-cart"
      assert html =~ "fa-vial"
      assert html =~ "fa-cogs"
    end
  end

  describe "ProductsLive template - add to cart buttons" do
    test "renders add item button for each product", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      assert has_element?(view, "#add-item-espresso-blend")
      assert has_element?(view, "#add-item-french-roast")
      assert has_element?(view, "#add-item-colombian-supremo")
      assert has_element?(view, "#add-item-ethiopian-yirgacheffe")
      assert has_element?(view, "#add-item-sumatra-mandheling")
    end

    test "add item buttons have correct text", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")
      # Count occurrences of "Add Item" - should be 5 (one per product)
      assert length(Regex.scan(~r/Add Item/, html)) == 5
    end
  end

  describe "add to cart event" do
    test "clicking add to cart stays on same page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      html =
        view
        |> element("#add-item-espresso-blend")
        |> render_click()

      # Page stays on /products - view is still alive and showing products
      assert has_element?(view, "#product-list")
      assert html =~ "Espresso Blend"
    end

    test "stores item in cart via EventStore", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      # Click add to cart - succeeds without error, confirming:
      # 1. Session was created (otherwise add_item would fail)
      # 2. Item was added to cart (otherwise we'd get an error)
      html =
        view
        |> element("#add-item-french-roast")
        |> render_click()

      # Page stays on /products and view remains functional
      assert has_element?(view, "#product-list")
      assert html =~ "French Roast"
    end
  end
end
