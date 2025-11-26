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

  test "given items added exceeds quantity limit then returns error", %{session: session} do
    # STEP: Given
    stream_name = EventStore.stream_name("cart", session.session_id)

    events = [
      %Cart.Events.ItemAddedToCart{
        product_id: "espresso-blend",
        quantity: 2,
        added_at: DateTime.utc_now()
      }
    ]

    {:ok, _} = EventStore.append_to_stream(stream_name, events)

    # STEP: When
    {:ok, _session} =
      CommandHandler.handle(%AddItem{
        session_id: session.session_id,
        product_id: "espresso-blend"
      })

    # STEP: Then
    assert {:error, :quantity_exceed} =
             CommandHandler.handle(%AddItem{
               session_id: session.session_id,
               product_id: "espresso-blend"
             })
  end
end
