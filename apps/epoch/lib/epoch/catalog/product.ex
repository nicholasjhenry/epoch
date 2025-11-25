defmodule Epoch.Catalog.Product do
  @moduledoc """
  Represents a coffee product in the catalog.

  Products are currently hardcoded but structured to support
  future database migration.
  """

  @type t :: %__MODULE__{
          product_id: String.t(),
          name: String.t(),
          description: String.t(),
          price: Decimal.t()
        }

  defstruct [:product_id, :name, :description, :price]
end
