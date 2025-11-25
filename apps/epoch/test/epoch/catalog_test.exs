defmodule Epoch.CatalogTest do
  use ExUnit.Case, async: true

  alias Epoch.Catalog
  alias Epoch.Catalog.Product

  describe "list_products/0" do
    test "returns all 5 products" do
      products = Catalog.list_products()
      assert length(products) == 5
    end

    test "returns products sorted by name" do
      products = Catalog.list_products()
      names = Enum.map(products, & &1.name)
      assert names == Enum.sort(names)
    end

    test "all products have required fields" do
      for product <- Catalog.list_products() do
        assert %Product{} = product
        assert is_binary(product.product_id)
        assert is_binary(product.name)
        assert is_binary(product.description)
        assert %Decimal{} = product.price
      end
    end

    test "returns the expected coffee products" do
      products = Catalog.list_products()
      product_ids = Enum.map(products, & &1.product_id)

      assert "espresso-blend" in product_ids
      assert "french-roast" in product_ids
      assert "colombian-supremo" in product_ids
      assert "ethiopian-yirgacheffe" in product_ids
      assert "sumatra-mandheling" in product_ids
    end
  end

  describe "get_product/1" do
    test "returns product when found" do
      assert {:ok, %Product{product_id: "espresso-blend"}} =
               Catalog.get_product("espresso-blend")
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Catalog.get_product("invalid-id")
    end

    test "returns correct product details" do
      {:ok, product} = Catalog.get_product("espresso-blend")

      assert product.name == "Espresso Blend"
      assert product.description == "Rich, bold espresso roast perfect for your morning cup"
      assert Decimal.equal?(product.price, Decimal.new("14.99"))
    end
  end

  describe "get_product!/1" do
    test "returns product when found" do
      assert %Product{product_id: "espresso-blend"} =
               Catalog.get_product!("espresso-blend")
    end

    test "raises when not found" do
      assert_raise ArgumentError, ~r/Product not found/, fn ->
        Catalog.get_product!("invalid-id")
      end
    end
  end
end
