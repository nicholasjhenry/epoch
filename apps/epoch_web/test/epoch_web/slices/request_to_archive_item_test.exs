defmodule EpochWeb.Slices.RequestToArchiveItemTest do
  use ExUnit.Case, async: false

  alias Epoch.Cart.Events.ItemArchiveRequested
  alias Epoch.EventStore
  alias Epoch.Slices.RequestToArchiveItem.Command
  alias Epoch.Slices.RequestToArchiveItem.CommandHandler

  setup do
    # Use existing application-started EventStore
    :ok
  end

  describe "when requesting item archive" do
    test "given valid request then emits ItemArchiveRequested event" do
      cart_id = "cart-#{System.unique_integer([:positive])}"
      product_id = "espresso-blend-#{System.unique_integer([:positive])}"
      item_id = "#{product_id}-#{System.unique_integer([:positive])}"

      command = %Command{
        cart_id: cart_id,
        product_id: product_id,
        item_id: item_id,
        reason: "price_changed"
      }

      assert {:ok, event} = CommandHandler.handle(command)

      assert %ItemArchiveRequested{} = event
      assert event.cart_id == cart_id
      assert event.product_id == product_id
      assert event.item_id == item_id
      assert event.reason == "price_changed"
      assert %DateTime{} = event.requested_at

      # Verify event was persisted to cart stream
      stream_name = "cart-#{cart_id}"
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)

      archive_requested_events =
        Enum.filter(events, fn e -> e.__struct__ == ItemArchiveRequested end)

      assert length(archive_requested_events) >= 1
    end

    test "given already requested item then returns error" do
      cart_id = "cart-#{System.unique_integer([:positive])}"
      product_id = "espresso-blend-#{System.unique_integer([:positive])}"
      item_id = "#{product_id}-#{System.unique_integer([:positive])}"

      command = %Command{
        cart_id: cart_id,
        product_id: product_id,
        item_id: item_id,
        reason: "price_changed"
      }

      # First request should succeed
      assert {:ok, _event} = CommandHandler.handle(command)

      # Second request for same item should fail (idempotent)
      assert {:error, :already_requested} = CommandHandler.handle(command)
    end

    test "given missing cart_id then returns error" do
      command = %Command{
        cart_id: nil,
        product_id: "espresso-blend",
        item_id: "item-123",
        reason: "price_changed"
      }

      assert {:error, :invalid_cart_id} = CommandHandler.handle(command)
    end

    test "given missing item_id then returns error" do
      command = %Command{
        cart_id: "cart-123",
        product_id: "espresso-blend",
        item_id: nil,
        reason: "price_changed"
      }

      assert {:error, :invalid_item_id} = CommandHandler.handle(command)
    end
  end
end
