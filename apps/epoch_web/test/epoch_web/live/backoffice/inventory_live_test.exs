defmodule EpochWeb.Backoffice.InventoryLiveTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    # Start a fresh EventStore for each test
    start_supervised!({Epoch.EventStore, name: :"test_event_store_#{System.unique_integer()}"})
    :ok
  end

  describe "mounting inventory form" do
    test "renders form with product_id dropdown and quantity fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      assert has_element?(view, "#inventory-form")
      assert has_element?(view, "select[name='product_id']")
      assert has_element?(view, "input[name='quantity']")
      assert has_element?(view, "button[type='submit']")
      # Verify dropdown contains products
      assert has_element?(view, "option[value='espresso-blend']")
    end
  end

  describe "submitting inventory form" do
    test "shows success message for valid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      html =
        view
        |> form("#inventory-form", %{product_id: "espresso-blend", quantity: "50"})
        |> render_submit()

      assert html =~ "Inventory updated"
      assert html =~ "espresso-blend"
      assert html =~ "50"
    end

    test "shows error when no product selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      # Submit with empty product_id (default "Select a product..." option)
      html =
        view
        |> form("#inventory-form", %{product_id: "", quantity: "50"})
        |> render_submit()

      # Empty product_id will fail validation in Inventory.update_quantity
      assert html =~ "not found" or html =~ "Error"
    end

    test "shows error for negative quantity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      html =
        view
        |> form("#inventory-form", %{product_id: "espresso-blend", quantity: "-10"})
        |> render_submit()

      assert html =~ "Invalid" or html =~ "Error"
    end

    test "shows error for non-numeric quantity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      html =
        view
        |> form("#inventory-form", %{product_id: "espresso-blend", quantity: "abc"})
        |> render_submit()

      assert html =~ "Invalid" or html =~ "Error"
    end
  end
end
