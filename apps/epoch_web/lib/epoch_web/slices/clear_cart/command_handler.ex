defmodule Epoch.Slices.ClearCart.CommandHandler do
  @moduledoc """
  Handles the ClearCart command by validating that the cart is non-empty
  and appending a CartCleared event to the cart stream.
  """

  require Logger

  alias Epoch.Cart
  alias Epoch.Cart.Events.CartCleared
  alias Epoch.EventStore
  alias Epoch.Slices.ClearCart.Command

  @doc """
  Handles the clear cart command.

  Returns `{:ok, cart_state}` on success or `{:error, reason}` on failure.

  ## Errors

  - `{:error, :cart_empty}` - Cart has no items to clear
  """
  @spec handle(Command.t()) :: {:ok, Cart.CartItemsView.state()} | {:error, term()}
  def handle(%Command{} = command) do
    with {:ok, cart_state} <- Cart.get_cart_items(command.session_id),
         :ok <- validate_not_empty(cart_state) do
      event = %CartCleared{cleared_at: DateTime.utc_now()}
      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} ->
          Cart.get_cart_items(command.session_id)

        {:error, reason} = error ->
          Logger.error(
            "Failed to append CartCleared event: session_id=#{command.session_id}, reason=#{inspect(reason)}"
          )

          error
      end
    end
  end

  defp validate_not_empty(%{items: []}), do: {:error, :cart_empty}
  defp validate_not_empty(_state), do: :ok
end
