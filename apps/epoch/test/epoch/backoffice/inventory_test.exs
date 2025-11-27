defmodule Epoch.Backoffice.InventoryTest do
  use ExUnit.Case

  alias Epoch.Backoffice.Inventory
  alias Epoch.Backoffice.InventoryState

  setup do
    # Start a fresh EventStore for each test
    start_supervised!({Epoch.EventStore, name: :"test_event_store_#{System.unique_integer()}"})
    :ok
  end

  describe "updating quantity" do
    test "updates quantity for valid product" do
      assert {:ok, %InventoryState{} = state} =
               Inventory.update_quantity("espresso-blend", 50)

      assert state.product_id == "espresso-blend"
      assert state.quantity == 50
    end

    test "updates quantity to zero (out of stock)" do
      {:ok, _} = Inventory.update_quantity("espresso-blend", 100)

      assert {:ok, %InventoryState{quantity: 0}} =
               Inventory.update_quantity("espresso-blend", 0)
    end

    test "returns error for negative quantity" do
      assert {:error, :invalid_quantity} =
               Inventory.update_quantity("espresso-blend", -5)
    end

    test "returns error for non-integer quantity" do
      assert {:error, :invalid_quantity} =
               Inventory.update_quantity("espresso-blend", 10.5)
    end

    test "returns error for non-existent product" do
      assert {:error, :not_found} =
               Inventory.update_quantity("nonexistent-product", 50)
    end
  end

  describe "getting quantity" do
    test "returns quantity for product with existing inventory" do
      {:ok, _} = Inventory.update_quantity("espresso-blend", 75)

      assert {:ok, 75} = Inventory.get_quantity("espresso-blend")
    end

    test "returns zero for product without inventory" do
      # Use ethiopian-yirgacheffe to avoid collision with other tests
      assert {:ok, 0} = Inventory.get_quantity("ethiopian-yirgacheffe")
    end
  end

  describe "getting state" do
    test "returns full inventory state" do
      {:ok, _} = Inventory.update_quantity("espresso-blend", 42)

      assert {:ok, %InventoryState{} = state} =
               Inventory.get_state("espresso-blend")

      assert state.product_id == "espresso-blend"
      assert state.quantity == 42
    end

    test "returns initial state for product without inventory" do
      # Use sumatra-mandheling to avoid collision with other tests
      assert {:ok, %InventoryState{quantity: 0}} =
               Inventory.get_state("sumatra-mandheling")
    end
  end

  describe "event persistence" do
    test "events are persisted to EventStore stream" do
      # Use french-roast to avoid collision with other tests
      {:ok, _} = Inventory.update_quantity("french-roast", 100)

      # Read events directly from the stream
      stream = Epoch.EventStore.stream_name("inventory", "french-roast")
      {:ok, %{events: events}} = Epoch.EventStore.read_stream(stream)

      assert length(events) == 1
      [event] = events
      assert event.product_id == "french-roast"
      assert event.quantity == 100
    end

    test "state is recovered after reading events from stream" do
      # Use colombian-supremo to avoid collision with other tests
      # Update quantity multiple times
      {:ok, _} = Inventory.update_quantity("colombian-supremo", 100)
      {:ok, _} = Inventory.update_quantity("colombian-supremo", 50)
      {:ok, _} = Inventory.update_quantity("colombian-supremo", 75)

      # Get state should return the latest quantity
      assert {:ok, %InventoryState{quantity: 75}} =
               Inventory.get_state("colombian-supremo")
    end
  end
end
