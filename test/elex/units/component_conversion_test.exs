defmodule Elex.Units.ComponentConversionTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog

  describe "evaluate/3 component-wise target conversion" do
    setup do
      %{ctx: context(speed_catalog())}
    end

    test "keeps leftover m / s without snapping to the hub", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("10m / 1s", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert inspect(%Elex.Quantity{value: value, unit: unit}) == "#Elex.Quantity<10 m | s>"
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end

    test "converts only length for unit: km | s", %{ctx: ctx} do
      assert Catalog.category_for_unit(ctx.units, "km | s") == :error
      assert Catalog.category_for_unit(ctx.units, "km/s") == :error

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / 1s", ctx, unit: "km | s")

      assert %Unit{monomial: %{"km" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("0.01")) == :eq
    end

    test "converts only time for unit: m | h", %{ctx: ctx} do
      assert Catalog.category_for_unit(ctx.units, "m | h") == :error

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / 1s", ctx, unit: "m | h")

      assert %Unit{monomial: %{"m" => 1, "h" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("36000")) == :eq
    end

    test "converts length and time for unit: km | h", %{ctx: ctx} do
      assert Catalog.category_for_unit(ctx.units, "km | h") == :error

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / 1s", ctx, unit: "km | h")

      assert %Unit{monomial: %{"km" => 1, "h" => -1}} = unit
      assert Unit.same?(unit, Unit.new!("km|h"))
      assert Decimal.compare(value, Decimal.new("36")) == :eq
      assert inspect(%Elex.Quantity{value: value, unit: unit}) == "#Elex.Quantity<36 km | h>"
    end

    test "rejects a simple target of a different category", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "km")
      assert message == "expression should return a valid length result"
    end

    test "rejects a formula whose dimension is not the result category", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "m * s")
      assert message == "expression should return a valid length * time result"
    end

    test "treats km*h as length * time, not kilometres per hour", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "km*h")
      assert message == "expression should return a valid length * time result"
    end

    test "rejects an unknown symbol in the target formula", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "foo | s")
      assert message == "unknown unit 'foo'"
    end
  end

  describe "evaluate/3 formula target without :speed" do
    setup do
      %{ctx: context(length_time_catalog())}
    end

    test "converts leftover m / s with unit: km | h when :speed is not registered", %{ctx: ctx} do
      assert Catalog.category_for_unit(ctx.units, "km | h") == :error

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / 1s", ctx, unit: "km | h")

      assert %Unit{monomial: %{"km" => 1, "h" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("36")) == :eq
    end

    test "names the target length category when leftover speed does not match", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "km")
      assert message == "expression should return a valid length result"
    end

    test "keeps a sensible error when the target dim is unnamed", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("10m / 1s", ctx, unit: "m * s")
      assert message == "expression should return a valid length * time result"
    end
  end

  describe "evaluate/3 unit: without a catalog" do
    test "raises when unit: is given with no catalog" do
      assert_raise ArgumentError, "unit: requires a units catalog", fn ->
        Elex.evaluate("1 + 2", Elex.new_context(), unit: "mm")
      end
    end
  end

  describe "convert/2 dim mismatch wording" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")
      %{ctx: context(catalog)}
    end

    test "keeps conversion wording for an in-expression convert", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S|convert(1m, "kg")|, ctx)
      assert message == "cannot convert length to mass"
    end
  end

  describe "evaluate/2 cancel-back to a base category" do
    setup do
      %{ctx: context(speed_length_time_catalog())}
    end

    test "validate of cancelled speed is length", %{ctx: ctx} do
      assert Elex.validate("(1m / 1s) * 1s", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "adds a length after cancelling speed back to metres", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("(1m / 1s) * 1s + 1mm", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1.001")) == :eq
    end

    test "converts cancelled length into the target unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("(1m / 1s) * 1s", ctx, unit: "mm")

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "validate of cancelled length divided by millimetres is decimal", %{ctx: ctx} do
      assert Elex.validate("(1m / 1s) * 1s / 1mm", ctx) == {:ok, :decimal}
    end

    test "converts then cancels same-category division after a cancelled monomial", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("(1m / 1s) * 1s / 1mm", ctx)
      assert Decimal.compare(result, Decimal.new("1000")) == :eq
    end

    test "cancels same-category division after a cancelled monomial to a decimal", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("((1m / 1s) * 1s) / 1m", ctx)
      assert Decimal.compare(result, Decimal.new("1")) == :eq
    end
  end

  describe "evaluate/2 dimensionless divided by a quantity" do
    setup do
      %{ctx: context(speed_length_time_catalog())}
    end

    test "validate of inverted time times length is speed", %{ctx: ctx} do
      assert Elex.validate("1m * (1 / 1s)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -1}}}
    end

    test "evaluates inverted time times length as leftover speed", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * (1 / 1s)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert inspect(%Elex.Quantity{value: value, unit: unit}) == "#Elex.Quantity<1 m | s>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "evaluate/3 acceleration component-wise target" do
    setup do
      %{ctx: context(acceleration_catalog())}
    end

    test "converts the leftover result into mm / (hour * hour)", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10mm / (1hour * 1hour)", ctx, unit: "mm | hour * hour")

      assert %Unit{monomial: %{"mm" => 1, "hour" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end
  end

  defp context(catalog) do
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp length_time_catalog do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "h", "value * 3600")
    catalog
  end

  defp speed_catalog do
    {:ok, catalog} =
      Catalog.add_category(length_time_catalog(), :speed,
        formula: "length | time",
        default: "m | s"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
    catalog
  end

  defp speed_length_time_catalog do
    {:ok, catalog} = Catalog.add_unit(speed_catalog(), :length, "mm", "value / 1000")
    catalog
  end

  defp acceleration_catalog do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "second")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "second", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "hour", "value * 3600")

    {:ok, catalog} =
      Catalog.add_category(catalog, :acceleration,
        formula: "length | time * time",
        default: "m | second * second"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :acceleration, "m | second * second", "value")
    catalog
  end
end
