defmodule Epoch.Slices.RemoveItem.CommandHandler do
  @moduledoc """
  Handles the RemoveItem command by validating item existence
  and appending an ItemRemoved event to the cart stream.
  """

  require Logger

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemRemoved
  alias Epoch.EventStore
  alias Epoch.Slices.RemoveItem.Command

  @doc """
  Handles the remove item command.

  Returns `{:ok, cart_state}` on success or `{:error, reason}` on failure.
  """
  @spec handle(Command.t()) :: {:ok, Cart.CartItemsView.state()} | {:error, term()}
  def handle(%Command{} = command) do
    with {:ok, cart_state} <- Cart.get_cart_items(command.session_id),
         :ok <- validate_item_exists(cart_state, command.item_id) do
      event = %ItemRemoved{
        item_id: command.item_id,
        removed_at: DateTime.utc_now()
      }

      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} ->
          Cart.get_cart_items(command.session_id)

        {:error, reason} = error ->
          Logger.error(
            "Failed to append ItemRemoved event: session_id=#{command.session_id}, item_id=#{command.item_id}, reason=#{inspect(reason)}"
          )

          error
      end
    end
  end

  defp validate_item_exists(cart_state, item_id) do
    case Enum.find(cart_state.items, &(&1.item_id == item_id)) do
      nil ->
        Logger.warning("Attempted to remove non-existent item: item_id=#{item_id}")

        {:error, :item_not_found}

      _item ->
        :ok
    end
  end
end
