defmodule Epoch.CartTest do
  use ExUnit.Case

  alias Epoch.Cart
  alias Epoch.Cart.CartSession

  setup do
    # Start a fresh EventStore for each test
    start_supervised!({Epoch.EventStore, name: :"test_event_store_#{System.unique_integer()}"})
    :ok
  end

  describe "create_session/1" do
    test "creates new cart session" do
      session_id = Ecto.UUID.generate()

      assert {:ok, %CartSession{session_id: ^session_id}} =
               Cart.create_session(session_id)
    end

    test "initializes empty items list" do
      session_id = Ecto.UUID.generate()
      {:ok, session} = Cart.create_session(session_id)

      assert session.items == []
    end

    test "sets created_at timestamp" do
      session_id = Ecto.UUID.generate()
      {:ok, session} = Cart.create_session(session_id)

      assert %DateTime{} = session.created_at
    end
  end

  describe "add_item/3" do
    setup do
      session_id = Ecto.UUID.generate()
      {:ok, _} = Cart.create_session(session_id)
      {:ok, session_id: session_id}
    end

    test "adds valid product to cart", %{session_id: session_id} do
      assert {:ok, session} = Cart.add_item(session_id, "espresso-blend", 1)
      assert [%{product_id: "espresso-blend", quantity: 1}] = session.items
    end

    test "increments quantity for existing item", %{session_id: session_id} do
      {:ok, _} = Cart.add_item(session_id, "espresso-blend", 1)
      {:ok, session} = Cart.add_item(session_id, "espresso-blend", 2)

      assert [%{product_id: "espresso-blend", quantity: 3}] = session.items
    end

    test "adds multiple different products", %{session_id: session_id} do
      {:ok, _} = Cart.add_item(session_id, "espresso-blend", 1)
      {:ok, session} = Cart.add_item(session_id, "french-roast", 2)

      assert length(session.items) == 2
      assert Enum.any?(session.items, &(&1.product_id == "espresso-blend"))
      assert Enum.any?(session.items, &(&1.product_id == "french-roast"))
    end

    test "rejects invalid product", %{session_id: session_id} do
      assert {:error, :not_found} =
               Cart.add_item(session_id, "invalid-product", 1)
    end

    test "defaults quantity to 1" do
      session_id = Ecto.UUID.generate()
      {:ok, _} = Cart.create_session(session_id)
      {:ok, session} = Cart.add_item(session_id, "espresso-blend")

      assert [%{product_id: "espresso-blend", quantity: 1}] = session.items
    end
  end

  describe "get_session/1" do
    test "returns session when exists" do
      session_id = Ecto.UUID.generate()
      {:ok, _} = Cart.create_session(session_id)

      assert {:ok, %CartSession{session_id: ^session_id}} =
               Cart.get_session(session_id)
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Cart.get_session("nonexistent-session-id")
    end

    test "returns session with items after adding" do
      session_id = Ecto.UUID.generate()
      {:ok, _} = Cart.create_session(session_id)
      {:ok, _} = Cart.add_item(session_id, "espresso-blend", 2)

      {:ok, session} = Cart.get_session(session_id)

      assert [%{product_id: "espresso-blend", quantity: 2}] = session.items
    end
  end
end
