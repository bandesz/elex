defmodule Elex.Units.ReciprocalConversionTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  test "rejects a reciprocal conversion on an additive category" do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :fuel, default: "L100km")
    {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "L100km")

    assert {:error, message} = Catalog.add_unit(catalog, :fuel, "mpg", "235.215 / value")

    assert message ==
             "reciprocal conversion for 'mpg' is not allowed on additive category :fuel"

    refute Map.has_key?(catalog.categories[:fuel].units, "mpg")
  end

  describe "non-additive fuel catalog" do
    setup do
      {:ok, catalog} =
        Catalog.add_category(Catalog.new(), :fuel, default: "L100km", additive: false)

      {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "L100km")
      {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "mpg", "235.215 / value")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "converts 30mpg to L100km via unit:", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("30mpg", ctx, unit: "L100km")

      assert %Elex.Unit{monomial: %{"L100km" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("7.8405")) == :eq
    end

    test "converts 10L100km to mpg via unit:", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10L100km", ctx, unit: "mpg")

      assert %Elex.Unit{monomial: %{"mpg" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("23.5215")) == :eq
    end

    test "reports division by zero when converting 0mpg", %{ctx: ctx} do
      assert Elex.evaluate("0mpg", ctx, unit: "L100km") == {:error, "division by zero"}
    end
  end
end
