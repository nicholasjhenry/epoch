defmodule Epoch.Slices.AddItem.CommandHandler do
  @moduledoc """
  Handles the AddItem command by validating quantity limits
  and appending an ItemAddedToCart event to the cart stream.
  """

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemAddedToCart
  alias Epoch.Catalog
  alias Epoch.EventStore
  alias Epoch.Slices.AddItem.Command

  def handle(%Command{} = command) do
    {:ok, session} = Cart.get_session(command.session_id)

    with {:ok, product} <- Catalog.get_product(command.product_id),
         :ok <- validate_quantity(session, product) do
      event = %ItemAddedToCart{
        product_id: command.product_id,
        quantity: command.quantity,
        added_at: DateTime.utc_now()
      }

      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> Cart.get_session(command.session_id)
        {:error, _} = error -> error
      end
    end
  end

  defp validate_quantity(session, product) do
    current_quantity =
      session.items
      |> Enum.filter(fn item -> item.product_id == product.product_id end)
      |> Enum.map(& &1.quantity)
      |> Enum.sum()

    if current_quantity + 1 > 3 do
      {:error, :quantity_exceed}
    else
      :ok
    end
  end
end
