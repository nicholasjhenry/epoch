defmodule Epoch.Splices.AddItemTest do
  use ExUnit.Case

  alias Epoch.Cart
  alias Epoch.EventStore
  alias Epoch.Slices.AddItem.Command, as: AddItem
  alias Epoch.Slices.AddItem.CommandHandler

  setup do
    # Start a fresh EventStore for each test
    start_supervised!({Epoch.EventStore, name: :"test_event_store_#{System.unique_integer()}"})

    {:ok, session} = Ecto.UUID.generate() |> Cart.create_session()

    %{session: session}
  end

  test "given session does not exist then session is created and item added" do
    # STEP: Given
    session_id = Ecto.UUID.generate()
    assert {:error, :not_found} = Cart.get_session(session_id)

    # STEP: When
    {:ok, session} =
      CommandHandler.handle(%AddItem{
        session_id: session_id,
        product_id: "espresso-blend"
      })

    # STEP: Then
    assert session.session_id == session_id
    assert [%{product_id: "espresso-blend", quantity: 1}] = session.items
  end

  test "given no items added then item added", %{session: session} do
    # STEP: When
    {:ok, _session} =
      CommandHandler.handle(%AddItem{
        session_id: session.session_id,
        product_id: "espresso-blend"
      })

    # STEP: Then
    {:ok, session} = Cart.get_session(session.session_id)
    assert [%{product_id: "espresso-blend", quantity: 1}] = session.items
  end

  test "given cart has 3 items then adding another returns error", %{session: session} do
    # STEP: Given - add 3 items (mix of products)
    stream_name = EventStore.stream_name("cart", session.session_id)
    now = DateTime.utc_now()

    events = [
      %Cart.Events.ItemAdded{
        item_id: "espresso-blend-#{DateTime.to_unix(now)}-1",
        product_id: "espresso-blend",
        name: "Espresso Blend",
        price: 14.99,
        added_at: now
      },
      %Cart.Events.ItemAdded{
        item_id: "french-roast-#{DateTime.to_unix(now)}-1",
        product_id: "french-roast",
        name: "French Roast",
        price: 13.99,
        added_at: now
      },
      %Cart.Events.ItemAdded{
        item_id: "colombian-supremo-#{DateTime.to_unix(now)}-1",
        product_id: "colombian-supremo",
        name: "Colombian Supremo",
        price: 15.99,
        added_at: now
      }
    ]

    {:ok, _} = EventStore.append_to_stream(stream_name, events)

    # STEP: Then - adding any item should fail
    assert {:error, :cart_limit_exceeded} =
             CommandHandler.handle(%AddItem{
               session_id: session.session_id,
               product_id: "espresso-blend"
             })
  end
end
