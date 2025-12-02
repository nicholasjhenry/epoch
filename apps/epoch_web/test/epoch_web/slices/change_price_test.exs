defmodule Epoch.Slices.ChangePriceTest do
  # Tests run synchronously to avoid EventStore state pollution
  use ExUnit.Case, async: false

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.EventStore
  alias Epoch.Slices.ChangePrice.Command, as: ChangePrice
  alias Epoch.Slices.ChangePrice.CommandHandler

  # Use a unique product suffix for each test to avoid state pollution
  # from the shared EventStore instance started by the application
  setup do
    suffix = System.unique_integer([:positive])
    # We'll use real products but track old_price behavior differently
    %{test_suffix: suffix}
  end

  describe "handle/1 with valid product" do
    test "emits PriceChanged event to price stream" do
      # Use french-roast to avoid pollution from other tests
      product_id = "french-roast"

      # STEP: When
      {:ok, event} =
        CommandHandler.handle(%ChangePrice{
          product_id: product_id,
          new_price: Decimal.new("15.99")
        })

      # STEP: Then
      assert %PriceChanged{} = event
      assert event.product_id == product_id
      assert Decimal.equal?(event.new_price, Decimal.new("15.99"))
      assert %DateTime{} = event.changed_at

      # Verify event was persisted to stream
      stream_name = EventStore.stream_name("price", product_id)
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)
      assert length(events) >= 1
      # The last event should be our new event
      last_event = List.last(events)
      assert %PriceChanged{} = last_event
      assert Decimal.equal?(last_event.new_price, Decimal.new("15.99"))
    end

    test "subsequent price change includes old_price" do
      # Use colombian-supremo for this test
      product_id = "colombian-supremo"

      # STEP: Given - first price change
      {:ok, first_event} =
        CommandHandler.handle(%ChangePrice{
          product_id: product_id,
          new_price: Decimal.new("14.99")
        })

      # STEP: When - second price change
      {:ok, second_event} =
        CommandHandler.handle(%ChangePrice{
          product_id: product_id,
          new_price: Decimal.new("16.99")
        })

      # STEP: Then - old_price should be the first event's new_price
      assert Decimal.equal?(second_event.old_price, first_event.new_price)
      assert Decimal.equal?(second_event.new_price, Decimal.new("16.99"))
    end
  end

  describe "handle/1 with invalid product" do
    test "returns error when product does not exist" do
      # STEP: When
      result =
        CommandHandler.handle(%ChangePrice{
          product_id: "nonexistent-product",
          new_price: Decimal.new("15.99")
        })

      # STEP: Then
      assert {:error, :product_not_found} = result
    end
  end

  describe "handle/1 with invalid price" do
    test "returns error when price is zero" do
      # STEP: When
      result =
        CommandHandler.handle(%ChangePrice{
          product_id: "espresso-blend",
          new_price: Decimal.new("0")
        })

      # STEP: Then
      assert {:error, :invalid_price} = result
    end

    test "returns error when price is negative" do
      # STEP: When
      result =
        CommandHandler.handle(%ChangePrice{
          product_id: "espresso-blend",
          new_price: Decimal.new("-5.00")
        })

      # STEP: Then
      assert {:error, :invalid_price} = result
    end
  end
end
