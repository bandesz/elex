defmodule Elex.Units.VariablesTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature
  alias Elex.Variable

  setup do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    %{ctx: ctx}
  end

  describe "add_variable/4 with category" do
    test "accepts category with a {number, unit} value", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", {10, "cm"}, category: :length)
      assert %Variable{type: :length, value: {10, "cm"}} = ctx.variables["width"]
    end

    test "accepts category with a Quantity value", %{ctx: ctx} do
      quantity = %Elex.Quantity{value: Decimal.new("10"), unit: "cm"}
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", quantity, category: :length)

      assert %Variable{
               type: :length,
               value: %Elex.Quantity{
                 value: value,
                 unit: %Unit{monomial: %{"cm" => 1}}
               }
             } = ctx.variables["width"]

      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end

    test "rejects category with a unitless value", %{ctx: ctx} do
      assert {:error, message} = Elex.add_variable(ctx, "width", 10, category: :length)
      assert message == "variable 'width' has category length but value is unitless"
    end

    test "rejects a {number, unit} value without a category", %{ctx: ctx} do
      assert {:error, message} = Elex.add_variable(ctx, "width", {10, "cm"})
      assert message == "variable 'width' has a unit but no category"
    end

    test "rejects a Quantity without a category", %{ctx: ctx} do
      quantity = %Elex.Quantity{value: Decimal.new("10"), unit: "cm"}
      assert {:error, message} = Elex.add_variable(ctx, "width", quantity)
      assert message == "variable 'width' has a unit but no category"
    end

    test "rejects a value unit that is not in the declared category", %{ctx: ctx} do
      assert {:error, message} =
               Elex.add_variable(ctx, "width", {10, "kg"}, category: :length)

      assert message == "unit 'kg' is not in category length"
    end

    test "rejects a Quantity unit that is not in the declared category", %{ctx: ctx} do
      quantity = %Elex.Quantity{value: Decimal.new("10"), unit: "kg"}
      assert {:error, message} = Elex.add_variable(ctx, "width", quantity, category: :length)
      assert message == "unit 'kg' is not in category length"
    end

    test "accepts an evaluated symbol Quantity with matching category", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("10cm", ctx)
      assert %Unit{monomial: %{"cm" => 1}} = quantity.unit
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", quantity, category: :length)
      assert %Variable{type: :length, value: ^quantity} = ctx.variables["width"]
    end
  end

  describe "validate/2 with category variables" do
    test "width + 1mm validates as :length", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", {10, "cm"}, category: :length)
      assert Elex.validate("width + 1mm", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "unitless count * 1mm validates as :length", %{ctx: ctx} do
      {:ok, ctx} = Elex.add_variable(ctx, "count", 3)
      assert Elex.validate("count * 1mm", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end
  end

  describe "evaluate/2 with category variables" do
    test "adds a length variable into its own unit", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", {10, "cm"}, category: :length)
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("width + 1mm", ctx)
      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("10.1")) == :eq
    end

    test "adds a length Quantity variable into its own unit", %{ctx: ctx} do
      quantity = %Elex.Quantity{value: Decimal.new("10"), unit: "cm"}
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", quantity, category: :length)
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("width + 1mm", ctx)
      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("10.1")) == :eq
    end

    test "scales a unit by a unitless variable", %{ctx: ctx} do
      {:ok, ctx} = Elex.add_variable(ctx, "count", 3)
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("count * 1mm", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("3")) == :eq
    end

    test "adds an evaluated symbol Quantity back into its own unit", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("10cm", ctx)
      assert {:ok, ctx} = Elex.add_variable(ctx, "width", quantity, category: :length)
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("width + 1mm", ctx)
      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("10.1")) == :eq
    end
  end

  describe "Quantity round-trip with derived monomials" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "h", "value * 3600")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed,
          formula: "length | time",
          default: "m | s"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "adds an evaluated monomial Quantity back with matching category", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("10m / 1s", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = quantity.unit
      assert {:ok, ctx} = Elex.add_variable(ctx, "speed", quantity, category: :speed)

      assert Elex.validate("speed", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -1}}}

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("speed * 1s", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end

    test "rejects a {number, compound unit} that is not a registered symbol", %{ctx: ctx} do
      assert {:error, message} =
               Elex.add_variable(ctx, "speed", {10, "km | h"}, category: :speed)

      assert message == "unknown unit 'km | h'"
    end

    test "rejects a monomial Quantity whose category does not match", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("10m / 1s", ctx)

      assert {:error, message} =
               Elex.add_variable(ctx, "width", quantity, category: :length)

      assert message == "unit 'm | s' is not in category length"
    end
  end

  describe "add_variable/4 with unit aliases" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2", aliases: ["m2", "sqm"])

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "evaluates a {number, alias} variable as the canonical monomial", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "area", {5, "m2"}, category: :area)
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate("area", ctx)
      assert %Unit{monomial: %{"m" => 2}} = unit
      refute Map.has_key?(unit.monomial, "m2")
      assert Decimal.compare(value, Decimal.new("5")) == :eq
      assert inspect(qty) == "#Elex.Quantity<5 m^2>"
    end

    test "treats a {number, alias} variable as the same unit as 1m * 1m", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "area", {5, "m2"}, category: :area)
      assert {:ok, %Elex.Quantity{unit: from_var}} = Elex.evaluate("area", ctx)
      assert {:ok, %Elex.Quantity{unit: from_product}} = Elex.evaluate("1m * 1m", ctx)
      assert Unit.same?(from_var, from_product)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("area + 1m * 1m", ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("6")) == :eq
    end

    test "canonicalizes a Quantity whose unit string is an alias", %{ctx: ctx} do
      quantity = %Elex.Quantity{value: Decimal.new("5"), unit: "m2"}
      assert {:ok, ctx} = Elex.add_variable(ctx, "area", quantity, category: :area)
      assert {:ok, %Elex.Quantity{unit: unit} = qty} = Elex.evaluate("area", ctx)
      assert %Unit{monomial: %{"m" => 2}} = unit
      assert inspect(qty) == "#Elex.Quantity<5 m^2>"
    end
  end

  describe "non-additive Quantity variables" do
    setup do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())
      %{ctx: ctx}
    end

    test "rejects multiplying a non-additive Quantity variable", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("32F", ctx)
      assert %Unit{monomial: %{"F" => 1}} = quantity.unit
      assert {:ok, ctx} = Elex.add_variable(ctx, "temp", quantity, category: :temperature)
      assert {:error, message} = Elex.validate("temp * 2", ctx)
      assert message == "cannot use non-additive temperature with '*' or '/'"
    end
  end
end
