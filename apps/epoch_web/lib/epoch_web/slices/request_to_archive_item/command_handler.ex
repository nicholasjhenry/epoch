defmodule Epoch.Slices.RequestToArchiveItem.CommandHandler do
  @moduledoc """
  Handles the RequestToArchiveItem command.

  Emits an ItemArchiveRequested event to the cart stream when a cart item
  needs to be archived (typically due to price changes).
  """

  alias Epoch.Cart
  alias Epoch.Cart.Events.ItemArchiveRequested
  alias Epoch.Slices.RequestToArchiveItem.Command

  @doc """
  Handles a RequestToArchiveItem command.

  Validates the command parameters and emits an ItemArchiveRequested event
  to the cart stream. Ensures idempotency by checking if the item has already
  been requested for archival.

  Returns `{:ok, event}` on success, `{:error, reason}` on failure.
  """
  @spec handle(Command.t()) :: {:ok, ItemArchiveRequested.t()} | {:error, atom()}
  def handle(%Command{cart_id: nil}), do: {:error, :invalid_cart_id}
  def handle(%Command{item_id: nil}), do: {:error, :invalid_item_id}

  def handle(%Command{cart_id: cart_id, product_id: product_id, item_id: item_id, reason: reason}) do
    Cart.request_item_archive(%{
      cart_id: cart_id,
      product_id: product_id,
      item_id: item_id,
      reason: reason
    })
  end
end
