defmodule Epoch.Slices.RemoveItem.Component do
  @moduledoc """
  LiveComponent for the "Remove" button that removes an item from the cart.
  """
  use EpochWeb, :live_component

  alias Epoch.Slices.RemoveItem.Command, as: RemoveItem
  alias Epoch.Slices.RemoveItem.CommandHandler

  @impl true
  def render(assigns) do
    ~H"""
    <button
      id={"remove-item-#{@item_id}"}
      class="button is-small is-danger is-outlined"
      phx-click="remove_from_cart"
      phx-target={@myself}
      aria-label={"Remove #{@item_name} from cart"}
      title={"Remove #{@item_name}"}
    >
      <span class="icon is-small">
        <i class="fas fa-trash"></i>
      </span>
      <span>Remove</span>
    </button>
    """
  end

  @impl true
  def handle_event("remove_from_cart", _params, socket) do
    result =
      CommandHandler.handle(%RemoveItem{
        session_id: socket.assigns.cart_session_id,
        item_id: socket.assigns.item_id
      })

    case result do
      {:ok, _state} ->
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:flash, :error, error_message(reason)})
        {:noreply, socket}
    end
  end

  defp error_message(:item_not_found), do: "Item not found in cart"
  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(_reason), do: "Unable to remove item from cart"
end
