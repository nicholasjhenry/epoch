defmodule Epoch.Slices.AddItem.CommandHandler do
  @moduledoc """
  Handles the AddItem command by validating quantity limits
  and appending an ItemAdded event to the cart stream.
  """

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemAdded
  alias Epoch.Catalog
  alias Epoch.EventStore
  alias Epoch.Slices.AddItem.Command

  @max_items_in_cart 3

  def handle(%Command{} = command) do
    {:ok, session} = get_or_create_session(command.session_id)

    with {:ok, product} <- Catalog.get_product(command.product_id),
         :ok <- validate_cart_limit(session) do
      now = DateTime.utc_now()

      event = %ItemAdded{
        cart_id: command.session_id,
        item_id: "#{command.product_id}-#{DateTime.to_unix(now, :microsecond)}",
        product_id: command.product_id,
        name: product.name,
        price: Decimal.to_float(product.price),
        added_at: now
      }

      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} -> Cart.get_session(command.session_id)
        {:error, _} = error -> error
      end
    end
  end

  defp get_or_create_session(session_id) do
    case Cart.get_session(session_id) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> Cart.create_session(session_id)
    end
  end

  defp validate_cart_limit(session) do
    total_items =
      session.items
      |> Enum.map(& &1.quantity)
      |> Enum.sum()

    if total_items >= @max_items_in_cart do
      {:error, :cart_limit_exceeded}
    else
      :ok
    end
  end
end
