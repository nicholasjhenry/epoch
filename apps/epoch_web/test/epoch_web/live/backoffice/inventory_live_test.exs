defmodule EpochWeb.Backoffice.InventoryLiveTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    # Start a fresh EventStore for each test
    start_supervised!({Epoch.EventStore, name: :"test_event_store_#{System.unique_integer()}"})
    :ok
  end

  describe "mounting inventory form" do
    test "renders form with product_id and quantity fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      assert has_element?(view, "#inventory-form")
      assert has_element?(view, "input[name='product_id']")
      assert has_element?(view, "input[name='quantity']")
      assert has_element?(view, "button[type='submit']")
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

    test "shows error for invalid product", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/backoffice/inventory")

      html =
        view
        |> form("#inventory-form", %{product_id: "nonexistent", quantity: "50"})
        |> render_submit()

      assert html =~ "not found" or html =~ "error"
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
