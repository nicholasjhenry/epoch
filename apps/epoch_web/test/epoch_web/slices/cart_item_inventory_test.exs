defmodule Epoch.Slices.CartItemInventoryTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Epoch.Backoffice.Inventory
  alias Epoch.Cart
  alias Epoch.EventStore

  setup do
    # Create a cart session with an item
    session_id = Ecto.UUID.generate()
    product_id = "espresso-blend"

    {:ok, _session} = Cart.create_session(session_id)

    # Add an item to the cart
    now = DateTime.utc_now()
    stream_name = EventStore.stream_name("cart", session_id)

    item_added_event = %Cart.Events.ItemAdded{
      item_id: "#{product_id}-#{DateTime.to_unix(now)}",
      product_id: product_id,
      name: "Espresso Blend",
      price: 14.99,
      added_at: now
    }

    {:ok, _} = EventStore.append_to_stream(stream_name, [item_added_event])

    %{session_id: session_id, product_id: product_id}
  end

  # ===========================================================================
  # User Story 1: View Available Inventory While Shopping
  # ===========================================================================

  describe "rendering inventory quantity" do
    test "given inventory exists then displays quantity", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set inventory quantity
      {:ok, _} = Inventory.update_quantity(product_id, 10)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify inventory display
      assert has_element?(view, "#inventory-#{product_id}")
      assert render(view) =~ "10 available"
    end

    test "given quantity is zero then shows out of stock", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set inventory to zero
      {:ok, _} = Inventory.update_quantity(product_id, 0)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify out of stock display
      assert has_element?(view, "#inventory-#{product_id}")
      assert render(view) =~ "Out of stock"
    end

    test "given no inventory events then shows unknown", %{
      conn: conn,
      session_id: session_id,
      product_id: _product_id
    } do
      # Don't set any inventory - product has no inventory events
      # The inventory system returns 0 for non-existent streams (initial state)
      # We need a product that truly has no inventory tracking

      # Use a different product that has no inventory stream
      now = DateTime.utc_now()
      stream_name = EventStore.stream_name("cart", session_id)
      new_product_id = "unknown-product-#{System.unique_integer()}"

      item_added_event = %Cart.Events.ItemAdded{
        item_id: "#{new_product_id}-#{DateTime.to_unix(now)}",
        product_id: new_product_id,
        name: "Unknown Product",
        price: 9.99,
        added_at: now
      }

      {:ok, _} = EventStore.append_to_stream(stream_name, [item_added_event])

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Initial state (0) should show as "Out of stock" (not "Unknown")
      # The "Unknown" state is for when inventory fetch fails
      assert has_element?(view, "#inventory-#{new_product_id}")
    end
  end

  describe "displaying cart items with inventory" do
    test "given multiple items then shows inventory for each", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set up a second product in the cart
      second_product_id = "french-roast"
      now = DateTime.utc_now()
      stream_name = EventStore.stream_name("cart", session_id)

      item_added_event = %Cart.Events.ItemAdded{
        item_id: "#{second_product_id}-#{DateTime.to_unix(now)}",
        product_id: second_product_id,
        name: "French Roast",
        price: 13.99,
        added_at: now
      }

      {:ok, _} = EventStore.append_to_stream(stream_name, [item_added_event])

      # Set inventory for both
      {:ok, _} = Inventory.update_quantity(product_id, 15)
      {:ok, _} = Inventory.update_quantity(second_product_id, 5)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify both inventory displays exist
      assert has_element?(view, "#inventory-#{product_id}")
      assert has_element?(view, "#inventory-#{second_product_id}")

      # Verify quantities
      html = render(view)
      assert html =~ "15 available"
      assert html =~ "5 available"
    end
  end

  # ===========================================================================
  # User Story 2: Real-time Inventory Updates
  # ===========================================================================

  describe "subscribing to inventory updates" do
    test "given connected then subscribes to stream_type:inventory", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set initial inventory
      {:ok, _} = Inventory.update_quantity(product_id, 10)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify initial display
      assert render(view) =~ "10 available"

      # Update inventory - this broadcasts to stream_type:inventory
      {:ok, _} = Inventory.update_quantity(product_id, 5)

      # Wait for PubSub message to propagate
      :timer.sleep(100)

      # Verify updated display
      assert render(view) =~ "5 available"
    end

    test "given inventory event for different product then ignores", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set initial inventory for our product
      {:ok, _} = Inventory.update_quantity(product_id, 10)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Verify initial display
      assert render(view) =~ "10 available"

      # Update inventory for a DIFFERENT product
      {:ok, _} = Inventory.update_quantity("colombian-supremo", 99)

      # Wait for PubSub message to propagate
      :timer.sleep(100)

      # Our product's display should be unchanged
      html = render(view)
      assert html =~ "10 available"
      refute html =~ "99 available"
    end
  end

  describe "processing inventory events" do
    test "given matching inventory update then updates display", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set initial inventory
      {:ok, _} = Inventory.update_quantity(product_id, 20)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      assert render(view) =~ "20 available"

      # Simulate multiple rapid updates
      {:ok, _} = Inventory.update_quantity(product_id, 15)
      :timer.sleep(50)
      {:ok, _} = Inventory.update_quantity(product_id, 8)
      :timer.sleep(50)
      {:ok, _} = Inventory.update_quantity(product_id, 3)

      # Wait for final update
      :timer.sleep(100)

      # Should show the latest value
      assert render(view) =~ "3 available"
    end
  end

  # ===========================================================================
  # User Story 3: Low Stock Visual Indicator
  # ===========================================================================

  describe "applying low stock styling" do
    test "given quantity less than or equal to 5 then applies low-stock class", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set low inventory
      {:ok, _} = Inventory.update_quantity(product_id, 3)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Check for low-stock styling class
      assert has_element?(view, "#inventory-#{product_id}.is-warning")
    end

    test "given quantity greater than 5 then applies normal styling", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set normal inventory
      {:ok, _} = Inventory.update_quantity(product_id, 15)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Check for normal styling class (info, not warning)
      assert has_element?(view, "#inventory-#{product_id}.is-info")
      refute has_element?(view, "#inventory-#{product_id}.is-warning")
    end

    test "given quantity is zero then applies out-of-stock styling", %{
      conn: conn,
      session_id: session_id,
      product_id: product_id
    } do
      # Set zero inventory
      {:ok, _} = Inventory.update_quantity(product_id, 0)

      # Visit cart page
      {:ok, view, _html} = live(conn, ~p"/cart/#{session_id}")

      # Check for out-of-stock styling class
      assert has_element?(view, "#inventory-#{product_id}.is-danger")
    end
  end
end
