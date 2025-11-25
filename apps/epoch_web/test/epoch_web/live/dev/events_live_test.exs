defmodule EpochWeb.Dev.EventsLiveTest do
  use EpochWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Epoch.EventStore

  # Test event structs
  defmodule OrderPlaced do
    defstruct [:order_id, :product, :quantity]
  end

  defmodule CartCreated do
    defstruct [:cart_id, :user_id]
  end

  # Helper to create unique stream names
  defp unique_stream_name(type, id \\ nil) do
    id = id || System.unique_integer([:positive])
    "#{type}-#{id}"
  end

  # ==========================================================================
  # Phase 3: User Story 1 - LiveView filter workflow integration tests
  # ==========================================================================

  describe "EventsLive mount" do
    test "mounts successfully at /dev/events", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/events")

      assert has_element?(view, "#filter-form")
    end

    test "shows empty state message on mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dev/events")

      assert html =~ "Enter a stream type to view events"
    end
  end

  describe "EventsLive filter workflow" do
    test "filters events by type and displays results", %{conn: conn} do
      # Create test events
      order_stream = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(order_stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Submit filter form
      view
      |> form("#filter-form", %{stream_type: "order"})
      |> render_submit()

      # Should show results
      assert has_element?(view, "#events")
    end

    test "shows no events message when no matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Submit filter form with non-matching type
      html =
        view
        |> form("#filter-form", %{
          stream_type: "nonexistent_type_#{System.unique_integer([:positive])}"
        })
        |> render_submit()

      assert html =~ "No events found"
    end

    test "clears filter when clear button clicked", %{conn: conn} do
      order_stream = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(order_stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter first
      view
      |> form("#filter-form", %{stream_type: "order"})
      |> render_submit()

      # Then clear
      html =
        view
        |> element("button[phx-click=clear_filter]")
        |> render_click()

      assert html =~ "Enter a stream type to view events"
    end
  end

  # ==========================================================================
  # Phase 4: User Story 2 - Live updates integration tests
  # ==========================================================================

  describe "EventsLive live updates" do
    test "receives new events via PubSub when filtered", %{conn: conn} do
      # Create initial event
      order_stream = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(order_stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter by order type
      view
      |> form("#filter-form", %{stream_type: "order"})
      |> render_submit()

      # Create a new order stream and append event (triggers PubSub broadcast)
      new_order_stream = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(new_order_stream, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      # Wait for live update to arrive
      # The LiveView should receive the PubSub message and update
      :timer.sleep(100)
      html = render(view)

      # Should show the new event's stream name
      assert html =~ new_order_stream
    end

    test "does not receive events for non-matching stream types", %{conn: conn} do
      order_stream = unique_stream_name("order")

      {:ok, _} =
        EventStore.append_to_stream(order_stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter by order type
      view
      |> form("#filter-form", %{stream_type: "order"})
      |> render_submit()

      # Create a cart event (different type)
      cart_stream = unique_stream_name("cart")

      {:ok, _} =
        EventStore.append_to_stream(cart_stream, [%CartCreated{cart_id: "c1", user_id: "u1"}])

      # Wait and check
      :timer.sleep(100)
      html = render(view)

      # Should NOT show the cart event
      refute html =~ cart_stream
    end
  end

  # ==========================================================================
  # Phase 5: User Story 3 - Pagination UI integration tests
  # ==========================================================================

  describe "EventsLive pagination" do
    defp unique_pagetype, do: "pagetype#{System.unique_integer([:positive])}"

    test "pagination controls display when results exist", %{conn: conn} do
      type = unique_pagetype()

      # Create 5 events
      for i <- 1..5 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter by type
      view
      |> form("#filter-form", %{stream_type: type})
      |> render_submit()

      html = render(view)

      # Should show pagination controls
      assert html =~ "Page 1"
      assert has_element?(view, "button", "Previous")
      assert has_element?(view, "button", "Next")
    end

    test "navigating to next page shows different events", %{conn: conn} do
      type = unique_pagetype()

      # Create 25 events (more than default page size of 20)
      for i <- 1..25 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter by type
      view
      |> form("#filter-form", %{stream_type: type})
      |> render_submit()

      # Should be on page 1
      html = render(view)
      assert html =~ "Page 1"
      # First event should have order_id "1" (HTML escapes quotes as &quot;)
      assert html =~ "order_id: &quot;1&quot;"

      # Click next page
      view |> element("button", "Next") |> render_click()

      html = render(view)
      assert html =~ "Page 2"
      # Page 2 should show order_id "21" (first of remaining 5)
      assert html =~ "order_id: &quot;21&quot;"
      # Should not show order_id "1" anymore
      refute html =~ "order_id: &quot;1&quot;"
    end

    test "navigating back to previous page", %{conn: conn} do
      type = unique_pagetype()

      # Create 25 events
      for i <- 1..25 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      # Filter and go to page 2
      view |> form("#filter-form", %{stream_type: type}) |> render_submit()
      view |> element("button", "Next") |> render_click()

      html = render(view)
      assert html =~ "Page 2"

      # Go back to page 1
      view |> element("button", "Previous") |> render_click()

      html = render(view)
      assert html =~ "Page 1"
      assert html =~ "order_id: &quot;1&quot;"
    end

    test "previous button is disabled on page 1", %{conn: conn} do
      type = unique_pagetype()

      # Create a few events
      for i <- 1..3 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      view |> form("#filter-form", %{stream_type: type}) |> render_submit()

      # Previous button should be disabled on page 1
      assert has_element?(view, "button[disabled]", "Previous")
    end

    test "next button is disabled when no more pages", %{conn: conn} do
      type = unique_pagetype()

      # Create only 3 events (less than default page size of 20)
      for i <- 1..3 do
        stream = unique_stream_name(type)

        {:ok, _} =
          EventStore.append_to_stream(stream, [
            %OrderPlaced{order_id: "#{i}", product: "P#{i}", quantity: i}
          ])
      end

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      view |> form("#filter-form", %{stream_type: type}) |> render_submit()

      # Next button should be disabled when there are no more pages
      assert has_element?(view, "button[disabled]", "Next")
    end
  end

  # ==========================================================================
  # Phase 6: User Story 4 - Stream name display integration tests
  # ==========================================================================

  describe "EventsLive stream name display" do
    defp unique_displaytype, do: "displaytype#{System.unique_integer([:positive])}"

    test "stream name is visible for each event in list", %{conn: conn} do
      type = unique_displaytype()
      stream1 = unique_stream_name(type)
      stream2 = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream1, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(stream2, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      view |> form("#filter-form", %{stream_type: type}) |> render_submit()

      html = render(view)

      # Both stream names should be visible in the rendered HTML
      assert html =~ stream1
      assert html =~ stream2
    end

    test "correct stream name displayed per event", %{conn: conn} do
      type = unique_displaytype()
      stream1 = unique_stream_name(type)
      stream2 = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream1, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, _} =
        EventStore.append_to_stream(stream2, [
          %OrderPlaced{order_id: "2", product: "Gadget", quantity: 2}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      view |> form("#filter-form", %{stream_type: type}) |> render_submit()

      html = render(view)

      # Stream names should appear in the output
      # The stream name appears in a span with font-mono class
      assert html =~ ~r/<span class="font-mono[^"]*">#{stream1}<\/span>/
      assert html =~ ~r/<span class="font-mono[^"]*">#{stream2}<\/span>/
    end

    test "stream name is displayed prominently for each event row", %{conn: conn} do
      type = unique_displaytype()
      stream = unique_stream_name(type)

      {:ok, _} =
        EventStore.append_to_stream(stream, [
          %OrderPlaced{order_id: "1", product: "Widget", quantity: 1}
        ])

      {:ok, view, _html} = live(conn, ~p"/dev/events")

      view |> form("#filter-form", %{stream_type: type}) |> render_submit()

      # Stream name should be in the event display area
      assert has_element?(view, "#events", stream)
    end
  end
end
