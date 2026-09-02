defmodule Elex.Units.TemperatureTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  setup do
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog())
    %{ctx: ctx}
  end

  test "temperature catalog is non-additive" do
    assert Temperature.catalog().categories[:temperature].additive == false
  end

  test "converts 32F to 0 C via unit:", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate("32F", ctx, unit: "C")

    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("0")) == :eq
  end

  test "converts 0C to 32 F via unit:", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate("0C", ctx, unit: "F")

    assert %Elex.Unit{monomial: %{"F" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("32")) == :eq
  end

  test "converts 32F to 0 C via convert/2", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|convert(32F, "C")|, ctx)

    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("0")) == :eq
  end

  test "compares same-unit temperatures", %{ctx: ctx} do
    assert Elex.evaluate("1C > 0C", ctx) == {:ok, true}
  end

  test "rejects comparing temperature to literal 0", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("1C > 0", ctx)
    assert message == "cannot compare temperature and number"
    assert {:error, ^message} = Elex.evaluate("1C > 0", ctx)
  end

  test "rejects min of temperature and literal 0", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("min(1C, 0)", ctx)
    assert message == "cannot mix temperature and number"
    assert {:error, ^message} = Elex.evaluate("min(1C, 0)", ctx)
  end

  test "min of same-unit temperatures keeps C", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("min(1C, 2C)", ctx)
    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("1")) == :eq
  end

  test "ceil of a temperature keeps C", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("ceil(1.2C)", ctx)
    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("2")) == :eq
  end

  test "if of same-unit temperatures keeps C", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate("if(true, 1C, 2C)", ctx)

    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("1")) == :eq
  end

  test "between same-unit temperatures", %{ctx: ctx} do
    assert Elex.evaluate("between(50C, 0C, 100C)", ctx) == {:ok, true}
  end

  test "unary minus of a temperature", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("-5C", ctx)
    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("-5")) == :eq
  end

  test "min of 1C and convert 33F to C", %{ctx: ctx} do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
             Elex.evaluate(~S|min(1C, convert(33F, "C"))|, ctx)

    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    expected = Decimal.div(Decimal.new(5), Decimal.new(9))
    assert Decimal.compare(value, expected) == :eq
  end

  test "rejects adding temperatures on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("1C + 2C", ctx)
    assert message == "cannot use non-additive temperature with '+'"
  end

  test "rejects adding temperatures on evaluate", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("1C + 2C", ctx)
    assert message == "cannot use non-additive temperature with '+'"
  end

  test "rejects adding mixed C and F on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("0C + 10F", ctx)
    assert message == "cannot use non-additive temperature with '+'"
  end

  test "rejects adding mixed C and F on evaluate", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("0C + 10F", ctx)
    assert message == "cannot use non-additive temperature with '+'"
  end

  test "rejects adding C to an already-converted C on validate and evaluate", %{ctx: ctx} do
    expr = "0C + convert(32F, \"C\")"
    assert {:error, message} = Elex.validate(expr, ctx)
    assert message == "cannot use non-additive temperature with '+'"
    assert {:error, ^message} = Elex.evaluate(expr, ctx)
  end

  test "rejects multiplying a scalar by C on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("2 * 1C", ctx)
    assert message == "cannot use non-additive temperature with '*' or '/'"
  end

  test "rejects multiplying a scalar by C on evaluate", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("2 * 1C", ctx)
    assert message == "cannot use non-additive temperature with '*' or '/'"
  end

  test "rejects dividing C by time on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("1C / 1s", ctx)
    assert message == "cannot use non-additive temperature with '*' or '/'"
  end

  test "rejects dividing C by C", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("10C / 50C", ctx)
    assert message == "cannot use non-additive temperature with '*' or '/'"
  end

  test "rejects if with mixed C and F on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("if(true, 1C, 2F)", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects if with mixed C and F on evaluate", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("if(true, 1C, 2F)", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects min with mixed C and F on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("min(1C, 32F)", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects min with mixed C and F on evaluate", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("min(1C, 32F)", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects clamp with mixed C and F", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("clamp(1C, 0C, 32F)", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects comparing mixed C and F on validate", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("1C > 32F", ctx)
    assert message == "cannot mix units of non-additive temperature"
  end

  test "rejects equality of mixed C and F", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("32F == 0C", ctx)
    assert message == "cannot mix units of non-additive temperature"
    assert {:error, ^message} = Elex.evaluate("32F == 0C", ctx)
  end

  test "rejects inequality of mixed C and F", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("1C != 32F", ctx)
    assert message == "cannot mix units of non-additive temperature"
    assert {:error, ^message} = Elex.evaluate("1C != 32F", ctx)
  end

  test "rejects a compound target that includes F", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("1Cps", ctx, unit: "F | s")
    assert message == "cannot use non-additive unit 'F' in a compound target"
  end

  test "a C-only catalog without additive: false still allows scaling" do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :temperature, default: "C")
    {:ok, catalog} = Catalog.add_unit(catalog, :temperature, "C", "value")
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("2 * 1C", ctx)
    assert %Elex.Unit{monomial: %{"C" => 1}} = unit
    assert Decimal.compare(value, Decimal.new("2")) == :eq
  end

  defp catalog do
    with_time_and_rate(Temperature.catalog())
  end

  defp with_time_and_rate(catalog) do
    # Cps is a named temperature/time unit so `unit: "F | s"` can test a compound
    # non-additive target. The units guide's linear Cps example is a different
    # catalog shape; this derived category exists only to match dims.
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :temperature_rate,
        formula: "temperature | time",
        default: "Cps"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :temperature_rate, "Cps", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :temperature_rate, "C | s", "value")
    catalog
  end
end
