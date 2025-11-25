defmodule Epoch.Catalog do
  @moduledoc """
  The Catalog context for managing products.
  """

  alias Epoch.Catalog.Product

  @products [
    %Product{
      product_id: "espresso-blend",
      name: "Espresso Blend",
      description: "Rich, bold espresso roast perfect for your morning cup",
      price: Decimal.new("14.99")
    },
    %Product{
      product_id: "french-roast",
      name: "French Roast",
      description: "Dark and smoky with a smooth finish",
      price: Decimal.new("13.99")
    },
    %Product{
      product_id: "colombian-supremo",
      name: "Colombian Supremo",
      description: "Smooth and balanced with hints of caramel",
      price: Decimal.new("15.99")
    },
    %Product{
      product_id: "ethiopian-yirgacheffe",
      name: "Ethiopian Yirgacheffe",
      description: "Fruity and bright with floral notes",
      price: Decimal.new("17.99")
    },
    %Product{
      product_id: "sumatra-mandheling",
      name: "Sumatra Mandheling",
      description: "Earthy and full-bodied with low acidity",
      price: Decimal.new("16.99")
    }
  ]

  @doc """
  Returns all products in the catalog, sorted by name.
  """
  @spec list_products() :: [Product.t()]
  def list_products do
    Enum.sort_by(@products, & &1.name)
  end

  @doc """
  Retrieves a single product by ID.

  Returns `{:ok, product}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get_product(String.t()) :: {:ok, Product.t()} | {:error, :not_found}
  def get_product(product_id) do
    case Enum.find(@products, &(&1.product_id == product_id)) do
      nil -> {:error, :not_found}
      product -> {:ok, product}
    end
  end

  @doc """
  Retrieves a single product by ID, raises on not found.
  """
  @spec get_product!(String.t()) :: Product.t()
  def get_product!(product_id) do
    case get_product(product_id) do
      {:ok, product} -> product
      {:error, :not_found} -> raise ArgumentError, "Product not found: #{product_id}"
    end
  end
end
