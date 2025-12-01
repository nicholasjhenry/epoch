defmodule Epoch.Slices.ChangePrice.CommandHandler do
  @moduledoc """
  Handles the ChangePrice command by delegating to the Price context.
  """

  alias Epoch.Backoffice.Events.PriceChanged
  alias Epoch.Backoffice.Price
  alias Epoch.Slices.ChangePrice.Command

  @doc """
  Handles a ChangePrice command.

  Validates the product exists in the catalog and that the new price is valid,
  then emits a PriceChanged event to the price stream.

  Returns `{:ok, event}` on success, `{:error, reason}` on failure.
  """
  @spec handle(Command.t()) :: {:ok, PriceChanged.t()} | {:error, atom()}
  def handle(%Command{product_id: product_id, new_price: new_price}) do
    Price.change_price(%{product_id: product_id, new_price: new_price})
  end
end
