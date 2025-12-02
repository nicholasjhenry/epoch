defmodule Epoch.Slices.SubmitCart.CommandHandler do
  @moduledoc """
  Handles the SubmitCart command by validating cart state and inventory,
  then appending a CartSubmitted event to the cart stream.
  """

  require Logger

  alias Epoch.Cart
  alias Epoch.Cart.Events.CartSubmitted
  alias Epoch.EventStore
  alias Epoch.Slices.SubmitCart.Command
  alias Epoch.Slices.SubmitCart.InventoriesView

  @doc """
  Handles the submit cart command.

  Returns `{:ok, event}` on success or `{:error, reason}` on failure.

  ## Errors

  - `{:error, :cart_empty}` - Cart has no active items
  - `{:error, {:insufficient_inventory, product_ids}}` - One or more products have 0 inventory
  """
  @spec handle(Command.t()) :: {:ok, CartSubmitted.t()} | {:error, term()}
  def handle(%Command{} = command) do
    with {:ok, cart_state} <- Cart.get_cart_items(command.session_id),
         :ok <- validate_not_empty(cart_state),
         :ok <- validate_inventory(cart_state) do
      event = %CartSubmitted{
        cart_id: command.session_id,
        submitted_at: DateTime.utc_now()
      }

      stream_name = EventStore.stream_name("cart", command.session_id)

      case EventStore.append_to_stream(stream_name, [event]) do
        {:ok, _} ->
          {:ok, event}

        {:error, reason} = error ->
          Logger.error(
            "Failed to append CartSubmitted event: session_id=#{command.session_id}, reason=#{inspect(reason)}"
          )

          error
      end
    end
  end

  defp validate_not_empty(%{items: []}), do: {:error, :cart_empty}
  defp validate_not_empty(_state), do: :ok

  defp validate_inventory(%{items: items}) do
    # Build inventory map for all products in cart
    product_ids = items |> Enum.map(& &1.product_id) |> Enum.uniq()

    inventory_map = build_inventory_map(product_ids)

    # Check each product has quantity > 0
    out_of_stock =
      product_ids
      |> Enum.filter(fn product_id ->
        InventoriesView.get_quantity(inventory_map, product_id) == 0
      end)

    case out_of_stock do
      [] -> :ok
      product_ids -> {:error, {:insufficient_inventory, product_ids}}
    end
  end

  defp build_inventory_map(product_ids) do
    Enum.reduce(product_ids, InventoriesView.initial_state(), fn product_id, acc ->
      stream_name = EventStore.stream_name("inventory", product_id)
      {:ok, %{events: events}} = EventStore.read_stream(stream_name)
      Enum.reduce(events, acc, &InventoriesView.evolve(&2, &1))
    end)
  end
end
