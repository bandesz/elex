defmodule Elex.Units.AddUnitTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Function
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  setup do
    catalog = Temperature.catalog()
    {:ok, catalog} = Catalog.add_category(catalog, :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    %{ctx: ctx}
  end

  test "declares wrap and unwrap units: policies" do
    assert Function.units(Elex.Functions.AddUnit) == :wrap
    assert Function.units(Elex.Functions.RemoveUnit) == :unwrap
  end

  test "remove_unit returns the magnitude as a decimal", %{ctx: ctx} do
    assert {:ok, result} = Elex.evaluate("remove_unit(2C)", ctx)
    assert %Decimal{} = result
    assert Decimal.compare(result, Decimal.new("2")) == :eq
  end

  test "add_unit wraps a dimensionless number as that unit", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|add_unit(5, "C")|, ctx)

    assert %Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("5")) == :eq
  end

  test "round-trips arithmetic on temperature magnitudes", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|add_unit(remove_unit(2C) + remove_unit(3C), "C")|, ctx)

    assert %Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("5")) == :eq
  end

  test "remove_unit and add_unit work on linear units", %{ctx: ctx} do
    assert {:ok, result} = Elex.evaluate("remove_unit(1mm)", ctx)
    assert %Decimal{} = result
    assert Decimal.compare(result, Decimal.new("1")) == :eq

    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|add_unit(10, "mm")|, ctx)

    assert %Unit{monomial: %{"mm" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("10")) == :eq
  end

  test "linear addition still works without helpers", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m + 1mm", ctx)
    assert %Unit{monomial: %{"m" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("1.001")) == :eq
  end

  test "remove_unit rejects a dimensionless number", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("remove_unit(1)", ctx)
    assert message == "cannot remove unit from a number"
  end

  test "add_unit rejects an already unitful first argument", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate(~S|add_unit(1C, "F")|, ctx)
    assert message == "add_unit cannot wrap a quantity that already has a unit"
  end

  test "add_unit rejects an unknown unit", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate(~S|add_unit(1, "nope")|, ctx)
    assert message == "unknown unit 'nope'"
  end

  test "add_unit wraps a registered formula unit name", %{ctx: ctx} do
    {:ok, catalog} = Catalog.add_category(ctx.units, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s")

    {:ok, catalog} =
      Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

    {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s")
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S[add_unit(5, "m | s")], ctx)

    assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
    assert Decimal.compare(value, Decimal.new("5")) == :eq
  end

  test "add_unit rejects a formula instead of a symbol", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate(~S[add_unit(1, "m | s")], ctx)
    assert message == "add_unit expects a registered unit symbol, got 'm | s'"
  end

  test "validates as decimal and the target unit's category", %{ctx: ctx} do
    assert Elex.validate("remove_unit(2C)", ctx) == {:ok, :decimal}

    assert Elex.validate(~S|add_unit(5, "C")|, ctx) ==
             {:ok, %Elex.Dimension{monomial: %{temperature: 1}}}

    assert Elex.validate(~S|add_unit(10, "mm")|, ctx) ==
             {:ok, %Elex.Dimension{monomial: %{length: 1}}}
  end

  test "add_unit wraps using a string variable unit", %{ctx: ctx} do
    ctx = Elex.add_variable!(ctx, "u", "C")

    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate("add_unit(5, u)", ctx)

    assert %Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("5")) == :eq
  end

  test "validates a string variable unit as that unit's category", %{ctx: ctx} do
    ctx = Elex.add_variable!(ctx, "u", "C")

    assert Elex.validate("add_unit(5, u)", ctx) ==
             {:ok, %Elex.Dimension{monomial: %{temperature: 1}}}
  end

  test "rejects a computed string unit without raising", %{ctx: ctx} do
    expr = "add_unit(5, concat(\"C\", \"\"))"

    assert {:error, validate_message} = Elex.validate(expr, ctx)
    assert validate_message == "add_unit expects a registered unit symbol literal"

    assert {:error, evaluate_message} = Elex.evaluate(expr, ctx)
    assert evaluate_message == "add_unit expects a registered unit symbol literal"
  end

  test "compares add_unit with a same-unit literal", %{ctx: ctx} do
    expr = "add_unit(1, \"C\") == 1C"

    assert Elex.validate(expr, ctx) == {:ok, :boolean}
    assert Elex.evaluate(expr, ctx) == {:ok, true}
  end

  test "min of add_unit and a same-unit literal keeps C", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|min(add_unit(1, "C"), 1C)|, ctx)

    assert %Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("1")) == :eq
  end

  test "rejects min of add_unit with a mixed-unit literal on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate(~S|min(add_unit(1, "C"), 1F)|, ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects min of add_unit C with add_unit F on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate(~S|min(add_unit(1, "C"), add_unit(1, "F"))|, ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  describe "canonical power aliases" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2", "value", aliases: ["m2", "sqm"])

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "wraps a dimensionless number with an area alias as m^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate(~S|add_unit(5, "m2")|, ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("5")) == :eq
      assert inspect(qty) == "#Elex.Quantity<5 m^2>"
    end

    test "wraps a dimensionless number with canonical m^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate(~S|add_unit(5, "m^2")|, ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("5")) == :eq
      assert inspect(qty) == "#Elex.Quantity<5 m^2>"
    end
  end
end
