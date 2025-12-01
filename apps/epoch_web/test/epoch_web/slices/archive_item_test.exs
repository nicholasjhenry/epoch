defmodule EpochWeb.Slices.ArchiveItemTest do
  use ExUnit.Case, async: false

  alias Epoch.Cart.Events.ItemArchived
  alias Epoch.EventStore
  alias Epoch.Slices.ArchiveItem.Command
  alias Epoch.Slices.ArchiveItem.CommandHandler

  setup do
    # Use existing application-started EventStore
    :ok
  end

  describe "when archiving item" do
    test "given valid request then emits ItemArchived event" do
      cart_id = "cart-#{System.unique_integer([:positive])}"
      item_id = "item-#{System.unique_integer([:positive])}"

      # Don't create ItemArchiveRequested because ArchiveProcessor will process it
      # Just test that we can archive an item directly
      command = %Command{
        cart_id: cart_id,
        item_id: item_id,
        reason: "price_changed"
      }

      assert {:ok, event} = CommandHandler.handle(command)

      assert %ItemArchived{} = event
      assert event.cart_id == cart_id
      assert event.item_id == item_id
      assert event.reason == "price_changed"
      assert %DateTime{} = event.archived_at

      # Verify event was persisted to cart stream
      stream_name = "cart-#{cart_id}"
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)

      archived_events =
        Enum.filter(events, fn e -> e.__struct__ == ItemArchived end)

      assert length(archived_events) >= 1
    end

    test "given already archived item then returns error (idempotent)" do
      cart_id = "cart-#{System.unique_integer([:positive])}"
      item_id = "item-#{System.unique_integer([:positive])}"

      # First manually archive (not through request, to avoid automation race)
      archived_event = %ItemArchived{
        cart_id: cart_id,
        item_id: item_id,
        reason: "manual_test",
        archived_at: DateTime.utc_now()
      }

      stream_name = "cart-#{cart_id}"
      {:ok, _} = EventStore.append_to_stream(stream_name, [archived_event])

      command = %Command{
        cart_id: cart_id,
        item_id: item_id,
        reason: "price_changed"
      }

      # Archive should fail since item is already archived
      assert {:error, :already_archived} = CommandHandler.handle(command)
    end

    test "given missing cart_id then returns error" do
      command = %Command{
        cart_id: nil,
        item_id: "item-123",
        reason: "price_changed"
      }

      assert {:error, :invalid_cart_id} = CommandHandler.handle(command)
    end

    test "given missing item_id then returns error" do
      command = %Command{
        cart_id: "cart-123",
        item_id: nil,
        reason: "price_changed"
      }

      assert {:error, :invalid_item_id} = CommandHandler.handle(command)
    end
  end
end
