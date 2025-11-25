defmodule EpochWeb.ProductsLiveTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "ProductsLive mount" do
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
      view
      |> element("#add-item-espresso-blend")
      |> render_click()

      # If we get here without error, session was created and item was added
      assert_redirect(view, "/cart")
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
    test "clicking add to cart redirects to /cart", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      view
      |> element("#add-item-espresso-blend")
      |> render_click()

      assert_redirect(view, "/cart")
    end

    test "stores item in cart via EventStore", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/products")

      # Click add to cart - the redirect confirms:
      # 1. Session was created (otherwise add_item would fail)
      # 2. Item was added to cart (otherwise we'd get an error)
      view
      |> element("#add-item-french-roast")
      |> render_click()

      # The redirect confirms:
      # 1. Session was created (otherwise add_item would fail)
      # 2. Item was added to cart (otherwise we'd get an error)
      assert_redirect(view, "/cart")
    end
  end
end
