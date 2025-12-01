defmodule Epoch.Slices.ArchiveItem.CommandHandler do
  @moduledoc """
  Handles the ArchiveItem command.

  Emits an ItemArchived event to the cart stream when a cart item
  is archived (completing a pending archive request).
  """

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemArchived
  alias Epoch.Slices.ArchiveItem.Command

  @doc """
  Handles an ArchiveItem command.

  Validates the command parameters and emits an ItemArchived event
  to the cart stream. Ensures idempotency by checking if the item has already
  been archived.

  Returns `{:ok, event}` on success, `{:error, reason}` on failure.
  """
  @spec handle(Command.t()) :: {:ok, ItemArchived.t()} | {:error, atom()}
  def handle(%Command{cart_id: nil}), do: {:error, :invalid_cart_id}
  def handle(%Command{item_id: nil}), do: {:error, :invalid_item_id}

  def handle(%Command{cart_id: cart_id, item_id: item_id, reason: reason}) do
    Cart.archive_item(%{
      cart_id: cart_id,
      item_id: item_id,
      reason: reason
    })
  end
end
